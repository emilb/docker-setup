#!/bin/bash -eu

###
# setup
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

echo "Generating passwords..."
./generate-passwords.sh

source passwords.sh

echo "Base install..."
base/base-install.sh

echo "Locale fix..."
base/post-install.sh

echo "Installing Docker..."
docker-services/docker.sh

echo "Adding users..."
base/users-install.sh
