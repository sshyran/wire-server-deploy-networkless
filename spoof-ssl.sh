#!/usr/bin/env bash

set -ex
USAGE="$0 <domain name>"

#DOMAINNAME=${1:?$USAGE}

DOMAINNAME=raw.githubusercontent.com

CA_key=/opt/certs/private.pem
CA_crt=/opt/certs/wire.com.crt
APACHE_IP=127.0.0.1

TMP=$(mktemp -d)

sudo openssl genrsa -out /etc/ssl/private/$DOMAINNAME.key 2048
sudo openssl req -new -key /etc/ssl/private/$DOMAINNAME.key -out $TMP/$DOMAINNAME.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=Wire/OU=Backend Team/CN=$DOMAINNAME"
sudo openssl x509 -req -in $TMP/$DOMAINNAME.csr -CA $CA_crt -CAkey $CA_key -CAcreateserial -out /etc/ssl/certs/$DOMAINNAME.pem -days 500 -sha256

sudo cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/000-$DOMAINNAME.conf

sudo sed -i "s=SSLCertificateFile.*/.*=SSLCertificateFile /etc/ssl/certs/$DOMAINNAME.pem=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
sudo sed -i "s=SSLCertificateKeyFile.*/.*=SSLCertificateKeyFile /etc/ssl/private/$DOMAINNAME.key=" /etc/apache2/sites-available/000-$DOMAINNAME.conf

sudo a2ensite 000-$DOMAINNAME

sudo systemctl reload apache2

echo "address=/$DOMAINNAME/$APACHE_IP" > /etc/dnsmasq.d/$DOMAINNAME

sudo systemctl restart dnsmasq

