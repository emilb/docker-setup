#!/bin/bash -eu

###
# systemd startup config for docker containers
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

guid=`getent group fileshare | cut -d: -f3`
uid=`id -u admin`

cat << EOF > /etc/default/northpath
# Northpath system defaults

# Data paths
GRAYLOG_DATA_DIR="$docker_base_path/graylog/data"
GRAYLOG_LOG_DIR="$docker_base_path/graylog/logs"
NGINX_CERTS_DIR="$docker_base_path/nginx-proxy/certs"
INFLUXDB_DATA_DIR="$docker_base_path/influxdb"
GRAFANA_DATA_DIR="$docker_base_path/grafana"
MYSQL_DATA_DIR="$docker_base_path/mysql"
MOVIES_DIR="$movies_path"
TV_DIR="$tv_path"
PLEX_CONFIG_DIR="$docker_base_path/plex/config"
PLEX_TRANSCODE_DIR="$docker_base_path_iscsi/transcode"
COUCHPOTATO_CONFIG_DIR="$docker_base_path/couchpotato/config"
SONARR_CONFIG_DIR="$docker_base_path/sonarr/config"
NZBGET_CONFIG_DIR="$docker_base_path/nzbget/config"
DOWNLOADS_DIR="$downloads_path"
OVPN_DATA="$openvpn_data_name"
EOF

#log_config="--log-driver=gelf --log-opt gelf-address=udp://localhost:12201"
log_config=""

#**** graylog-docker.service ****
cat << EOF > /etc/systemd/system/graylog-docker.service
[Unit]
Description=Graylog container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill graylog
ExecStartPre=-/usr/bin/docker rm graylog

ExecStart=/usr/bin/docker run \
	-p 9000:9000 \
	-p 12201:12201 \
	-p 12201:12201/udp \
	-e VIRTUAL_PORT=9000 \
	-e VIRTUAL_HOST=graylog.$domain \
	-e GRAYLOG_USERNAME=admin \
	-e GRAYLOG_PASSWORD=$graylog \
	-e GRAYLOG_TIMEZONE=Europe/Stockholm \
	-e GRAYLOG_SERVER_SECRET=$graylog_server_secret \
	-e ES_MEMORY=4g \
	-e GRAYLOG_RETENTION="--size=3 --indices=10" \
	-v \${GRAYLOG_DATA_DIR}:/var/opt/graylog/data \
	-v \${GRAYLOG_LOG_DIR}:/var/log/graylog \
	--name graylog \
	graylog2/allinone

ExecStop=/usr/bin/docker stop graylog

[Install]
WantedBy=multi-user.target
EOF

#**** skydns-docker.service ****
cat << EOF > /etc/systemd/system/skydns-docker.service
[Unit]
Description=SkyDNS container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill skydns
ExecStartPre=-/usr/bin/docker rm skydns

ExecStart=/usr/bin/docker run \
	$log_config \
	-p 172.17.0.1:53:53/udp \
	--name skydns \
	crosbymichael/skydns -nameserver 8.8.8.8:53 -domain docker

ExecStop=/usr/bin/docker stop skydns

[Install]
WantedBy=multi-user.target
EOF

# **** skydock-docker.service ****
cat << EOF > /etc/systemd/system/skydock-docker.service
[Unit]
Description=SkyDock container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill skydock
ExecStartPre=-/usr/bin/docker rm skydock

ExecStart=/usr/bin/docker run \
	$log_config \
	-v /var/run/docker.sock:/docker.sock \
	--link="skydns" \
	--name skydock \
	crosbymichael/skydock -ttl 30 -environment prod -s /docker.sock -domain docker -name skydns

ExecStop=/usr/bin/docker stop skydock

[Install]
WantedBy=multi-user.target
EOF

#**** nginx-proxy-docker.service ****
cat << EOF > /etc/systemd/system/nginx-proxy-docker.service
[Unit]
Description=nginx proxy container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill nginx-proxy
ExecStartPre=-/usr/bin/docker rm nginx-proxy

ExecStart=/usr/bin/docker run \
	$log_config \
	-p 443:443 \
	-v \${NGINX_CERTS_DIR}:/etc/nginx/certs \
	-v /var/run/docker.sock:/tmp/docker.sock:ro \
	--name nginx-proxy \
	jwilder/nginx-proxy

ExecStop=/usr/bin/docker stop nginx-proxy

[Install]
WantedBy=multi-user.target
EOF

#**** influxdb-docker.service ****
cat << EOF > /etc/systemd/system/influxdb-docker.service
[Unit]
Description=influxdb container
Requires=docker.service
After=nginx-proxy-docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill influxdb
ExecStartPre=-/usr/bin/docker rm influxdb

ExecStart=/usr/bin/docker run \
	$log_config \
	-p 25826:25826/udp \
	-p 8086:8086 \
	-e VIRTUAL_PORT=8083 \
	-e VIRTUAL_HOST=influxdb.$domain \
	-e ADMIN_USER="root" \
	-e INFLUXDB_INIT_PWD="$influx" \
	-e PRE_CREATE_DB=collectdb \
	-e COLLECTD_DB="collectdb" \
	-e COLLECTD_BINDING=':25826' \
	-v \${INFLUXDB_DATA_DIR}:/data \
	--name influxdb \
	tutum/influxdb

ExecStop=/usr/bin/docker stop influxdb

[Install]
WantedBy=multi-user.target
EOF

#**** grafana-docker.service ****
cat << EOF > /etc/systemd/system/grafana-docker.service
[Unit]
Description=Grafana container
Requires=docker.service
After=nginx-proxy-docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill grafana
ExecStartPre=-/usr/bin/docker rm grafana

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=3000 \
	-e VIRTUAL_HOST=grafana.$domain \
	-e GF_SERVER_ROOT_URL="http://grafana.$domain/" \
	-e GF_SECURITY_ADMIN_PASSWORD="$grafana" \
	-v \${GRAFANA_DATA_DIR}:/var/lib/grafana \
	--name grafana \
	grafana/grafana

ExecStop=/usr/bin/docker stop grafana

[Install]
WantedBy=multi-user.target
EOF

#**** mysql-docker.service ****
#cat << EOF > /etc/systemd/system/mysql-docker.service
#[Unit]
#Description=mysql container
#Requires=docker.service graylog-docker.service
#After=docker.service graylog-docker.service
#
#[Service]
#Restart=always
#
#ExecStartPre=-/usr/bin/docker kill mysql
#ExecStartPre=-/usr/bin/docker rm mysql
#
#ExecStart=/usr/bin/docker run \
#	$log_config \
#	-v \$MYSQL_DATA_DIR:/var/lib/mysql \
#	-e MYSQL_ROOT_PASSWORD="$mysql_root" \
#	-e MYSQL_USER=newznab \
#	-e MYSQL_PASSWORD="$mysql_newznab_password" \
#	-e MYSQL_DATABASE=newznab \
#	--name mysql \
#	mysql:latest
#
#ExecStop=/usr/bin/docker stop mysql
#
#[Install]
#WantedBy=multi-user.target
#EOF

#**** newznab-docker.service ****
#cat << EOF > /etc/systemd/system/newznab-docker.service
#[Unit]
#Description=newznab container
#Requires=docker.service mysql-docker.service
#After=docker.service mysql-docker.service
#
#[Service]
#Restart=always
#
#ExecStartPre=-/usr/bin/docker kill newznab
#ExecStartPre=-/usr/bin/docker rm newnab
#
#ExecStart=/usr/bin/docker run $log_config -e VIRTUAL_PORT=80 -e VIRTUAL_HOST=newznab.$domain -v $docker_base_path/newznab:/nzb -v /etc/localtime:/etc/localtime:ro --name="newznab" newznab
#ExecStop=/usr/bin/docker stop newznab
#
#[Install]
#WantedBy=multi-user.target
#EOF

#**** plex-docker.service ****
cat << EOF > /etc/systemd/system/plex-docker.service
[Unit]
Description=plex container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill plex
ExecStartPre=-/usr/bin/docker rm plex

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=32400 \
	-e VIRTUAL_HOST=plex.$domain \
	-e PGID=$guid \
	-e PUID=$uid \
	-e VERSION="plexpass" \
	-v \${PLEX_TRANSCODE_DIR}:/transcode \
	-v \${PLEX_CONFIG_DIR}:/config \
	-v \${TV_DIR}:/data/tvshows \
	-v \${MOVIES_DIR}:/data/movies \
	--name=plex \
	linuxserver/plex

ExecStop=/usr/bin/docker stop plex

[Install]
WantedBy=multi-user.target
EOF

#**** couchpotato-docker.service ****
cat << EOF > /etc/systemd/system/couchpotato-docker.service
[Unit]
Description=couchpotato container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill couchpotato
ExecStartPre=-/usr/bin/docker rm couchpotato

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=5050 \
	-e VIRTUAL_HOST=movies.$domain \
	-v /etc/localtime:/etc/localtime:ro \
	-v \${COUCHPOTATO_CONFIG_DIR}:/config \
	-v \${DOWNLOADS_DIR}:/downloads \
	-v \${MOVIES_DIR}:/movies \
	-e PGID=$guid \
	-e PUID=$uid \
	--name=couchpotato \
	linuxserver/couchpotato

ExecStop=/usr/bin/docker stop couchpotato

[Install]
WantedBy=multi-user.target
EOF

#**** sonarr-docker.service ****
cat << EOF > /etc/systemd/system/sonarr-docker.service
[Unit]
Description=sonarr container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill sonarr
ExecStartPre=-/usr/bin/docker rm sonarr

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=8989 \
	-e VIRTUAL_HOST=tv.$domain \
	-v /dev/rtc:/dev/rtc:ro \
	-v \${SONARR_CONFIG_DIR}:/config \
	-v \${DOWNLOADS_DIR}:/downloads \
	-v \${TV_DIR}:/tv \
	-e PGID=$guid \
	-e PUID=$uid \
	--name=sonarr \
	linuxserver/sonarr

ExecStop=/usr/bin/docker stop sonarr

[Install]
WantedBy=multi-user.target
EOF

#**** nzbget-docker.service ****
cat << EOF > /etc/systemd/system/nzbget-docker.service
[Unit]
Description=nzbget container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill nzbget
ExecStartPre=-/usr/bin/docker rm nzbget

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=6789 \
	-e VIRTUAL_HOST=nzbget.$domain \
	-v /etc/localtime:/etc/localtime:ro \
	-v \${NZBGET_CONFIG_DIR}:/config \
	-v \${DOWNLOADS_DIR}:/downloads \
	-e PGID=$guid \
	-e PUID=$uid \
	--name=nzbget \
	linuxserver/nzbget

ExecStop=/usr/bin/docker stop nzbget

[Install]
WantedBy=multi-user.target
EOF

#**** plex-docker.service ****
cat << EOF > /etc/systemd/system/openvpn-docker.service
[Unit]
Description=openvpn container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=/etc/default/northpath

ExecStartPre=-/usr/bin/docker kill openvpn
ExecStartPre=-/usr/bin/docker rm openvpn

ExecStart=/usr/bin/docker start \${OVPN_DATA}

ExecStart=/usr/bin/docker run \
	$log_config \
	--volumes-from \${OVPN_DATA} \
	-p 1194:1194/udp \
	--cap-add=NET_ADMIN \
	--name=openvpn \
	kylemanna/openvpn

ExecStop=/usr/bin/docker stop openvpn
ExecStop=/usr/bin/docker stop \${OVPN_DATA}

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable graylog-docker.service
systemctl enable skydns-docker.service
systemctl enable skydock-docker.service
systemctl enable nginx-proxy-docker.service
systemctl enable influxdb-docker.service
systemctl enable grafana-docker.service
#systemctl enable mysql-docker.service
#systemctl enable newznab-docker.service
systemctl enable plex-docker.service
systemctl enable couchpotato-docker.service
systemctl enable sonarr-docker.service
systemctl enable nzbget-docker.service
systemctl enable openvpn-docker.service


