# Semaphore Test Stand

Terraform-based test stands for [Semaphore UI](https://semaphoreui.com). They
spin up reproducible Semaphore environments for end-to-end testing — from
configuring resources inside a single instance to provisioning a full cloud
cluster from scratch.

The repo is split into two independent stands that operate at different layers:

| Stand                | Layer          | What it does                                                                                                                           | Docs                                 |
| -------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| [`stand1`](stand1)   | Application    | Configures resources *inside* a running Semaphore instance — projects, keys, repositories, inventories, environments, and templates.    | [stand1/README.md](stand1/README.md) |
| [`stand2`](stand2)   | Infrastructure | Provisions a complete Semaphore UI *cluster* (load balancer + UI nodes + PostgreSQL + Redis + runners) on DigitalOcean.                  | [stand2/README.md](stand2/README.md) |

The two are independent: `stand1` targets any reachable Semaphore API (typically
a local instance), while `stand2` stands up the cloud infrastructure that
Semaphore itself runs on.

## stand1 — Semaphore resources

Drives a Semaphore instance through the
[`semaphoreui/semaphore`](https://registry.terraform.io/providers/semaphoreui/semaphore/latest/docs)
Terraform provider, declaring the project resources used by the test suite:
projects, SSH/login keys, repositories, inventories, environments (including
variable groups with secrets), and templates that exercise features such as
multiple Ansible vault passwords and env/var secret injection.

```sh
cd stand1
cp terraform.tfvars.example terraform.tfvars   # set api_token
terraform init
terraform apply
```

See [stand1/README.md](stand1/README.md) for obtaining an API token and the full
list of resources.

## stand2 — Cluster infrastructure

Provisions a Semaphore UI cluster on **DigitalOcean**: a load balancer fronting
several stateless UI nodes that share one PostgreSQL database and one Redis
instance, plus a pool of runners. The deployment is split into two Terraform
root modules — [`server/`](stand2/do/server) (the cluster) and
[`runner/`](stand2/do/runner) (the task runners) — driven by wrapper scripts in
[`stand2/do/`](stand2/do). Nodes are configured at boot through the cloud-init
templates in [`stand2/shared/`](stand2/shared).

DNS and TLS are handled by **Cloudflare**: the load balancer is published as a
proxied `<name>-lb.<parent_domain>` record in the Cloudflare-hosted parent
zone, so TLS terminates at the Cloudflare edge with its certificate and no
certificates are managed on the provider side.

Several independent stands can run from the same code: each stand is a
Terraform **workspace**, configured by a directory in
[`workspaces/`](workspaces) (see [workspaces/README.md](workspaces/README.md)).
Credentials and shared settings come from `stand2/.env` (`TF_VAR_*` variables)
rather than per-stack `.tfvars`:

```sh
cd stand2
cp .env.example .env                   # fill in tokens, passwords, keys
cp -r ../workspaces/example ../workspaces/test1   # per-stand config.yml

cd do
./up.sh test1                          # apply server, wait for API, apply runner
./down.sh test1                        # destroy everything
```

`down_servers.sh` / `down_runners.sh` tear down the two halves separately;
`down_servers.sh` keeps the Cloudflare records so a later `up.sh` reuses them.
See [stand2/README.md](stand2/README.md) and
[stand2/do/server/README.md](stand2/do/server/README.md) for details.

## Repository layout

```
.
├── stand1/                 # Semaphore resources via the semaphoreui provider
├── stand2/                 # Cloud cluster infrastructure
│   ├── .env.example        #   TF_VAR_* credentials/settings template
│   ├── do/                 #   DigitalOcean deployment
│   │   ├── server/         #     load balancer + UI cluster + Postgres + Redis
│   │   ├── runner/         #     task runners
│   │   └── up.sh, down*.sh #     wrapper scripts (take a workspace name)
│   └── shared/             #   cloud-init templates and runner config
└── workspaces/             # per-stand config (one dir per Terraform workspace)
    └── example/            #   committed template — copy to start a new stand
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- For `stand1`: a reachable Semaphore instance and an API token
- For `stand2`:
  - A DigitalOcean API token and an SSH key uploaded to DigitalOcean (the
    matching key loaded in your `ssh-agent` — Terraform connects over SSH to
    mint the admin token)
  - A Cloudflare API token (DNS edit + zone read) for the parent domain

## Secrets

This is a **test stand** — secrets are passed to nodes via cloud-init and stored
in local files. State files, `*.tfvars`, `.env*`, generated tokens, and the
per-stand `workspaces/` directories are git-ignored (see
[.gitignore](.gitignore)); only `*.example` templates and `workspaces/example/`
are committed. Copy them and fill in your own values. For production, use a
secrets manager and restrict SSH source IPs in the firewall configuration.

## Domain access troubleshooting

On MacOS you should refresh your DNS cache:

```
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```