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

We assume that your uplink is wifi; details may vary for you.

Install [ubuntu 18 server](http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso) (including docker snap, otherwise no special choices needed)

Here is the checksum again if you want to trust this repo instead of the ubuntu page:

```sh
$ sha256sum ubuntu-18.04.2-live-server-amd64.iso
ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53  ubuntu-18.04.2-live-server-amd64.iso
```

Install a few extra packages:

```sh
apt-get install linux-wlan-ng rfkill wpasupplicant pump resolvconf isc-dhcp-server dnsmasq`
```

copy the [proxybox files](./proxybox) over the ones in your system

create /etc/wpa_supplicant.conf with your wifi settings

```sh
systemctl disable systemd-resolved
systemctl stop systemd-resolved
netplan generate && netplan apply
/root/sbin/wlan start
/root/sbin/ethnet start
/root/sbin/iptables
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

Build and run our squid container on proxybox. follow the directions in "README-Wire.md" in the [docker-squid4](https://github.com/wireapp/docker-squid4) repo.


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

Add local ca cert to localbox:

```sh
mkdir -p /usr/local/share/ca-certificates/wire.com/
...  # scp the local_mitm.pem from proxybox to /usr/local/share/ca-certificates/wire.com/
chmod 644 /usr/local/share/ca-certificates/wire.com/local_mitm.pem
update-ca-certificates
```

Consider this:

- https://github.com/kubernetes-sigs/kubespray#ansible
- https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment

Then try, on localbox:

```sh
git clone https://github.com/kubernetes-sigs/kubespray
...
```
