#!/bin/bash -eu

###
# UFW install and setup
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

ufw disable

ufw reset
ufw default deny incoming
ufw default allow outgoing

ufw allow from any to any app OpenSSH
ufw allow http

tokens=($allowed_samba_nets)
for net in "${tokens[@]}"
do
	ufw allow from $net to any app Samba
done

ufw enable
