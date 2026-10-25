# Stand 2 — Semaphore UI cluster test stand

A Terraform-provisioned [Semaphore UI](https://semaphoreui.com) cluster used for
testing clustered deployments end-to-end: multiple UI nodes behind a load
balancer, sharing one PostgreSQL database and a Redis Sentinel cluster for HA
coordination, with a pool of runners that execute tasks.

Runs on **DigitalOcean** ([`do/`](do)), split into two Terraform root modules —
[`do/server/`](do/server) (the cluster) and [`do/runner/`](do/runner) (the
runners) — driven by wrapper scripts in [`do/`](do). See
[do/server/README.md](do/server/README.md) for provider-level details.

## Topology

| Role                 | Count | Notes                                            |
| -------------------- | ----- | ------------------------------------------------ |
| Load balancer        | 1     | Public entrypoint → cluster `:3000`              |
| Semaphore UI cluster | 3     | Stateless nodes sharing one DB + Redis Sentinel  |
| Semaphore runners    | 1+    | Defined in the workspace `config.yml`            |
| PostgreSQL           | 1     | Shared database for the cluster                  |
| Redis Sentinel       | 2     | 1 master + 1 replica, Sentinel on each node      |

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
- **redis** — installs `redis-server` + `redis-sentinel`, binds both to the
  private IP, sets passwords. The first node boots as replication master, the
  others as replicas; every Sentinel monitors the same master (see below).
- **semaphore** — runs the Semaphore server, configured to point at Postgres and
  at the Sentinels (`ha.engine: redis_sentinel`), runs DB migrations on boot.
- **runner** — runs a Semaphore runner that registers with the cluster through
  the load balancer.

## Redis Sentinel (HA coordination)

Semaphore nodes do not talk to a fixed Redis address. They ask the Sentinels for
the current master of `redis_master_name` and follow a failover without a
restart — the `ha` section of `/etc/semaphore/config.yml` is:

```yaml
ha:
  enabled: true
  engine: redis_sentinel
  redis_sentinel:
    master_name: semaphore
    addrs: ["<redis-1 private ip>:26379", "<redis-2 private ip>:26379"]
    sentinel_pass: <redis_sentinel_password>
    pass: <redis_password>
```

This requires **Semaphore ≥ 2.20.16-beta5** (first release with the
`redis_sentinel` engine); `.env.example` pins that version.

The cluster shape comes from the workspace `config.yml` (`redis_nodes`,
`redis_sentinel_quorum`, `redis_master_name`, all optional) and two secrets from
`.env`: `redis_password` for the data nodes and `redis_sentinel_password` for
the Sentinels themselves.

**Why 2 nodes and quorum 1.** This is a test stand, not a reference HA layout.
With two Sentinels and `quorum: 1` the surviving Sentinel can promote the
replica when the master dies, which is what the failover test needs. The price
is that a network split between the two nodes can leave both believing they are
master (split-brain). `quorum: 2` would avoid that but makes failover impossible
once one node is gone. For a production-like layout set `redis_nodes: 3` and
`redis_sentinel_quorum: 2`.

Useful checks (on any Redis droplet, passwords from `.env`):

```sh
REDISCLI_AUTH=<redis_password>          redis-cli INFO replication
REDISCLI_AUTH=<redis_sentinel_password> redis-cli -p 26379 SENTINEL get-master-addr-by-name semaphore
systemctl stop redis-server             # on the master: forces a failover
```

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

Runners are registered on the Semaphore server, so `down_runners.sh` normally
deletes their server-side records through the API using the admin token the
server apply left in `/tmp/<workspace>-admin.token`. If the servers are already
gone (or that token file is), the API call cannot succeed and the destroy would
fail before removing a single droplet. For that case:

```sh
./down_runners.sh test1 --skip-server   # or: ./down.sh test1 --skip-server
```

`--skip-server` drops the `semaphoreui_runner.*` records from the Terraform
state and destroys only the DigitalOcean resources. It is implied automatically
when the token file is missing. If the server is in fact still alive, the runner
records stay registered there and have to be removed by hand.
