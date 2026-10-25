#!/usr/bin/env zsh
# Destroy the runner half of a stand.
#
#   ./down_runners.sh [<workspace>] [--skip-server]
#
# Runner records live on the Semaphore server (semaphoreui_runner.*) and are
# normally deleted through its API with the admin token the server module left
# in /tmp/<workspace>-admin.token. When the servers are already gone (or that
# token file is), the API call cannot succeed and `terraform destroy` fails
# before touching a single droplet.
#
# --skip-server: forget the semaphoreui_runner.* records (terraform state rm)
# and destroy only the DigitalOcean resources. Implied automatically when the
# token file is missing. The records, if the server still exists, stay there
# and must be removed by hand.
set -e
set -a; source ../.env; set +a

workspace=""
skip_server=0
for arg in "$@"; do
  case "$arg" in
    --skip-server) skip_server=1 ;;
    --*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) workspace="$arg" ;;
  esac
done

cd runner

if [[ -n "$workspace" ]]; then
  terraform workspace select -or-create "$workspace"
fi
workspace=$(terraform workspace show)
token_file="/tmp/${workspace}-admin.token"

if (( ! skip_server )) && [[ ! -f "$token_file" ]]; then
  echo "WARNING: $token_file not found — cannot deregister runners on the server; implying --skip-server." >&2
  skip_server=1
fi

if (( skip_server )); then
  echo "Skipping server-side runner cleanup: dropping semaphoreui_runner.* from state."
  terraform state list 2>/dev/null | grep '^semaphoreui_runner\.' | while read -r addr; do
    terraform state rm "$addr"
  done
fi

terraform destroy -auto-approve -var "skip_server=$([[ $skip_server == 1 ]] && echo true || echo false)"
