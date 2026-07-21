droplets=$(doctl compute droplet list --format PublicIPv4 --no-header --tag-name $1)

echo Tag: $1
echo Service name: $2

echo $droplets | xargs -P 20 -n 1 ./upload_semaphore.sh $2
