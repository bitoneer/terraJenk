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
sudo apt-get install -y xmlstarlet
sudo sh -c "xmlstarlet -q ed -u '//slaveAgentPort' -v '49187' /var/lib/jenkins/config.xml > /tmp/jenkins_config.xml"
sudo sh -c "xmlstarlet -q ed -u '//installStateName' -v 'NORMAL' /tmp/jenkins_config.xml > /tmp/jenkins_config2.xml"

sudo mv /tmp/jenkins_config2.xml /var/lib/jenkins/config.xml
sudo service jenkins restart

# wait for jenkins up
while ! nc -z localhost 8080 ; do sleep 1 ; done

# get the admin password
sudo cp /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar /var/lib/jenkins/jenkins-cli.jar

# Initialization of Plugins
#

jenkins_plugins=""

DEFAULT_PLUGINS="docker-workflow ant build-timeout credentials-binding email-ext github-organization-folder gradle workflow-aggregator ssh-slaves subversion timestamper ws-cleanup"

JENKINS_HOME=/var/lib/jenkins

if [ -n "${JENKINS_PLUGINS}" ]; then
  JENKINS_PLUGINS=$JENKINS_PLUGINS" "$DEFAULT_PLUGINS
else
  JENKINS_PLUGINS=$DEFAULT_PLUGINS
fi

if [ -n "${JENKINS_PLUGINS}" ]; then
  if [ ! -d "${JENKINS_HOME}/init.groovy.d" ]; then
    mkdir ${JENKINS_HOME}/init.groovy.d
  fi
  jenkins_plugins=${JENKINS_PLUGINS}
  cat > ${JENKINS_HOME}/init.groovy.d/loadPlugins.groovy <<_EOF_
import jenkins.model.*
import java.util.logging.Logger
def logger = Logger.getLogger("")
def installed = false
def initialized = false
def pluginParameter="${jenkins_plugins}"
def plugins = pluginParameter.split()
logger.info("" + plugins)
def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()
def uc = instance.getUpdateCenter()
plugins.each {
  logger.info("Checking " + it)
  if (!pm.getPlugin(it)) {
    logger.info("Looking UpdateCenter for " + it)
    if (!initialized) {
      uc.updateAllSites()
      initialized = true
    }
    def plugin = uc.getPlugin(it)
    if (plugin) {
      logger.info("Installing " + it)
        def installFuture = plugin.deploy()
      while(!installFuture.isDone()) {
        logger.info("Waiting for plugin install: " + it)
        sleep(3000)
      }
      installed = true
    }
  }
}
if (installed) {
  logger.info("Plugins installed, initializing a restart!")
  instance.save()
  instance.restart()
}
_EOF_
fi

sudo java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080 -auth admin:admin groovy = < /var/lib/jenkins/init.groovy.d/loadPlugins.groovy
