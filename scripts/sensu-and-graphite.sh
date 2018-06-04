#!/bin/sh
IPADDR=$(/sbin/ip -o -4 addr list enp0s8  | awk '{print $4}' | cut -d/ -f1)

# Make sure we have all the package repos we need!
sudo yum install epel-release vim yum-utils openssl httpd python-devel cairo-devel libffi-devel mod_wsgi git bitmap-fonts -y
sudo yum groupinstall 'Development Tools' -y
sudo yum install python-pip -y

# Set up zero-dependency erlang
echo ' [rabbitmq-erlang]
name=rabbitmq-erlang
baseurl=https://dl.bintray.com/rabbitmq/rpm/erlang/20/el/7
gpgcheck=1
gpgkey=https://www.rabbitmq.com/rabbitmq-release-signing-key.asc
repo_gpgcheck=0
enabled=1' | sudo tee /etc/yum.repos.d/rabbitmq-erlang.repo
 sudo yum install erlang -y

# Install rabbitmq
 sudo yum install https://dl.bintray.com/rabbitmq/rabbitmq-server-rpm/rabbitmq-server-3.6.12-1.el7.noarch.rpm -y

# Set up Sensu's repository & Sensu Enterprise
echo '[sensu]
name=sensu
baseurl="https://repositories.sensuapp.org/yum/$releasever/$basearch/"
gpgcheck=0
enabled=1' | sudo tee /etc/yum.repos.d/sensu.repo

# Get Redis installed
 sudo yum install redis -y

# Install Sensu itself
 sudo yum install sensu uchiwa -y

# Provide minimal transport configuration (used by client, server and API)
 echo '{
  "transport": {
    "name": "rabbitmq"
  }
}' | sudo tee /etc/sensu/transport.json

# provide minimal client configuration
 echo "{
 \"client\": {
   \"address\": \"$IPADDR\",
   \"environment\": \"development\",
   \"subscriptions\": [
     \"dev\"
   ]
 }
}" |sudo tee /etc/sensu/conf.d/client.json

# Ensure config file permissions are correct
 sudo chown -R sensu:sensu /etc/sensu

# Install curl and jq helper utilities
 sudo yum install curl jq -y

# Provide minimal uchiwa conifguration, pointing at API on localhost
# Optionally, you can see Sensu datacenters(see https://docs.uchiwa.io/getting-started/configuration/#datacenters-configuration-sensu) in action by adding an additional 
# configuration for another datacenter. If you, by chance, spin up Sensu using 
# kubernetes, it might look like this:

#    {                
#      "name": "sensu-k8s",                     
#      "host": "your-minikube-ip",                 
#      "port": your-minikube-service-port
#    }

  echo '{
  "sensu": [
    {
      "name": "sensu",
      "host": "127.0.0.1",
      "port": 4567
    }
  ],
  "uchiwa": {
    "host": "0.0.0.0",
    "port": 3000
  }
 }' |sudo tee /etc/sensu/uchiwa.json

# Configure sensu to use rabbitmq

echo '{
  "rabbitmq": {
    "host": "127.0.0.1",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "secret",
    "heartbeat": 30,
    "prefetch": 50
  }
}' | sudo tee /etc/sensu/conf.d/rabbitmq.json

# Configure minimal Redis configuration for Sensu

echo '{
  "redis": {
    "host": "127.0.0.1",
    "port": 6379
  }
}' | sudo tee /etc/sensu/conf.d/redis.json

# Start up rabbitmq services
sudo systemctl start rabbitmq-server

# Add rabbitmq vhost configurations
sudo rabbitmqctl add_vhost /sensu
sudo rabbitmqctl add_user sensu secret
sudo rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"

# Going to do some general setup stuff
cd /etc/sensu/conf.d
mkdir {checks,filters,mutators,handlers,templates}

# Installing some Nagios & Sensu plugins
sudo yum install -y nagios-plugins nagios-plugins-disk

sudo yum update -y

sudo sensu-install -p sensu-plugins-network-checks
sudo sensu-install -p sensu-plugins-disk-checks
sudo sensu-install -p sensu-plugins-graphite
sudo sensu-install -p sensu-plugins-http
sudo sensu-install -p sensu-plugins-mailer
sudo sensu-install -e snmp-trap:0.0.33

# Creating a some building blocks
# Disk check - Uses the nagios-disk plugin 
echo '{
  "checks": {
    "fs_free_space": {
      "command": "/usr/lib64/nagios/plugins/check_disk  -w 90 -c 95",
      "subscribers": ["dev"],
      "interval": 30,
      "handlers": ["graphite_tcp"]
    }
  }
}' | sudo tee /etc/sensu/conf.d/checks/check_disk.json

echo '{
  "checks": {
    "metric-disk-check": {
      "command": "metrics-disk-usage.rb",
      "type": "metric",
      "subscribers": ["dev"],
      "interval": 10,
      "handlers": ["graphite_tcp"],
      "mutator": "only_check_output"
    }
  }
}' | sudo tee /etc/sensu/conf.d/checks/nagios_check_disk.json

# Filter - 
echo '{
  "filters": {
    "development": {
      "attributes": {
        "client": {
          "environment": "development"
        }
      },
      "negate": false
    }
  }
}' | sudo tee /etc/sensu/conf.d/filters/dev_filter.json

# Mutator - Using the community 'Graphite' plugin, which adds the mutator executable
echo '{
  "mutators": {
    "graphite": {
      "command": "mutator-graphite.rb"
    }
  }
}' | sudo tee /etc/sensu/conf.d/mutators/graphite.json


# Handlers 
# Using the community 'Mailer' plugin (https://github.com/sensu-plugins/sensu-plugins-mailer)
echo '{
    "mailer" :  {
        "admin_gui" : "http://localhost:3000",
        "mail_from": "from@email.com",
        "mail_to": "to@email.com",
        "delivery_method": "smtp",
        "smtp_address": "localhost",
        "smtp_port": "25",
        "smtp_domain": "localhost.local_domain",
        "smtp_enable_starttls_auto": "true",
        "smtp_username" : "username",
        "smtp_password" : "XXXXXXXX"
    },  
    "handlers": {
        "mailer": {
            "type": "pipe",
            "command": "/opt/sensu/embedded/bin/handler-mailer.rb"
        }
    }
}' | sudo tee /etc/sensu/conf.d/handlers/mailer.json

# Using the community 'Graphite' handler (https://github.com/sensu-plugins/sensu-plugins-graphite)
echo '{
  "handlers": {
    "graphite_tcp": {
      "type": "tcp",
      "socket": {
        "host":"127.0.0.1",
        "port":2003
      },
      "mutator": "only_check_output",
      "prefix": "sensu",
      "tags": [
        "dev"
      ]
    }
  }
}' | sudo tee /etc/sensu/conf.d/handlers/graphite_tcp.json



#Start up other services
sudo systemctl start sensu-{server,api,client}.service
sudo systemctl start redis.service
sudo systemctl start uchiwa
sudo systemctl enable uchiwa
sudo systemctl enable redis.service
sudo systemctl enable rabbitmq-server
sudo systemctl enable sensu-{server,api,client}.service

# Now setting up Graphite so we can do some cool graphing stuff
# Cloning the projects
cd /usr/local/src

sudo git clone https://github.com/graphite-project/carbon.git
sudo git clone https://github.com/graphite-project/graphite-web.git

# Installing via Python
sudo python -m pip install --upgrade pip setuptools

sudo pip install -r /usr/local/src/graphite-web/requirements.txt

cd /usr/local/src/carbon/
sudo python setup.py install
 
cd /usr/local/src/graphite-web/
sudo python setup.py install

# Adding our init scripts
sudo cp /usr/local/src/carbon/distro/redhat/init.d/carbon-* /etc/init.d/
sudo chmod +x /etc/init.d/carbon-*

# Setting up the db
sudo PYTHONPATH=/opt/graphite/webapp/ django-admin.py migrate --settings=graphite.settings

# Porting in the static files
sudo PYTHONPATH=/opt/graphite/webapp/ django-admin.py collectstatic --settings=graphite.settings

# Copying the config files we need
sudo cp /opt/graphite/conf/carbon.conf.example /opt/graphite/conf/carbon.conf
sudo cp /opt/graphite/conf/storage-schemas.conf.example /opt/graphite/conf/storage-schemas.conf
sudo cp /opt/graphite/conf/storage-aggregation.conf.example /opt/graphite/conf/storage-aggregation.conf
sudo cp /opt/graphite/conf/relay-rules.conf.example /opt/graphite/conf/relay-rules.conf
sudo cp /opt/graphite/webapp/graphite/local_settings.py.example /opt/graphite/webapp/graphite/local_settings.py
sudo cp /opt/graphite/conf/graphite.wsgi.example /opt/graphite/conf/graphite.wsgi
 
# Setting the appropriate perms
sudo chown -R apache:apache /opt/graphite/{storage,static,webapp}

# Copy the graphite vhost
sudo cp /vagrant/files/graphite.conf /etc/httpd/conf.d/graphite.conf

# Start the graphite services & apache
sudo service carbon-cache start
sudo chkconfig carbon-cache on
 
sudo systemctl enable httpd
sudo systemctl start httpd


echo -e "=================
Sensu is now up and running!
Access it at $IPADDR:3000
Access the Graphite Dashboard at:$IPADDR
================="

