
srcdir=$docker_base_path/src/docker-newznab
rm -rf $srcdir
mkdir -p $srcdir


git clone https://github.com/cmeindl/Docker-NewzNab_Plus.git $srcdir

sed -i "s/ENV nn_user .*/ENV nn_user $nnuser/" $srcdir/Dockerfile
sed -i "s/ENV nn_pass .*/ENV nn_pass $nnpassword/" $srcdir/Dockerfile
sed -i "s,chmod 777 /var/www/newznab/www/covers/movies.*,chmod 777 /var/www/newznab/www/covers/movies \&\& \\\ \nchmod 777 /var/www/newznab/www/covers/tv \&\& \\\," $srcdir/Dockerfile


sed -i "s/define('DB_HOST'.*/define('DB_HOST', 'mysql.prod.docker');/g" $srcdir/config.php
sed -i "s/define('DB_USER'.*/define('DB_USER', 'newznab');/g" $srcdir/config.php
sed -i "s/define('DB_PASSWORD'.*/define('DB_PASSWORD','$mysql_newznab_password');/g" $srcdir/config.php

sed -i "s/define('NNTP_USERNAME'.*/define('NNTP_USERNAME', '$nntp_username');/g" $srcdir/config.php
sed -i "s/define('NNTP_PASSWORD'.*/define('NNTP_PASSWORD', '$nntp_password');/g" $srcdir/config.php
sed -i "s/define('NNTP_SERVER'.*/define('NNTP_SERVER', '$nntp_server');/g" $srcdir/config.php
sed -i "s/define('NNTP_PORT'.*/define('NNTP_PORT', '$nntp_port');/g" $srcdir/config.php
sed -i "s/define('NNTP_SSLENABLED'.*/define('NNTP_SSLENABLED', '$nntp_ssl');/g" $srcdir/config.php

currdir=`pwd`

# Start DNS
systemctl start skydns-docker
sleep 10

cd $srcdir
docker build -t "newznab" .

cd $currdir
