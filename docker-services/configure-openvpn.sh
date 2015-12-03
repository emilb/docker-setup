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

echo "****************************************************"
echo "Configuring VPN"
echo ""
echo "PEM pass phrase: $vpn_pem_pass_phrase"
echo "****************************************************"

docker run --volumes-from $OVPN_DATA --rm kylemanna/openvpn ovpn_genconfig -u udp://vpn.$domain
docker run --volumes-from $OVPN_DATA --rm -it kylemanna/openvpn ovpn_initpki

# Generate client cert
mkdir certs
tokens=($users)
for user in "${tokens[@]}"
do
	docker run --volumes-from $OVPN_DATA --rm -it kylemanna/openvpn easyrsa build-client-full $user nopass
	docker run --volumes-from $OVPN_DATA --rm kylemanna/openvpn ovpn_getclient $user > certs/$user.ovpn
done