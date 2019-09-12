# Purpose of this file:

To contain directions in how to change a proxybox so that it serves all of the resources requested during an install, up to the point of having kubespray deployed.

## Raw Content (http)

### Setting up to serve raw content

* We're going to serve raw HTTP content with apache and configure dns with dnsmasq:
```
sudo apt install apache2 dnsmasq
```

by default the contents of /var/www/html are available at http://10.0.0.1/.

#### Squid configuration

* Edit mnt/squid.conf, and ensure that the nameserver it's using is the local nameserver:
```
dns_nameservers 10.0.0.1
```

* Ensure the last line of mnt/squid.conf is commented out.
```
#refresh_pattern . 10080 100% 10080 ignore-auth ignore-no-store store-stale ignore-private ignore-no-cache ignore-reload override-expire
```

If you had to make either of these three changes:
* (re)Start squid
```
./run.sh
```

### Making a directory available to clients:

#### Directory Creation
* Create a directory under /home/wire/docker-squid4/docker-squid. for this example, we're going to create apt_repository, so that we can serve an APT repository (which we will build later).
```
mkdir -p /home/wire/docker-squid4/docker-squid/apt_repository
```

#### Permissions
Note: the owner of this directory and all of it's contents must be the user www-data, with the group www-data, so once you are done populating your content:
```
chown -R www-data.www-data /home/wire/docker-squid4/docker-squid/apt_repository
```

#### Apache Configuration
Add the directory to apache, and assign it an alias. for this example, we're going to use an alias 'apt' for the apt repository, so that it is availale at /apt/ on our web server.
* Edit /etc/apache2/sites-available/000-default.conf as root, and add:
```
HostnameLookups Off
alias /apt /home/wire/docker-squid4/docker-squid/apt_repository
<Directory /home/wire/docker-squid4/docker-squid/apt_repository>
     Options Indexes FollowSymLinks MultiViews
     Require all granted
</Directory>     
```
right before the closing '</VirtualHost> tag.

* restart apache for changes to take effect.
```
sudo service apache2 restart
```

#### DNSMASQ configuration

* Edit/Create /etc/dnsmasq.d/apache to set DNSMASQ to tell both squid and your clients that the site is hosted locally, and to 'lie' to the clients about it's name:
```
#use dnsmasq to point your target site to resolve as 10.0.0.1.
address=/apt.wire.com/10.0.0.1
```

* Restart dnsmasq for your changes to go into effect.
```
sudo service dnsmasq restart
```

#### Testing

From any of your clients, you should now see an index page with no contents if you load 'http://apt.wire.com/apt/'

## Raw Content (https)

* We're going to serve raw HTTPS content with apache and configure DNS with dnsmasq:
```
sudo apt install apache2 dnsmasq
```

* prepare apache to serve ssl content
```
sudo apachectl configtest
sudo a2enmod ssl
sudo a2dissite default-ssl
```

Copy our CA certificate into the system's CA certificate repository:
```
sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
sudo cp /home/wire/docker-squid4/mk-ca-cert/certs/wire.com.crt /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo update-ca-certificates
```

#### Squid configuration

* Edit mnt/squid.conf, and ensure that the nameserver it's using is the local nameserver:
```
dns_nameservers 10.0.0.1
```

* Ensure the last line is commented out.
```
#refresh_pattern . 10080 100% 10080 ignore-auth ignore-no-store store-stale ignore-private ignore-no-cache ignore-reload override-expire
```

* edit run.sh, and add $(pwd) to the volume declarations in the 'SETUP_TLS' variable.
```
SETUP_TLS="
    -v $(pwd)/etc/ssl/certs:/etc/ssl/certs:ro
    -v $(pwd)/usr/share/ca-certificates:/usr/share/ca-certificates:ro
    -v $(pwd)/usr/local/share/ca-certificates:/usr/local/share/ca-certificates:ro"
```

* copy the system certificate stores to a place docker can reference them:
```
mkdir -p /home/wire/docker-squid4/docker-squid/etc/ssl/certs
mkdir -p /home/wire/docker-squid4/docker-squid/usr/share/ca-certificates
mkdir -p /home/wire/docker-squid4/docker-squid/usr/local/share/ca-certificates
cp -a /etc/ssl/certs/* /home/wire/docker-squid4/docker-squid/etc/ssl/certs/
cp -a /usr/share/ca-certificates/* /home/wire/docker-squid4/docker-squid/usr/share/ca-certificates/
cp -a /usr/local/share/ca-certificates/* /home/wire/docker-squid4/docker-squid/usr/local/share/ca-certificates/
```
If you had to make either of these two changes, or had to copy the system certificate stores:
* (re)Start squid
```
./run.sh
```

### Making a directory available to clients:

* Create a certificate for our target site, and sign it with our wire.com ssl certificate:
```
export DOMAINNAME=raw.githubusercontent.com
sudo openssl genrsa -out /etc/ssl/private/$DOMAINNAME.key 2048
sudo openssl req -new -key /etc/ssl/private/$DOMAINNAME.key -out /home/wire/docker-squid4/docker-squid/$DOMAINNAME.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=Wire/OU=Backend Team/CN=$DOMAINNAME"
sudo openssl x509 -req -in /home/wire/docker-squid4/docker-squid/$DOMAINNAME.csr -CA /home/wire/docker-squid4/mk-ca-cert/certs/wire.com.crt -CAkey /home/wire/docker-squid4/mk-ca-cert/certs/private.pem -CAcreateserial -out /etc/ssl/certs/$DOMAINNAME.pem -days 500 -sha256
```

* copy the default apache ssl configuration to a new name.
```
export DOMAINNAME=raw.githubusercontent.com
sudo cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/000-$DOMAINNAME.conf
```

edit /etc/apache2/sites-available/000-$DOMAINNAME.conf, and change the SSLCertificateFile and SSLCertificateKeyFile, to point to the certificate and key we created above.
or, if you trust my SED:
```
export DOMAINNAME=raw.githubusercontent.com
sudo sed -i "s=SSLCertificateFile.*/.*=SSLCertificateFile /etc/ssl/certs/$DOMAINNAME.pem=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
sudo sed -i "s=SSLCertificateKeyFile.*/.*=SSLCertificateKeyFile /etc/ssl/private/$DOMAINNAME.key=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
```

* Enable the site configuration for your new ssl site.
```
export DOMAINNAME=raw.githubusercontent.com
sudo a2ensite 000-$DOMAINNAME
```

* reload apache's configuration for your changes to take effect.
```
sudo systemctl reload apache2
```

At this point, the content of /var/www/html are available at https://raw.githubusercontent.com/ from any of our client nodes. 

#### Directory Creation
* Create a directory under /home/wire/docker-squid4/docker-squid. for this example, we're going to create sdispater/poetry/master/, so that we can mirror https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py.
```
mkdir -p /home/wire/docker-squid4/docker-squid/sdispater/poetry/master
```

#### Content population
If you haven't already, populate your new directory with the content you want to serve. for this example:
```
curl https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py -o /home/wire/docker-squid4/docker-squid/sdispater/poetry/master/get-poetry.py
```

#### Permissions
* The owner of this directory and all of it's contents must be the user www-data, with the group www-data, so once you are done populating your content:
```
sudo chown -R www-data.www-data /home/wire/docker-squid4/docker-squid/sdispater
```

#### Apache Configuration
Add the directory to apache, and assign it an alias. for this example, we're going to use an alias the same as the name we gave the directory.
* Edit /etc/apache2/sites-available/000-$DOMAINNAME.conf as root, and add:
```
HostnameLookups Off
ServerName raw.githubusercontent.com
alias /sdispater /home/wire/docker-squid4/docker-squid/sdispater
<Directory /home/wire/docker-squid4/docker-squid/sdispater>
     Options Indexes FollowSymLinks MultiViews
     Require all granted
</Directory>     
```
Right before the closing '</VirtualHost> tag.

Or, if you trust my sed:
```
export DOMAINNAME=raw.githubusercontent.com
export DIRNAME=sdispater
export TARGETDIR=/home/wire/docker-squid4/docker-squid/sdispater
sudo sed -i "s=\(</VirtualHost>\)=ServerName $DOMAINNAME\nHostnameLookups Off\nalias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
```

* restart apache for changes to take effect.
```
sudo service apache2 restart
```

#### DNSMASQ configuration

* Edit/Create /etc/dnsmasq.d/apache to set DNSMASQ to tell both squid and your clients that the site is hosted locally:
```
address=/raw.githubusercontent.com/10.0.0.1
```
Or, use echo to add a line:
```
export DOMAINNAME=raw.githubusercontent.com
echo $'\n' "address=/$DOMAINNAME/10.0.0.1" | sudo bash -c "cat >> /etc/dnsmasq.d/apache"
```

* Restart dnsmasq for your changes to go into effect.
```
sudo service dnsmasq restart
```

## APT style resources:

### Generating the repository
First, we're going to add FAI to our proxybox, so that we can use fai-mirror to stand up a mirror of just the APT packages we require.

```
sudo bash -c 'echo "deb http://archive.ubuntu.com/ubuntu/ xenial universe" > /etc/sources.list.d/ubuntu_universe.sources.list'
sudo apt install fai-server reprepro aptitude
```

Next, we're going to prepare the bare minimum amount of FAI for fai-mirror to do it's job:
```
cd /home/wire/docker-squid4/docker
mkdir -p fai_etc/apt/
touch fai_etc/fai.conf
echo 'FAI_DEBOOTSTRAP="bionic http://archive.ubuntu.com/ubuntu"' > fai_etc/nfsroot.conf
echo 'FAI_CONFIGDIR=/home/wire/docker-squid4/docker-squid/fai_config' >> fai_etc/nfsroot.conf
sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 3B4FE6ACC0B21F32
cp /etc/apt/sources.list fai_etc/apt/sources.list
```

* Select what you want in the repo:
```
mkdir -p fai_config/package_config/
echo "PACKAGES aptitude-r" > fai_config/package_config/poetry
echo "python2.7 python-pip" >> fai_config/package_config/poetry
echo "PACKAGES aptitude-r" > fai_config/package_config/emacs
echo "emacs25-nox" >> fai_config/package_config/emacs
echo "PACKAGES aptitude-r" > fai_config/package_config/ansible
echo "sshpass" >> fai_config/package_config/ansible
```

note that 'aptitude-r' downloads a package, it's dependencies, and all of the packages it recommends and their dependencies. 'aptitude' would just get a package and it's dependencies. aptitude-r seems to be the default behavior, in ubuntu.


* (re)build the repo:
```
sudo rm -rf apt_repository
mkdir -p apt_repository/aptcache/etc/apt/
cp -a /etc/apt/trusted.gpg.d/ apt_repository/aptcache/etc/apt/
fai-mirror -v -b -C fai_etc /home/wire/docker-squid4/docker-squid/apt_repository
sudo chown -R www-data.www-data /home/wire/docker-squid4/docker-squid/apt_repository

```

### Making the repository available to clients:

Your repository is now a directory, so use the 'Raw Content' steps above to serve it to the nodes in your cluster.

After you've done that, running 'curl apt.wire.com/apt_repository/' on the admin node should show the contents of the apt repo.

#### Add the repo to your target system:
```
sudo mv /etc/apt/sources.list /etc/apt/sources.list.online
sudo bash -c 'echo "deb [trusted=yes] http://apt.wire.com/apt_repository/ cskoeln main" >> /etc/apt/sources.list.d/apt.wire.com.sources.list'
sudo apt update
```

## Poetry repository:

poetry's repository index is available at:
```
https://pypi.org/pypi/poetry/json
```

* Make a directory, and store the poetry index in it:
```
mkdir -p /home/wire/docker-squid4/docker-squid/pypi/poetry/
curl https://pypi.org/pypi/poetry/json -o /home/wire/docker-squid4/docker-squid/pypi/poetry/json

* Follow the 'Making a directory available to clients' in the 'Raw Content (https)' section above to serve /home/wire/docker-squid4/docker-squid/pypi as pypi.org.

The poetry install script reads this index, and uses it to find the most recent version of poetry available.

* to get the most recent version of poetry from the json file:
```
cat /home/wire/docker-squid4/docker-squid/pypi/poetry/json | jq .info.version
```

* to get the sha256sum of a version from the index file:
```
cat /home/wire/docker-squid4/docker-squid/pypi/poetry/json | jq '.releases."0.12.17"[1].digests.sha256'
```

to download a version of poetry and it's sha256sum:
```
export POETRYVERSION=0.12.17
mkdir -p /home/wire/docker-squid4/docker-squid/sdispater/poetry/releases/download/$POETRYVERSION/
curl -L https://github.com/sdispater/poetry/releases/download/$POETRYVERSION/poetry-$POETRYVERSION-linux.sha256sum -o /home/wire/docker-squid4/docker-squid/sdispater/poetry/releases/download/$POETRYVERSION/poetry-$POETRYVERSION-linux.sha256sum
curl -L https://github.com/sdispater/poetry/releases/download/$POETRYVERSION/poetry-$POETRYVERSION-linux.tar.gz -o /home/wire/docker-squid4/docker-squid/sdispater/poetry/releases/download/$POETRYVERSION/poetry-$POETRYVERSION-linux.tar.gz
```

FIXME: why does the poetry md5sum in the index file not match the released version on github?
* Check to ensure the sha256sum of your downloaded poetry tarball matches the sha256sum downloaded with it:
```
export POETRYVERSION=0.12.17
sha256sum /home/wire/docker-squid4/docker-squid/sdispater/poetry/releases/download/$POETRYVERSION/poetry-$POETRYVERSION-linux.tar.gz
cat /home/wire/docker-squid4/docker-squid/sdispater/poetry/releases/download/$POETRYVERSION/poetry-$POETRYVERSION-linux.sha256sum
```

* Follow the 'Making a directory available to clients' in the 'Raw Content (https)' section above to serve /home/wire/docker-squid4/docker-squid/sdispater as github.com.

## Git repository:

The next thing our directions download is a git repo, from github.com. Since the last step set up our fake github.com, we are only going to need to add content to it:

* Make a directory for holding our git repo. for this example, we're going to be mirroring wire-server-deploy.
```
export ORG=wireapp
mkdir -p /home/wire/docker-squid4/docker-squid/$ORG
```

* populate the repo:
```
export ORG=wireapp
export REPO=wireapp/wire-server-deploy.git
export REPOURI=https://github.com/wireapp/wire-server-deploy
cd /home/wire/docker-squid4/docker-squid/$ORG
git clone --bare $REPOURI $REPO
mv $REPO/hooks/post-update.sample $REPO/hooks/post-update
chmod a+x $REPO/hooks/post-update
cd $REPO && git update-server-info
```

#### Permissions
* The owner of this directory and all of it's contents must be the user www-data, with the group www-data, so once you are done populating your content:
```
export ORG=wireapp
sudo chown -R www-data.www-data /home/wire/docker-squid4/docker-squid/$ORG
```

#### Making the content available to nodes:

* Perform the same procedure to add a directory to apache as above in the https section, minus the Server name, and the hostname lookups off:
Add the directory to apache, and assign it an alias. for this example, we're going to use an alias the same as the name we gave the directory.
* Edit /etc/apache2/sites-available/000-$DOMAINNAME.conf as root, and add:
```
alias /wireapp /home/wire/docker-squid4/docker-squid/wireapp
<Directory /home/wire/docker-squid4/docker-squid/wireapp>
     Options Indexes FollowSymLinks MultiViews
     Require all granted
</Directory>     
```
Right before the closing '</VirtualHost> tag.

Or, if you trust my sed:
```
export DOMAINNAME=github.com
export DIRNAME=wireapp
export TARGETDIR=/home/wire/docker-squid4/docker-squid/wireapp
sudo sed -i "s=\(</VirtualHost>\)=alias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
```

* restart apache for changes to take effect.
```
sudo service apache2 restart
```

## building a pypi repo:

https://pypi.org/simple/ contains a pypi repo. this repo contains python packages. In order to get a list of what packages we're going to place in the repo, we're going to need the 'poetry.lock' files from all of the things that are pulling from this repo. specifically:
```
https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/poetry.lock
```

* create a directory, and store our first lock there.
```
mkdir -p /home/wire/docker-squid4/docker-squid/poetry_locks
curl https://raw.githubusercontent.com/wireapp/wire-server-deploy/master/ansible/poetry.lock -o /home/wire/docker-squid4/docker-squid/poetry_locks/ansible.lock
```

* Create a script for making the pypi repo:
```
LOCKDIR=poetry_locks
INDEXDIR=/home/wire/docker-squid4/docker-squid/pypi_repository/simple
REPODIR=/home/wire/docker-squid4/docker-squid/pypi_repository/repo
URLBASE="https://pypi.org/repo"
mkdir -p $REPODIR
for each in $(find $LOCKDIR -name *.lock -type f)
do {
    for target in $(cat $each | sed -n 's/^name = "\(.*\)"$/\1/p');
    do {
        target_md5s=$(cat $each | sed -n "s/^[\"]*$target[\"]* = \[/[/p")
	hrefs=""
	mkdir -p $INDEXDIR/$target
	target="$(echo $target | tr '.' '-')"
	echo '<html>' > $INDEXDIR/$target/index.html
	echo '    <head>' >> $INDEXDIR/$target/index.html
	for md5no in $(seq 1 `echo $target_md5s | jq '. | length'`)
	do {
	    md5=$(echo $target_md5s | jq .[$(($md5no-1))] | tr -d "\"")
	    href=$(curl -L https://pypi.org/simple/$target/ 2>/dev/null | grep $md5 | sed "s=.*href.\"\([^\"]*\)#.*=\1=")
	    hrefs="$hrefs$href"$'\n'
	    filename=$(echo $href | sed "s=.*/==")
	    curl -L $href -o $REPODIR/$filename 2>/dev/null
	    echo "    <a href=\"$URLBASE/$filename#sha256=$md5\">$filename</a><br\>" >> $INDEXDIR/$target/index.html
	} done
	echo '    <\head>' >> $INDEXDIR/$target/index.html
	echo '<\html>' >> $INDEXDIR/$target/index.html
    } done
} done
```

* Run this script, to populate your pypi repo.

#### Permissions
* The owner of this directory and all of it's contents must be the user www-data, with the group www-data, so once you are done populating your content:
```
sudo chown -R www-data.www-data /home/wire/docker-squid4/docker-squid/pypi_repository
```

#### Making the content available to nodes:

Since there is already a site set up for pypi.org, we only need to add these directories to that site's definition. note that we need to add the 'simple' and 'repo' subdirectories seperately.

Add the simple directory to apache, and assign it an alias. for this example, we're going to use an alias the same as the name we gave the directory.
* Edit /etc/apache2/sites-available/000-$DOMAINNAME.conf as root, and add:
```
alias /simple /home/wire/docker-squid4/docker-squid/pypi_repository/simple
<Directory /home/wire/docker-squid4/docker-squid/pypi_repository/simple>
     Options Indexes FollowSymLinks MultiViews
     Require all granted
</Directory>     
```
Right before the closing '</VirtualHost> tag.

Also:
Add the repo directory to apache, and assign it an alias. for this example, we're going to use an alias the same as the name we gave the directory.
* Edit /etc/apache2/sites-available/000-$DOMAINNAME.conf as root, and add:
```
alias /repo /home/wire/docker-squid4/docker-squid/pypi_repository/repo
<Directory /home/wire/docker-squid4/docker-squid/pypi_repository/repo>
     Options Indexes FollowSymLinks MultiViews
     Require all granted
</Directory>     
```
Right before the closing '</VirtualHost> tag.

Or, if you trust my sed:
```
export DOMAINNAME=pypi.org
export DIRNAME=simple
export TARGETDIR=/home/wire/docker-squid4/docker-squid/pypi_repository/simple
sudo sed -i "s=\(</VirtualHost>\)=alias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
export DIRNAME=repo
export TARGETDIR=/home/wire/docker-squid4/docker-squid/pypi_repository/repo
sudo sed -i "s=\(</VirtualHost>\)=alias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
```

* restart apache for changes to take effect.
```
sudo service apache2 restart
```

## Kubespray:

### Git Repo:
Use the directions for 'Git Repository' above to mirror kubernetes:
```
https://github.com/kubernetes-sigs/kubespray.git
```

* restart apache for changes to take effect.
```
sudo service apache2 restart
```
