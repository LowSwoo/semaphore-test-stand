# Stand 2 — Semaphore UI cluster test stand

A Terraform-provisioned [Semaphore UI](https://semaphoreui.com) cluster used for
testing clustered deployments end-to-end: multiple UI nodes behind a load
balancer, sharing one PostgreSQL database and one Redis instance, with a pool of
runners that execute tasks.

The same topology is provided for two cloud providers — pick one:

| Variant       | Provider      | Directory   | Docs                          |
| ------------- | ------------- | ----------- | ----------------------------- |
| DigitalOcean  | `digitalocean`| [`do/`](do) | [do/README.md](do/README.md)  |

## Topology

Both variants provision the same logical layout:

| Role                 | Count | Notes                                            |
| -------------------- | ----- | ------------------------------------------------ |
| Load balancer        | 1     | Public entrypoint → cluster `:3000`              |
| Semaphore UI cluster | 3     | Stateless nodes sharing one DB + Redis           |
| Semaphore runners    | 3     | Execute tasks, reach the cluster via the LB      |
| PostgreSQL           | 1     | Shared database for the cluster                  |
| Redis                | 1     | Shared cache / session store                     |

All nodes join a private network so cloud-init can wire services together at
boot. The 3 UI nodes share the same `access_key_encryption` key, which is what
lets them act as one cluster against the shared database.

## Software provisioning (cloud-init)

Each role boots from a dedicated cloud-init template under `shared/cloud-init/`:

- **postgres** — installs PostgreSQL, binds to its private IP, creates the
  Semaphore database/user, allows access from the private network.
- **redis** — installs Redis, binds to its private IP, sets a password and AOF.
- **semaphore** — runs the Semaphore server (Docker or systemd variant),
  configured to point at Postgres + Redis, runs DB migrations on boot.
- **runner** — runs a Semaphore runner that registers with the cluster through
  the load balancer.

## Quick start

### Create .env

```sh
cd do
cp .env.example .env
```

Generate the shared cluster encryption key once and reuse it across nodes:

```sh
head -c32 /dev/urandom | base64
```

### Create workspace

```sh
cd ..
cd workspaces
mkdir test1
```

Create `config.yml`:

```yml
runners:
  delta:
    name: delta
    runner_executor_type: docker

cluster_ip_range: 10.10.13.0/24
runners_ip_range: 10.10.12.0/24
subscription_key: 75b1875e-df08-4b38-9ab0-23b4c2ba9a69
cluster: 3
ha_disabled: false
```

### Create infrastructure

```sh
cd do
./up test1
```