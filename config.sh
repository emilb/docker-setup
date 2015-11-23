
export domain="northpath.se"
export docker_base_path="/data"
export docker_base_path_iscsi="/mnt/iscsi"
export password_keys="emil patrik admin root_user mysql_root mysql_newznab grafana influx graylog graylog_server_secret"
export users="emil patrik admin"
export allowed_samba_nets="213.185.253.3"
export subdomains="www nzbs nzbget tv plex graylog grafana vpn"

echo "Enter the SVN username for newznab, followed by [ENTER]:"
read user
export nnuser=$user

echo "Enter the SVN password for newznab, followed by [ENTER]:"
read password
export nnpassword=$user

echo "Enter the nntp username, followed by [ENTER]:"
read nu
export nntp_username=$nu

echo "Enter the nntp password, followed by [ENTER]:"
read npwd
export nntp_password=$npwd

echo "Enter the nntp server, followed by [ENTER]:"
read nserver
export nntp_server=$nserver

echo "Enter the nntp port, followed by [ENTER]:"
read nport
export nntp_port=$nport

echo "Enter SSL enabled (true/false), followed by [ENTER]:"
read nssl
export nntp_ssl=$nssl


