# Semaphore Test Stand

Terraform-based test stands and projects for [Semaphore UI](https://semaphoreui.com). They
spin up reproducible Semaphore environments for end-to-end testing — from
configuring resources inside a single instance to provisioning a full cloud
cluster from scratch.

The repo contains 2 types of entities:
- `*_project` &mdash; Terraform code for provisiing a Semaphore UI project
- `*_stand` &mdash; Terraform and Ansible code for provising some infrasructure for testing Semaphore UI

Provisioned Semaphore UI projects can refer to Ansible playbooks and Terraform code from repository https://github.com/semaphoreui/semaphore-test-stand-tests.

The repo contains following stands and projects:

| Stand                | Layer          | What it does                                                                                                                           | Docs                                 |
| -------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| [`ansible_vaults_test_project`](ansible_vaults_test_project)   | Application    | Configures resources *inside* a running Semaphore instance — projects, keys, repositories, inventories, environments, and templates.    | [ansible_vaults_test_project/README.md](ansible_vaults_test_project/README.md) |
| [`ha_stand`](ha_stand)   | Infrastructure | Provisions a complete Semaphore UI *cluster* (load balancer + UI nodes + PostgreSQL + Redis + runners) on DigitalOcean.                  | [ha_stand/README.md](ha_stand/README.md) |

The two are independent: `ansible_vaults_test_project` targets any reachable Semaphore API (typically
a local instance), while `ha_stand` stands up the cloud infrastructure that
Semaphore itself runs on.

## ansible_vaults_test_project — Semaphore resources

Drives a Semaphore instance through the
[`semaphoreui/semaphore`](https://registry.terraform.io/providers/semaphoreui/semaphore/latest/docs)
Terraform provider, declaring the project resources used by the test suite:
projects, SSH/login keys, repositories, inventories, environments (including
variable groups with secrets), and templates that exercise features such as
multiple Ansible vault passwords and env/var secret injection.

```sh
cd ansible_vaults_test_project
cp terraform.tfvars.example terraform.tfvars   # set api_token
terraform init
terraform apply
```

See [ansible_vaults_test_project/README.md](ansible_vaults_test_project/README.md) for obtaining an API token and the full
list of resources.

## ha_stand — Cluster infrastructure

Provisions a Semaphore UI cluster on **DigitalOcean**: a load balancer fronting
several stateless UI nodes that share one PostgreSQL database and one Redis
instance, plus a pool of runners. The deployment is split into two Terraform
root modules — [`server/`](ha_stand/do/server) (the cluster) and
[`runner/`](ha_stand/do/runner) (the task runners) — driven by wrapper scripts in
[`ha_stand/do/`](ha_stand/do). Nodes are configured at boot through the cloud-init
templates in [`ha_stand/shared/`](ha_stand/shared).

DNS and TLS are handled by **Cloudflare**: the load balancer is published as a
proxied `<name>-lb.<parent_domain>` record in the Cloudflare-hosted parent
zone, so TLS terminates at the Cloudflare edge with its certificate and no
certificates are managed on the provider side.

Several independent stands can run from the same code: each stand is a
Terraform **workspace**, configured by a directory in
[`workspaces/`](workspaces) (see [workspaces/README.md](workspaces/README.md)).
Credentials and shared settings come from `ha_stand/.env` (`TF_VAR_*` variables)
rather than per-stack `.tfvars`:

```sh
cd ha_stand
cp .env.example .env                   # fill in tokens, passwords, keys
cp -r ../workspaces/example ../workspaces/test1   # per-stand config.yml

cd do
./up.sh test1                          # apply server, wait for API, apply runner
./down.sh test1                        # destroy everything
```

`down_servers.sh` / `down_runners.sh` tear down the two halves separately;
`down_servers.sh` keeps the Cloudflare records so a later `up.sh` reuses them.
`down_runners.sh test1 --skip-server` destroys the runner droplets without
deregistering them on the server — for stands whose servers (or admin token)
are already gone.
See [ha_stand/README.md](ha_stand/README.md) and
[ha_stand/do/server/README.md](ha_stand/do/server/README.md) for details.

## Repository layout

```
.
├── ansible_vaults_test_project/                 # Semaphore resources via the semaphoreui provider
├── ha_stand/                 # Cloud cluster infrastructure
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
- For `ansible_vaults_test_project`: a reachable Semaphore instance and an API token
- For `ha_stand`:
  - A DigitalOcean API token and an SSH key uploaded to DigitalOcean (the
    matching key loaded in your `ssh-agent` — Terraform connects over SSH to
    mint the admin token)
  - A Cloudflare API token (DNS edit + zone read) for the parent domain
  - A Cloudflare R2 API token (Object Read & Write, may create buckets) and the
    account's R2 S3 endpoint: the server module uploads the admin token to a
    private bucket there and the runner module reads it

## Secrets

This is a **test stand** — secrets are passed to nodes via cloud-init and stored
in local files. State files, `*.tfvars`, `.env*`, generated tokens, and the
per-stand `workspaces/<name>/` directories are git-ignored (see
[.gitignore](.gitignore)); only `*.example` templates, `workspaces/README.md`
and `workspaces/example/` are committed (the already tracked
`workspaces/stress1/` predates the rule, see
[workspaces/README.md](workspaces/README.md)). Copy them and fill in your own values. For production, use a
secrets manager and restrict SSH source IPs in the firewall configuration.

## Domain access troubleshooting

On MacOS you should refresh your DNS cache:

```
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```
