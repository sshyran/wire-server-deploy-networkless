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

### Networking (Physical hosts only)
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

* Remove the lxd configuration for dnsmasq:
```
rm /etc/dnsmasq.d/lxd
```

* Copy the dnsmasq snippet we've prepared for providing DNS services:
```
sudo cp etc/dnsmasq.d/proxybox.conf /etc/dnsmasq.d/
```
* If you know a specific DNS server you'd rather use than google's, edit /etc/dnsmasq.d/proxybox.conf, and set it there.


* Edit /etc/netplan/50-cloud-init.yaml, and set the interface we are going to be listening on to use the fixed address 10.0.0.1. for example, if we are using the ethernet interface 'ens4':
```
        ens4:
	    addresses:
	      -  10.0.0.1/24
```

* Restart networking, isc-dhcp-server, and dnsmasq:
```
sudo netplan apply
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

* Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)
  * If you would like to check the checksum, please get it from the top of this file.

* Add local ca cert to admin:
```sh
sudo mkdir -p /usr/local/share/ca-certificates/wire.com/
```
  * from proxybox, in the location you checked out the docker-squid4 repo:
```sh
scp docker-squid4/mk-ca-cert/certs/wire.com.crt $USERNAME@$ADMIN_PC_IP:/home/$USERNAME/
```
  * back on admin_vm:
```
sudo cp wire.com.crt /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo chmod 644 /usr/local/share/ca-certificates/wire.com/local_mitm.crt
sudo update-ca-certificates
```

* Check out this repository, and run 'make all', to install helm, and kubectl.
```
sudo apt install make
mkdir -p ~/.local/bin
export PATH=$PATH:~/.local/bin
git clone https://github.com/wireapp/wire-server-deploy-networkless.git
cd wire-server-deploy-networkless
make
```

```
apt install pip3
pip3 install ansible
pip3 install kubespray
pip3 install jinja2
```


### setting up the kubernetes nodes:
Create three more virtual/physical nodes, attached to the physical interface you are running squid on.

* Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including 'stable' docker snap, otherwise no special choices needed)
  * If you would like to check the checksum, please get it from the top of this file.

* After installing, make sure you perform security updates:
```
sudo apt update
sudo apt dist-upgrade
```

### Preparing to install Kubernetes:

(from https://linoxide.com/how-tos/ssh-login-with-public-key/)
* on 'admin', create an SSH key. 
```
ssh-keygen -t rsa
```

* Install it on each of the kubenodes, so that you can SSH into them without a password:
```
ssh-copy-id -i ~/.ssh/id_rsa.pub $ANSIBLE_LOGIN_USERNAME@$IP
```
Replace `$ANSIBLE_LOGIN_USERNAME` with the username of the account you set up when you installed the machine.

Ansible needs permission to become the root user, so that it can perform administratine tasks.
* As root on each of the nodes, add the following line at the end of the /etc/sudoers file:
```
<ANSIBLE_LOGIN_USERNAME>     ALL=(ALL) NOPASSWD:ALL
```
Replace `<ANSIBLE_LOGIN_USERNAME>` with the username of the account you set up when you installed the machine.

It is important that the IPs of machines do not change.

* Get the IPs of all nodes.
```
cat /var/log/syslog | grep DHCPACK | grep -v ubuntu | grep \) | sed "s/.*DHCPACK on //" | sed "s/to .*[(]//" | sed "s/[)] via.*//" | sort -u
```

* set the IPs of the nodes in /etc/dhcp/dhcpd.conf, so that ansible doesn't break:
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

From here, follow wire-server-deploy/ansible/README.md , with the following exception:

Once you get to the 'ansible pre-kubernetes' step, run the setup-mitm-cert.yml script, to copy our certificate to all of the nodes:
```
wire@admin:~/wire-server-deploy/ansible$ poetry run ansible-playbook -i hosts.ini ~/wire-server-deploy-networkless/admin_vm/setup-mitm-cert.yml -vv
```

log into one of the master nodes.
copy the config from .kube in root's homedirectory to being in your user's home directory.

helm init

clone wire-server-deploy.

add the wire helm repo

helm upgrade to add the demo-databases-ephemeral.

helm add the wtf repo for kubernetes-charts.storage.googleapis.com


=== BELOW HERE IS DRAGONS ===



helm init

clone wire-server-deploy.

add the wire helm repo

helm upgrade to add the demo-databases-ephemeral.

helm add the wtf repo for kubernetes-charts.storage.googleapis.com


Making Squid work offline:
add 'offline_mode on' to your squid.conf
apt-get update still doesn't work with internet offline.

refresh_pattern -i \.*$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private

Consider this:

- https://github.com/kubernetes-sigs/kubespray#ansible
- https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment

Then try, on admin-pc:


