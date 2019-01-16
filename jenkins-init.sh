#!/bin/bash

# install java
sudo apt update
sudo apt install openjdk-8-jdk

# install jenkins
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
echo "deb http://pkg.jenkins.io/debian-stable binary/" >> /etc/apt/sources.list
apt-get update
apt-get install -y jenkins=2.150.1

# wait for jenkins up
while ! nc -z localhost 8080 ; do sleep 1 ; done

# bypass the startup wizard 
cat > /var/lib/jenkins/jenkins.install.UpgradeWizard.state << EOF
2.0
EOF

cat > /var/lib/jenkins/init.groovy.d/basic-security.groovy << EOF
#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

println "--> creating local user 'admin'"

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('{{ jenkins_admin_username }}','{{ jenkins_admin_password }}')
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()
EOF

# set the cli port
sudo apt install xmlstarlet
xmlstarlet -q ed -u "//slaveAgentPort" -v "49187" /var/lib/jenkins/config.xml > /tmp/jenkins_config.xml
sudo mv /tmp/jenkins_config.xml /var/lib/jenkins/config.xml
sudo service jenkins restart

# wait for jenkins up
while ! nc -z localhost 8080 ; do sleep 1 ; done

# get the admin password
sudo cp /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar /var/lib/jenkins/jenkins-cli.jar
PASS=$(sudo bash -c "cat /var/lib/jenkins/secrets/initialAdminPassword")



