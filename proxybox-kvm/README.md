create the files in this directory.
make sure KVM is enabled in your BIOS.
add your user to the 'kvm' system group.

```
apt install qemu-utils
wget http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso
qemu-img create proxybox.img 50G
```

```
apt install uml-utilities bridge-utils
apt install ufw isc-dhcp-server bind9
```

change "DEFAULT_FORWARD_POLICY=DENY" to 'DEFAULT_FORWARD_POLICY="ACCEPT"' in /etc/default/ufw

disable ipv6, and allow ipv4 forwarding in  /etc/ufw/sysctl.conf:

```
net.ipv4.ip_forward=1
#net/ipv6/conf/default/forwarding=1
#net/ipv6/conf/all/forwarding=1
```

add the following right after the first comment block in /etc/ufw/before.rules:
```
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Forward traffic through enp0s25 - Change to match you out-interface
-A POSTROUTING -s 172.16.0/24 -o enp0s25 -j MASQUERADE

# don't delete the 'COMMIT' line or these nat table rules won't
# be processed
COMMIT
```
edit /etc/dhcp/dhcpd.conf
comment out the line at the top reading: 'option domain-name "example.org";'
comment out the line at the top reading: 'option domain-name-servers ns1.example.org, ns2.example.org;'
add the following to the end of the file:
```
# Our ethernet bridge
subnet 172.16.0.0 netmask 255.255.255.0 {
  range 172.16.0.10 172.16.0.20;
  option routers 172.16.0.1;
  option domain-name-servers 172.16.0.1;
}
```    

add br0 to the list of ipv4 interfaces dhcpd can listen to in /etc/default/isc-dhcp-server

add port 53 udp to the list of ports to allow remote connections from.
```
sudo ufw allow 53/udp
```

./start_kvm.sh

Wait for timeout at "keyboard = human"
english
done


