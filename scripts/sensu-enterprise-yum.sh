#!/bin/bash
PUB_KEY=https://repositories.sensuapp.org/yum/pubkey.gpg

if [ -z "$SE_USER" ] || [ -z "$SE_PASS" ]; then
    echo "SE_USER and SE_PASS credentials are required"
    exit 1
fi

if rpm --import "$PUB_KEY" ; then
  echo "Successfully imported GPG public key"
else
  echo "Importing GPG public key failed"
  exit 1
fi

echo "[sensu-enterprise]
name=sensu-enterprise
baseurl=https://$SE_USER:$SE_PASS@enterprise.sensuapp.com/yum/noarch/
gpgcheck=1
enabled=1" > /etc/yum.repos.d/sensu-enterprise.repo

SE_REPO_SUCCESS=$?

if [ $SE_REPO_SUCCESS -eq 0 ] ; then
  echo "Successfully added Sensu Enterprise yum repository definition"
else
  echo "Failed to install Sensu Enterprise yum repository definition"
  exit 1
fi

echo "[sensu-enterprise-dashboard]
name=sensu-enterprise
baseurl=https://$SE_USER:$SE_PASS@enterprise.sensuapp.com/yum/\$basearch/
gpgcheck=1
enabled=1" > /etc/yum.repos.d/sensu-enterprise-dashboard.repo

SED_REPO_SUCCESS=$?

if [ $SED_REPO_SUCCESS -eq 0 ] ; then
  echo "Successfully added Sensu Enterprise Dashboard yum repository definition"
else
  echo "Failed to install Sensu Enterprise Dashboard yum repository definition"
  exit 1
fi

