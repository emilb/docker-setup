#!/bin/bash

###
# Create users and group memberships
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Create common group
groupadd $common_group

# Create users
tokens=($users)
for user in "${tokens[@]}"
do
	pwd=`printenv $user`
	sudo adduser $user --gecos "$user,,," --disabled-password
	echo $user:$pwd | chpasswd

	# Add admin users to correct groups
	usermod -aG sudo $user
	usermod -aG docker $user
	usermod -aG $common_group $user
done

# Reset root password
pwd=`printenv root_user`
echo root:$pwd | chpasswd

mkdir -p $docker_base_path/downloads
chown -R :fileshare $docker_base_path/downloads
chmod -R 775 $docker_base_path/downloads
chmod -R 2775 $docker_base_path/downloads
