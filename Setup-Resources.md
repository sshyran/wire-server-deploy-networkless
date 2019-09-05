# Purpose of this file:

To contain directions in how to change a proxybox so that it serves all of the resources requested during an install, up to the point of having kubespray deployed.

## Raw Content (http)

* We're going to serve raw HTTP content with apache:
```
sudo apt install apache2
```

by default the contents of /var/www/html are available at http://10.0.0.1/.

### Making a directory available to clients:

#### Directory Creation
* Create a directory under /home/wire/docker-squid4/docker-squid. for this example, we're going to create sdispater/poetry/master/, so that we can mirror https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py.
```
mkdir -p /home/wire/docker-squid4/docker-squid/sdispater/poetry/master
```

#### Permissions
Note: the owner of this directory and all of it's contents must be the user www-data, with the group www-data, so once you are done populating your content:
```
chown -R www-data.www-data /home/wire/docker-squid4/docker-squid/sdispater
```

#### Apache Configuration
Add the directory to apache, and assign it an alias. for this example, we're going to use an alias the same as the name we gave the directory.
* Edit /etc/apache2/sites-available/000-default.conf as root, and add:
```
HostnameLookups Off
alias /sdispater /home/wire/docker-squid4/docker-squid/sdispater
<Directory /home/wire/docker-squid4/docker-squid/sdispater>
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

* Edit/Create /etc/dnsmasq.d/apache to set DNSMASQ to tell both squid and your clients that the site is hosted locally:
```
#use dnsmasq to point your target site to resolve as 10.0.0.1.
address=/raw.githubusercontent.com/10.0.0.1
```
#### Squid configuration

* Edit mnt/squid.conf, and ensure that the nameserver it's using is the local nameserver:
```
dns_nameservers 10.0.0.1
```

also remove the last line, that is requesting overly-heavy caching.

* (re)Start squid
```
./run.sh
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

Select what you want in the repo:
```
mkdir -p fai_config/package_config/
echo "PACKAGES aptitude-r" > fai_config/package_config/poetry
echo "python2.7 python-pip" >> fai_config/package_config/poetry
echo "PACKAGES aptitude-r" > fai_config/package_config/emacs
echo "emacs25-nox" >> fai_config/package_config/emacs
```

(re)build the repo:
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


