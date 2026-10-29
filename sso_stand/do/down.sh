#!/usr/bin/env bash
# Destroy an SSO stand, Cloudflare records included.
#
#   ./down.sh <workspace>
set -euo pipefail
cd "$(dirname "$0")"
set -a; source ../.env; set +a

tofu init -input=false > /dev/null
if [[ -n "${1:-}" ]]; then
  tofu workspace select "$1"
fi

tofu destroy -auto-approve
