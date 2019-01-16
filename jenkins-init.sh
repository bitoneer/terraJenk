#!/bin/bash
set -e -x

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales

# install java
sudo apt update
sudo apt install -y openjdk-8-jdk

# install jenkins
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo bash -c 'echo "deb http://pkg.jenkins.io/debian-stable binary/" >> /etc/apt/sources.list'
sudo apt-get update
sudo apt-get install -y jenkins=2.150.1

# wait for jenkins up
while ! nc -z localhost 8080 ; do sleep 1 ; done

# bypass the startup wizard 
cat > /var/lib/jenkins/jenkins.install.UpgradeWizard.state << EOF
2.150.1
EOF
sudo chmod 777 /var/lib/jenkins/jenkins.install.UpgradeWizard.state

sudo mkdir /var/lib/jenkins/init.groovy.d/
sudo sh -c "cat > /var/lib/jenkins/init.groovy.d/basic-security.groovy <<EOF
#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('admin','admin')
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()
EOF
"
sudo chmod 777 /var/lib/jenkins/init.groovy.d/
sudo chmod 777 /var/lib/jenkins/init.groovy.d/basic-security.groovy


# set the cli port
sudo apt install xmlstarlet
sudo xmlstarlet -q ed -u "//slaveAgentPort" -v "49187" /var/lib/jenkins/config.xml > /tmp/jenkins_config.xml
sudo mv /tmp/jenkins_config.xml /var/lib/jenkins/config.xml
sudo service jenkins restart

# wait for jenkins up
while ! nc -z localhost 8080 ; do sleep 1 ; done

# get the admin password
sudo cp /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar /var/lib/jenkins/jenkins-cli.jar
PASS=$(sudo bash -c "cat /var/lib/jenkins/secrets/initialAdminPassword")



