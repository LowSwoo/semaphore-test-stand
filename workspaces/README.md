# Workspaces

Per-stand configuration. Each
subdirectory here corresponds to one **Terraform workspace** (= one isolated
stand), and its name must match the workspace name:

```sh
./up.sh stress1          # runs `terraform workspace select -or-create stress1`
                         # and reads ../../workspaces/stress1/
```

## Why workspaces

- **Several independent stands from the same code.** The `server` and `runner`
  modules derive everything per-stand from `terraform.workspace`
  (`local.prefix`): resource names, the DigitalOcean project, VPC ranges and
  the public hostname `<name>-lb.<parent_domain>`
  (e.g. `stress1-lb.semaphoreui.dev`). Spinning up a second stand is just
  running the scripts with a different name — no code changes, no state
  collisions.
- **Config lives outside the modules.** `server` and `runner` are separate
  Terraform root modules with separate state files. This directory is the
  place both read the same per-stand settings from, instead of duplicating
  tfvars in each module.
- **Hand-off between modules.** The `server` apply mints an admin API token
  and drops it here; the `runner` apply later picks it up to register runners
  through the Semaphore API. The filesystem is the channel between the two
  states.

## Directory layout

```
workspaces/
  example/            # committed template — copy it to start a new stand
    config.yml
  <name>/             # one directory per stand, gitignored (may hold secrets)
    config.yml        # stand definition, written by hand (required)
```

Everything in `workspaces/` except this `README.md` and `example/` is
gitignored (rule `/workspaces/*` in the repo root [.gitignore](../.gitignore)):
`config.yml` contains the subscription key. `admin.token` and `id_rsa` are
ignored even inside the allowed directories.

To commit a stand directory on purpose (e.g. a CI stand whose `config.yml` has
no key and gets it from `TF_VAR_subscription_key`), add the exception
`!/workspaces/<name>/` to `.gitignore` and check it with
`git check-ignore -v workspaces/<name>/config.yml`.

`.gitignore` does not affect files that are already tracked:
`workspaces/stress1/config.yml` was committed before this rule and stays
tracked until it is removed from the index with `git rm --cached`.

## Files

### `config.yml` (required, written by hand)

Read by both `ha_stand/do/server` and `ha_stand/do/runner`:

```yaml
runners:                      # one entry per runner droplet
  delta:
    name: delta
    runner_executor_type: docker   # or "k8s"

cluster_ip_range: 10.10.13.0/24    # VPC range for the server cluster
runners_ip_range: 10.10.12.0/24    # VPC range for the runners (must differ)
subscription_key: <key>            # Semaphore Pro subscription key
cluster: 3                         # number of Semaphore UI droplets behind the LB
ha_disabled: false                 # true = run without HA mode

redis_nodes: 2                     # Redis droplets: 1 master + (N-1) replicas, Sentinel on each (optional, default 2)
redis_sentinel_quorum: 1           # Sentinels that must agree the master is down (optional, default 1)
redis_master_name: semaphore       # master name in `sentinel monitor` and in Semaphore's ha.redis_sentinel.master_name (optional)
```

The three `redis_*` keys are optional. With 2 nodes and quorum 1 a single
surviving Sentinel can promote the replica; quorum 2 would need both Sentinels
alive and makes failover impossible once one node is lost. For a production-like
setup use `redis_nodes: 3` and `redis_sentinel_quorum: 2`.

Commenting runner entries in or out and re-applying the `runner` module is the
intended way to scale runners up and down.

### Admin token (generated, not stored here)

Created by the `server` apply: after cloud-init finishes on the first cluster
droplet, Terraform mints an admin API token over SSH, saves it to
`/tmp/<name>-admin.token` on the machine running Terraform and uploads it to
`s3://<name>-semaphore-stand/<name>/admin.token` in Cloudflare R2. The `runner`
module reads that object to call the Semaphore API when registering runners (see
[ha_stand/README.md](../ha_stand/README.md#admin-token-hand-over-cloudflare-r2--s3)). If it
is lost or invalid, taint/replace `terraform_data.fetch_admin_token` in the
`server` module to re-mint and re-upload it.

## Creating a new stand

```sh
cp -r workspaces/example workspaces/<name>
# edit workspaces/<name>/config.yml: set subscription_key, adjust runners/ranges
cd ha_stand/do
./up.sh <name>
```

Keep `<name>` short and DNS-safe (lowercase, digits, hyphens) — it becomes
part of resource names and the public hostname `<name>-lb.<parent_domain>`.
