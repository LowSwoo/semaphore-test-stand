#!/usr/bin/env zsh
# Destroy the server half of a stand (keeps the Cloudflare records).
#
#   ./down_servers.sh [<workspace>]
#
# Options meant for down_runners.sh (e.g. --skip-server) are accepted and ignored
# so down.sh can pass the same argument list to both halves.
set -e
set -a; source ../.env; set +a

workspace=""
for arg in "$@"; do
  case "$arg" in
    --*) ;;
    *) workspace="$arg" ;;
  esac
done

cd server

if [[ -n "$workspace" ]]; then
  terraform workspace select -or-create "$workspace"
fi

terraform destroy -auto-approve
