

mkdir -p $docker_base_path/src/docker-newznab

git clone https://github.com/cmeindl/Docker-NewzNab_Plus.git $docker_base_path/src/docker-newznab

sed -i "s/ENV nn_user .*/ENV nn_user $nnuser/" $docker_base_path/src/docker-newznab/Dockerfile
sed -i "s/ENV nn_pass .*/ENV nn_pass $nnpassword/" $docker_base_path/src/docker-newznab/Dockerfile

sed -i "s/define('DB_HOST'.*/define('DB_HOST', 'mysql.prod.docker');/g" $docker_base_path/src/docker-newznab/config.php
sed -i "s/define('DB_USER'*./define('DB_USER', 'newznab');/g" $docker_base_path/src/docker-newznab/config.php
sed -i "s/define('DB_PASSWORD'.*/define('DB_PASSWORD','$mysql_newznab');/g" $docker_base_path/src/docker-newznab/config.php

sed -i "s/define('NNTP_USERNAME'.*/define('NNTP_USERNAME', '$nntp_username');/g" $docker_base_path/src/docker-newznab/config.php
sed -i "s/define('NNTP_PASSWORD'.*/define('NNTP_PASSWORD', '$nntp_password');/g" $docker_base_path/src/docker-newznab/config.php
sed -i "s/define('NNTP_SERVER'.*/define('NNTP_SERVER', '$nntp_server');/g" $docker_base_path/src/docker-newznab/config.php
sed -i "s/define('NNTP_PORT'.*/define('NNTP_PORT', '$nntp_port');/g" $docker_base_path/src/docker-newznab/config.php
sed -i "s/define('NNTP_SSLENABLED'.*/define('NNTP_SSLENABLED', '$nntp_ssl');/g" $docker_base_path/src/docker-newznab/config.php

currdir=`pwd`

cd $docker_base_path/src/docker-newznab
docker build -t "newznab"

cd $currdir
