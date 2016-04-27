#!/bin/bash

###
# scripts install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

mkdir -p /opt/scripts

cat << EOF > /opt/scripts/first-register-dns.sh
#!/bin/bash

source \$1

# Get IP for nginx-proxy
dockerip=\`ip addr | awk '/inet/ && /docker0/{sub(/\/.*\$/,"",\$2); print \$2}'\`
nginxproxyip=\$(dig @\$dockerip +short nginx-proxy.docker.\$DOMAIN)
skydnsip=\`dig @\$dockerip +short skydns.docker.\$DOMAIN\`

tokens=(\$SUBDOMAINS)
counter=0
for subdomain in "\${tokens[@]}"
do
    echo "registering \$subdomain.\$INTERNAL_DOMAIN"
    sequence=\`printf "%03d\n" \$counter\`

    data=\`echo "{\"Name\":\"\$subdomain\",\"Environment\":\"internal\",\"Port\":80,\"host\":\"\$nginxproxyip\",\"TTL\":900}"\`
    curl -X PUT -L http://\$skydnsip:8080/skydns/services/4\$sequence -d \$data
    let counter=counter+1
done
EOF
chmod +x /opt/scripts/first-register-dns.sh

cat << EOF > /opt/scripts/re-register-dns.sh
#!/bin/bash

source \$1

# Get IP for nginx-proxy
dockerip=\`ip addr | awk '/inet/ && /docker0/{sub(/\/.*\$/,"",\$2); print \$2}'\`
nginxproxyip=\$(dig @\$dockerip +short nginx-proxy.docker.\$DOMAIN)
skydnsip=\`dig @\$dockerip +short skydns.docker.\$DOMAIN\`

tokens=(\$SUBDOMAINS)
counter=0
for subdomain in "\${tokens[@]}"
do
    echo "registering \$subdomain.\$INTERNAL_DOMAIN"
    sequence=\`printf "%03d\n" \$counter\`

    curl -X PATCH -L http://\$skydnsip:8080/skydns/services/4\$sequence -d '{"TTL":900}'
    let counter=counter+1
done
EOF
chmod +x /opt/scripts/re-register-dns.sh