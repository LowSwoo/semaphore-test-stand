#!/usr/bin/env bash
# Add network latency between the Semaphore UI nodes and PostgreSQL, to mimic a
# remote / shared database platform. netem delays what the postgres droplet
# sends into the VPC, so every query round trip and every step of a new
# connection (TCP + SCRAM handshake) to the UI nodes gets slower; the runners,
# Redis and SSH are not affected.
#
#   ./db_latency.sh <workspace> <delay>     # e.g. 5ms, 20ms, "20ms 5ms" (delay + jitter)
#   ./db_latency.sh <workspace> off
#   ./db_latency.sh <workspace>             # show the current setting
set -euo pipefail

ws=${1:?usage: $0 <workspace> [<delay>|off]}
delay=${2:-}

cd "$(dirname "$0")/server"
pg=$(TF_WORKSPACE="$ws" terraform output -json postgres_server)
pg_ip=$(jq -r .public_ip <<<"$pg")
private_ip=$(jq -r .private_ip <<<"$pg")

ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=10 -o LogLevel=ERROR \
  root@"$pg_ip" bash -s -- "$private_ip" "$delay" <<'REMOTE'
set -euo pipefail
private_ip=$1 delay=$2

dev=$(ip -o -4 addr show | awk -v ip="$private_ip" '{ split($4, a, "/") } a[1] == ip { print $2; exit }')
[[ -n $dev ]] || { echo "no interface holds $private_ip" >&2; exit 1; }

case $delay in
  '') ;;
  off) tc qdisc del dev "$dev" root 2>/dev/null || true ;;
  *)
    # Ubuntu ships sch_netem in linux-modules-extra, which cloud images may lack.
    if ! modprobe sch_netem 2>/dev/null; then
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "linux-modules-extra-$(uname -r)" >/dev/null
      modprobe sch_netem
    fi
    # shellcheck disable=SC2086 # "20ms 5ms" is delay + jitter
    tc qdisc replace dev "$dev" root netem delay $delay
    ;;
esac

echo "$dev ($private_ip): $(tc qdisc show dev "$dev" | head -n 1)"
REMOTE
