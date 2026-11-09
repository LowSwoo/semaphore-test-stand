set -e

set -a; source ../.env; set +a

cd runner

terraform init -input=false > /dev/null

if [[ -n "$1" ]]; then
  terraform workspace select -or-create $1
fi

terraform apply \
    -var skip_server=1 \
    -var admin_token=acvooujvggshibkz4ouw-ibsz_usda02pydougvfduy= \
    -var web_root=https://semaphore-demo-1.ngrok.dev \
    -auto-approve
