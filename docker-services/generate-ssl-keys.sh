#!/bin/bash -eu

###
# Generate keys for domains
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "Generating self signed certificates to: $docker_base_path/nginx-proxy/certs"

mkdir -p "$docker_base_path/nginx-proxy/certs"

domains=($domain $internal_domain)
tokens=($subdomains)
for subdomain in "${tokens[@]}"
do
	for currdomain in "${domains[@]}"
	do
		hostname="$subdomain.$currdomain"

		# Create config file
		cat << EOF > openssl.cnf
#-------------openssl.cnf----------------
[ req ]
default_bits = 1024 # Size of keys
default_keyfile = key.pem # name of generated keys
default_md = md5 # message digest algorithm
string_mask = nombstr # permitted characters
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
# Variable name   Prompt string
0.organizationName = Organization Name (company)
organizationalUnitName = Organizational Unit Name (department, division)
emailAddress = Email Address
emailAddress_max = 40
localityName = Locality Name (city, district)
stateOrProvinceName = State or Province Name (full name)
countryName = Country Name (2 letter code)
countryName_min = 2
countryName_max = 2
commonName = Common Name (hostname, IP, or your name)
commonName_max = 64


#-------------------Edit this section------------------------------
countryName_default     = US
stateOrProvinceName_default = N/A
localityName_default        = San Francisco
0.organizationName_default  = Northpath Industries
organizationalUnitName_default  = Survival dept
commonName_default          = $hostname
emailAddress_default            = admin@$currdomain
EOF

		# Create
		openssl genrsa -des3 -passout pass:x -out $hostname.pass.key 2048 > /dev/null
		openssl rsa -passin pass:x -in $hostname.pass.key -out $hostname.key > /dev/null
		rm $hostname.pass.key > /dev/null

		openssl req -new -key $hostname.key -out $hostname.csr -config openssl.cnf -batch > /dev/null

		openssl x509 -req -days 1825 -in $hostname.csr -signkey $hostname.key -out $hostname.crt > /dev/null

		mv $hostname.crt "$docker_base_path/nginx-proxy/certs/" > /dev/null
		mv $hostname.key "$docker_base_path/nginx-proxy/certs/" > /dev/null

		rm $hostname.csr > /dev/null
		rm openssl.cnf > /dev/null
	done
done
