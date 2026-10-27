#!/usr/bin/env bash
# Create the local config for a new ha_stand stand. Creates no cloud resources.
#
#   .claude/skills/stand/scripts/new-stand.sh <stand-name> [--cluster N] [--redis-nodes N] [--redis-quorum N]
#
# - workspaces/<name>/config.yml: free VPC ranges, a placeholder subscription key.
# - ha_stand/.env, only if missing: generated passwords and keys, placeholders for
#   tokens, domain and ssh key, the newest published Semaphore release.
# Prints which values the user still has to fill in, never the values themselves.
# Exit code: 0 = created, 1 = refused (name taken or invalid), 64 = usage error.
set -euo pipefail

usage() { echo "usage: $0 <stand-name> [--cluster N] [--redis-nodes N] [--redis-quorum N]" >&2; exit 64; }

name="${1:-}"; [[ -n "$name" && "$name" != -* ]] || usage; shift
cluster=2 redis_nodes=2 redis_quorum=1
while (( $# )); do
  case "$1" in
    --cluster)      cluster="${2:-}"; shift 2 ;;
    --redis-nodes)  redis_nodes="${2:-}"; shift 2 ;;
    --redis-quorum) redis_quorum="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done
for n in "$cluster" "$redis_nodes" "$redis_quorum"; do [[ "$n" =~ ^[1-9][0-9]*$ ]] || usage; done
(( redis_quorum <= redis_nodes )) || { echo "--redis-quorum must not exceed --redis-nodes" >&2; exit 64; }

repo="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
dir="$repo/workspaces/$name"
env_file="$repo/ha_stand/.env"
env_example="$repo/ha_stand/.env.example"

# The name ends up in the bucket "<name>-semaphore-stand" (S3 limit 63 chars) and in DNS.
if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || (( ${#name} > 40 )); then
  echo "REFUSED: '$name' must be DNS-safe (lowercase, digits, hyphens) and at most 40 chars" >&2; exit 1
fi
[[ "$name" != example ]] || { echo "REFUSED: 'example' is the committed template" >&2; exit 1; }
[[ ! -e "$dir" ]] || { echo "REFUSED: workspaces/$name already exists" >&2; exit 1; }

# Third octets of 10.10.X.0/24 already taken by local stands and, when the DO token
# works, by any VPC in the account (stands of other people included).
used=$(grep -hoE '10\.10\.[0-9]+\.0/24' "$repo"/workspaces/*/config.yml 2>/dev/null | cut -d. -f3 || true)
do_checked=no
if [[ -f "$env_file" ]]; then
  tok=$(set -a; source "$env_file" >/dev/null 2>&1; echo "${TF_VAR_do_token:-}")
  if [[ -n "$tok" && "$tok" != *... ]]; then
    vpcs=$(printf 'Authorization: Bearer %s\n' "$tok" | curl -sf --max-time 20 -H @- \
      'https://api.digitalocean.com/v2/vpcs?per_page=200' || true)
    if [[ -n "$vpcs" ]]; then
      used="$used $(printf '%s' "$vpcs" | grep -oE '"ip_range":"10\.10\.[0-9]+\.0/[0-9]+"' | cut -d. -f3 || true)"
      do_checked=yes
    fi
  fi
fi
pick=""
for (( r = 2; r < 254; r += 2 )); do
  if ! grep -qwE "($r|$((r + 1)))" <<<"$(echo $used)"; then pick=$r; break; fi
done
[[ -n "$pick" ]] || { echo "REFUSED: no free 10.10.X.0/24 pair" >&2; exit 1; }

mkdir -p "$dir"
cat > "$dir/config.yml" <<EOF
runners:
  delta:
    name: delta
    runner_executor_type: docker

cluster_ip_range: 10.10.$((pick + 1)).0/24
runners_ip_range: 10.10.$pick.0/24
subscription_key: <ВПИШИ ключ подписки Semaphore Pro>
cluster: $cluster
ha_disabled: false

# Redis Sentinel cluster: redis_nodes droplets (1 master + replicas), each running
# redis-server and redis-sentinel. quorum = sentinels that must agree the master is down.
redis_nodes: $redis_nodes
redis_sentinel_quorum: $redis_quorum
redis_master_name: semaphore
EOF
echo "CREATED workspaces/$name/config.yml"
echo "  cluster=$cluster redis_nodes=$redis_nodes redis_sentinel_quorum=$redis_quorum runner=delta (docker)"
echo "  cluster_ip_range=10.10.$((pick + 1)).0/24 runners_ip_range=10.10.$pick.0/24 (checked against DO VPCs: $do_checked)"
if ! git -C "$repo" check-ignore -q "workspaces/$name/config.yml"; then
  echo "  WARN workspaces/$name/config.yml is NOT gitignored on this branch: do not commit it"
fi

if [[ ! -f "$env_file" ]]; then
  # Newest release (prereleases included) whose linux_amd64 archive downloads. The
  # Atom feed is not rate-limited like the anonymous REST API; gh is tried first.
  tags=$( { gh api 'repos/semaphoreui/semaphore/releases?per_page=30' --jq '.[].tag_name' 2>/dev/null \
            || curl -sf --max-time 20 https://github.com/semaphoreui/semaphore/releases.atom \
               | grep -oE 'releases/tag/v[^"<]+' | cut -d/ -f3; } | sed 's/^v//' | head -15 || true)
  ver=""
  for t in $tags; do
    code=$(curl -s -o /dev/null -w '%{http_code}' -IL --max-time 20 \
      "https://github.com/semaphoreui/semaphore/releases/download/v$t/semaphore_${t}_linux_amd64.tar.gz" || true)
    [[ "$code" == 200 ]] && { ver=$t; break; }
  done
  umask 077
  NEW_VERSION="${ver:-<ВПИШИ опубликованную версию>}" python3 -I - "$env_example" "$env_file" <<'PY'
import os, re, secrets, base64, sys
src, dst = sys.argv[1], sys.argv[2]
hexed = {"db_password", "redis_password", "redis_sentinel_password", "semaphore_admin_password"}
b64 = {"semaphore_cookie_hash", "semaphore_cookie_encryption", "semaphore_access_key_encryption"}
fixed = {"semaphore_version": os.environ["NEW_VERSION"],
         "parent_domain": "<ВПИШИ домен зоны Cloudflare>",
         "ssh_key_name": "<ВПИШИ имя ssh-ключа в DigitalOcean>"}
out = []
for line in open(src):
    m = re.match(r'^TF_VAR_([a-z0-9_]+)=', line)
    if m:
        k = m.group(1)
        if k in hexed: line = f'TF_VAR_{k}="{secrets.token_hex(16)}"\n'
        elif k in b64: line = f'TF_VAR_{k}="{base64.b64encode(secrets.token_bytes(32)).decode()}"\n'
        elif k in fixed: line = f'TF_VAR_{k}="{fixed[k]}"\n'
    out.append(line)
open(dst, "w").write("".join(out))
PY
  chmod 600 "$env_file"
  echo "CREATED ha_stand/.env (600): passwords and keys generated, Semaphore ${ver:-version NOT found, fill it in}"
else
  echo "KEPT ha_stand/.env (it already exists and is shared by all stands)"
fi

# What is still to be filled in, by name only.
todo=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$env_file" | grep -vE '^TF_VAR_do_k8s_cluster=' \
  | grep -E '<ВПИШИ|\.\.\."|<r2 |<account_id>|change-me' | cut -d= -f1 || true)
echo "TODO workspaces/$name/config.yml: subscription_key"
for k in $todo; do echo "TODO ha_stand/.env: $k"; done
