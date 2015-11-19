#!/bin/bash -eu

###
# Base install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source ../config.sh

#####################################################################
# Update everything
#####################################################################
echo "Updating system"
apt-get -qq update > /dev/null
apt-get -qq -y dist-upgrade > /dev/null

#####################################################################
# Install packages
#####################################################################
echo "Installing makepasswd screen htop unzip unrar glances emacs wget curl man mc..."
apt-get -qq -y install makepasswd screen tmux htop unzip unrar glances emacs wget curl man mc > /dev/null

# Version control
echo "Installing collectd sensord smartmontools..."
apt-get -qq -y install collectd sensord smartmontools > /dev/null


# Get a sane build environment
echo "Installing autoconf build-essential ..."
apt-get -qq -y install autoconf build-essential checkinstall > /dev/null

# Version control
echo "Installing git-core..."
apt-get -qq -y install git-core > /dev/null

# Filesharing
echo "Installing samba nfs-kernel-server..."
apt-get -qq -y install samba nfs-kernel-server > /dev/null

# ntp
echo "Installing ntp ntpdate..."
apt-get -qq -y install ntp ntpdate > /dev/null

echo "Installations done"