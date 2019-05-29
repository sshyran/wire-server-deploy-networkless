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

Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)

Here is the checksum again if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.2-live-server-amd64.iso
ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53  ubuntu-18.04.2-live-server-amd64.iso
```

### Networking
#### Wireless Networking + USB dongle
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

* start wireless, and bring up the USB dongle.
```
/root/sbin/wlan start
/root/sbin/ethnet start
```

#### Wired Network Setup

Should just work by default.

### Installing and Configuring Services

* Install these packages to provide networking (DNS and DHCP) from the proxybox to the machines you will be installing wire on:
```
apt update
apt install isc-dhcp-server dnsmasq
```

* Copy the [proxybox files](./proxybox) to the proxybox. dhcpd.conf for providing DHCP, and iptables for forwarding traffic to squid/haproxy.
```
git clone https://github.com/wireapp/wire-server-deploy-networkless.git
cd wire-server-deploy-networkless/proxybox
sudo cp etc/dhcp/dhcpd.conf /etc/dhcp/
sudo mkdir /root/sbin
sudo cp root/sbin/iptables /root/sbin/
```

* Edit /root/sbin/iptables, and ensure the physical interface you want to serve content from is labeled correctly.

Remove the lxd configuration for dnsmasq:
```
rm /etc/dnsmasq.d/lxd
```

Edit /etc/dnsmasq.conf. uncomment 'no-resolv' 'bind-interfaces' and 'log-queries', specify that we should use 'server=8.8.8.8' to forward dns to, and specify the interface we are listening to on the 'interfaces=' line.

* Add the interface we are listening on to /etc/default/isc-dhcp-server, on the 'INTERFACESv4=' line.

* Edit /etc/netplan/50-cloud-init.yaml, and set the interface we are going to be listening on to use the fixed address 10.0.0.1. for example:

```
        ens4:
	    addreses:
	      -  10.0.0.1/24
```

* Restart networking, isc-dhcp-server, and dnsmasq:
```
sudo netplan apply
sudo service isc-dhcp-server restart
sudo service dnsmasq restart
```

### Testing services

Now you should be able to connect any laptop to proxybox via ethernet and get IP connectivity to 10.0.0.1, and DNS resolution, but not beyond:

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

### Test it!

Connect a laptop to the local network and try it out: with
explicit proxy...

```sh
curl -v -x 10.0.0.1:3128 http://wire.com/en/
curl -v -x 10.0.0.1:3128 --cacert local_mitm.pem https://wire.com/en/
```

...  and with transparent proxy.

```sh
curl -v http://wire.com/en/
curl -v --cacert local_mitm.pem https://wire.com/en/
```

### setting up admin-pc

FIXME: exclude port 123 outgoing, NTP.


Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)

Here is the checksum again if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.2-live-server-amd64.iso
ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53  ubuntu-18.04.2-live-server-amd64.iso
```

Add local ca cert to admin-pc:
```sh
sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
```

from proxybox:
```sh
scp docker-squid4/mk-ca-cert/certs/wire.com.crt <USERNAME>@<ADMIN-PCIP>:/home/<USERNAME>
```

back on admin-pc:
```
sudo cp wire.com.crt /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo chmod 644 /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo update-ca-certificates
```

run 'make all', using the make file in this directory to install helm, and kubectl.

pip3 install ansible
pip3 install kubespray
pip3 install jinja2

### Setting up a Virtual Machine
follow the directions in proxybox-kvm/README.md. make sure to skip the networking for local networking.

To create more KVM configuration directories, just create a new directory, copy *.sh out of the proxybox-kvm folder, and configure startup.sh, and the two tap*-vars.sh files. don't forget to create a disk image.

Create three nodes, attached to the physical interface you are running squid on.


### Installing Kubernetes on the VMs with kubespray:

https://linoxide.com/how-tos/ssh-login-with-public-key/
Create an SSH key, and 
```
ssh-keygen -t rsa
```

Install it on all of the kubenodes, so that you can SSH into them without a password:
```
ssh-copy-id -i .ssh/id_rsa.pub demo@<IP>
```

On each of the nodes, in order for ansible to sudo to root without a password, at the end of the /etc/sudoers file add this line:
```
username     ALL=(ALL) NOPASSWD:ALL
```
Replace username with your account username

check out the kubespray repo.
```sh
git clone https://github.com/kubernetes-sigs/kubespray
cd kubespray
```

create a cluster configuration.
```
cp -a inventory/sample inventory/mycluster
sudo CONFIG_FILE=inventory/mycluster/hosts.yml python3 contrib/inventory_builder/inventory.py <IPs_Of_All_Nodes>
```
edit inventory/mycluster/group_vars/k8s-cluster/addons.yml, and set helm_enabled to true.

install the SSL certificate on all of the nodes.
```
ssh demo@IP sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
scp /usr/local/share/ca-certificates/wire.com/local_mitm.crt demo@<IP>:/home/demo
ssh demo@IP sudo mv /home/demo/local_mitm.crt /usr/local/share/ca-certificates/wire.com/
ssh demo@IP sudo chown root.root /usr/local/share/ca-certificates/wire.com/local_mitm.crt
ssh demo@IP sudo chmod 644 /usr/local/share/ca-certificates/wire.com/local_mitm.crt
1ssh demo@ip sudo update-ca-certificate
```
FIXME: ANSIBLE THIS STEP.

Run kubespray:
ansible_playbook -i inventory/mycluster/hosts.yml --ssh-extra-args="-o StrictHostKeyChecking=no" --become --become-user=root cluster.yml

log into one of the master nodes.
copy the config from .kube in root's homedirectory to being in your user's home directory.

helm init

clone wire-server-deploy.

add the wire helm repo

helm upgrade to add the demo-databases-ephemeral.

helm add the wtf repo for kubernetes-charts.storage.googleapis.com


=== BELOW HERE IS DRAGONS ===

Making Squid work offline:
add 'offline_mode on' to your squid.conf
apt-get update still doesn't work with internet offline.

refresh_pattern -i \.*$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private

Consider this:

- https://github.com/kubernetes-sigs/kubespray#ansible
- https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment

Then try, on admin-pc:

