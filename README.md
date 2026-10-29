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
| [`sso_stand`](sso_stand) | Infrastructure | Provisions one Semaphore UI node + PostgreSQL + an `idp` droplet with OpenLDAP and Dex on DigitalOcean, for LDAP and OIDC login tests. | [sso_stand/README.md](sso_stand/README.md) |

They are independent: `ansible_vaults_test_project` targets any reachable Semaphore API (typically
a local instance), while `ha_stand` and `sso_stand` stand up the cloud
infrastructure that Semaphore itself runs on. The two stands have separate
root modules, state and `.env`, and build their droplets from the shared
modules in [`modules/`](modules) (see [modules/README.md](modules/README.md)).

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
[`ha_stand/do/`](ha_stand/do). Postgres, Redis and the UI nodes come from the
shared modules in [`modules/do/`](modules/do), which also hold their cloud-init
templates; the runner templates live in [`ha_stand/shared/`](ha_stand/shared).

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

## sso_stand — LDAP and OIDC login

One Semaphore UI node on `:80` behind a proxied `<name>-ui.<parent_domain>`
record, a PostgreSQL droplet and an `idp` droplet with OpenLDAP (VPC only) and
Dex (`<name>-dex.<parent_domain>`). No Redis, load balancer or runners.
Directory, users and secrets are the integration-tests fixtures, so the SSO
tests run against it unchanged.

```sh
cd sso_stand
cp .env.example .env
cp -r ../workspaces/example-sso ../workspaces/sso1

cd do
./up.sh sso1
./down.sh sso1
```

See [sso_stand/README.md](sso_stand/README.md) for the providers, fixture users
and checks.

## Repository layout

```
.
├── ansible_vaults_test_project/                 # Semaphore resources via the semaphoreui provider
├── modules/do/             # shared DigitalOcean modules (+ their cloud-init templates)
│   ├── postgres/           #   PostgreSQL droplet
│   ├── redis/              #   Redis Sentinel cluster
│   ├── semaphore/          #   Semaphore UI nodes
│   └── idp/                #   OpenLDAP + Dex droplet
├── ha_stand/               # Cloud cluster infrastructure
│   ├── .env.example        #   TF_VAR_* credentials/settings template
│   ├── do/                 #   DigitalOcean deployment
│   │   ├── server/         #     load balancer + UI cluster + Postgres + Redis
│   │   ├── runner/         #     task runners
│   │   └── up.sh, down*.sh #     wrapper scripts (take a workspace name)
│   └── shared/             #   runner cloud-init template and config
├── sso_stand/              # SSO stand: Semaphore + Postgres + OpenLDAP/Dex
│   ├── .env.example
│   └── do/                 #   root module + up.sh, down.sh
└── workspaces/             # per-stand config (one dir per Terraform workspace)
    ├── example/            #   template of an ha_stand stand
    └── example-sso/        #   template of an sso_stand stand
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- For `ansible_vaults_test_project`: a reachable Semaphore instance and an API token
- For `sso_stand`: a DigitalOcean API token and SSH key, a Cloudflare API token
  (DNS edit + zone read) for a zone in SSL mode Flexible, [OpenTofu](https://opentofu.org)
  (the scripts call `tofu`)
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
per-stand `workspaces/` directories are git-ignored (see
[.gitignore](.gitignore)); only `*.example` templates and `workspaces/example/`
are committed. Copy them and fill in your own values. For production, use a
secrets manager and restrict SSH source IPs in the firewall configuration.

## Domain access troubleshooting

On MacOS you should refresh your DNS cache:

```
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```
