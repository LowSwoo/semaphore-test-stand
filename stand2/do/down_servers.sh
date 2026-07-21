#!/usr/bin/env zsh
set -a; source ../.env; set +a

cd server

if [[ -n "$1" ]]; then
  terraform workspace select $1
fi

terraform destroy -auto-approve