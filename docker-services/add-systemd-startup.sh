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
northpath_defaults="/etc/default/northpath"

cat << EOF > $northpath_defaults
# Northpath system defaults

GRAYLOG_DATA_DIR="$docker_base_path/graylog/data"
GRAYLOG_LOG_DIR="$docker_base_path/graylog/logs"
NGINX_CERTS_DIR="$docker_base_path/nginx-proxy/certs"
INFLUXDB_DATA_DIR="$docker_base_path/influxdb"
GRAFANA_DATA_DIR="$docker_base_path/grafana"
MYSQL_DATA_DIR="$docker_base_path/mysql"
MOVIES_DIR="$movies_path"
TV_DIR="$tv_path"
COMICS_DIR="$comics_path"
PLEX_CONFIG_DIR="$docker_base_path/plex/config"
PLEX_TRANSCODE_DIR="$docker_base_path_iscsi/transcode"
COUCHPOTATO_CONFIG_DIR="$docker_base_path/couchpotato/config"
SONARR_CONFIG_DIR="$docker_base_path/sonarr/config"
NZBGET_CONFIG_DIR="$docker_base_path/nzbget/config"
TRANSMISSION_CONFIG_DIR="$docker_base_path/transmission/config"
TRANSMISSION_WATCH_DIR="$docker_base_path/transmission/watch"
MYLAR_CONFIG_DIR="$docker_base_path/mylar/config"
DOWNLOADS_DIR="$downloads_path"
OVPN_DATA="$openvpn_data_name"
DOMAIN="$domain"
INTERNAL_DOMAIN="$internal_domain"
SUBDOMAINS="$subdomains"
DOCKER_IP="$docker_ip"
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
EnvironmentFile=$northpath_defaults

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
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill skydns
ExecStartPre=-/usr/bin/docker rm skydns

ExecStart=/usr/bin/docker run \
	$log_config \
	-p $docker_ip:53:53/udp \
	-p $docker_ip:8080:8080 \
	--name skydns \
	crosbymichael/skydns \
	    -nameserver 8.8.8.8:53,8.8.4.4:53 \
	    -domain \${DOMAIN}

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
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill skydock
ExecStartPre=-/usr/bin/docker rm skydock

ExecStart=/usr/bin/docker run \
	$log_config \
	-v /var/run/docker.sock:/docker.sock \
	--link="skydns" \
	--name skydock \
	crosbymichael/skydock -ttl 30 -environment docker -s /docker.sock -domain $domain -name skydns

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
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill nginx-proxy
ExecStartPre=-/usr/bin/docker rm nginx-proxy

# Use this to enable certs:
# -v \${NGINX_CERTS_DIR}:/etc/nginx/certs \

ExecStart=/usr/bin/docker run \
	$log_config \
	-p 80:80 \
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
EnvironmentFile=$northpath_defaults

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
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill grafana
ExecStartPre=-/usr/bin/docker rm grafana

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=3000 \
	-e VIRTUAL_HOST=grafana.$domain \
	-e GF_SERVER_ROOT_URL="https://grafana.$domain/" \
	-e GF_SECURITY_ADMIN_PASSWORD="$grafana" \
	-v \${GRAFANA_DATA_DIR}:/var/lib/grafana \
	--name grafana \
	grafana/grafana

ExecStop=/usr/bin/docker stop grafana

[Install]
WantedBy=multi-user.target
EOF


#**** plex-docker.service ****
cat << EOF > /etc/systemd/system/plex-docker.service
[Unit]
Description=plex container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=$northpath_defaults

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
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill couchpotato
ExecStartPre=-/usr/bin/docker rm couchpotato

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=5050 \
	-e VIRTUAL_HOST=couchpotato.$domain \
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
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill sonarr
ExecStartPre=-/usr/bin/docker rm sonarr

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=8989 \
	-e VIRTUAL_HOST=sonarr.$domain \
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
EnvironmentFile=$northpath_defaults

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

#**** mylar-docker.service ****
cat << EOF > /etc/systemd/system/mylar-docker.service
[Unit]
Description=mylar container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill mylar
ExecStartPre=-/usr/bin/docker rm mylar

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=8090 \
	-e VIRTUAL_HOST=mylar.$domain \
	-v /etc/localtime:/etc/localtime:ro \
	-v \${MYLAR_CONFIG_DIR}:/config \
	-v \${DOWNLOADS_DIR}:/downloads \
	-v \${COMICS_DIR}:/comics \
	-e PGID=$guid \
	-e PUID=$uid \
	--name=mylar \
	linuxserver/mylar

ExecStop=/usr/bin/docker stop mylar

[Install]
WantedBy=multi-user.target
EOF

#**** deluge-docker.service ****
cat << EOF > /etc/systemd/system/transmission-docker.service
[Unit]
Description=transmission container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill transmission
ExecStartPre=-/usr/bin/docker rm transmission

ExecStart=/usr/bin/docker run \
	$log_config \
	-e VIRTUAL_PORT=9091 \
	-e VIRTUAL_HOST=transmission.$domain \
	-v /etc/localtime:/etc/localtime:ro \
	-v \${TRANSMISSION_CONFIG_DIR}:/config \
	-v \${TRANSMISSION_WATCH_DIR}:/watch \
	-v \${DOWNLOADS_DIR}:/downloads \
	-e PGID=$guid \
	-e PUID=$uid \
	-p 9091:9091 -p 51413:51413 \
	--name=transmission \
	linuxserver/transmission

ExecStop=/usr/bin/docker stop transmission

[Install]
WantedBy=multi-user.target
EOF

#**** openvpn-docker.service ****
cat << EOF > /etc/systemd/system/openvpn-docker.service
[Unit]
Description=openvpn container
Requires=docker.service
After=docker.service

[Service]
Restart=always
EnvironmentFile=$northpath_defaults

ExecStartPre=-/usr/bin/docker kill openvpn
ExecStartPre=-/usr/bin/docker rm openvpn

ExecStart=/usr/bin/docker run \
	$log_config \
	--volumes-from \${OVPN_DATA} \
	-p 1194:1194/udp \
	--cap-add=NET_ADMIN \
	--name=openvpn \
	kylemanna/openvpn

ExecStop=/usr/bin/docker stop openvpn

[Install]
WantedBy=multi-user.target
EOF

#**** register-dns.timer ****
cat << EOF > /etc/systemd/system/register-dns.timer
[Unit]
Description=Register local services to skydns
Requires=skydns-docker.service
After=skydns-docker.service

[Timer]
OnBootSec=1min

[Install]
WantedBy=timers.target
EOF

#**** register-dns.service ****
cat << EOF > /etc/systemd/system/register-dns.service
[Unit]
Description=register-dns service

[Service]
Type=simple
EnvironmentFile=$northpath_defaults
ExecStart=/opt/scripts/first-register-dns.sh $northpath_defaults
EOF

#**** register-dns.timer ****
cat << EOF > /etc/systemd/system/re-register-dns.timer
[Unit]
Description=Re-register local services to skydns
Requires=skydns-docker.service
After=skydns-docker.service

[Timer]
OnBootSec=10minutes
OnUnitActiveSec=10minutes	

[Install]
WantedBy=timers.target
EOF

#**** register-dns.service ****
cat << EOF > /etc/systemd/system/re-register-dns.service
[Unit]
Description=re-register-dns service

[Service]
Type=simple
EnvironmentFile=$northpath_defaults
ExecStart=/opt/scripts/re-register-dns.sh $northpath_defaults
EOF

#systemctl enable graylog-docker.service
systemctl enable skydns-docker.service
systemctl enable skydock-docker.service
systemctl enable nginx-proxy-docker.service
#systemctl enable influxdb-docker.service
#systemctl enable grafana-docker.service
systemctl enable plex-docker.service
systemctl enable couchpotato-docker.service
systemctl enable sonarr-docker.service
systemctl enable nzbget-docker.service
systemctl enable mylar-docker.service
systemctl enable transmission-docker.service
systemctl enable openvpn-docker.service

systemctl enable register-dns.timer
systemctl enable re-register-dns.timer

systemctl daemon-reload

find /etc/systemd/system -iname "*.service" -exec chmod +x {} \;
find /etc/systemd/system -iname "*.timer" -exec chmod +x {} \;
