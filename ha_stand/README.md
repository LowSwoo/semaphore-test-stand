# Stand 2 — Semaphore UI cluster test stand

A Terraform-provisioned [Semaphore UI](https://semaphoreui.com) cluster used for
testing clustered deployments end-to-end: multiple UI nodes behind a load
balancer, sharing one PostgreSQL database and one Redis instance, with a pool of
runners that execute tasks.

Runs on **DigitalOcean** ([`do/`](do)), split into two Terraform root modules —
[`do/server/`](do/server) (the cluster) and [`do/runner/`](do/runner) (the
runners) — driven by wrapper scripts in [`do/`](do). See
[do/server/README.md](do/server/README.md) for provider-level details.

## Topology

| Role                 | Count | Notes                                            |
| -------------------- | ----- | ------------------------------------------------ |
| Load balancer        | 1     | Public entrypoint → cluster `:3000`              |
| Semaphore UI cluster | 3     | Stateless nodes sharing one DB + Redis           |
| Semaphore runners    | 1+    | Defined in the workspace `config.yml`            |
| PostgreSQL           | 1     | Shared database for the cluster                  |
| Redis                | 1     | Shared cache / session store                     |

All nodes join private VPCs so cloud-init can wire services together at boot.
The UI nodes share the same `access_key_encryption` key, which is what lets
them act as one cluster against the shared database.

DNS and TLS are handled by **Cloudflare**: the load balancer is published as a
proxied `<workspace>-lb.<parent_domain>` record (e.g.
`test1-lb.semaphoreui.dev`) in the Cloudflare-hosted parent zone. TLS
terminates at the Cloudflare edge with its universal certificate; the load
balancer itself serves plain HTTP.

## Software provisioning (cloud-init)

Each role boots from a dedicated cloud-init template under
[`shared/cloud-init/`](shared/cloud-init):

- **postgres** — installs PostgreSQL, binds to its private IP, creates the
  Semaphore database/user, allows access from the private network.
- **redis** — installs Redis, binds to its private IP, sets a password and AOF.
- **semaphore** — runs the Semaphore server, configured to point at Postgres +
  Redis, runs DB migrations on boot.
- **runner** — runs a Semaphore runner that registers with the cluster through
  the load balancer.

## Quick start

### 1. Create `.env`

```sh
cp .env.example .env    # in ha_stand/ — the scripts source ../.env from do/
```

Fill in the DigitalOcean token, Cloudflare token, parent domain, SSH key name
and passwords. Generate the cookie/encryption keys once and reuse them across
nodes:

```sh
head -c32 /dev/urandom | base64
```

### 2. Create a workspace

Each stand is a Terraform workspace configured by a directory in
[`../workspaces/`](../workspaces) (see
[../workspaces/README.md](../workspaces/README.md)):

```sh
cp -r ../workspaces/example ../workspaces/test1
# edit ../workspaces/test1/config.yml: subscription key, runners, IP ranges
```

### 3. Create the infrastructure

```sh
cd do
./up.sh test1
```

The script applies `server/`, waits until the API answers on the public URL,
then applies `runner/`. When it finishes, open the `semaphore_url` output and
log in with the `semaphore_admin_*` credentials from `.env`.

### 4. Tear down

```sh
./down.sh test1            # everything (runners, then servers)
./down_runners.sh test1    # runners only
./down_servers.sh test1    # servers only; keeps the Cloudflare records
```
