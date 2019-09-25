# Purpose of this file

to list the resources that are requested during a wire-server deployment at a high-level, so that we may automate the extraction and placement of those resources on a server, and perform the installation without internet access.

# Status:

Experimental. first draft.

## Assumptions:

docker images are covered partially by https://github.com/wireapp/wire-server-deploy/blob/master/ansible/files/registry/list_of_docker_images.txt , so we are going to be a bit unclear re: docker images during the first draft of this document.

## Tools:

Most of the data here will be gathered from the logs of a transparent SSL squid instance. Some may be retrieved through careful use of TcpDump, or MockServer, or by observing one of the target VMs from the CLI.

## Results:

In order to log into admin, kube, or ansible servers, i first located them via nmap, which was not in our proxybox install.

### All Nodes, during install (all of the steps of wire-server-deploy-networkless README.md):

#### Updates
Style: APT
By default, all nodes on ubuntu 18.04.3 look for updates from archive.ubuntu.com. this content is delivered over HTTP, while we are performing security updates.

#### Snap
Style: Snap
Once you have the SSL cert installed, snap will try to update via https://api.snapcraft.io.

It's protocol includes some sort of auth URI, similar to docker's protocol.

#### New Release Check
Style: Simple

On reboot, /usr/lib/ubuntu-release-upgrader/release-upgrade-motd calls /usr/lib/ubuntu-release-upgrader/check-new-release to check for a new ubuntu release. It performs requests to https://changelogs.ubuntu.com/meta-release/lts.

#### NTP
Style: NTP protocol
By default, All nodes look for NTP services from the local network. You can see this in the squid log as a whole bunch of requests to 91.189.9[245].* that are unanswered, because squid doesn't know what to do with this.


#### MOTD

FIXME:
motd.ubuntu.com?

### Admin node, during 'Dependencies' of wire-server-deploy/ansible/README.md:

#### Poetry

##### Python install
Style: APT

The first steps we perform are to download and install python2.7 and python-pip from ubuntu. This has the effect of installing all of the following packages:
```
libpython2.7-minimal
python2.7-minimal
python-minimal
libpython2.7-stdlib
python2.7
libpython-stdlib
python
binutils-common
libbinutils
binutils-x86-64-linux-gnu
binutils
libc-dev-bin
linux-libc-dev
libc6-dev
gcc-7-base
libisl19
libmpc3
cpp-7
cpp
libcc1-0
libgomp1
libitm1
libatomic1
libasan4
liblsan0
libtsan0
libubsan0
libcilkrts5
libmpx2
libquadmath0
libgcc-7-dev
gcc-7
gcc
libstdc++-7-dev
g++-7
g++
make
libdpkg-perl
dpkg-dev
build-essential
libfakeroot
fakeroot
libalgorithm-diff-perl
libalgorithm-diff-xs-perl
libalgorithm-merge-perl
libexpat1-dev
libfile-fcntllock-perl
libpython2.7
libpython2.7-dev
libpython-dev
libpython-all-dev
manpages-dev
python-all
python2.7-dev
python-dev
python-all-dev
python-asn1crypto
python-cffi-backend
python-crypto
python-enum34
python-idna
python-ipaddress
python-six
python-cryptography
python-dbus
python-gi
python-secretstorage
python-keyring
python-keyrings.alt
python-pip-whl
python-pip
python-pkg-resources
python-setuptools
python-wheel
python-xdg
```

##### Downloading poetry
Style: Raw

We download the poetry installer with CURL from:
```
https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py
```

When we run the installer, it grabs information about poetry releases from:
```
https://pypi.org/pypi/poetry/json
```

It then downloads poetry from:
```
https://github.com/sdispater/poetry/releases/download/0.12.17/poetry-0.12.17-linux.sha256sum
https://github.com/sdispater/poetry/releases/download/0.12.17/poetry-0.12.17-linux.tar.gz
```

The installation of poetry grabs content from raw.githubusercontent.com, pypi.org, and gets a poetry release from github.com.

#### Downloading wire-server-deploy

we then download the wire-server-deploy repo from github.
```
https://github.com/wireapp/wire-server-deploy

#### poetry install
during 'poetry install', poetry appears to be getting a reference for each package it wants to install from pypi.org/simple/<packagename>/ , then fetching the content by some sort of hash at files.pythonhosted.org/packages/ . It does this for the following list of packages:
```
six
certifi
chardet
docutils
idna
jmespath
python-dateutil
urllib3
botocore
futures
requests
ansible
hvac
markupsafe
s3transfer
ansible-modules-hashivault
boto
boto3
dnspython
jinja2
netaddr
pbr
pyyaml
rpamel-yaml
```

While it's doing that, it's also looking for an updated pip, which is not needed for a successful result, and can be safely ignored.

#### make download

The 'make download' step uses a rule in a makefile, that is broken into three pieces:

##### make download-kubespray
```
make download-kubespray
```

Downloads a tested version of the kubespray repository via git from:
```
https://github.com/kubernetes-sigs/kubespray.git
```

##### make download-ansible-roles
This rule downloads ansible roles over git, and over the 'GALAXY REST API'.

###### GIT
The git repos that roles are downloaded from are:
```
https://github.com/elastic/ansible-elasticsearch.git
https://github.com/ANXS/hostname.git
https://github.com/ANXS/apt.git
https://github.com/geerlingguy/ansible-role-java
https://github.com/geerlingguy/ansible-role-ntp
https://github.com/wireapp/ansible-cassandra
https://github.com/wireapp/ansible-minio
https://github.com/wireapp/ansible-restund
https://github.com/wireapp/ansible-tinc
https://github.com/githubixx/ansible-role-kubectl
https://github.com/andrewrothstein/ansible-kubernetes-helm
https://github.com/cchurch/ansible-role-admin-users
```

###### GALAXY REST API
Then has a different system it uses to speak to galaxy.ansible.com. It uses the 'GALAXY REST API':
```
https://galaxy.ansible.com/api/
https://galaxy.ansible.com/api/v1/roles?name=unarchive-deps
```
it uses this data to find the most recent version of unarchive-deps.

Next, it downloads:
```
https://github.com/andrewrothstein/ansible-unarchive-deps/archive/v1.0.12.tar.gz
```
##### Static Content:
it downloads tarballs over https from dl.k8s.io and storage.googreapis to get kubernetes itsself, then initializes a helm repo from kubernetes-charts.storage.googleapis.com/index.yaml.
```
https://dl.k8s.io/v1.14.2/kubernetes-client-linux-amd64.tar.gz
```

##### APT Content:
It insures that python-apt , unzip, gzip, bzip2, tar, and xz-utils are installed via apt at this stage.

## Admin node, during 'Preparing to run ansible' of wire-server-deploy/ansible/README.md:


#### Adding IPs to hosts.ini

##### Emacs
Style: APT

At this point, i installed emacs25-nox, to edit tho hosts.ini file. it has the following dependencies:
```
emacsen-common
emacs25-common
liblockfile-bin
liblockfile1
emacs25-bin
emacs25-el
libasound2-data
libasound2
emacs25-nox
```

#### Password authentication

##### sshpass
Style: APT

During this step, we install sshpass, so that ansible can use passwords to log in and become root on the kubernetes/ansible nodes.

#### Optional Steps

Here, we check out wire-server-deploy-networkless, in order to run the ansible script located there, to copy our ca certificate to all of the nodes.

### Kubernetes nodes, during kubespray.

#### Apt Install
Style: APT

The first step performs an apt update,
```
https://changelogs.ubuntu.com/meta-release-lts
http://archive.ubuntu.com/ubuntu/dists/bionic/InRelease
http://archive.ubuntu.com/ubuntu/dists/bionic-updates/InRelease
http://archive.ubuntu.com/ubuntu/dists/bionic-backports/InRelease
http://archive.ubuntu.com/ubuntu/dists/bionic-security/InRelease
```

Then it installs the following packages through APT:
```
libpython2.7-minimal
python2.7-minimal
python-minimal
libpython2.7-stdlib
python2.7
apt-transport-https
aufs-tools
python-apt
unzip
python-httplib2
ipvsadm
socat
```

It adds a GPG key and an apt entry for docker's apt repository.
```
https://download.docker.com/linux/ubuntu/gpg
http://archive.ubuntu.com/ubuntu/dists/bionic/InRelease
http://archive.ubuntu.com/ubuntu/dists/bionic-updates/InRelease
https://download.docker.com/linux/ubuntu/dists/bionic/InRelease
http://archive.ubuntu.com/ubuntu/dists/bionic-backports/InRelease
http://archive.ubuntu.com/ubuntu/dists/bionic-security/InRelease
https://download.docker.com/linux/ubuntu/dists/bionic/stable/binary-amd64/Packages.bz2
```

Then performs an apt update, and downloads the following packages from docker's apt repository:
```
pigz
cgroupfs-mount
libltdl7
containerd.io
docker-ce-cli
docker-ce
```

Note that the version of docker-ce is version locked, and is not the newest available in the repository.

#### Docker pulls
Style: docker-pull
At this point, it downloads some docker images via 'docker pull'. they are:
```
k8s.gcr.io / cluster-proportional-autoscaler-amd64:1.4.0
gcr.io / google_containers/pause-amd64:3.1
quay.io / coreos/etcd:v3.2.26
docker.io / lachlanevenson/k8s-helm:v2.13.1
```

#### kubeadm
Style: Simple
The install downloads the kubeadm binary from:
```
https://storage.googleapis.com/kubernetes-release/release/v1.14.2/bin/linux/amd64/kubeadm
```

#### Another docker pull
Style: Docker-pull
The installer downloads the local-path-provisioner docker image.
```
docker.io / rancher/local-path-provisioner:v0.0.2

```

#### hyperkube
Style: Simple
The install downloads the hyperkube binary from:
```
https://storage.googleapis.com/kubernetes-release/release/v1.14.2/bin/linux/amd64/hyperkube
```

#### More docker pulls:
Style: Docker-pull

The installation continues with more docker pulls, for:
```
quay.io / coreos/flannel-cni:v0.3.0
docker.io / library/nginx:1.15
gcr.io / kubernetes-helm/tiller:v2.13.1
quay.io / coreos/flannel:v0.11.0
gcr.io / google_containers/kubernetes-dashboard-amd64:v1.10.1
quay.io / external_storage/local-volume-provisioner:v2.1.0
quay.io / calico/kube-controllers:v3.4.0
k8s.gcr.io / k8s-dns-node-cache:1.15.1
```

#### container networking
Style: Simple

At this point, the installer downloads containernetworking from:
```
https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz
```

#### Even more docker pulls:
Style: Docker-pull

One last batch of docker containers is downloaded during the install:
```
docker.io / coredns/coredns:1.5.0
gcr.io / google-containers/kube-apiserver:v1.14.2
gcr.io / google-containers/kube-controller-manager:v1.14.2
gcr.io / google-containers/kube-scheduler:v1.14.2
gcr.io / google-containers/kube-proxy:v1.14.2
gcr.io / google-containers/pause:3.1
gcr.io / google-containers/coredns:1.3.1
```

#### Release identifiers:
Style: Simple

At the end of an install, the following URLs are hit only by one node. I assume tracking.

```
https://dl.k8s.io/release/stable-1.txt
https://dl.k8s.io/release/stable-1.14.txt
```




