# Purpose of this file:

To contain directions in how to change a proxybox so that it serves all of the resources requested during an install, up to the point of having kubespray deployed.

## Raw Content (http)

### Setting up to serve raw content

* We're going to serve raw HTTP content with apache:
```
sudo apt install apache2
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

* We're going to serve raw HTTPS content with apache:
```
sudo apt install apache2
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


#### Creating Certificates

* Create a certificate for our target site, and sign it with our wire.com ssl certificate:
```
export DOMAINNAME=raw.githubusercontent.com
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
sudo openssl genrsa -out /etc/ssl/private/$DOMAINNAME.key 2048
sudo openssl req -new -key /etc/ssl/private/$DOMAINNAME.key -out $CONTENTHOME/$DOMAINNAME.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=Wire/OU=Backend Team/CN=$DOMAINNAME"
sudo openssl x509 -req -in $CONTENTHOME/$DOMAINNAME.csr -CA /home/wire/docker-squid4/mk-ca-cert/certs/wire.com.crt -CAkey /home/wire/docker-squid4/mk-ca-cert/certs/private.pem -CAcreateserial -out /etc/ssl/certs/$DOMAINNAME.pem -days 500 -sha256
```

#### Creating an Apache Configuration
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

#### Content Population
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
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=raw.githubusercontent.com
export DIRNAME=sdispater
export TARGETDIR=$CONTENTHOME/sdispater
sudo sed -i "s=\(</VirtualHost>\)=ServerName $DOMAINNAME\nHostnameLookups Off\nalias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
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
cp /etc/apt/sources.list fai_etc/apt/sources.list
echo "deb https://download.docker.com/linux/ubuntu/dists/ bionic stable"
```

* Add the GPG keys for the repos we're going to pull content from:
```
sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 3B4FE6ACC0B21F32
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add –
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
echo "PACKAGES aptitude-r" > fai_config/package_config/unarchive-deps
echo "python-apt" >> fai_config/package_config/unarchive-deps
echo "PACKAGES aptitude-r" > fai_config/package_config/kubernetes
echo "aufs-tools python-httplib2 socat unzip ipvsadm" >> fai_config/package_config/kubernetes
echo "pigz cgroupfs-mount libltdl7 containerd.io docker-ce-cli docker-ce" >> fai_config/package_config/kubernetes
```

Note that 'aptitude-r' downloads a package, it's dependencies, and all of the packages it recommends and their dependencies. 'aptitude' would just get a package and it's dependencies. aptitude-r seems to be the default behavior, in ubuntu.

* Force the fai-mirror tool to create a mirror named 'bionic', with a 'stable' component.
```
export DISTRO=bionic
export COMPONENT=stable
sudo sed -i "s/Codename: .*/Codename: $DISTRO/" /usr/bin/fai-mirror
sudo sed -i "s/Components: .*/Components: $COMPONENT/" /usr/bin/fai-mirror
sudo sed -i "s/includedeb [^ ]*/includedeb $DISTRO/" /usr/bin/fai-mirror

```

* (re)build the repo:
```
sudo rm -rf apt_repository
mkdir -p apt_repository/aptcache/etc/apt/
cp -a /etc/apt/trusted.gpg.d/ apt_repository/aptcache/etc/apt/
cp -a /etc/apt/trusted.gpg apt_repository/aptcache/etc/apt/
fai-mirror -v -b -C fai_etc /home/wire/docker-squid4/docker-squid/apt_repository
sudo chown -R www-data.www-data /home/wire/docker-squid4/docker-squid/apt_repository

```

### Making the repository available to clients:

Your repository is now a directory, so use the 'Raw Content' steps above to serve it to the nodes in your cluster.

After you've done that, running 'curl apt.wire.com/apt_repository/' on the admin node should show the contents of the apt repo.

#### Add the repo to your target system:

On each node in your cluster (kubernetes and non-kubernetes), move the original sources.list out of the way, and add a one line repository definition for this repo. afterward, disable gpg integrety checks for all repos, and run apt update.
```
sudo mv /etc/apt/sources.list /etc/apt/sources.list.online
sudo bash -c 'echo "deb http://apt.wire.com/apt/ bionic stable" >> /etc/apt/sources.list.d/apt.wire.com.sources.list'
sudo bash -c 'echo "Acquire::AllowInsecureRepositories \"true\"" >> /etc/apt/apt.conf.d/99insecure'
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
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=github.com

# expects CONTENTHOME, DOMAINNAME, ORG, and REPO
function clone_git_repo {
export REPOURI=https://$DOMAINNAME/$REPO
mkdir -p $CONTENTHOME/$ORG
git clone --bare $REPOURI $REPO
mv $REPO/hooks/post-update.sample $REPO/hooks/post-update
chmod a+x $REPO/hooks/post-update
cd $REPO && git update-server-info
cd $CONTENTHOME
}

export ORG=wireapp
export REPO=$ORG/wire-server-deploy

clone_git_repo
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
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=github.com
export ORG=wireapp

# expects CONTENTHOME, DOMAINNAME, and ORG.
function add_git_org {
export DIRNAME=$ORG
export TARGETDIR=$CONTENTHOME/$ORG
sudo sed -i "s=\(</VirtualHost>\)=alias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
sudo chown -R www-data.www-data $CONTENTHOME/$ORG
}

add_git_org
```

#### Permissions
* The owner of this directory and all of it's contents must be the user www-data, with the group www-data, so once you are done populating your content:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export ORG=wireapp
sudo chown -R www-data.www-data $CONTENTHOME/$ORG
```
#### Restart Apache

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

## Docker Registry:

### Setting up the registry
change the /root/sbin/iptables script to allow port 22 inbound, and re-run it.

use the ansible 'registry.yml' playbook to set up the registry.

edit the startup script, and change the port to 5001

### Enabling apache proxying:
Apache's proxying functionality is used to forward client requests for the registry to the registry.

* Enable apache proxying:
```
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo service apache2 restart
```

### Setup an apache forward to the registry:

Follow the directions in 'Raw Content (https)/Making a directory available to clients/Creating Certificates' to create fake certificates for this domain.

Follow the directions in 'Raw Content (https)/DNSMASQ configuration' to create a fake domain.

* Create an apache configuration for your fake domain in /etc/apache2/sites-available/000-$DOMAINNAME.conf . for example, for k8s.gcr.io:
```
<VirtualHost _default_:443>
    ServerName k8s.gcr.io

    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>

    SSLEngine on
    SSLProxyEngine On
    SSLCertificateFile /etc/ssl/certs/k8s.gcr.io.pem
    SSLCertificateKeyFile /etc/ssl/private/k8s.gcr.io.key

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyPass / https://localhost:5001/
    ProxyPassReverse / https://localhost:5001/
</VirtualHost>
```

* Enable the site, and restart apache.
```
sudo a2ensite 000-k8s.gcr.io
sudo service apache2 restart
```

### Adding an image to the registry:

* To add an image to our docker registry, run the 'upload_image.sh' script in $CONTENTHOME/docker_registry/opt/registry. For example, to upload k8s.gcr.io's cluster-proportional-autoscaler-amd64:1.4.0:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid
$CONTENTHOME/docker_registry/opt/registry/upload_image.sh k8s.gcr.io cluster-proportional-autoscaler-amd64:1.4.0
```

## make download
the make download step uses three rules in the makefile. we're going to prepare for each of them separately:

### make download-kubespray:
the 'download-kubespray' rule just needs a git repo set up, so it can grab kubespray.

* Use the directions for 'Git Repository' above to mirror kubernetes:
```
https://github.com/kubernetes-sigs/kubespray.git
```

* restart apache for changes to take effect.
```
sudo service apache2 restart
```

## Galaxy Repo
This Makefile rule uses the ansible Galaxy V1 API to request the latest version of the 'unarchive-deps' role.

* Create a directory for containing our Galaxy repo:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
mkdir -p $CONTENTHOME/galaxy_repository/api
```

* Follow the directions in 'Raw Content (https)/Making a Directory available to clients' to create a fake galaxy.ansible.com. Skip the 'Content Population' and 'Permissions' portion. Point the website to $CONTENTHOME/galaxy_repository.


The galaxy rest API stores a definition of it's server version, and protocol version in /api/.
* Make the repo look like it's speaking galaxy API version 1:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export REPOPATH=$CONTENTHOME/galaxy_repository/api/
echo '{"description":"GALAXY REST API","current_version":"v1","available_versions":{"v1":"/api/v1/","v2":"/api/v2/"},"server_version":"3.3.0","version_name":"Doin' it Right","team_members":["chouseknecht","cutwater","alikins","newswangerd","awcrosby","tima","gregdek"]}' > $repopath/index.html
```

The next endpoint we have to serve is /api/v1/roles. you can query for a specific role by name:
```
curl -L 'https://galaxy.ansible.com/api/v1/roles/?name=unarchive-deps'> unarchive-deps.json
```

For the time being, we're going to save this index unmodified, so that the single package 'unarchive-deps' will be served from this repo.

* Save the result of searching for unarchive-deps into api/v1/roles/
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export REPOPATH=$CONTENTHOME/galaxy_repository/api/
mkdir -p $REPOPATH/v1/roles
curl -L 'https://galaxy.ansible.com/api/v1/roles/?name=unarchive-deps' > $REPOPATH/v1/roles/index.html
```

Add the most recent unarchive-deps to our fake-github entry for andrewrothstein.
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
sudo chown -R wire.wire $CONTENTHOME/andrewrothstein
mkdir -p $CONTENTHOME/andrewrothstein/ansible-unarchive-deps/archive/
curl -L https://github.com/andrewrothstein/ansible-unarchive-deps/archive/v1.0.12.tar.gz -o $CONTENTHOME/andrewrothstein/ansible-unarchive-deps/archive/v1.0.12.tar.gz
sudo chown -R www-data.www-data $CONTENTHOME/andrewrothstein
```

### make download-ansible-roles:

#### Git
Almost all of these roles are pulled from git. be prepared to make a lot of git mirrors:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=github.com

# expects CONTENTHOME, DOMAINNAME, ORG, and REPO
function clone_git_repo {
export REPOURI=https://$DOMAINNAME/$REPO
mkdir -p $CONTENTHOME/$ORG
git clone --bare $REPOURI $REPO
mv $REPO/hooks/post-update.sample $REPO/hooks/post-update
chmod a+x $REPO/hooks/post-update
cd $REPO && git update-server-info
cd $CONTENTHOME
}

# expects CONTENTHOME, DOMAINNAME, and ORG.
function add_git_org {
export DIRNAME=$ORG
export TARGETDIR=$CONTENTHOME/$ORG
sudo sed -i "s=\(</VirtualHost>\)=alias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
sudo chown -R www-data.www-data $CONTENTHOME/$ORG
}

export ORG=elastic
export REPO=$ORG/ansible-elasticsearch.git
clone_git_repo

add_git_org

export ORG=ANXS
export REPO=$ORG/hostname.git
clone_git_repo
export REPO=$ORG/apt.git
clone_git_repo

add_git_org

export ORG=geerlingguy
export REPO=$ORG/ansible-role-java.git
clone_git_repo
export REPO=$ORG/ansible-role-ntp.git
clone_git_repo

add_git_org

sudo chown -R wire.wire wireapp
export ORG=wireapp
export REPO=$ORG/ansible-cassandra.git
clone_git_repo
export REPO=$ORG/ansible-minio.git
clone_git_repo
export REPO=$ORG/ansible-restund.git
clone_git_repo
export REPO=$ORG/ansible-tinc.git
clone_git_repo
sudo chown -R www-data.www-data $ORG

export ORG=githubixx
export REPO=$ORG/ansible-role-kubectl.git
clone_git_repo
add_git_org

export ORG=andrewrothstein
export REPO=$ORG/ansible-kubernetes-helm.git
clone_git_repo
add_git_org

export ORG=cchurch
export REPO=$ORG/ansible-role-admin-users.git
clone_git_repo
add_git_org
```

... simple, right?

##### Restart Apache

* restart apache for changes to take effect.
```
sudo service apache2 restart
```

#### make download-cli-binaries:

* Create a directory for holding our kubernetes client:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
mkdir -p $CONTENTHOME/kubernetes_client/v1.14.2/
```

* Follow the directions in 'Raw Content (https)/Making a Directory available to clients' to create a fake dl.k8s.io. Skip the 'Directory creation', 'Content Population' and 'Permissions' portion. Point the website to $CONTENTHOME/kubernetes_client.

* Download kuburnetes client v1.14.2, and place it where it will be served:

```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
curl -L https://dl.k8s.io/v1.14.2/kubernetes-client-linux-amd64.tar.gz -o $CONTENTHOME/kubernetes_client/v1.14.2/kubernetes-client-linux-amd64.tar.gz
```

* Change the permissions so this can be served by apache:
```
sudo chown -R www-data.www-data $CONTENTHOME/kubernetes_client/
```

#### ansible pre-kubernetes

In our squid configuration, we use an ansible script in the wire-server-deploy-networkless git repo to copy our CA certificate to all of the nodes.

* Add the wire-server-deploy-networkless get repo to our wireapp organization:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=github.com

# expects CONTENTHOME, DOMAINNAME, ORG, and REPO
function clone_git_repo {
export REPOURI=https://$DOMAINNAME/$REPO
mkdir -p $CONTENTHOME/$ORG
git clone --bare $REPOURI $REPO
mv $REPO/hooks/post-update.sample $REPO/hooks/post-update
chmod a+x $REPO/hooks/post-update
cd $REPO && git update-server-info
cd $CONTENTHOME
}

sudo chown -R wire.wire wireapp
export ORG=wireapp
export REPO=$ORG/wire-server-deploy-networkless.git
clone_git_repo
sudo chown -R www-data.www-data $ORG
```

#### download.docker.com

* Follow the directions in 'Raw Content (https)/Making a Directory available to clients' to create a fake download.docker.com. Skip the 'Directory creation', 'Content Population' and 'Permissions' portion. Point the website's linux/ubuntu/ to $CONTENTHOME/apt_repository.

* copy download.docker.com's gpg key into place in the repository:
```
curl https://download.docker.com/linux/ubuntu/gpg -o apt_repository/gpg
sudo chown -R www-data.www-data ubuntu 
```

#### more static content:

set up the storage.googleapis.com domain.

```
mkdir kubernetes
curl https://storage.googleapis.com/kubernetes-release/release/v1.14.2/bin/linux/amd64/kubeadm -o kubernetes/kubeadm
curl https://storage.googleapis.com/kubernetes-release/release/v1.14.2/bin/linux/amd64/hyperkube -o kubernetes/hyperkube
sudo chown -R www-data.www-data kubernetes
```

Create a directory for containernetworking's plugins.
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=github.com
mkdir $CONTENTHOME/containernetworking
```

Add an alias and a directory entry to /etc/apache2/sites-available/000-github.com.conf , pointing containernetworking/plugins/releases/download/v0.6.0 to $CONTENTHOME/containernetworking
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=github.com
export DIRNAME=containernetworking/plugins/releases/download/v0.6.0
export TARGETDIR=$CONTENTHOME/containernetworking
sudo sed -i "s=\(</VirtualHost>\)=alias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
```

Add the content:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
curl -L https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz -o $CONTENTHOME/containernetworking/cni-plugins-amd64-v0.6.0.tgz
```

Fix the permissions so apache can serve it:
```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
sudo chown -R www-data.www-data $CONTENTHOME/containernetworking/
```


#### preparing for kubernetes deploy:

Follow the instructions in 'Docker Registry/Setting up the registry' and 'Docker Registry/Enabling apache proxying' to deploy a docker registry.

Follow the instructions in 'Docker Registry/Setup an Apache forward to the registry' to set up forwarding entries for our registry for the following domains:
```
k8s.gcr.io
gcr.io
quay.io
docker.io
registry-1.docker.io
```

Note that docker.io is registry-1.docker.io is dns... but the image name does not contain the first component of the name? just add them both.

Follow the instructions in 'Docker Registry/Adding an image to the registry' to add the following images to the registry:
```
k8s.gcr.io / cluster-proportional-autoscaler-amd64:1.4.0
gcr.io / google_containers/pause-amd64:3.1
quay.io / coreos/etcd:v3.2.26
docker.io / lachlanevenson/k8s-helm:v2.13.1
docker.io / rancher/local-path-provisioner:v0.0.2
quay.io / coreos/flannel-cni:v0.3.0
docker.io / library/nginx:1.15
gcr.io / kubernetes-helm/tiller:v2.13.1
quay.io / coreos/flannel:v0.11.0
gcr.io / google_containers/kubernetes-dashboard-amd64:v1.10.1
quay.io / external_storage/local-volume-provisioner:v2.1.0
quay.io / calico/kube-controllers:v3.4.0
k8s.gcr.io / k8s-dns-node-cache:1.15.1
docker.io / coredns/coredns:1.5.0
gcr.io / google-containers/kube-apiserver:v1.14.2

```

Download the last two release files, and add an alias for serving them:

```
export CONTENTHOME=/home/wire/docker-squid4/docker-squid/
export DOMAINNAME=dl.k8s.io
sudo mkdir -p $CONTENTHOME/kubernetes_client/release
sudo curl -L https://dl.k8s.io/release/table-1.txt -o kubernetes_client/release/stable-1.txt
sudo curl -L https://dl.k8s.io/release/table-1.14.txt -o kubernetes_client/release/stable-1.14.txt
export DOMAINNAME=dl.k8s.io
export DIRNAME=release
export TARGETDIR=$CONTENTHOME/kubernetes_client/release
sudo sed -i "s=\(</VirtualHost>\)=alias /$DIRNAME $TARGETDIR\n<Directory $TARGETDIR>\nOptions Indexes FollowSymLinks MultiViews\nRequire all granted\n</Directory>\n\1=" /etc/apache2/sites-available/000-$DOMAINNAME.conf
```

Restart apache for the change to go into effect:
```
sudo service apache2 restart
```
