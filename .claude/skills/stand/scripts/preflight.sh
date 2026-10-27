#!/usr/bin/env bash
# Pre-flight checks for bringing up an ha_stand stand from this machine with OpenTofu.
#
#   .claude/skills/stand/scripts/preflight.sh <stand-name>
#
# Read-only: only GET/list API calls, creates nothing, prints no secret values.
# Exit code: 0 = all checks passed, 1..63 = number of failed checks, 64 = usage error.
set -uo pipefail

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "usage: $0 <stand-name>" >&2
  exit 64
fi

repo="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/../../../.." && pwd))"
env_file="$repo/ha_stand/.env"
env_example="$repo/ha_stand/.env.example"
config="$repo/workspaces/$name/config.yml"
fails=0
ok()   { echo "  OK   $*"; }
warn() { echo "  WARN $*"; }
fail() { echo "  FAIL $*"; fails=$((fails + 1)); }

echo "== tools"
for t in tofu curl ssh ssh-add python3; do
  command -v "$t" >/dev/null && ok "$t" || fail "$t not found"
done

echo "== files"
if [[ -f "$env_file" ]]; then ok "ha_stand/.env"; else fail "ha_stand/.env missing (cp ha_stand/.env.example ha_stand/.env)"; fi
if [[ -f "$config" ]]; then ok "workspaces/$name/config.yml"; else fail "workspaces/$name/config.yml missing (.claude/skills/stand/scripts/new-stand.sh $name)"; fi
if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  fail "stand name '$name' is not DNS-safe (lowercase, digits, hyphens)"
fi
(( fails )) && { echo "$fails check(s) failed"; exit "$fails"; }

set -a; source "$env_file"; set +a

echo "== placeholders and example values"
# TF_VAR_do_k8s_cluster is only needed for k8s runners; its example value "..." is not an error.
left=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$env_file" | grep -vE '^TF_VAR_do_k8s_cluster=' \
  | grep -E '<ВПИШИ|\.\.\."|<r2 |<account_id>|change-me' | cut -d= -f1)
[[ -z "$left" ]] && ok ".env has no placeholders" || fail ".env still has placeholders in: $(echo $left)"
# Any secret still equal to the value committed in .env.example is public.
if [[ -f "$env_example" ]]; then
  same=""
  while IFS= read -r line; do
    k=${line%%=*}; v=${line#*=}; v=${v#\"}; v=${v%\"}
    case "$k" in TF_VAR_aws_region|TF_VAR_semaphore_version|TF_VAR_parent_domain|TF_VAR_ssh_key_name|TF_VAR_do_k8s_cluster) continue ;; esac
    [[ -n "$v" && "${!k:-}" == "$v" ]] && same="$same $k"
  done < <(grep -E '^TF_VAR_[A-Za-z0-9_]+=' "$env_example")
  [[ -z "$same" ]] && ok "no secret is left at its .env.example value" || fail "still at the public .env.example value:$same (openssl rand -base64 32 / -hex 16)"
fi
if grep -qE '^subscription_key: *(<|75b1875e-\.\.\.)' "$config"; then
  fail "config.yml: subscription_key is a placeholder"
elif grep -qE '^subscription_key: *75b1875e-' "$config"; then
  warn "config.yml: subscription_key is the key committed in workspaces/stress1/ (public in git history, incident S1)"
else
  ok "config.yml: subscription_key set"
fi
for v in TF_VAR_do_token TF_VAR_cloudflare_api_token TF_VAR_parent_domain TF_VAR_ssh_key_name \
         TF_VAR_aws_access_key TF_VAR_aws_secret_key TF_VAR_semaphore_version \
         TF_VAR_semaphore_admin_password TF_VAR_redis_password TF_VAR_redis_sentinel_password; do
  [[ -n "${!v:-}" ]] || fail "$v is empty"
done
if [[ -n "${TF_VAR_s3_endpoint:-}" ]]; then
  for v in AWS_REQUEST_CHECKSUM_CALCULATION AWS_RESPONSE_CHECKSUM_VALIDATION; do
    [[ "${!v:-}" == when_required ]] || fail "$v must be when_required for R2 (the token upload fails late otherwise)"
  done
fi

echo "== semaphore release"
v="${TF_VAR_semaphore_version:-}"
code=$(curl -s -o /dev/null -w '%{http_code}' -IL --max-time 20 \
  "https://github.com/semaphoreui/semaphore/releases/download/v$v/semaphore_${v}_linux_amd64.tar.gz")
[[ "$code" == 200 ]] && ok "v$v is published" || fail "v$v not downloadable (HTTP $code)"

echo "== cloudflare"
cf() { curl -s --max-time 20 -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" "https://api.cloudflare.com/client/v4/$1"; }
zone=$(cf "zones?name=$TF_VAR_parent_domain" | python3 -c 'import sys,json
try: d = json.load(sys.stdin)
except Exception: print("none no-JSON-from-api.cloudflare.com"); sys.exit()
r = d.get("result") or []
errs = ";".join(e.get("message", "") for e in d.get("errors") or [])
print(r[0]["id"] + " " + r[0]["status"] if r else "none " + (errs or "not-visible-to-token"))')
zone_id=${zone%% *}; zone_status=${zone#* }
if [[ "$zone_id" != none && "$zone_status" == active ]]; then
  ok "zone $TF_VAR_parent_domain is active and visible to the token"
  n=$(cf "zones/$zone_id/dns_records?name=$name-lb.$TF_VAR_parent_domain" | python3 -c 'import sys,json
try: print(len(json.load(sys.stdin).get("result") or []))
except Exception: print("?")')
  case "$n" in
    0) ok "record $name-lb.$TF_VAR_parent_domain is free" ;;
    "?") fail "could not list DNS records (token needs DNS read/edit on the zone)" ;;
    *) fail "record $name-lb.$TF_VAR_parent_domain already exists (another stand with this name?)" ;;
  esac
else
  fail "zone $TF_VAR_parent_domain: $zone_status (token needs Zone:Read + DNS:Edit on it)"
fi

echo "== digitalocean"
do_get() { curl -s --max-time 20 -H "Authorization: Bearer $TF_VAR_do_token" "https://api.digitalocean.com/v2/$1"; }
do_fp=$(do_get "account/keys?per_page=200" | python3 -c 'import sys,json,os
try: d = json.load(sys.stdin)
except Exception: print("ERR no JSON from api.digitalocean.com (network? HTTP error?)"); sys.exit()
if "ssh_keys" not in d: print("ERR " + str(d.get("message", "unexpected reply"))); sys.exit()
keys = d.get("ssh_keys") or []
print(next((k["fingerprint"] for k in keys if k.get("name") == os.environ["TF_VAR_ssh_key_name"]), "MISSING"))')
case "$do_fp" in
  ERR*)    fail "DO token rejected or API unreachable: ${do_fp#ERR }" ;;
  MISSING) fail "DO has no ssh key named '$TF_VAR_ssh_key_name'" ;;
  *)       ok "DO token works, ssh key '$TF_VAR_ssh_key_name' found"
           if ssh-add -l -E md5 2>/dev/null | grep -q "MD5:$do_fp"; then
             ok "matching private key is loaded in ssh-agent"
           else
             fail "private key for '$TF_VAR_ssh_key_name' is not in ssh-agent (ssh-add <key>)"
           fi
           # Leftovers from an earlier stand with this name break the apply (name clashes).
           for kind in vpcs projects load_balancers; do
             hits=$(do_get "$kind?per_page=200" | STAND="$name" KIND="$kind" python3 -c 'import sys,json,os
try: d = json.load(sys.stdin)
except Exception: print("?"); sys.exit()
items = d.get(os.environ["KIND"]) or []
print(" ".join(i.get("name", "") for i in items if os.environ["STAND"] in i.get("name", "")))')
             case "$hits" in
               "") ok "DO $kind: nothing named like '$name'" ;;
               "?") warn "DO $kind: could not list (token scope?)" ;;
               *) fail "DO $kind already has: $hits" ;;
             esac
           done ;;
esac

echo "== r2 / s3"
python3 -I - "$name" <<'PY'
import os, hmac, hashlib, datetime, urllib.request, urllib.error, re, sys
stand = sys.argv[1]
ep = os.environ.get("TF_VAR_s3_endpoint", "").rstrip("/")
if not ep:
    print("  WARN s3_endpoint empty (AWS S3 mode): SigV4 check skipped"); sys.exit(0)
host = ep.split("://", 1)[-1]
ak, sk = os.environ.get("TF_VAR_aws_access_key", ""), os.environ.get("TF_VAR_aws_secret_key", "")
region = os.environ.get("TF_VAR_aws_region") or "auto"
t = datetime.datetime.now(datetime.timezone.utc); amz = t.strftime("%Y%m%dT%H%M%SZ"); day = t.strftime("%Y%m%d")
ph = hashlib.sha256(b"").hexdigest(); signed = "host;x-amz-content-sha256;x-amz-date"
canon = "\n".join(["GET", "/", "", f"host:{host}", f"x-amz-content-sha256:{ph}", f"x-amz-date:{amz}", "", signed, ph])
scope = f"{day}/{region}/s3/aws4_request"
sts = "\n".join(["AWS4-HMAC-SHA256", amz, scope, hashlib.sha256(canon.encode()).hexdigest()])
k = ("AWS4" + sk).encode()
for m in (day, region, "s3", "aws4_request"): k = hmac.new(k, m.encode(), hashlib.sha256).digest()
sig = hmac.new(k, sts.encode(), hashlib.sha256).hexdigest()
req = urllib.request.Request(ep + "/", headers={"x-amz-date": amz, "x-amz-content-sha256": ph,
    "Authorization": f"AWS4-HMAC-SHA256 Credential={ak}/{scope}, SignedHeaders={signed}, Signature={sig}"})
try:
    body = urllib.request.urlopen(req, timeout=20).read().decode()
except urllib.error.HTTPError as e:
    print("  FAIL S3 endpoint rejected the keys:", e.code, re.findall(r"<Code>([^<]+)<", e.read().decode(errors="replace"))); sys.exit(1)
except Exception as e:
    print("  FAIL S3 endpoint unreachable:", type(e).__name__); sys.exit(1)
print("  OK   S3 endpoint accepts the keys (ListBuckets)")
bucket = os.environ.get("TF_VAR_s3_bucket") or stand + "-semaphore-stand"
if bucket in re.findall(r"<Name>([^<]+)</Name>", body):
    print(f"  FAIL bucket {bucket} already exists (left over from an earlier stand?)"); sys.exit(1)
print(f"  OK   bucket {bucket} does not exist yet")
PY
(( $? )) && fails=$((fails + 1))

echo "== local state"
for m in server runner; do
  st="$repo/ha_stand/do/$m/terraform.tfstate.d/$name/terraform.tfstate"
  if [[ -s "$st" ]] && python3 -c 'import sys,json; sys.exit(0 if json.load(open(sys.argv[1])).get("resources") else 1)' "$st" 2>/dev/null; then
    warn "$m: state for '$name' already has resources (stand is up or half-up)"
  else
    ok "$m: no resources in local state for '$name'"
  fi
done

echo
(( fails )) && echo "$fails check(s) failed" || echo "all checks passed"
exit "$fails"
