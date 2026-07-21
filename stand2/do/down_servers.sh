#!/usr/bin/env zsh
set -a; source ../.env; set +a

cd server

if [[ -n "$1" ]]; then
  terraform workspace select $1
fi

TARGETS=("${(@f)$(terraform state list |
  grep -v -E 'cloudflare_' |
  sed 's/^/-target=/'
)}")

if (( ${#TARGETS[@]} == 0 )); then
  echo "No resources selected"
  exit 1
fi

echo "Targets:"
printf '  %s\n' "${TARGETS[@]}"

terraform destroy "${TARGETS[@]}" -auto-approve