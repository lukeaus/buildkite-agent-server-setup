#!/bin/bash

# ===================================
# VARIABLES - to edit
# ===================================

# Github details
# Edit these with your account details.
# If anyone else is to have access to any testing server, consider creating a new github account
# and then adding your new github user as a collaborator on your existing project. Then add the new user's github details below.
GITHUB_USERNAME='my-github-username'
GITHUB_PASSWORD='password for GITHUB_USERNAME'
GITHUB_EMAIL='email address for GITHUB_USERNAME'
# Get your Github token from 'Personal Settings --> Personal access tokens'.
# You will need to generate a new token if you do not already have one.
GITHUB_TOKEN='token for GITHUB_USERNAME'

# Buildkite details
# Get your buildkite token from here: https://buildkite.com/organizations/MY-BUILDKITE-ACCOUNT/agents
BUILDKITE_TOKEN='your token here'


# ===================================
# SCRIPT
# ===================================
SCRIPT_PATH="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

echo "Do not run this script as root or with root privileges "
echo "unless root will normally be running the buildkite agent"
sleep 5


# STEP - Buildkite Installation
# Steps below copied and pasted from: https://buildkite.com/organizations/myorg/agents
printf "\nInstalling buildkite agent\n"
if [ ! -f /usr/bin/buildkite-agent ]
then
    sudo sh -c 'echo deb https://apt.buildkite.com/buildkite-agent stable main > /etc/apt/sources.list.d/buildkite-agent.list'
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 32A37959C2FA5C3C99EFBC32A79206696452D198
    sudo apt-get update && sudo apt-get install -y buildkite-agent
    sudo sed -i "s/xxx/$BUILDKITE_TOKEN/g" /etc/buildkite-agent/buildkite-agent.cfg
    # add a tag so we can use agent targeting rules in buldkite to target jobs to milticore
    # machines (e.g. parallel test jobs)
    ISMULTICORE=`if (( $(nproc) > 1 )); then echo 'true'; else echo 'false'; fi;`
    sed -i '1s/^/meta-data="is-multicore='$ISMULTICORE'"\n\n/' /etc/buildkite-agent/buildkite-agent.cfg
    sed -i '1s/^/# Meta data for the agent\n/' /etc/buildkite-agent/buildkite-agent.cfg
    # add user buildkite-agent to docker
    sudo usermod -aG docker buildkite-agent
    printf "\nIgnore Buildkite message below re: adding your agent token...already done above"
fi


# STEP - Create a new public-private key pair for user 'buildkite-agent'.
# Then add that public key to your github account that has access to your repository
printf "\nCreating a new key for user: buildkite-agent\n"

if [ ! -f /var/lib/buildkite-agent/.ssh/id_rsa.pub ]
then
    # The following steps have been modified from: https://buildkite.com/docs/agent/ssh-keys
    sudo -H -u buildkite-agent bash -c 'mkdir -p ~/.ssh && cd ~/.ssh'
    # make a key for user 'buildkite-agent' without user input using $GITHUB_EMAIL
    sudo -H -u buildkite-agent bash -c 'cat /dev/zero | ssh-keygen -q -P "" -f "/var/lib/buildkite-agent/.ssh/id_rsa" -t rsa -b 4096 -C "$GITHUB_EMAIL"'
fi

printf "\nAdding public key for user: buildkite-agent to github account: $GITHUB_USERNAME\n"

PUBLIC_KEY=`cat ~buildkite-agent/.ssh/id_rsa.pub`
SERVER_IP=`ifconfig eth0 | grep "inet " | awk '{gsub("addr:","",$2);  print $2 }'`
PUBLIC_KEY_NAME_FOR_GITHUB="vultr-builtkite-agent-server-ip-$SERVER_IP"

curl -u "$GITHUB_USERNAME:$GITHUB_PASSWORD" -H "Accept: application/json" \
-H "Content-Type:application/json" -X POST \
--data '{"title":"'"$PUBLIC_KEY_NAME_FOR_GITHUB"'","key":"'"$PUBLIC_KEY"'"}' https://api.github.com/user/keys


# STEP - Enable the build directory to be cleaned before each build.
# This will remove any temporary files that were made by django.
# Buildkite can't remove these cause thet were made by another user.
# So when using BUILDKITE_CLEAN_CHECKOUT=true as a buildkite
# environmental variable you may get error from temp files created by docker:
# ```/var/lib/buildkite-agent/builds/hostname/proj/media/cache/path/to/temp.jpg```
# etc. giving errors cause these files aren't owned by buildkite.
# The first build on any new server will be fine. This will only possibly affect the 2nd+ build on
# any server.
# Note: If you don't use BUILDKITE_CLEAN_CHECKOUT=true than you can get .pyc and other temp files
# etc. files files staying in the directory. This is bad, cause then you get errors like this:
# InvalidTemplateLibrary: Invalid template library specified. ImportError raised when trying to load
# 'utilities.templatetags.cms_tags': No module named feincms.module.page.models
# even though that whole module has been deleted, as it remains in a .pyc file. So if
# you use BUILDKITE_CLEAN_CHECKOUT=true you solve both problems.
# For more info see notes at the top of this file re: docker ownership and buildkite-agent.

# copy the environment hook script to where buildkite can see and use it
printf "\nFixing permissions for `hostname`\n"
# note that environment.sample is also at /usr/share/buildkite-agent/hooks/environment.sample
# but putting a script in /usr/share/buildkite-agent/hooks/ seems to mean it never gets called.
cp $SCRIPT_PATH/buildkite-agent-hooks-environment /etc/buildkite-agent/hooks/environment
chown buildkite-agent:buildkite-agent /etc/buildkite-agent/hooks/environment
cp $SCRIPT_PATH/fix-buildkite-agent-builds-permissions /usr/bin/

# now we need to enable user buildkite-agent to access 'chown' command that is called
# in the 'fix-buildkite-agent-builds-permissions' script
sed -i -e "\$a# let buildkite-agent chown docker created files so the build directory can be completly cleaned (when using BUILDKITE_CLEAN_CHECKOUT=true)" /etc/sudoers
sed -i -e "\$abuildkite-agent ALL=NOPASSWD:/bin/chown" /etc/sudoers

# STEP - start agent after buildkite-agent added to docker group
sudo service buildkite-agent start

# STEP - Show user setup is complete
printf "\nSetup complete. Head to the url below to check that the agent is connected:"
printf "    https://buildkite.com/organizations/myorg/agents"
