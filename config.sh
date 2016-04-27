
export domain="northpath.se"
export internal_domain="internal.northpath.se"
export docker_ip="172.17.0.1"
export docker_base_path="/data"
export docker_base_path_iscsi="/data/downloads" #"/mnt/iscsi"
export movies_path="$docker_base_path_iscsi/movies"
export tv_path="$docker_base_path_iscsi/tv"
export downloads_path="$docker_base_path_iscsi/downloads"
export password_keys="emil patrik admin vpn_pem_pass_phrase root_user mysql_root mysql_newznab_password grafana influx graylog graylog_server_secret"
export users="emil patrik admin"
export common_group="fileshare"
export allowed_samba_nets="213.185.253.3"
export subdomains="www nzbget couchpotato plex deluge sonarr graylog grafana vpn influxdb"
export openvpn_data_name="openvpn_data"
