#!/usr/bin/env bash
# Create (or update) an SSO stand and wait until Semaphore answers.
#
#   ./up.sh <workspace>
set -euo pipefail
cd "$(dirname "$0")"
set -a; source ../.env; set +a

tofu init -input=false > /dev/null
if [[ -n "${1:-}" ]]; then
  tofu workspace select -or-create "$1"
fi

tofu apply -auto-approve

web_root=$(tofu output -raw semaphore_url)
echo "Waiting for $web_root to become available..."
deadline=$(( $(date +%s) + 600 ))
until curl -sk -o /dev/null -f "$web_root/api/ping"; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "Timed out waiting for $web_root" >&2
    exit 1
  fi
  sleep 5
  echo "Still waiting for $web_root..."
done
echo "$web_root is available."
