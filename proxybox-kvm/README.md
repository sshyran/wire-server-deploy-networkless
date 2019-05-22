# Installing QEMU

check out this repository on your target machine.

make sure KVM is enabled in your BIOS.

add your user to the 'kvm' system group, and ensure your user is in the sudo group.
```
# usermod -a -G sudo <username>
$ sudo usermod -a -G kvm <username>
```

log out, and back in again.

install qemu-kvm:
```
sudo apt install qemu-kvm
```

# Preparing to install ubuntu on QEMU

change directory to proxybox-kvm, download our ubuntu iso, and 
```
sudo apt install qemu-utils
wget http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso
qemu-img create proxybox.img 50G
```


# choosing an interface
edit ./start.sh and uncomment the line with CURSES on it.

# Setting up Networking

```
sudo apt install bridge-utils
```

## LocalHost -> QEMU
== Skip this entire step if we are not providing masquerading to the VM ==

```
apt install uml-utilities ufw isc-dhcp-server bind9
```

change "DEFAULT_FORWARD_POLICY=DROP" to 'DEFAULT_FORWARD_POLICY="ACCEPT"' in /etc/default/ufw

disable ipv6, and allow ipv4 forwarding in /etc/ufw/sysctl.conf:

```
net.ipv4.ip_forward=1
#net/ipv6/conf/default/forwarding=1
#net/ipv6/conf/all/forwarding=1
```

Change the 'enp0s25' to match the interface you're using, then add the following right after the first comment block in /etc/ufw/before.rules:
```

# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Masqeurade traffic from our qemu network of 172.16.0/24 to enp0s25 - Change to match your out-interface, and your desired network.
-A POSTROUTING -s 172.16.0/24 -o enp0s25 -j MASQUERADE

# don't delete the 'COMMIT' line or these nat table rules won't
# be processed
COMMIT
```

sudo ufw disable && sudo ufw enable

edit /etc/dhcp/dhcpd.conf
comment out the line at the top reading: 'option domain-name "example.org";'
comment out the line at the top reading: 'option domain-name-servers ns1.example.org, ns2.example.org;'
add the following to the end of the file:
```
# provide DHCP to our hosted kvm network.
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

add port 22 tcp for ssh.
```
ufw allow 22/tcp
```


## QEMU -> No Ethernet (on second interface)
edit ./startup.sh
change thi instances of bridge to bridge2.

cp ifup-tap-bridge.sh ifup-tap-bridge2.sh
cp ifdown-tap-bridge.sh ifdown-tap-bridge2.sh
cp tap-bridge-vars.sh tap-bridge2-vars.sh

BR1="-netdev tap,id=n2,ifname=$BR1TAP,script=./ifup-tap-bridge2.sh,downscript=./ifdown-tap-bridge2.sh -device rtl8139,mac=52:54:00:55:44:33,netdev=n2"

edit the two ifup and down scripts to point to the new vars.

edit vars
no usedhcp, no usedns, no hostroute.

## QEMU -> No Ethernet (primary interface)
edit ./startup.sh, comment out BR1, and ensure the tap device for BR0 and it's mac address are unique.
edit ./tap-, ensure all three services are disabled, and that br0 is changed to br1.

## QEMU -> Ethernet

edit the tap-bridge-physif-vars.sh, and change the PHYSIF to point to the ethernet device you would like to use.
If you skipped the last section, comment out the 'BR0' sections of ./start_kvm.sh.

If this interface is shared with the physical host,

edit the ./start_kvm.sh, and change the mac addresses.

# Launch the VM, and install ubuntu.
./start_kvm.sh

Wait for timeout at "keyboard = human" if you are in graphical mode. otherwise, wait for the '640x480 graphic mode' warning to go away.


english
done
install ubuntu
check that the ethernet has an IP.
'Done'
no, we do not need to set a proxy.
use an entire disk.
qemu_harddisk
Done
Yes, Continue.
username, hostname, password, password again.
install openssh server.

once it reboots, power off the VM. either by hitting 'alt-2' and typing quit, or with the GUI.

To boot into the OS:
```
DRIVE=c ./start_kvm.sh
```


