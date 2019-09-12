#!/usr/bin/env bash

set -ex
#USAGE="$0 <domain name>"

#DOMAINNAME=${1:?$USAGE}

APACHE_ROOT=/opt/offline

# poetry
export DIRNAME=sdispater
export TARGETDIR="$APACHE_ROOT/$DIRNAME"
export DIR_SUB="$TARGETDIR/poetry/master"

mkdir -p $DIR_SUB
curl https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py -o $DIR_SUB/get-poetry.py
chown -R www-data.www-data $APACHE_ROOT

export DOMAINNAME=raw.githubusercontent.com
sudo sed -i "s=\(</VirtualHost>\)=\tServerName $DOMAINNAME\n\t\tHostnameLookups Off\n\t\talias /$DIRNAME $TARGETDIR\n\t\t<Directory $TARGETDIR>\n\t\t\tOptions Indexes FollowSymLinks MultiViews\n\t\t\tRequire all granted\n\t\t</Directory>\n\t\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf

sudo service apache2 restart
