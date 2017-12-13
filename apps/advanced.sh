#!/bin/sh

# Repeat
REPEAT=${SS_REPEAT:-2}
SLEEP_TIME=${SS_SLEEP:-3}

chmod 400 roles/infrastructure/files/ansible_id*
chmod +x scripts/*.py

if [ `python scripts/openstack.py --host beijing | wc -l` -gt 2 ]; then
  curl -sL --connect-timeout 5 --retry 2 -k https://$BEIJING_DOMAIN:8888 -u $SYNC_GUIUSER:$SYNC_GUIPWD > /dev/null || (
    SSHFILE=~/.ssh/config
    SSHFILEOK="True"

    if [ ! -f $SSHFILE ]; then
      # Not enough public IPs, use SSH bastion for private IP connections
      SSHFILESIZE=0
      SSHFILEOK="False"

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
    fi

    if [ "$SSHFILEOK"=="True" ]; then
      if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
      fi
      cp roles/infrastructure/files/ansible_id ~/.ssh/id_rsa
      cp roles/infrastructure/files/ansible_id.pub ~/.ssh/id_rsa.pub

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
        ansible-playbook -i scripts/openstack.py instances-setup_advanced.yml -T ${SSH_TIMEOUT:-60} -v
        if [ -f instances-setup_advanced.retry ]; then
          rm -rf instances-setup_advanced.retry
        else
          break
        fi

        sleep $SLEEP_TIME
      done
    else
      echo "SSH bastion configuration failed ..."
    fi
  )
else
  echo "NO VM machine resource available..."
fi

