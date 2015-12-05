#!/bin/bash -eu

###
# setup
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "Disabling two factor login"
if ( grep 'pam_google_authenticator.so' /etc/pam.d/sshd ); then
	  mv /etc/pam.d/sshd /etc/pam.d/sshd.org > /dev/null
    cat /etc/pam.d/sshd.org | sed 's/auth required pam_google_authenticator.*//' > /etc/pam.d/sshd
    rm /etc/pam.d/sshd.org
else
    echo "Couldn't find pam_google_authenticator.so in /etc/pam.d/sshd"
fi

if ( grep 'ChallengeResponseAuthentication no' /etc/ssh/sshd_config ); then
    echo "ChallengeResponseAuthentication already set to no"
else
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.org > /dev/null
    cat /etc/ssh/sshd_config.org | sed 's/ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' > /etc/ssh/sshd_config
    rm /etc/ssh/sshd_config.org
fi
systemctl restart ssh