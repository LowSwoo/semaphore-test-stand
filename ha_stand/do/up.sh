set -e

set -a; source ../.env; set +a

cd server

terraform init -input=false > /dev/null

if [[ -n "$1" ]]; then
  terraform workspace select -or-create $1
fi

terraform apply -auto-approve


web_root=$(terraform output -raw semaphore_url)
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

cd ..

cd runner

terraform init -input=false > /dev/null

if [[ -n "$1" ]]; then
  terraform workspace select -or-create $1
fi

terraform apply -auto-approve
