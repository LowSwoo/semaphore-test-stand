ssh root@$2 systemctl stop $1
if [[ $1 == "semaphore" ]]; then
  scp config.json root@$2:/etc/semaphore/
else 
  scp runner-config.json root@$2:/etc/semaphore/
fi
ssh root@$2 systemctl start $1
