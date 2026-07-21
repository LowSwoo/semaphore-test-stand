# Stand 2 (Google Cloud) — Semaphore UI cluster

Google Cloud port of [`../../do/server`](../../do/server). Provisions a full
[Semaphore UI](https://semaphoreui.com) deployment with the
[`hashicorp/google`](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
provider.

## Infrastructure

| Resource              | Count | Size       | Notes                                               |
| --------------------- | ----- | ---------- | --------------------------------------------------- |
| Load balancer         | 1     | global     | HTTPS `:443` → cluster `:3000`, HTTP→HTTPS redirect  |
| Semaphore UI cluster  | 1     | `e2-small` | Behind the LB (see *Zones* below)                   |
| PostgreSQL            | 1     | `e2-small` | Shared database for the cluster                     |
| Redis                 | 1     | `e2-small` | Shared cache/session store                          |

Runners live in the sibling [`../runner`](../runner) module.

All instances join one VPC subnet (`10.10.10.0/24`). Google Cloud firewall rules
(matched by network tags) allow SSH and `:3000` from anywhere, Postgres/Redis
only from the subnet, and rely on the default allow-all egress.

### TLS / SSL (subdomain delegation)

The global external HTTPS load balancer terminates TLS with a
**Google-managed** certificate and redirects HTTP→HTTPS. Hostnames are derived
from `var.prefix` + `var.parent_domain`:

- Delegated Cloud DNS zone: `<prefix>.<parent_domain>` (e.g. `stand2.semaphoreui.dev`)
- LB hostname / cert: `<lb_subdomain>.<prefix>.<parent_domain>`
  (e.g. `lb.stand2.semaphoreui.dev`)

The parent domain (`semaphoreui.dev`) stays hosted on **Cloudflare**. Terraform
manages the whole delegation automatically:

1. `google_dns_managed_zone` creates the `<prefix>.<parent_domain>` sub-zone in
   Google Cloud DNS ([certificate.tf](certificate.tf)).
2. `cloudflare_record` adds `NS` records on the `<prefix>` label in the
   Cloudflare parent zone, pointing at the Cloud DNS nameservers
   ([cloudflare.tf](cloudflare.tf)).
3. `google_dns_record_set` points `lb.<prefix>.<parent_domain>` at the LB IP.
4. Once DNS resolves, Google provisions the managed certificate (validated
   through the load balancer) and serves `https://lb.<prefix>.<parent_domain>`.

This needs a `cloudflare_api_token` with **DNS edit** + **zone read** on the
parent domain. Semaphore and the runners are configured with
`web_host = https://<lb_fqdn>` so redirects, cookies and runner registration
work over TLS.

> **Note:** Google-managed certificates take several minutes to become `ACTIVE`
> after DNS propagates, and the load balancer returns TLS errors until then. A
> cold `terraform apply` succeeds, but `https://lb.<...>` only serves traffic
> once the certificate finishes provisioning.

### Zones

The VPC subnet is regional and the external HTTPS load balancer is global. The
cluster instances share a single zone (`var.zone`). For multi-zone HA, spread
the instances across zones in the region and add them to a multi-zone or
regional instance group behind the same load balancer.

## Software provisioning (cloud-init)

Each role boots with a dedicated cloud-init template in [cloud-init/](cloud-init/),
passed through the `user-data` instance metadata key:

- **postgres** — installs PostgreSQL, discovers its private IP from the GCE
  metadata server, binds to it, creates the Semaphore database/user, and allows
  `scram-sha-256` access from the subnet.
- **redis** — installs Redis, binds to its private IP, sets a password and AOF.
- **semaphore** — installs the Semaphore binary, writes
  `/etc/semaphore/config.yml` pointing at Postgres + Redis (private IPs injected
  by Terraform), serializes DB migrations with a Postgres advisory lock, then
  starts the Semaphore systemd service. The same `access_key_encryption` key is
  shared across all cluster nodes so they form one cluster.

## Setup

```sh
cd stand2/gcp/server
gcloud auth application-default login          # Google Cloud auth
cp terraform.tfvars.example terraform.tfvars   # fill in project, ssh key, secrets
terraform init
terraform plan
terraform apply
```

Generate the cluster encryption keys once and reuse them:

```sh
head -c32 /dev/urandom | base64
```

After apply, open the `semaphore_url` output and log in with the
`semaphore_admin_*` credentials.

## Differences from the DigitalOcean stand

- **Provider primitives:** `google_compute_instance` instead of droplets, a
  `google_compute_network` + `google_compute_subnetwork` instead of a VPC, and a
  multi-resource global external HTTPS load balancer (forwarding rule → target
  proxy → URL map → backend service → instance group) instead of a single
  `digitalocean_loadbalancer`.
- **Tags:** plain network-tag strings (centralised in [tags.tf](tags.tf)) instead
  of first-class `digitalocean_tag` resources.
- **SSH key:** injected per-instance via the `ssh-keys` metadata entry rather
  than a shared `digitalocean_ssh_key` resource.
- **Certificate:** Google-managed cert validated through the LB, with the
  sub-zone hosted in Google Cloud DNS (vs. DigitalOcean's Let's Encrypt cert via
  DNS validation in a DO-managed zone).
- **Project:** the Google Cloud project is a pre-existing container
  (`var.gcp_project`), not a Terraform-created grouping resource.
