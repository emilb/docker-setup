#!/bin/bash -eu

###
# Install and setup docker
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ ! `which docker` ]; then
	curl -sSL https://get.docker.com/ | sh
fi

echo "Adding docker override setting for DNS"

mkdir -p /etc/systemd/system/docker.service.d > /dev/null

cat << EOF > /etc/systemd/system/docker.service.d/override.conf
[Service]
EnvironmentFile=
EnvironmentFile=-/etc/default/docker
ExecStart=
ExecStart=/usr/bin/docker -d \$DOCKER_OPTS -H fd://
EOF

cat << EOF > /etc/default/docker
# Docker Upstart and SysVinit configuration file

# Customize location of Docker binary (especially for development testing).
#DOCKER="/usr/local/bin/docker"

# Use DOCKER_OPTS to modify the daemon startup options.
DOCKER_OPTS="--dns 172.17.0.1"
# --iptables=false"

# If you need Docker to use an HTTP proxy, it can also be specified here.
#export http_proxy="http://127.0.0.1:3128/"

# This is also a handy place to tweak where Docker's temporary files go.
#export TMPDIR="/mnt/bigdrive/docker-tmp"
EOF

echo "Restarting docker"
systemctl daemon-reload
systemctl restart docker
