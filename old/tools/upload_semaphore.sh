echo Starting updating semaphore...

ssh root@$2 systemctl stop $1
scp semaphore root@$2:/usr/local/bin/semaphore
ssh root@$2 systemctl start $1


echo Done.
