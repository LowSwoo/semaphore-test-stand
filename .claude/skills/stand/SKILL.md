---
name: stand
description: Create, bring up, check, debug and tear down an ha_stand test stand (HA Semaphore Pro on DigitalOcean + Cloudflare) from this machine with OpenTofu, and test Redis Sentinel failover on it. Use when the user asks to create a new stand ("создай новый тестовый стенд <name>"), raise/up, destroy/tear down, check or debug a stand in this repo. Not for editing the Terraform modules or cloud-init templates themselves.
---

# ha_stand from the local machine (OpenTofu)

This skill holds the procedure and the rules. The background, the reasons behind each step and the pitfalls are in the urb-workbench codex note `/semaphore-test-stand/local-opentofu` (CODEX@CE6E27F9F9). Read it when a step fails in a way not covered here.

A stand has two OpenTofu root modules with **local state**:

- `ha_stand/do/server` — LB, UI nodes, PostgreSQL, Redis Sentinel, the Cloudflare record, and an R2 bucket for the admin token.
- `ha_stand/do/runner` — runner droplets and their registration.

The stand name `<name>` is the OpenTofu workspace and selects `workspaces/<name>/config.yml`.

## Rules

1. **Billable actions need an explicit "yes" from the user in this conversation.** This means apply and destroy, for this stand and this module. Always go plan → summary → "yes" → apply.
   - The summary covers resource counts, droplet sizes and the region.
   - For destroy, check that every resource belongs to this stand. Names alone don't prove it: droplets are named `ui-1`, `postgres`, `redis-1`, `runner-N-<runner>`, and the Semaphore runner record just `<runner>`. Check that the plan comes from `TF_WORKSPACE=<name>`, that the droplets carry a `<name>-*` tag, and that their IPs match the ones from the bring-up. Everything else (LB, firewall, VPC, project, tags, bucket, DNS record) is named `<name>…`.
   - Before an apply, check that the resource count is what you expect. If it differs, stop and ask, even inside an approved series.
   - One approval never carries over to the next step: server apply, runner apply and destroy each need their own.
2. **Never rely on the sticky workspace.** Create the workspace once with `tofu workspace select -or-create <name>`. Prefix every `plan`/`apply`/`state`/`output` with `TF_WORKSPACE=<name>`.
3. **Only `tofu`, never `terraform`,** on a stand raised with tofu: the state format may diverge. The repo scripts `up.sh`/`down*.sh` call `terraform`, so use the commands below instead.
4. **Load the env in every module command:** `set -a; source ../../.env; set +a` (from `ha_stand/do/<module>`). Without it tofu prompts or picks up stale values.
   - To override a variable for one run (e.g. `TF_VAR_semaphore_version=0.0.0`), set it after the `source`, for **both** `plan` and `apply`. If the apply sees another value than the saved plan, it fails with `Mismatch between input and plan variable value`.
5. **Never print or expose secrets.** This covers `.env` values, `/tmp/<name>-admin.token`, `.tfplan` files and the passwords in `redis.conf`/`sentinel.conf`.
   - A saved `.tfplan` holds every `TF_VAR_*` in cleartext. Keep it in the scratchpad, never `tofu show` it, and `rm` it right after the apply.
   - Pass passwords on stdin, not in argv. For remote commands: `echo "$TF_VAR_x" | ssh … 'read -r P; REDISCLI_AUTH=$P redis-cli …'`. For curl: `printf '…' "$VAR" | curl --data-binary @- …`.
   - Mask secrets when showing logs or config.
6. **Don't type the user's secrets into files.** You may create placeholders and generate random passwords and keys with `openssl rand`. Tokens and the subscription key are entered by the user.
7. **Tear down in order: runner first, then server.** Runner records live on the server.
8. **Interactive steps belong to the user,** e.g. `ssh-add` with a passphrase. Suggest `! ssh-add --apple-use-keychain <key>`.

## Create a new stand

Use this when the user asks for a new stand ("создай новый тестовый стенд `<name>`"). It only writes local files, creates nothing in the cloud and costs nothing, so it needs no approval.

1. **Name.** Take it from the request. If none is given, ask for one. It must be DNS-safe (`[a-z0-9-]`, at most 40 chars) and not taken by `workspaces/<name>`. Pass `--cluster N`, `--redis-nodes N`, `--redis-quorum N` only if the user asked for them; the defaults are 2, 2 and 1.
2. **Run the script:**

   ```sh
   .claude/skills/stand/scripts/new-stand.sh <name> [--cluster N] [--redis-nodes N] [--redis-quorum N]
   ```

   It prints no secret values. It does the following:
   - **`workspaces/<name>/config.yml`.** One docker runner `delta`. A free pair of `10.10.X.0/24` ranges, checked against the other workspaces and, when the DO token in `.env` works, against every VPC in the account. A placeholder in `subscription_key`.
   - **`ha_stand/.env`, only if it is missing.** It is shared by all stands, so an existing one is kept as is. A new one is mode 600, with generated passwords and keys (`hex 16` / `base64 32`), the newest published Semaphore release, and placeholders for the domain, the ssh key name, the tokens and the R2 keys.
   - **`TODO` lines:** every value still to be filled in, by name.
   - **`WARN`** if `workspaces/<name>/` is not gitignored on the current branch. Then tell the user not to commit it.
   - Exit code 0 means created, 1 means refused (the reason is printed), 64 means a usage error.
3. **Tell the user**, in their language:
   - the stand was created locally, with its name, size and VPC ranges; nothing was created in the cloud;
   - **sensitive data is not filled in.** List every `TODO` with the file it is in and where to get it (see "Credentials the user provides" below). The user enters these values themselves (rule 6);
   - the next step: after filling them in, run preflight, then bring the stand up on request.

## Prepare a new stand by hand

Prefer `new-stand.sh` above. By hand:

1. **Stand config.** `cp -r workspaces/example workspaces/<name>`.
   - The name must be DNS-safe (`[a-z0-9-]`).
   - Pick unique `cluster_ip_range`/`runners_ip_range`: another live stand may use the example's `10.10.13.0/24` and `10.10.12.0/24`.
   - The user fills in `subscription_key`. `workspaces/*` is gitignored except `example/` (on branches with the D2 fix).
2. **Env file.** `cp ha_stand/.env.example ha_stand/.env`, then `chmod 600`. It is gitignored.
   - Replace every example secret with a generated one. Use `openssl rand -hex 16` for `db_password`, `redis_password`, `redis_sentinel_password` and `semaphore_admin_password`. Use `openssl rand -base64 32` for `semaphore_cookie_hash`, `semaphore_cookie_encryption` and `semaphore_access_key_encryption`.
   - Set `TF_VAR_semaphore_version` to a **published** release ≥ 2.20.16-beta5 (needed for Sentinel), the newest `2.20.16-*` or later. The defaults in the modules and in `.env.example` are unusable: `2.20.16-beta5` was never published. Preflight checks that the release asset exists.

### Credentials the user provides

- **DO token, custom scopes.** These worked on 2026-10-27: droplet, vpc, load_balancer, firewall, project and tag with full access (create/read/update/delete), and ssh_key, regions, sizes, image and actions read-only. Add kubernetes only for k8s runners. Use a stand-only token, never one for an account with production resources: the token is copied onto every runner.
- **Cloudflare token:** Zone:Read + DNS:Edit on `TF_VAR_parent_domain`. The zone's SSL mode must accept an HTTP origin (Flexible). The token usually can't read that setting. A 525 or 526 on `/api/ping` means it doesn't accept one.
- **R2 S3 key pair** with Admin Read & Write (the module creates and deletes the bucket), plus the account ID for `TF_VAR_s3_endpoint`.
- **SSH key:** its name as stored in DO, and the matching private key loaded in ssh-agent.

### Preflight

Run it until it passes:

```sh
.claude/skills/stand/scripts/preflight.sh <name>
```

It makes read-only API calls only, creates nothing and prints no secrets. It checks:
- tools, files and placeholders;
- secrets still at their `.env.example` values, and the R2 checksum env vars;
- that the release exists;
- the Cloudflare zone, and that the record name is free;
- the DO token, and that the ssh key's fingerprint matches one in ssh-agent;
- leftover DO VPCs, projects and LBs with this name;
- the R2 keys (SigV4 ListBuckets, no aws CLI needed), and that the bucket doesn't exist yet;
- local state.

Exit code 0 means everything passed, 64 means a usage error, and anything else is the number of failed checks.

## Bring up

Run inside `ha_stand/do/<module>`. `S` is the scratchpad directory.

1. **Server.**
   ```sh
   set -a; source ../../.env; set +a
   tofu init -input=false && tofu workspace select -or-create <name>
   TF_WORKSPACE=<name> tofu plan -input=false -out=$S/server.tfplan
   ```
   Summarise the plan and **ask**. Then run `TF_WORKSPACE=<name> tofu apply $S/server.tfplan` in the background, logging to `$S`. It takes about 10–15 minutes. Afterwards `rm $S/server.tfplan`.
2. **Wait for the API.** Poll `curl -s -o /dev/null -w '%{http_code}' https://<name>-lb.<domain>/api/ping` until it returns 200; allow up to about 10 minutes. If it stays at 503, go to Diagnostics.
3. **Runner.** Same steps in `ha_stand/do/runner`: plan → **ask** → apply → `rm` the plan. The first provisioner waits for cloud-init: look for `cloud-init finished` in the log.
4. **Verify.**
   - **Runners.** Call `GET /api/runners` with `Authorization: Bearer $(cat /tmp/<name>-admin.token)`. Each runner from config.yml needs a `touched` time within the last minute. Don't rely on `active`: Terraform sets it at creation, even when registration failed. On the droplet, `systemctl is-active semaphore-runner` must report active.
   - **Docker access.** `id semaphore` includes `docker`. The `Groups:` line of the `semaphore-runner` MainPID includes the docker gid. `sudo -u semaphore docker ps` works.
   - **A task on the runner** (optional, e.g. to check the docker executor). Create a project via the API: a `none` key, a public https repository (e.g. `https://github.com/semaphoreui/semaphore-demo.git`, `print_system_info.sh`), a static inventory, an environment and a `bash` template. The template needs `runner_tag` set to one of the runner's tags (`local` or `dev`). Without it the task fails with `no runners available`: the runners are tagged and not `is_default`. Expect `Task #N is assigned to runner #M` and `docker: pulling image semaphoreui/job:develop` in the output. `runner_id` in the task JSON stays `null` anyway. The project is gone with the server.
   - **Admin login:** user `admin`, password `TF_VAR_semaphore_admin_password`.

**SSH to the nodes.** Use `ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@<ip>`. In zsh, don't keep these options in a string variable: it won't word-split. Use a small wrapper script instead.

**Where to get IPs.**
- In server: `tofu output -json cluster_servers` (keys `ui-1`…), `redis_servers` (keys `redis-1`…) and `postgres_server`.
- In runner: `tofu state show 'digitalocean_droplet.runner["<key>"]'`.

## Diagnostics

| Symptom | Check | Known cause |
|---|---|---|
| LB returns 503; `/api/ping` never 200 | On a UI node: `systemctl show semaphore -p NRestarts`, `journalctl -u semaphore -n 50`, `ss -ltn \| grep :3000` | `failed to connect to the HA Redis backend`; see the next row |
| Sentinel `broken pipe`/`EOF` in the Semaphore log; the sentinels `+sdown` each other | On a redis node: `redis-cli -h <private ip> -p 26379 PING` returns `DENIED ... protected mode` | The line `user default on nopass` in `/etc/redis/sentinel.conf` overrides `requirepass`. Cloud-init removes it on branches that contain commit `9e61583` (`wip/test-stand-fixes` and later), so expect this only on older branches such as `main`. Hot-fix there: stop redis-sentinel, run `sed -i -E '/^user default /d' /etc/redis/sentinel.conf`, start redis-sentinel |
| `sentinel.conf` still has a `user default ...` line after the fix | `grep '^user ' /etc/redis/sentinel.conf` | Fine if it reads `user default on sanitize-payload #<hash> ...`: Sentinel writes it itself from `requirepass` on CONFIG REWRITE. Only the `nopass` variant breaks auth; an unauthenticated `PING` to :26379 must return `NOAUTH` |
| A UI node fails to download Semaphore | `/var/log/cloud-init-output.log` shows `curl ... 404` | `TF_VAR_semaphore_version` is not a published release |
| Runner apply fails with `failed to obtain registration token` | `/tmp/runner-registration.log` on the runner | The branch lacks the C2 fix (no wait for cloud-init), or the admin token is stale: in server, run `tofu apply -replace=terraform_data.fetch_admin_token` (plan → ask first) |

## Redis Sentinel failover check (optional)

1. **Baseline.** Record, before touching anything:
   - `SENTINEL get-master-addr-by-name semaphore` on both sentinels;
   - the roles from `INFO replication`;
   - `NRestarts` on the UI nodes;
   - a login session (`POST /api/auth/login`, password on stdin, cookie jar in `$S`).

   Start a 1-second `/api/ping` monitor in the background.
2. **Fail the master.** Run `systemctl stop redis-server` on the master and keep its sentinel running.
3. **Expected result:**
   - `+switch-master` within about 8 seconds;
   - the UI logs show `sentinel: new master=...`;
   - `NRestarts` is unchanged;
   - the session still returns 200;
   - the ping monitor shows 200 throughout.
4. **Restore.** Run `systemctl start redis-server` and expect `+convert-to-slave` and `master_link_status:up`. Then stop the monitor and delete the cookie jar.

With `redis_nodes: 2` and quorum 1, losing a whole node does **not** fail over (see the codex note). Test that only with 3 nodes and quorum 2.

## Tear down

Plan the destroy, then **ask**, then apply. Runner first:

```sh
cd ha_stand/do/runner && set -a; source ../../.env; set +a
TF_WORKSPACE=<name> tofu plan -destroy -input=false -out=$S/runner-destroy.tfplan
# summarise: count, ownership per rule 1 → ask → apply
TF_WORKSPACE=<name> tofu apply $S/runner-destroy.tfplan && rm $S/runner-destroy.tfplan
```

Then the same in `ha_stand/do/server` with `server-destroy.tfplan`.

- **The server is already gone.** Runner destroy then fails while reading the token. Run `TF_WORKSPACE=<name> tofu state rm 'semaphoreui_runner.runner'`, then the same plan/ask/apply with `-var skip_server=true` on the plan. Do this only if the server really is gone: if it is alive, its runner records stay registered and must be deleted via `DELETE /api/runners/<id>`.
- **Server destroy fails on a missing `/tmp/<name>-admin.token`.** Destroy only needs the file to exist, so create a dummy one: `printf x > /tmp/<name>-admin.token`.
- **After a failed apply** the destroy count is lower than the apply count: resources created after the failure point (e.g. `digitalocean_project_resources.main` for the runner) are not in state. Tainted droplets are destroyed normally.
- **The Cloudflare record `<name>-lb` is deleted too,** whatever the repo comments say.
- **Afterwards, clean up and report what you checked:**
  - delete the token: `rm -f /tmp/<name>-admin.token`;
  - confirm there are no DO droplets tagged or named `<name>` and no LB, firewall, VPC or project `<name>*`;
  - confirm there is no Cloudflare record `<name>-lb`;
  - confirm the R2 bucket `<name>-semaphore-stand` is gone. Preflight reports it if it still exists.
