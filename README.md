This repo contains tools for using the [docker-squid4](https://github.com/wireapp/docker-squid4) docker image to set up a completely transparent proxy host.
This host is to proxy all traffic during a WIRE installation, so that the exact same installation can be performed from cache, without internet access.

# Status

Experimental

# Inspiration

Sources:
- https://www.ascinc.com/blog/linux/how-to-build-a-simple-router-with-ubuntu-server-18-04-1-lts-bionic-beaver/
- https://stackoverflow.com/questions/20446930/how-to-put-wildcard-entry-into-etc-hosts/20446931#20446931
- https://github.com/fgrehm/squid3-ssl-docker
- https://github.com/wireapp/docker-squid4
- http://roberts.bplaced.net/index.php/linux-guides/centos-6-guides/proxy-server/squid-transparent-proxy-http-https


## Installing


### Ubuntu18
Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)

Here is the checksum again if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.2-live-server-amd64.iso
ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53  ubuntu-18.04.2-live-server-amd64.iso
```

### Ubuntu16
Install [Ubuntu 16 server](http://releases.ubuntu.com/16.04.6/ubuntu-16.04.6-server-amd64.iso)


### Networking (Physical hosts only)
#### Wireless Networking + Etherner (Example)
* Install a few extra packages if you are using wireless networking:

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

Should just work by default.

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
sudo netplan apply
```
* Restart networking:
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

### setting up an admin node:

The admin node is the machine we're going to perform administrative tasks with. This includes both setting up our kubernetes cluster, and setting up non-kubernetes services via ansible.


#### Ubuntu 18
* Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso)
  * If you would like to check the checksum, please get it from the top of this file.

#### Ubuntu 16
* Install [ubuntu 16 server](http://releases.ubuntu.com/16.04/ubuntu-16.04.6-server-amd64.iso)

#### Adding CA Cert:

* Add local ca cert to admin:
```sh
sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
```
  * from proxybox, in the location you checked out the docker-squid4 repo:
```sh
scp docker-squid4/mk-ca-cert/certs/wire.com.crt $USERNAME@$ADMIN_PC_IP:/home/$USERNAME/
```
  * back on admin:
```
sudo cp wire.com.crt /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo chmod 644 /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo update-ca-certificates
```

### setting up the kubernetes nodes:

#### Provisioning:
Create three more virtual/physical nodes, attached to the physical interface you are running squid on.

##### Ubuntu 18
* Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso)
  * If you would like to check the checksum, please get it from the top of this file.

##### Ubuntu 16
* Install [ubuntu 16 server](http://releases.ubuntu.com/16.04/ubuntu-16.04.6-server-amd64.iso)

#### Post-Installation
* After installing, make sure you perform security updates:
```
sudo apt update
sudo apt dist-upgrade
```

### Preparing to install Kubernetes:

#### SSH with keys
(from https://linoxide.com/how-tos/ssh-login-with-public-key/)
If you want a bit higher security, you can copy SSH keys between your admin node, and your ansible/kubernetes nodes.

* On 'admin', create an SSH key.
```
ssh-keygen -t rsa
```

* Install your SSH key on each of the kubenodes, so that you can SSH into them without a password:
```
ssh-copy-id -i ~/.ssh/id_rsa.pub $ANSIBLE_LOGIN_USERNAME@$IP
```
Replace `$ANSIBLE_LOGIN_USERNAME` with the username of the account you set up when you installed the machine.

#### sudo without password
Ansible can be configured to use a password for switching from the $ANSIBLE_LOGIN_USERNAME to the root user. This involves having the password lying about, so has security problems.
If you want ansible to not be prompted for any administrative command (a different security problem!):

* As root on each of the nodes, add the following line at the end of the /etc/sudoers file:
```
<ANSIBLE_LOGIN_USERNAME>     ALL=(ALL) NOPASSWD:ALL
```
Replace `<ANSIBLE_LOGIN_USERNAME>` with the username of the account you set up when you installed the machine.

#### Fix IPs.
It is important to ansible that the IPs of machines do not change.

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
many DHCP client softwares (ubuntu 18 + netplan) cannot support changing the client ID to a known value. instead, they submit a GUID, based on the mac address.
Does not work with ubuntu 18 + netplan in our KVM environment, where a reboot can change your Mac address.

* on the Proxybox:, get the IPs of all nodes:
```
cat /var/log/syslog | grep DHCPACK | grep -v ubuntu | grep \) | sed "s/.*DHCPACK on //" | sed "s/to .*[(]//" | sed "s/[)] via.*//" | sort -u
```

* On the proxybox, set the IPs of the nodes in /etc/dhcp/dhcpd.conf, so that ansible doesn't break:
```
sudo bash -c 'cat /var/log/syslog | grep DHCPACK | grep -v ubuntu | grep \) | sed "s/.*DHCPACK on //" | sed "s/to .*[(]//" | sed "s/[)] via.*//" | sort -u | sed "s/\(.*\) \(.*\)/host \2\n\toption dhcp-client-identifier \"\2\"\n\tfixed-address \1\n}\n\n/" >> /etc/dhcp/dhcpd.conf'
```
This should generate entries like the following:
```
host <hostname> {
     option dhcp-client-identifier "<hostname>";
     fixed-address <address>;
}
```

* Restart isc-dhcp-server for the previous to go into effect.

FIXME: DOES NOT WORK WITH UBUNTU 18
* now log into each node, and add the following line to the end of /etc/dhcp/dhclient.conf:
```
send dhcp-client-identifier = gethostname();
```

##### "Static Assignment" via hostname

You can configure your DHCP server with 'class' sections matching the hostname given by the client, and put 'pools' of leases with a single lease in each, that only allows an individual class.
Pros:
Works in our KVM environment.
Easy to tell most systems to provide a hostname, Ubuntu 18 (after security patching) does so by default.
Cons:
Long, ugly, complicated configuration.
Ubuntu 18 must be security patched before it provides a hosntame.

###### Server Side
For each host, add one class section BEFORE our subnet declaration in /etc/dhcp/dhcpd.conf. for example:
```
class "admin" { match if option host-name = "admin"; }
```

Rewrite your subnet section. create a pool containing only the leases you've been giving out, and deny members of each of your classes from getting a lease from that pool. now for each class, create a pool, allow that class access to that pool, and stick one IP in that pool. The result shoud look something like this:
```
subnet 10.0.0.0 netmask 255.255.255.0 {
  option subnet-mask 255.255.255.0;
  option routers 10.0.0.1;
  option broadcast-address 10.0.0.255;
  pool {
    deny members of "admin";
    range 10.0.0.8 10.0.0.28;
  }
  pool {
    allow members of "admin";
    range 10.0.0.38 10.0.0.38;
  }
}
```

NOTE: when you install kubernetes, the kubenode1-3 nodes rename themselves kubenode01-03, so you will need to allow that name in the rules for the three kubernetes nodes, and add a class section for each of those names as well.
NOTE: when you install cassandra, the ansnode1-3 nodes rename themserves cassandra01-03, so you will need to allow that name in the rules for the three kubernetes nodes, and add a class section for each of those names as well.

###### Client side
On ubuntu 18.04, just make sure it got security patched.

On ubuntu 16.04.06, it should work out of the box.

#### Deploying Wire
From here, follow wire-server-deploy/ansible/README.md, with the following exception:

* Once you get to the 'ansible pre-kubernetes' step, check out this repo, and run the setup-mitm-cert.yml script, to copy our certificate to all of the nodes:
```
cd ~
git clone https://github.com/wireapp/wire-server-deploy-networkless.git
cd wire-server-deploy/ansible
poetry run ansible-playbook -i hosts.ini ~/wire-server-deploy-networkless/admin_vm/setup-mitm-cert.yml -vv
```

=== BELOW HERE IS DRAGONS ===

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
poetry run ansible-playbook -i hosts.ini ~/wire-server-deploy-networkless/admin_vm/kubernetes_proxy.yml -vv -e proxy_host=10.0.0.1 -e proxy_port=3128
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
