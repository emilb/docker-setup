#!/bin/bash -eu

###
# Base install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#####################################################################
# Update everything
#####################################################################
echo "Updating system"
apt-get -qq update > /dev/null
apt-get -qq -y dist-upgrade > /dev/null

#####################################################################
# Install packages
#####################################################################
echo "Installing makepasswd pwgen screen htop unzip unrar glances emacs wget curl man mc landscape-common..."
apt-get -qq -y install makepasswd pwgen screen tmux htop unzip unrar glances emacs wget curl man mc landscape-common> /dev/null

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
echo "Installing samba open-iscsi nfs-kernel-server..."
apt-get -qq -y install samba open-iscsi nfs-kernel-server > /dev/null
# https://www.howtoforge.com/using-iscsi-on-ubuntu-10.04-initiator-and-target

# Fail2ban
echo "Installing fail2ban..."
apt-get -qq -y install fail2ban > /dev/null

# ntp
echo "Installing ntp ntpdate..."
apt-get -qq -y install ntp ntpdate > /dev/null

echo "Installations done"
