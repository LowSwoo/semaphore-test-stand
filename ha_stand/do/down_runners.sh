#!/usr/bin/env zsh
# Destroy the runner half of a stand.
#
#   ./down_runners.sh [<workspace>] [--skip-server]
#
# Runner records live on the Semaphore server (semaphoreui_runner.*) and are
# normally deleted through its API with the admin token the server module
# uploaded to s3://<bucket>/<workspace>/admin.token. When the servers are
# already gone (and their bucket with them), the API call cannot succeed and
# `terraform destroy` fails before touching a single droplet.
#
# --skip-server: forget the semaphoreui_runner.* records (terraform state rm)
# and destroy only the DigitalOcean resources. Implied automatically when the
# token object is missing in S3 (checked with the aws CLI when available). The
# records, if the server still exists, stay there and must be removed by hand.
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
bucket="${TF_VAR_s3_bucket:-${workspace}-semaphore-stand}"
token_key="${workspace}/admin.token"

if (( ! skip_server )); then
  if command -v aws >/dev/null 2>&1; then
    export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-$TF_VAR_aws_access_key}"
    export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-$TF_VAR_aws_secret_key}"
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${TF_VAR_aws_region:-auto}}"
    endpoint_opt=()
    [[ -n "$TF_VAR_s3_endpoint" ]] && endpoint_opt=(--endpoint-url "$TF_VAR_s3_endpoint")
    if ! aws s3api head-object "${endpoint_opt[@]}" --bucket "$bucket" --key "$token_key" >/dev/null 2>&1; then
      echo "WARNING: s3://$bucket/$token_key not found — cannot deregister runners on the server; implying --skip-server." >&2
      skip_server=1
    fi
  else
    echo "NOTE: aws CLI not found — cannot check s3://$bucket/$token_key; pass --skip-server if the servers are gone." >&2
  fi
fi

if (( skip_server )); then
  echo "Skipping server-side runner cleanup: dropping semaphoreui_runner.* from state."
  terraform state list 2>/dev/null | grep '^semaphoreui_runner\.' | while read -r addr; do
    terraform state rm "$addr"
  done
fi

terraform destroy -auto-approve -var "skip_server=$([[ $skip_server == 1 ]] && echo true || echo false)"
