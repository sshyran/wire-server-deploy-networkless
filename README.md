This repo contains tools for using the [docker-squid4](https://github.com/wireapp/docker-squid4) docker image to set up a completely transparent proxy host.
This host is to proxy all traffic during a WIRE installation, so that the exact same installation can be performed from cache, without internet access.

### status

experimental


### setting up proxybox
Sources:
- https://www.ascinc.com/blog/linux/how-to-build-a-simple-router-with-ubuntu-server-18-04-1-lts-bionic-beaver/
- https://stackoverflow.com/questions/20446930/how-to-put-wildcard-entry-into-etc-hosts/20446931#20446931
- https://github.com/fgrehm/squid3-ssl-docker
- https://github.com/wireapp/docker-squid4
- http://roberts.bplaced.net/index.php/linux-guides/centos-6-guides/proxy-server/squid-transparent-proxy-http-https


#### Wireless
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

#### Hard Ethernet.

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


### setting up localbox

FIXME: port 123, NTP.
FIXME: port 22, SSH.

FIXME: expand DHCP range and reduce subnet in dhcpd.conf of proxybox.
FIXME: update-ca-certificates and a read write /etc/ssl/certs



Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)

Here is the checksum again if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.2-live-server-amd64.iso
ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53  ubuntu-18.04.2-live-server-amd64.iso
```

Add local ca cert to localbox:
```sh
sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
```

from proxybox:
```sh
scp docker-squid4/mk-ca-cert/certs/wire.com.crt <USERNAME>@<LOCALBOXIP>:/home/<USERNAME>
```

back on localbox:
```
sudo cp wire.com.crt /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo chmod 644 /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo update-ca-certificates
```

=== BELOW HERE IS DRAGONS ===

run 'make all', using the make file in this directory to install helm, and kubectl.



check out kubespray:
```
git clone https://github.com/kubernetes-sigs/kubespray
```

start setting up qemu:
```
sudo apt install qemu-kvm
```

download the 

pip3 install kubespray
pip3 install jinja2
pip3 install ansible



CONFIG_FILE=inventory/mycluster/hosts.yml python3 





Consider this:

- https://github.com/kubernetes-sigs/kubespray#ansible
- https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment

Then try, on localbox:

```sh
git clone https://github.com/kubernetes-sigs/kubespray
...
```
