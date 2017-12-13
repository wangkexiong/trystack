#!/bin/sh

TIME=`date +%s`
HOUR=`expr $TIME / 3600 % 24`
MINUTE=`expr $TIME / 60 % 60`

if [ $HOUR -eq 20 ]; then
  . $PWD/keystone_trystack1 && nova delete beijing hangzhou huhhot
  . $PWD/keystone_trystack2 && nova delete master1-k8s worker1-k8s worker2-k8s
fi

# Redirect stdio to LOGFILE
if [ "$LOGPATH" != "" ]; then
  exec 1>"$LOGPATH"
fi

# Repeat if SSH connection fail
REPEAT=${SS_REPEAT:-2}
SLEEP_TIME=${SS_SLEEP:-3}

if [ `python scripts/openstack.py --host beijing | wc -l` -lt 2 ]; then
  # Create the necessary instances
  #
  for i in `seq $REPEAT`
  do
    ansible-playbook instances-create.yml
    if [ -f instances-create.retry ]
    then
      rm -rf instances-create.retry
    else
      break
    fi

    sleep $SLEEP_TIME
  done
fi

# Not enough public IPs, use SSH bastion for private IP connections
chmod 400 roles/infrastructure/files/ansible_id*
chmod +x scripts/*.py

SSHFILE=~/.ssh/config
SSHFILESIZE=0
SSHFILEOK=False

for i in `seq $REPEAT`
do
  echo "Prepare SSH bastion configuration for $i time ..."
  python scripts/bastion.py --ucl --sshkey roles/infrastructure/files/ansible_id --refresh
  if [ -f $SSHFILE ]; then
    SSHFILESIZE=`stat -c%s $SSHFILE`
    if [ $SSHFILESIZE -gt 0 ]; then
      SSHFILEOK="True"
      break
    fi
  fi

  sleep $SLEEP_TIME
done

if [ "$SSHFILEOK"=="True" ]; then
  rm -rf ~/.ssh/id_rsa && ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
  cp roles/infrastructure/files/ansible_id ~/.ssh/id_rsa
  cp roles/infrastructure/files/ansible_id.pub ~/.ssh/id_rsa.pub

  SSH_CHECK=`ssh beijing -l ubuntu sudo tail -1 /etc/ddclient.conf`
  if [ "$SSH_CHECK" != "$BEIJING_DOMAIN" ]; then
    # Prepare the instances for ansible working
    #   - if no python installed, just DO IT
    #
    for i in `seq $REPEAT`
    do
      ansible-playbook -i scripts/openstack.py instances-prepare.yml -T ${SSH_TIMEOUT:-60}
      if [ -f instances-prepare.retry ]; then
        rm -rf instances-prepare.retry
      else
        break
      fi

      sleep $SLEEP_TIME
    done

    # Setup instances with playbook
    #
    for i in `seq $REPEAT`
    do
      ansible-playbook -i scripts/openstack.py instances-setup_abase.yml -T ${SSH_TIMEOUT:-60}
      if [ -f instances-setup_abase.retry ]; then
        rm -rf instances-setup_abase.retry
      else
        break
      fi

      sleep $SLEEP_TIME
    done
  fi
else
  echo "SSH bastion configuration failed ..."
fi

# Restore std output
exec 1>&2

