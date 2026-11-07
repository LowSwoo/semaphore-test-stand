#!/usr/bin/env bash
# Watch the PostgreSQL sessions of a stand, split by Semaphore UI node.
#
#   ./db_sessions.sh <workspace> [interval_sec]      # default interval: 5
#
# SSHes to the postgres droplet (key from ssh-agent, as the Terraform
# provisioners do) and prints one line per interval:
#
#   time      total  new/s     tps   ui-1 a/i/t   ui-2 a/i/t   ui-3 a/i/t  other
#   12:00:05      7    0.2     131        0/2/0        1/2/0        0/2/0      0
#
#   total   sessions connected to the Semaphore database (pg_stat_activity)
#   new/s   sessions opened per second since the previous line
#           (pg_stat_database.sessions): connection churn, not concurrency
#   tps     transactions per second (xact_commit + xact_rollback)
#   ui-N    sessions of that UI node: active / idle / idle in transaction
#   other   sessions from addresses that are not UI nodes
#
# The monitor connects to the "postgres" database, so it does not count itself.
# Ctrl-C stops it; pipe through `tee` to keep a log.
set -euo pipefail

ws=${1:?usage: $0 <workspace> [interval_sec]}
interval=${2:-5}

cd "$(dirname "$0")"
if [[ -f ../.env ]]; then set -a; source ../.env; set +a; fi
db_name=${TF_VAR_db_name:-semaphore}

cd server
# TF_WORKSPACE reads the stand's state without switching the selected workspace.
out() { TF_WORKSPACE="$ws" terraform output -json "$1"; }
pg_ip=$(out postgres_server | jq -r .public_ip)
# "<private ip>=<node name>" pairs, e.g. 10.10.40.3=ui-1.
nodes=$(out cluster_servers | jq -r 'to_entries | sort_by(.key) | .[] | "\(.value.private_ip)=\(.key)"')

# shellcheck disable=SC2086 # $nodes is a list of words on purpose
ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=10 -o LogLevel=ERROR \
  root@"$pg_ip" bash -s -- "$interval" "$db_name" $nodes <<'REMOTE'
set -euo pipefail
interval=$1 db=$2
shift 2

declare -A node_of=()   # private ip -> UI node name
order=()
for kv in "$@"; do
  node_of[${kv%%=*}]=${kv#*=}
  order+=("${kv%%=*}")
done

q() { sudo -u postgres psql -X -q -At -F '|' -d postgres -c "$1" </dev/null; }

echo "max_connections=$(q 'show max_connections'); database $db; every ${interval}s; Ctrl-C to stop"
header=$(printf '%-8s %6s %6s %7s' time total new/s tps)
for ip in "${order[@]}"; do header+=$(printf ' %12s' "${node_of[$ip]} a/i/t"); done
header+=$(printf ' %6s' other)

prev_t='' prev_s='' prev_x='' n=0
while :; do
  now=$(date +%s.%N)
  IFS='|' read -r sessions xacts < <(q "select sessions, xact_commit + xact_rollback from pg_stat_database where datname = '$db'")

  declare -A act=() idl=() itx=()
  total=0 other=0
  while IFS='|' read -r addr state cnt; do
    [[ -n $cnt ]] || continue
    total=$((total + cnt))
    if [[ -z ${node_of[$addr]:-} ]]; then
      other=$((other + cnt))
      continue
    fi
    case $state in
      idle) idl[$addr]=$((${idl[$addr]:-0} + cnt)) ;;
      'idle in transaction'*) itx[$addr]=$((${itx[$addr]:-0} + cnt)) ;;
      *) act[$addr]=$((${act[$addr]:-0} + cnt)) ;;
    esac
  done < <(q "select coalesce(host(client_addr), 'local'), coalesce(state, ''), count(*) from pg_stat_activity where datname = '$db' group by 1, 2")

  new='-' tps='-'
  if [[ -n $prev_t ]]; then
    new=$(awk -v a="$sessions" -v b="$prev_s" -v t1="$now" -v t0="$prev_t" 'BEGIN { printf "%.1f", (a - b) / (t1 - t0) }')
    tps=$(awk -v a="$xacts" -v b="$prev_x" -v t1="$now" -v t0="$prev_t" 'BEGIN { printf "%.0f", (a - b) / (t1 - t0) }')
  fi

  ((n % 20 == 0)) && echo "$header"
  line=$(printf '%-8s %6d %6s %7s' "$(date +%T)" "$total" "$new" "$tps")
  for ip in "${order[@]}"; do line+=$(printf ' %12s' "${act[$ip]:-0}/${idl[$ip]:-0}/${itx[$ip]:-0}"); done
  line+=$(printf ' %6d' "$other")
  echo "$line"

  prev_t=$now prev_s=$sessions prev_x=$xacts n=$((n + 1))
  sleep "$interval"
done
REMOTE
