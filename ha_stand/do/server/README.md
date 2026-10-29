# Stand 2 (DigitalOcean) — Semaphore UI cluster

DigitalOcean port of [`stand_hetzner`](../stand_hetzner). Provisions a full
[Semaphore UI](https://semaphoreui.com) deployment with the
[`digitalocean/digitalocean`](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
provider.

## Infrastructure

| Resource              | Count | Size          | Notes                                             |
| --------------------- | ----- | ------------- | ------------------------------------------------- |
| Load balancer         | 1     | regional      | HTTP `:80` → cluster `:3000`, TLS at Cloudflare edge |
| Semaphore UI cluster  | 3     | `s-1vcpu-2gb` | Behind the LB (see *Zones* below)                 |
| Semaphore runners     | 3     | `s-1vcpu-2gb` | Execute tasks, reach the cluster via the LB       |
| PostgreSQL            | 1     | `s-1vcpu-2gb` | Shared database for the cluster                   |
| Redis Sentinel        | 2     | `s-1vcpu-2gb` | `redis-1` master + `redis-2` replica, Sentinel on each (`redis_nodes`) |

All droplets join one VPC (`10.10.10.0/24`). A DigitalOcean Cloud Firewall
allows SSH and `:3000` from anywhere, Postgres (`5432`), Redis (`6379`) and
Sentinel (`26379`) only from the VPC, and all egress.

### TLS / SSL (Cloudflare proxy)

TLS terminates at the **Cloudflare edge** with the zone's universal
certificate; the load balancer itself only serves plain HTTP. Terraform
([cloudflare.tf](cloudflare.tf)) creates in the Cloudflare-hosted parent zone:

1. A **proxied** `A` record `<prefix>-lb.<parent_domain>`
   (e.g. `stand2-lb.semaphoreui.dev`) pointing at the load balancer IP.
   Proxying enables Cloudflare caching and its edge certificate.
2. A page rule pinning SSL mode **flexible** for that hostname, so Cloudflare
   reaches the origin over HTTP `:80` regardless of the zone-wide SSL setting.

The hostname is flat (`<prefix>-lb.`) because Cloudflare's universal
certificate only covers first-level subdomains — nested names like
`lb.<prefix>.<parent_domain>` would need a paid certificate.

This needs a `cloudflare_api_token` with **DNS edit**, **page rules edit** and
**zone read** on the parent domain. Semaphore and the runners are configured
with `web_host = https://<prefix>-lb.<parent_domain>` so redirects, cookies and
runner registration work over TLS.

> **Note:** the Cloudflare free plan allows only 3 page rules per zone, and
> each workspace consumes one.

### Zones

DigitalOcean does **not** expose availability zones, and both the VPC and the
load balancer are regional. The 3 cluster droplets therefore share a single
region (`var.region`) — the closest functional equivalent to the Hetzner
"different zones" layout. For multi-zone HA, deploy this stack to multiple
regions and front it with DigitalOcean global load balancing / DNS.

## Software provisioning (cloud-init)

Each role boots with a dedicated cloud-init template, kept next to its shared
module in [modules/do/](../../../modules/do) (the runner one in
[ha_stand/shared/cloud-init/](../../shared/cloud-init)):

- **postgres** — installs PostgreSQL, discovers its private IP from the
  DigitalOcean metadata service, binds to it, creates the Semaphore
  database/user, and allows `scram-sha-256` access from the VPC.
- **redis** — installs `redis-server` + `redis-sentinel` from packages.redis.io,
  binds both to the private IP and sets passwords. `redis-1` boots as the
  replication master, the other droplets get `replicaof <master>` and wait
  for the master before starting. Each Sentinel monitors `redis_master_name` at
  the master's private IP with `redis_sentinel_quorum` ([database.tf](database.tf),
  [modules/do/redis](../../../modules/do/redis/templates/redis.yaml.tftpl)).
- **semaphore** — installs Docker, writes `/etc/semaphore/config.yml` pointing
  at Postgres and at the Sentinel list (`ha.engine: redis_sentinel`, private
  IPs injected by Terraform), runs DB migrations,
  then starts the Semaphore server container. The same `access_key_encryption`
  key is shared across all 3 nodes so they form one cluster.
- **runner** — installs Docker and starts a Semaphore runner that registers
  with the cluster through the load balancer.

## Setup

```sh
cd ha_stand/do/server
cp terraform.tfvars.example terraform.tfvars   # fill in token, ssh key, secrets
terraform init
terraform plan
terraform apply
```

Generate the cluster encryption key once and reuse it:

```sh
head -c32 /dev/urandom | base64
```

After apply, open `http://<load_balancer_ip>` and log in with the
`semaphore_admin_*` credentials.

## Differences from the Hetzner stand

- **Zones:** single region (DigitalOcean has no AZ concept) vs. 3 Hetzner
  locations in one network zone.
- **Private IPs:** assigned dynamically by the VPC (referenced via droplet
  attributes / metadata service) rather than statically pre-allocated.
- **Public IPs:** DigitalOcean droplets always get a public IPv4, so there is
  no IPv6-only optimization here.
