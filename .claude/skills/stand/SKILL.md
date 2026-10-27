---
name: stand
description: Bring up, check, debug and tear down an ha_stand test stand (HA Semaphore Pro on DigitalOcean + Cloudflare) from this machine with OpenTofu, and test Redis Sentinel failover on it. Use when the user asks to raise/up, destroy/tear down, check or debug a stand in this repo. Not for editing the Terraform modules or cloud-init templates themselves.
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
   - For destroy, check that every resource name contains `<name>`.
   - One approval never carries over to the next step: server apply, runner apply and destroy each need their own.
2. **Never rely on the sticky workspace.** Create the workspace once with `tofu workspace select -or-create <name>`. Prefix every `plan`/`apply`/`state`/`output` with `TF_WORKSPACE=<name>`.
3. **Only `tofu`, never `terraform`,** on a stand raised with tofu: the state format may diverge. The repo scripts `up.sh`/`down*.sh` call `terraform`, so use the commands below instead.
4. **Load the env in every module command:** `set -a; source ../../.env; set +a` (from `ha_stand/do/<module>`). Without it tofu prompts or picks up stale values.
5. **Never print or expose secrets.** This covers `.env` values, `/tmp/<name>-admin.token`, `.tfplan` files and the passwords in `redis.conf`/`sentinel.conf`.
   - A saved `.tfplan` holds every `TF_VAR_*` in cleartext. Keep it in the scratchpad, never `tofu show` it, and `rm` it right after the apply.
   - Pass passwords on stdin, not in argv. For remote commands: `echo "$TF_VAR_x" | ssh … 'read -r P; REDISCLI_AUTH=$P redis-cli …'`. For curl: `printf '…' "$VAR" | curl --data-binary @- …`.
   - Mask secrets when showing logs or config.
6. **Don't type the user's secrets into files.** You may create placeholders and generate random passwords and keys with `openssl rand`. Tokens and the subscription key are entered by the user.
7. **Tear down in order: runner first, then server.** Runner records live on the server.
8. **Interactive steps belong to the user,** e.g. `ssh-add` with a passphrase. Suggest `! ssh-add --apple-use-keychain <key>`.

## Prepare a new stand

1. **Stand config.** `cp -r workspaces/example workspaces/<name>`.
   - The name must be DNS-safe (`[a-z0-9-]`).
   - Pick unique `cluster_ip_range`/`runners_ip_range`: another live stand may use the example's `10.10.13.0/24` and `10.10.12.0/24`.
   - The user fills in `subscription_key`. `workspaces/*` is gitignored except `example/`.
2. **Env file.** `cp ha_stand/.env.example ha_stand/.env`, then `chmod 600`. It is gitignored.
   - Replace every example secret with a generated one. Use `openssl rand -hex 16` for `db_password`, `redis_password`, `redis_sentinel_password` and `semaphore_admin_password`. Use `openssl rand -base64 32` for `semaphore_cookie_hash`, `semaphore_cookie_encryption` and `semaphore_access_key_encryption`.
   - Set `TF_VAR_semaphore_version` to a **published** release ≥ 2.20.16-beta5 (needed for Sentinel), the newest `2.20.16-*` or later. The defaults in the modules and in `.env.example` are unusable: `2.20.16-beta5` was never published. Preflight checks that the release asset exists.
3. **Credentials the user provides:**
   - **DO token, custom scopes.** These worked on 2026-10-27: droplet, vpc, load_balancer, firewall, project and tag with full access (create/read/update/delete), and ssh_key, regions, sizes, image and actions read-only. Add kubernetes only for k8s runners. Use a stand-only token, never one for an account with production resources: the token is copied onto every runner.
   - **Cloudflare token:** Zone:Read + DNS:Edit on `TF_VAR_parent_domain`. The zone's SSL mode must accept an HTTP origin (Flexible). The token usually can't read that setting. A 525 or 526 on `/api/ping` means it doesn't accept one.
   - **R2 S3 key pair** with Admin Read & Write (the module creates and deletes the bucket), plus the account ID for `TF_VAR_s3_endpoint`.
   - **SSH key:** its name as stored in DO, and the matching private key loaded in ssh-agent.
4. **Run preflight until it passes:**

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
# summarise: count, every name contains <name> → ask → apply
TF_WORKSPACE=<name> tofu apply $S/runner-destroy.tfplan && rm $S/runner-destroy.tfplan
```

Then the same in `ha_stand/do/server` with `server-destroy.tfplan`.

- **The server is already gone.** Runner destroy then fails while reading the token. Run `TF_WORKSPACE=<name> tofu state rm 'semaphoreui_runner.runner'`, then the same plan/ask/apply with `-var skip_server=true` on the plan. Do this only if the server really is gone: if it is alive, its runner records stay registered and must be deleted via `DELETE /api/runners/<id>`.
- **Server destroy fails on a missing `/tmp/<name>-admin.token`.** Destroy only needs the file to exist, so create a dummy one: `printf x > /tmp/<name>-admin.token`.
- **The Cloudflare record `<name>-lb` is deleted too,** whatever the repo comments say.
- **Afterwards, clean up and report what you checked:**
  - delete the token: `rm -f /tmp/<name>-admin.token`;
  - confirm there are no DO droplets tagged or named `<name>` and no LB, firewall, VPC or project `<name>*`;
  - confirm there is no Cloudflare record `<name>-lb`;
  - confirm the R2 bucket `<name>-semaphore-stand` is gone. Preflight reports it if it still exists.
