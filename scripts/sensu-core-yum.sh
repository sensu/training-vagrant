#!/bin/bash
PUB_KEY=https://repositories.sensuapp.org/yum/pubkey.gpg

if rpm --import "$PUB_KEY" ; then
  echo "Successfully imported GPG public key"
else
  echo "Importing GPG public key failed"
  exit 1
fi


echo "[sensu]
name=sensu
baseurl=https://repositories.sensuapp.org/yum/\$releasever/\$basearch/
gpgcheck=1
enabled=1" > /etc/yum.repos.d/sensu.repo

SENSU_REPO_SUCCESS=$?

if [ $SENSU_REPO_SUCCESS -eq 0 ] ; then
  echo "Successfully added Sensu Core yum repository definition"
else
  echo "Failed to install Sensu Core yum repository definition"
  exit 1
fi

