#!/bin/bash -eu

###
# systemd startup config for docker containers
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

log_config="--log-driver=gelf --log-opt gelf-address=udp://localhost:12201"

#**** graylog-docker.service ****
cat << EOF > /etc/systemd/system/graylog-docker.service
[Unit]
Description=Graylog container
Requires=docker.service
After=docker.service

[Service]
Restart=always

ExecStartPre=-/usr/bin/docker kill graylog
ExecStartPre=-/usr/bin/docker rm graylog

ExecStart=/usr/bin/docker run -p 9000:9000 -p 12201:12201 -p 12201:12201/udp -e VIRTUAL_PORT=9000 -e VIRTUAL_HOST=graylog.$domain -e GRAYLOG_USERNAME=admin -e GRAYLOG_PASSWORD=$graylog -e GRAYLOG_TIMEZONE=Europe/Stockholm -e GRAYLOG_SERVER_SECRET=$graylog_server_secret -e ES_MEMORY=4g -e GRAYLOG_RETENTION="--size=3 --indices=10" -v $docker_base_path/graylog/data:/var/opt/graylog/data -v $docker_base_path/graylog/logs:/var/log/graylog --name graylog graylog2/allinone

ExecStop=/usr/bin/docker stop graylog

[Install]
WantedBy=multi-user.target
EOF

#**** skydns-docker.service ****
cat << EOF > /etc/systemd/system/skydns-docker.service
[Unit]
Description=SkyDNS container
Requires=docker.service graylog-docker.service
After=docker.service graylog-docker.service

[Service]
Restart=always

ExecStartPre=-/usr/bin/docker kill skydns
ExecStartPre=-/usr/bin/docker rm skydns

ExecStart=/usr/bin/docker run $log_config -p 172.17.0.1:53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 -domain docker

ExecStop=/usr/bin/docker stop skydns

[Install]
WantedBy=multi-user.target
EOF

# **** skydock-docker.service ****
cat << EOF > /etc/systemd/system/skydock-docker.service
[Unit]
Description=SkyDock container
Requires=skydns-docker.service
After=skydns-docker.service

[Service]
Restart=always

ExecStartPre=-/usr/bin/docker kill skydock
ExecStartPre=-/usr/bin/docker rm skydock

ExecStart=/usr/bin/docker run $log_config -v /var/run/docker.sock:/docker.sock --link="skydns" --name skydock crosbymichael/skydock -ttl 30 -environment prod -s /docker.sock -domain docker -name skydns

ExecStop=/usr/bin/docker stop skydock

[Install]
WantedBy=multi-user.target
EOF

#**** nginx-proxy-docker.service ****
cat << EOF > /etc/systemd/system/nginx-proxy-docker.service
[Unit]
Description=nginx proxy container
Requires=docker.service skydock-docker.service
After=docker.service skydock-docker.service

[Service]
Restart=always

ExecStartPre=-/usr/bin/docker kill nginx-proxy
ExecStartPre=-/usr/bin/docker rm nginx-proxy

ExecStart=/usr/bin/docker run $log_config -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro --name nginx-proxy jwilder/nginx-proxy

ExecStop=/usr/bin/docker stop nginx-proxy

[Install]
WantedBy=multi-user.target
EOF

#**** influxdb-docker.service ****
cat << EOF > /etc/systemd/system/influxdb-docker.service
[Unit]
Description=influxdb container
Requires=docker.service skydock-docker.service
After=nginx-proxy-docker.service skydock-docker.service

[Service]
Restart=always

ExecStartPre=-/usr/bin/docker kill influxdb
ExecStartPre=-/usr/bin/docker rm influxdb

ExecStart=/usr/bin/docker run $log_config -p 25826:25826/udp -p 8086:8086 -e VIRTUAL_PORT=8083 -e VIRTUAL_HOST=influxdb.$domain -e ADMIN_USER="root" -e INFLUXDB_INIT_PWD="$influx" -e PRE_CREATE_DB=collectdb -e COLLECTD_DB="collectdb" -e COLLECTD_BINDING=':25826' -v $docker_base_path/influxdb:/data --name influxdb tutum/influxdb

ExecStop=/usr/bin/docker stop influxdb

[Install]
WantedBy=multi-user.target
EOF

#**** grafana-docker.service ****
cat << EOF > /etc/systemd/system/grafana-docker.service
[Unit]
Description=Grafana container
Requires=docker.service graylog-docker.service
After=nginx-proxy-docker.service graylog-docker.service

[Service]
Restart=always

ExecStartPre=-/usr/bin/docker kill grafana
ExecStartPre=-/usr/bin/docker rm grafana

ExecStart=/usr/bin/docker run $log_config -e VIRTUAL_PORT=3000 -e VIRTUAL_HOST=grafana.$domain -e GF_SERVER_ROOT_URL="http://grafana.$domain/" -e GF_SECURITY_ADMIN_PASSWORD="$grafana" -v $docker_base_path/grafana:/var/lib/grafana --name grafana grafana/grafana

ExecStop=/usr/bin/docker stop grafana

[Install]
WantedBy=multi-user.target
EOF

#**** mysql-docker.service ****
cat << EOF > /etc/systemd/system/mysql-docker.service
[Unit]
Description=mysql container
Requires=docker.service graylog-docker.service
After=docker.service graylog-docker.service

[Service]
Restart=always

ExecStartPre=-/usr/bin/docker kill mysql
ExecStartPre=-/usr/bin/docker rm mysql

ExecStart=/usr/bin/docker run $log_config -v $docker_base_path/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="$mysql_root" -e MYSQL_USER=newznab -e MYSQL_PASSWORD="$mysql_newznab" -e MYSQL_DATABASE=newznab --name mysql mysql:latest

ExecStop=/usr/bin/docker stop mysql

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
systemctl enable mysql-docker.service

