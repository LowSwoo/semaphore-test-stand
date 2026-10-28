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
| Identity providers   | 0–1   | Optional `idp` droplet: OpenLDAP and/or Dex      |

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
- **idp** (optional) — runs OpenLDAP and/or Dex with Docker Compose for the
  SSO checks; created only when the workspace enables `identity_providers`
  (see [Identity providers](#identity-providers-ldap--dex)).

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

## Identity providers (LDAP + Dex)

An optional `idp` droplet turns the stand into an SSO stand. It is switched on
by the `identity_providers` block of the workspace `config.yml`; a missing block
or key means `false`, so stands without it plan exactly as before:

```yaml
identity_providers:
  ldap: true    # OpenLDAP + Semaphore's ldap_* settings
  dex: true     # Dex + Semaphore's oidc_providers
```

With either flag on, the server module creates one `idp` droplet in the cluster
VPC that runs the enabled services with Docker Compose
([`shared/cloud-init/idp.yaml.tftpl`](shared/cloud-init/idp.yaml.tftpl)):

| Service  | Image                                | Exposure                                                         | Semaphore config                         |
| -------- | ------------------------------------ | ---------------------------------------------------------------- | ---------------------------------------- |
| OpenLDAP | `osixia/openldap:1.5.0`              | plain LDAP `:389`, open to `cluster_ip_range` only               | `ldap_*` (no TLS, bind as `cn=admin`)    |
| Dex      | `ghcr.io/dexidp/dex:v2.45.1-alpine`  | `:80` behind proxied `<prefix>-dex.<parent_domain>`, Cloudflare edge ranges only | `oidc_providers.dex` + `oidc_providers.unavailable` |

LDAP and Dex are two **independent** login methods: Dex has no LDAP connector
and authenticates its own static users. `unavailable` is a deliberately
unreachable OIDC provider (`http://127.0.0.1:1/oidc`) kept from the fixtures for
the provider-failure check.

Directory, users, client and secrets mirror the integration-tests fixtures
(`test-environment/profiles/feature-ldap-tls` and `feature-oidc-local`), so the
tests run against the stand unchanged:

| Provider | Login                       | Password                       | Purpose                                          |
| -------- | --------------------------- | ------------------------------ | ------------------------------------------------ |
| LDAP     | `ldap.user`                 | `Bookwright-LDAP-42!`          | regular directory login                          |
| LDAP     | `ldap.invalid`              | `Bookwright-LDAP-Invalid-42!`  | wrong-password checks                            |
| LDAP     | `ldap-admin-conflict`       | `Bookwright-LDAP-Conflict-42!` | `mail: admin@localhost`, collides with the admin |
| Dex      | `oidc.user@bookwright.test` | `Bookwright-OIDC-42!`          | regular OIDC login                               |
| Dex      | `admin@localhost`           | `Bookwright-OIDC-Conflict-42!` | collides with the admin by email                 |

The LDAP base DN is `dc=bookwright,dc=test`, users live under
`ou=people,dc=bookwright,dc=test` (`shared/idp/50-bookwright-users.ldif`); Dex
serves the `semaphore` client (`shared/idp/dex.yaml.tftpl`). The two secrets,
`ldap_admin_password` (OpenLDAP admin and Semaphore's bind password) and
`dex_client_secret`, default to the fixture values in
[`do/server/variables.tf`](do/server/variables.tf) — they are public test
values, not real secrets — and can be overridden with `TF_VAR_ldap_admin_password`
/ `TF_VAR_dex_client_secret`. With the flag on, the Semaphore admin email is
forced to `admin@localhost` (instead of `semaphore_admin_email`) so the
conflict users above really collide with the local admin. The email is set
only when the bootstrap node creates the admin in an empty database, so enable
the block on a fresh stand; on an existing one the admin keeps its old email
until it is changed by hand.

The server module adds two outputs: `idp_server` (public and private IP of the
droplet) and `dex_issuer_url` (`https://<prefix>-dex.<parent_domain>/dex`, the
`provider_url` of `oidc_providers.dex`); both are `null` when the feature is off.

**Semaphore version.** The SSO stand needs **Semaphore ≥ 2.20.16-beta8**: the
`2.20.16-beta5` default from `variables.tf` / `.env.example` is not published,
so set it explicitly:

```sh
TF_VAR_semaphore_version="2.20.16-beta8"
```

**Cloudflare SSL mode.** Dex is published exactly like the load balancer —
proxied record, TLS at the Cloudflare edge, plain HTTP to the origin — so it
relies on the zone SSL mode being **Flexible**. A 525/526 on the discovery URL
means the zone setting, not the stand. The Semaphore nodes also fetch Dex
discovery through this public URL (the issuer must match what the browser
sees), so OIDC login breaks the same way if the zone is not Flexible.

**Replacing the `idp` droplet.** Its private IP is part of the UI nodes'
`user_data` (`ldap_server`), so replacing `idp` (or toggling the flags) replaces
all UI nodes, which in turn re-mints the admin token. Re-apply the runner module
afterwards (`./up.sh <name>` does both).

Useful checks (`<prefix>-lb.<domain>` is the `semaphore_url` output):

```sh
# Dex discovery through Cloudflare — 200 with the issuer https://<prefix>-dex.<domain>/dex
curl https://<prefix>-dex.<domain>/dex/.well-known/openid-configuration

# LDAP from a UI node (ldapsearch is not installed there by default)
apt-get install -y ldap-utils
ldapsearch -x -H ldap://<idp private ip>:389 \
  -D 'cn=admin,dc=bookwright,dc=test' -w 'Bookwright-LDAP-Bind-42!' \
  -b 'ou=people,dc=bookwright,dc=test' '(uid=ldap.user)'

# LDAP login through Semaphore — 204
curl -i -X POST https://<prefix>-lb.<domain>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"auth":"ldap.user","password":"Bookwright-LDAP-42!","method":"ldap"}'

# Provider failure — 500
curl -i https://<prefix>-lb.<domain>/api/auth/oidc/unavailable/login
```

Dex login is checked in a browser: the login page of `semaphore_url` shows a
"Bookwright Dex" button that redirects to Dex; sign in as
`oidc.user@bookwright.test` / `Bookwright-OIDC-42!` and Dex returns you to
Semaphore logged in (`skipApprovalScreen` is on).

**Known defect, not a stand bug.** LDAP login as `ldap-admin-conflict` answers
`500` instead of the expected `401` (successful bind, then a unique-constraint
failure on the email). It is tracked in the integration tests'
`test-environment/known-defects.md`.

## Admin token hand-over (Cloudflare R2 / S3)

The `server` and `runner` modules are separate Terraform roots and may run on
different machines (for example as two Semaphore tasks), so the admin API token
is exchanged through a private **Cloudflare R2** bucket (any S3-compatible
store works, including AWS S3) instead of a local file:

1. `server` apply mints the token over SSH on the first cluster node, saves it to
   `/tmp/<workspace>-admin.token` and uploads it to
   `s3://<bucket>/<workspace>/admin.token` (`aws_s3_object.admin_token`).
   The bucket is created by the module (R2 buckets are private and encrypted at
   rest by default) with `force_destroy` so `down_servers.sh` can remove it.
2. `runner` apply reads the object with an `aws_s3_object` data source and uses
   the token for the `semaphoreui` provider and for the registration-token calls
   made from the runner droplets.

Both modules talk to the store through the `hashicorp/aws` provider configured
for R2: `TF_VAR_s3_endpoint` is the account endpoint
`https://<account_id>.r2.cloudflarestorage.com`, `TF_VAR_aws_region` is `auto`,
and `TF_VAR_aws_access_key` / `TF_VAR_aws_secret_key` are an R2 API token with
Object Read & Write permission that is also allowed to create and delete
buckets. With `s3_endpoint` empty the same code targets AWS S3 (set a real
region; leave the keys empty for the default AWS credential chain).

R2 rejects the request checksums the AWS SDK sends by default. The provider has
no setting for this, so the SDK is configured through two plain environment
variables that must be present wherever the modules run (the `.env` sourced by
the scripts, or the Semaphore environment of the templates):

```sh
AWS_REQUEST_CHECKSUM_CALCULATION=when_required
AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
```

The bucket name defaults to `<workspace>-semaphore-stand` (unique per account on
R2, global on AWS; override with `TF_VAR_s3_bucket` on a clash).

The upload reads the token back from `/tmp/<workspace>-admin.token` on the
machine that runs the `server` apply. If that file is gone on a later apply
(another machine, `/tmp` cleaned on reboot) the plan fails with "no file exists";
re-mint and re-upload the token with:

```sh
terraform apply -replace=terraform_data.fetch_admin_token
```

## Quick start

### 1. Create `.env`

```sh
cp .env.example .env    # in ha_stand/ — the scripts source ../.env from do/
```

Fill in the DigitalOcean token, Cloudflare token, AWS credentials, parent
domain, SSH key name and passwords. Generate the cookie/encryption keys once and
reuse them across nodes:

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
server apply uploaded to `s3://<bucket>/<workspace>/admin.token`. If the servers
are already gone (and their bucket with them), the API call cannot succeed and
the destroy would fail before removing a single droplet. For that case:

```sh
./down_runners.sh test1 --skip-server   # or: ./down.sh test1 --skip-server
```

`--skip-server` drops the `semaphoreui_runner.*` records from the Terraform
state and destroys only the DigitalOcean resources. It is implied automatically
when the token object is missing in S3 (checked with the `aws` CLI when it is
installed). If the server is in fact still alive, the runner records stay
registered there and have to be removed by hand.
