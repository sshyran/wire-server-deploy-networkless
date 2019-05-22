This repo contains tools for using the [docker-squid4](https://github.com/wireapp/docker-squid4) docker image to set up a completely transparent proxy host.
This host is to proxy all traffic during a WIRE installation, so that the exact same installation can be performed from cache, without internet access.

# status

experimental

# Inspiration

Sources:
- https://www.ascinc.com/blog/linux/how-to-build-a-simple-router-with-ubuntu-server-18-04-1-lts-bionic-beaver/
- https://stackoverflow.com/questions/20446930/how-to-put-wildcard-entry-into-etc-hosts/20446931#20446931
- https://github.com/fgrehm/squid3-ssl-docker
- https://github.com/wireapp/docker-squid4
- http://roberts.bplaced.net/index.php/linux-guides/centos-6-guides/proxy-server/squid-transparent-proxy-http-https


## Wireless Networking
Install a few extra packages if you are using wireless networking:

```sh
apt-get install linux-wlan-ng rfkill wpasupplicant pump resolvconf
```
create /etc/wpa_supplicant.conf with your wifi settings

```sh
systemctl disable systemd-resolved
systemctl stop systemd-resolved
netplan generate && netplan apply
/root/sbin/wlan start
/root/sbin/ethnet start
/root/sbin/iptables
```
## Wired Network Setup

Should just work by default.

## Installing

Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)

Here is the checksum again if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.2-live-server-amd64.iso
ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53  ubuntu-18.04.2-live-server-amd64.iso
```

Install these packages to provide networking to the machine you will be installing wire on:
```
isc-dhcp-server dnsmasq
```

copy the [proxybox files](./proxybox) to the proxybox.
```
git clone https://github.com/wireapp/wire-server-deploy-networkless.git
cd wire-server-deploy-networkless/proxybox
sudo cp etc/dhcp/dhcpd.conf /etc/dhcp/
sudo mkdir /root/sbin
sudo cp root/sbin/iptables /root/sbin/
```

edit /root/sbin/iptables, and ensure the physical interface you want to serve content from is labeled correctly.

remove the lxd configuration for dnsmasq:
```
rm /etc/dnsmasq.d/lxd
```

edit /etc/dnsmasq.conf. uncomment 'no-resolv' 'bind-interfaces' and 'log-queries', specify that we should use 'server=8.8.8.8' to forward dns to, and specify the interface we are listening to on the 'interfaces=' line.

add the interface we are listening on to /etc/default/isc-dhcp-server, on the 'INTERFACESv4=' line.

edit /etc/netplan/50-cloud-init.yaml, and set the interface we are going to be listening on to use 10.0.0.1. for example:

```
        ens4:
	    addreses:
	      -  10.0.0.1/24
```

restart networking, isc-dhcp-server, and dnsmasq.
```
sudo netplan apply
sudo service isc-dhcp-server restart
sudo service dnsmasq restart
```

Now you should be able to connect any laptop to proxybox via ethernet
and get connectivity to 10.0.0.1, but not beyond:

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

Note that we get an IP address from dnsmasq, but not internet,
since we have not set up the transparent proxy yet.

set up docker to be built as your user. taken from https://superuser.com/questions/835696/how-solve-permission-problems-for-docker-in-ubuntu

```
sudo groupadd docker
sudo gpasswd -a <YOUR_USERNAME_HERE> docker
sudo systemctl restart snap.docker.dockerd
```

log out, and log in again.

FIXME: update-ca-certificates and a read write /etc/ssl/certs
Build and run our squid container on proxybox. Follow the directions in "README-Wire.md" in the [docker-squid4](https://github.com/wireapp/docker-squid4) repo.


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


### setting up admin_vm

FIXME: port 123 outgoing, NTP.



Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)

Here is the checksum again if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.2-live-server-amd64.iso
ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53  ubuntu-18.04.2-live-server-amd64.iso
```

Add local ca cert to admin_vm:
```sh
sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
```

from proxybox:
```sh
scp docker-squid4/mk-ca-cert/certs/wire.com.crt <USERNAME>@<LOCALBOXIP>:/home/<USERNAME>
```

back on admin_vm:
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
# assumes the cert at /usr/local/share/ca-certificates/wire.com - edit setup-nodes.yml if that's not the case
# assumes an inventory group called 'nodes' containing all the IPs/names of the nodes that you wish to install the mitm certificate on.
ansible-playbook -i <path-to-inventory-file> setup-nodes.yml
```

Run kubespray:
ansible_playbook -i inventory/mycluster/hosts.yml --ssh-extra-args="-o StrictHostKeyChecking=no" --become --become-user=root cluster.yml

=== BELOW HERE IS DRAGONS ===

Making Squid work offline:
add 'offline_mode on' to your squid.conf
apt-get update still doesn't work with internet offline.

refresh_pattern -i \.*$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private

Consider this:

- https://github.com/kubernetes-sigs/kubespray#ansible
- https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment

Then try, on admin_vm:

