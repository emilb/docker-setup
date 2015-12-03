#!/bin/bash -eu

###
# setup
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

OVPN_DATA=$openvpn_data_name

docker run --name $OVPN_DATA -v /etc/openvpn busybox
docker run --volumes-from $OVPN_DATA --rm kylemanna/openvpn ovpn_genconfig -u udp://vpn.$domain
docker run --volumes-from $OVPN_DATA --rm -it kylemanna/openvpn ovpn_initpki

#docker run --volumes-from $OVPN_DATA -d -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn

# Generate client cert
mkdir certs
tokens=($users)
for user in "${tokens[@]}"
do
	docker run --volumes-from $OVPN_DATA --rm -it kylemanna/openvpn easyrsa build-client-full $user nopass
	docker run --volumes-from $OVPN_DATA --rm kylemanna/openvpn ovpn_getclient CLIENTNAME > certs/$user.ovpn
done