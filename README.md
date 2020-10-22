This repo contains tools for using the [docker-squid4](https://github.com/wireapp/docker-squid4) docker image to set up a completely transparent proxy host.
This host is to proxy all traffic during a WIRE installation, so that the exact same installation can be performed from cache, without internet access.
It also contains scripts and documentation for prototyping this environment using the KVM virtualization suite, on linux.

# Status

Experimental

# Inspiration

Sources:
- https://www.ascinc.com/blog/linux/how-to-build-a-simple-router-with-ubuntu-server-18-04-1-lts-bionic-beaver/
- https://stackoverflow.com/questions/20446930/how-to-put-wildcard-entry-into-etc-hosts/20446931#20446931
- https://github.com/fgrehm/squid3-ssl-docker
- https://github.com/wireapp/docker-squid4
- http://roberts.bplaced.net/index.php/linux-guides/centos-6-guides/proxy-server/squid-transparent-proxy-http-https

## Installing a proxybox:

These directions are made to deploy either on a virtual server, or a physical server. If you need help setting up KVM, please see [our KVM README.md](kvmhelper/README.md).

### Ubuntu18
Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.3-live-server-amd64.iso)

For security purposes, we recommend verifying the SHA256SUM of your downloaded image.

Here is the checksum we got, if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.3-live-server-amd64.iso
b9beac143e36226aa8a0b03fc1cbb5921cff80123866e718aaeba4edb81cfa63  ubuntu-18.04.3-live-server-amd64.iso
```

### Ubuntu16
Install [Ubuntu 16 server](http://releases.ubuntu.com/16.04.6/ubuntu-16.04.6-server-amd64.iso)

### Networking (Physical hosts only)
#### Wireless Networking + Ethernet (Example)
If you are using wireless networking to talk to the internet, and ethernet to talk to the hosts using this proxy:

* Install some extra packages for wireless networking:
```sh
apt-get install linux-wlan-ng rfkill wpasupplicant pump resolvconf
```

* Create /etc/wpa_supplicant.conf with your wifi settings.

* Disable systemd-resolved, so that you can manually manipulate resolv.conf.
```sh
systemctl disable systemd-resolved
systemctl stop systemd-resolved
netplan generate && netplan apply
```

* Copy the wlan and ethernet script from this repo.
```
git clone https://github.com/wireapp/wire-server-deploy-networkless.git
cd wire-server-deploy-networkless/proxybox
mkdir /root/sbin
cp root/sbin/wlan root/sbin/ethnet /root/sbin
```

* start wireless and ethernet.
```
/root/sbin/wlan start
/root/sbin/ethnet start
```

#### Wired Network Setup

Ubuntu's wired network management should just work by default.

### Installing and Configuring Services (virtual hosts only)

* First, if this is a new install, you should perform an update to ensure security patches are applied:
```
sudo apt update
sudo apt dist-upgrade
```

* Install isc-dhcp-server and dnsmasq to provide networking (DNS and DHCP) from the proxybox to the machines you will be installing wire on:
```
sudo apt install isc-dhcp-server dnsmasq
```

* Check out the wire-server-deploy-networkless repo, and copy our pre-written configuration for isc dhcpd over the default one:
```
git clone https://github.com/wireapp/wire-server-deploy-networkless.git
cd wire-server-deploy-networkless/proxybox
sudo cp etc/dhcp/dhcpd.conf /etc/dhcp/
```

* Copy the iptables script we're going to use to forward traffic to squid:
```
sudo mkdir /root/sbin
sudo cp root/sbin/iptables /root/sbin/
```

* Edit /etc/default/isc-dhcp-server, and add the interface we are providing DHCP services on. for example, if we are using the 'ens4' ethernet port to talk to the servers we're installing wire on:
```
INTERFACESv4=ens4
```

* If it exists, remove the lxd configuration for dnsmasq:
```
[ -f /etc/dnsmasq.d/lxd ] && sudo rm /etc/dnsmasq.d/lxd
```

* Copy the dnsmasq snippet we've prepared for providing DNS services:
```
sudo cp etc/dnsmasq.d/proxybox.conf /etc/dnsmasq.d/
```
* If you know a specific DNS server you'd rather use than google's, edit /etc/dnsmasq.d/proxybox.conf, and set it there.

#### Adding a second network interface
##### Ubuntu 18
* Edit /etc/netplan/50-cloud-init.yaml, and set the interface we are going to be listening on to use the fixed address 10.0.0.1. for example, if we are using the ethernet interface 'ens4':
```
        ens4:
            addresses:
              -  10.0.0.1/24
```
Note: Be careful about tabs vs spaces. if your editor uses tabs, netplan will complain, and not work.

* Restart networking:
```
sudo netplan apply
```

##### Ubuntu 16
* Edit /etc/network/interfaces, and set the interface we are going to be listening on to use the fixed address 10.0.0.1. for example, if we are using the ethernet interface 'ens4':
```
iface ens4 inet static
      address 10.0.0.1
      netmask 255.255.255.0
```
* Don't forget to add the new interface on the 'auto' line to make the system bring it up automatically. If the new interface is 'ens4', and the currently used interface is 'ens3':
```
auto ens3 ens4
```

* Bring up the new interface.
```
sudo ifup ens4
```

* Manually add google as your system nameserver.
```
sudo bash -c 'echo "nameserver 8.8.8.8" >> /etc/resolvconf/resolv.conf.d/head'
```

#### Restarting services
* Restart isc-dhcp-server, and dnsmasq:
```
sudo service isc-dhcp-server restart
sudo service dnsmasq restart
```

### Testing services

* Now you should be able to connect a device into the second ethernet port on your proxybox and get a DHCP lease, IP connectivity to 10.0.0.1, and DNS resolution, but not beyond. for example, you should see:
```sh
$ ping 10.0.0.1
PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
64 bytes from 10.0.0.1: icmp_seq=1 ttl=64 time=0.477 ms
64 bytes from 10.0.0.1: icmp_seq=2 ttl=64 time=0.581 ms
^C
[...]
$ ping denic.de
PING denic.de (81.91.170.12) 56(84) bytes of data.
[nothing ...]
```

While DNS is working and IPs resolve, we do not have internet, since we have not set up the transparent proxy yet.

### Build and/or install squid

Install and run our squid container on proxybox. Follow the directions in "README-Wire.md" in the [docker-squid4](https://github.com/wireapp/docker-squid4) repo.


### Forward traffic to squid
* Run the iptables script, to forward all traffic to the squid daemon.
```
sudo /root/sbin/iptables
```
### Test it!

Connect a laptop or a VM to the local network and try it out:

* with explicit proxy...
```sh
curl -v -x 10.0.0.1:3128 http://wire.com/en/
curl -v -x 10.0.0.1:3128 --cacert local_mitm.pem https://wire.com/en/
```

* with transparent http proxy.
```sh
curl -v http://wire.com/en/
```

### setting up an admin node, the ansible nodes, and kubernetes nodes:

The admin node is the machine we're going to perform administrative tasks with. This includes both setting up our kubernetes cluster, and setting up non-kubernetes services via ansible.
Kubernetes nodes are the nodes we're going to run kubernetes, and all of the kubernetes compatible services on. think: everything that does not require state.
Ansible nodes are nodes we are going to install stateful services on: cassandra, minio, etc.

Our post-ubuntu-install procedure for each one of these nodes is the same: apply security updates, add our SSL certificate, and remove a warning in the login banner.

Follow this procedure 7 times: once for your 'admin' node, once for kubenode[1-3], and once for ansnode[1-3].

#### Ubuntu 18
* Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.3-live-server-amd64.iso)
  * If you would like to check the checksum, please get it from the top of this file.

#### Ubuntu 16
* Install [ubuntu 16 server](http://releases.ubuntu.com/16.04/ubuntu-16.04.6-server-amd64.iso)

#### Post-Installation security updates:
* After installing, make sure you perform security updates:
```
sudo apt update
sudo apt dist-upgrade
sudo reboot
```

#### Adding CA Cert:

* Add our local ca certificate to the target machine:
```sh
sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
```
  * from proxybox, in the location you checked out the docker-squid4 repo:
```sh
scp docker-squid4/mk-ca-cert/certs/wire.com.crt $USERNAME@$IP:/home/$USERNAME/
```
  * back on the target machine:
```
sudo cp wire.com.crt /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo chmod 644 /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo update-ca-certificates
```

#### Fixing the MOTD
You might notice the following message as you log in, after a few logins:
```
Failed to connect to https://changelogs.ubuntu.com/meta-release-lts. Check your Internet connection or proxy settings
```

This comes from ubuntu trying to check for updates before our CA certificate is installed. during this time, the nodes cannot communicate to squid via https.

* To make this go away:
```
sudo rm /var/lib/ubuntu-release-upgrader/release-upgrade-available
```

Note: this may re-appear, due to a network outage.

### Preparing to install Kubernetes:

#### KubeNode Hostnames:
During the deployment of kubernetes via kubespray, the hostnames of the kubenodes are changed. It is suggested that you change this before running the kubespray install, so that DHCP reservations based on name (like in the next step) will be consistent during the install.

# To set the hostname of a linux machine, just change /etc/hostname to contain that hostname, and ONLY that hostname. for example:
```
sudo bash -c "echo kubenode03 > /etc/hostname"
```

# Once you change a hostname, you should also update the appropriate entry in /etc/hosts. as root, edit that file, and change the old hostname for the new one. or:
```
sudo sed -i s/kubenode3/kubenode03/ /etc/hosts
```

After changing a hostname and the hosts entry for that hostname, reboot the machine.

#### Fix IPs.
It is important when we are configuring ansible that the IPs of the virtual machines do not change.

to accomplish this, there are several methods:

##### Static Assignment via MAC

You can configure your DHCP server with additional 'host' sections, matching against the MAC address, one for each host.
Pros:
simple, well documented.
Cons:
Does not work in our KVM environment, where a reboot can change your MAC address.

##### Static Assignment via client-identifier

WARNING: this is complicated by the fact that [some playbooks we use change the hostnames of their target machines](https://github.com/wireapp/wire-server-deploy/blob/80e63ce74eb6ff178802e821f83fe21922199e56/ansible/README.md#warning-host-re-use).

You can configure your DHCP server with additional 'host' sections, matching against a client given identifier, one for each host.
Cons:
Some DHCP client softwares (ubuntu 18 + netplan) cannot support changing the client ID to a known value. instead, they submit a GUID, based on the mac address.
Does not work with ubuntu 18 + netplan in our KVM environment, where a reboot can change your Mac address.

* on the Proxybox:, get the IPs of all nodes:
```
cat /var/log/syslog | grep DHCPACK | grep -v ubuntu | grep \) | sed "s/.*DHCPACK on //" | sed "s/to .*[(]//" | sed "s/[)] via.*//" | sort -u
```

* On the proxybox, set the IPs of the nodes in /etc/dhcp/dhcpd.conf, so that ansible doesn't break:
```
sudo bash -c 'cat /var/log/syslog | grep DHCPACK | grep -v ubuntu | grep \) | sed "s/.*DHCPACK on //" | sed "s/to .*[(]//" | sed "s/[)] via.*//" | sort -u | sed "s/\(.*\) \(.*\)/host \2 {\n\toption dhcp-client-identifier \"\2\";\n\tfixed-address \1;\n}\n/" >> /etc/dhcp/dhcpd.conf'
```
This should add entries for each host to the dhcp configuration similar to the following:
```
host <hostname> {
     option dhcp-client-identifier "<hostname>";
     fixed-address <address>;
}
```

* Restart isc-dhcp-server for the previous to go into effect.
```
sudo service isc-dhcp-server restart
```


NOTE: when you install kubernetes, the kubenode1-3 nodes rename themselves kubenode01-03, so you will need to allow that name in the rules for the three kubernetes nodes.
NOTE: when you install cassandra, the ansnode1-3 nodes rename themserves cassandra01-03, so you will need to allow that name in the rules for the three kubernetes nodes.

To prevent confision, I suggest changing the hostnames of kubenode1-3 to kubenode01-03, and changing ansnode1-3 to cassandra01-03.
To change the hostname of a node, and reboot it:
```
export HOSTNO=1
sudo sed -i "s/node$HOSTNO/node0$HOSTNO/" /etc/hosts
sudo sed -i "s/node$HOSTNO/node0$HOSTNO/" /etc/hostname
sudo sed -i "s/ansnode/cassandra/" /etc/hosts
sudo sed -i "s/ansnode/cassandra/" /etc/hostname
sudo reboot
```

To prevent further confusion, I suggest adding a 'host' entry in /etc/dhcp/dhcpd.conf for each ansnode, to provide the same address after it changes names to cassandra0[1-3].


###### Ubuntu 16:
* now log into each node, and add the following line to the end of /etc/dhcp/dhclient.conf:

```
send dhcp-client-identifier = gethostname();
```

##### "Static Assignment" via hostname

You can configure your DHCP server with 'class' sections matching the hostname given by the client, and put 'pools' of leases with a single lease in each, that only allows an individual class.
Pros:
Works in our KVM environment.
Easy to tell most systems to provide a hostname, Ubuntu 18 does so by default.
handles hostname switching easily.
Cons:
Long, ugly, complicated configuration.

###### Server Side
For each host, add one class section BEFORE our subnet declaration in /etc/dhcp/dhcpd.conf. for example:
```
class "admin" { match if option host-name = "admin"; }
class "kubenode1" { match if option host-name = "kubenode01" or option host-name = "kubenode1"; }
class "kubenode2" { match if option host-name = "kubenode02" or option host-name = "kubenode2"; }
class "kubenode3" { match if option host-name = "kubenode03" or option host-name = "kubenode3"; }
class "ansnode1" { match if option host-name = "cassandra01" or option host-name = "ansnode1"; }
class "ansnode2" { match if option host-name = "cassandra02" or option host-name = "ansnode2"; }
class "ansnode3" { match if option host-name = "cassandra03" or option host-name = "ansnode3"; }
```

Rewrite your subnet section. create a pool containing only the leases you've been giving out, and deny members of each of your classes from getting a lease from that pool. now for each class, create a pool, allow that class access to that pool, and stick one IP in that pool. The result shoud look something like this:
```
subnet 10.0.0.0 netmask 255.255.255.0 {
  option subnet-mask 255.255.255.0;
  option routers 10.0.0.1;
  option broadcast-address 10.0.0.255;
  pool {
    deny members of "admin";
    deny members of "kubenode1";
    deny members of "kubenode2";
    deny members of "kubenode3";
    deny members of "ansnode1";
    deny members of "ansnode2";
    deny members of "ansnode3";
    range 10.0.0.8 10.0.0.28;
  }
  pool {
    allow members of "admin";
    range 10.0.0.8 10.0.0.8;
  }
  pool {
    allow members of "kubenode1";
    range 10.0.0.9 10.0.0.9;
  }
  pool {
    allow members of "kubenode2";
    range 10.0.0.10 10.0.0.10;
  }
  pool {
    allow members of "kubenode3";
    range 10.0.0.11 10.0.0.11;
  }
  pool {
    allow members of "ansnode1";
    range 10.0.0.12 10.0.0.12;
  }
  pool {
    allow members of "ansnode2";
    range 10.0.0.13 10.0.0.13;
  }
  pool {
    allow members of "ansnode3";
    range 10.0.0.14 10.0.0.14;
  }
}
```

NOTE: when you install kubernetes, the kubenode1-3 nodes rename themselves kubenode01-03, so you will need to allow that name in the rules for the three kubernetes nodes, and add a class section for each of those names as well.
NOTE: when you install cassandra, the ansnode1-3 nodes rename themserves cassandra01-03, so you will need to allow that name in the rules for the three kubernetes nodes, and add a class section for each of those names as well.

###### Client side
On ubuntu 18.04.2, just make sure it got security patched.

On ubuntu 16.04.6 and 18.04.3, it should work out of the box.

#### Deploying Wire
From here, follow wire-server-deploy/ansible/README.md on your 'admin' node. skip the 'Provision virtual machines' section.

When you get to the 'Preparing to run ansible' section, use the ansnode IPs for cassandra*, elasticsearch* and minio*. use kubenode IPs for ansible_host on kubenode*, 
FIXME: what about restund?


=== BELOW HERE IS DRAGONS ===


, with the following exception:

* Once you get to the 'ansible pre-kubernetes' step, check out this repo, and run the setup-mitm-cert.yml script, to copy our certificate to all of the nodes:
```
cd ~
git clone https://github.com/wireapp/wire-server-deploy-networkless.git
cd wire-server-deploy/ansible
ansible-playbook -i hosts.ini ~/wire-server-deploy-networkless/admin_vm/setup-mitm-cert.yml -vv
```

helm upgrade to add the demo-databases-ephemeral.

helm add the wtf repo for kubernetes-charts.storage.googleapis.com

Making Squid work offline:
add 'offline_mode on' to your squid.conf
apt-get update still doesn't work with internet offline.

refresh_pattern -i \.*$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private

Consider this:

- https://github.com/kubernetes-sigs/kubespray#ansible
- https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment


## Pitfalls / FAQ

### A note on proxy settings and k8s

In rare cases, squid has been observed to remove the body from a response, which may result in issues like this:

```
"k8s.gcr.io/defaultbackend:1.4": rpc error: code = Unknown desc = error pulling image configuration: image config verification failed for digest sha256:846921f0fe0e57df9e4d4961c0c4af481bf545966b5f61af68e188837363530e
```

If you set the proxy explicitly in the k8s environment, these errors should go away:

#### With ansible:

```
ansible-playbook -i hosts.ini ~/wire-server-deploy-networkless/admin_vm/kubernetes_proxy.yml -vv -e proxy_host=10.0.0.1 -e proxy_port=3128
```

#### Manually:

On every kube node, add the following to `/etc/systemd/system/docker.service.d/docker-options.conf`:

```
[Service]
Environment="HTTP_PROXY=http://10.0.0.1:3128/" "HTTPS_PROXY=http://10.0.0.1:3128/" "DOCKER_OPTS=  --data-root=/var/lib/docker --log-opt max-size=50m --log-opt max-file=5 --iptables=false"
```

followed by:

```
sudo systemctl daemon-reload
sudo systemctl restart docker
```

For more info, [check out the docker manual](https://docs.docker.com/config/daemon/systemd/).
