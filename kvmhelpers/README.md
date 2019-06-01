# Setting up a KVM network for WIRE:

## Scope of this document:

This document and the files contained in this directory contain instructions and code for setting up KVM virtual hosts and virtual networking, for the testing of various configurations of WIRE and it's dependencies.

## Assumptions:

We're going to assume basic command line skills, and that you have installed some version of ubuntu, debian, or a debian derivitave.

## Installing KVM Virtual Machines

### Verifying KVM extensions, and enabling them.

First, make sure KVM is available and ready to use.

* To see if your CPUs support it, see: https://vitux.com/how-to-check-if-your-processor-supports-virtualization-technology/ . We recommend method '2'.
  * If method 2 does not tell you "KVM acceleration can be used", try method 3. If method 3 works, but method 2 does not, you need to enable virtualization in your BIOS.
    * For loose directions on enabling virtualization in your BIOS, follow https://www.bleepingcomputer.com/tutorials/how-to-enable-cpu-virtualization-in-your-computer-bios/ .

### Install QEMU:

QEMU is the application that lets us take advantage of KVM extensions.

* To install QEMU:
```
sudo apt install qemu-kvm
```

#### Configuring a non-priviledged user

QEMU can be run as a user (suggested for security, but more complicated) or as the 'root' user.

* If you want to run QEMU as a user, add your user to the 'kvm' system group, and ensure your user is in the sudo group.

```
# usermod -a -G sudo <username>
$ sudo usermod -a -G kvm <username>
```

Make sure you log out, and back in again afterwards, to make these group changes take effect..

### Network Plans:

When setting up a fake network of VMs for wire, there are several ways you can hook up the VMs to each other, network wise.

for the purposes of this document, we are going to use:
host <-> proxybox 
            |
	 admin
	    |
	 kubenode1
	    |
         kubenode2
	    |
	 kubenode3
	    |
	 ansnode1
	    |
	 ansnode2
	    |
	 ansnode3

This is to say, we are going to talk to the machine we are running on with a proxy, have one node for administration, three for kubernetes, and three for non-kubernetes services.

We are going to refer to this as 'network plan 1'.

For setting up the host, so that the proxybox can be set up, see README.md in the root of this repository.

### Preparing to install ubuntu on QEMU

* Make a directory for containing each of your virtual machines, inside of a directory. for example, to create the directories for network plan 1:
```
mkdir kvm
mkdir kvm/proxybox
mkdir kvm/admin
mkdir kvm/kubenode1
mkdir kvm/kubenode2
mkdir kvm/kubenode3
mkdir kvm/ansnode1
mkdir kvm/ansnode2
mkdir kvm/ansnode3
```

* Change into the kvm directory, and download our ubuntu iso:
```
wget http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso
```

* Create a virtual hard disk image, to serve as the disk of each of our virtual machines. we're going to make each disk the same, 50 Gigabytes:
```
sudo apt install qemu-utils
qemu-img create proxybox/drive-c.img 50G
qemu-img create admin/drive-c.img 50G
qemu-img create kubenode1/drive-c.img 50G
qemu-img create kubenode2/drive-c.img 50G
qemu-img create kubenode3/drive-c.img 50G
qemu-img create ansnode1/drive-c.img 50G
qemu-img create ansnode2/drive-c.img 50G
qemu-img create ansnode3/drive-c.img 50G
```

### Copying helper scripts:

The repository this file is in (https://github.com/wireapp/wire-server-deploy-networkless.git) the directory that contains this README.md. along side it are helper scripts, for managing QEMU and it's network interfaces.

The helper scripts consist of all of the files in this directory ending in '.sh'. Copy them into the directories you are using to contain your virtual machines. for instance, with this repo checked out to wire-app/wire-server-deploy-networkless:

```
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/proxybox
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/admin
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/kubenode1
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/kubenode2
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/kubenode3
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/kubenode4
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/kubenode5
cp wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kvm/kubenode6
```

#### Choosing an interface:
If the system you are using has a graphical interface, and you elected to set up QEMU to be used by a non-priviledged user, it will use the graphical interface by default. If one of these conditions is not true, Then this script will use the ncurses (text) interface. Should it chose wrong, there are settings in start_kvm.sh you can change.

#### Choosing networking, Ram, CPUs, and boot media:

If you edit the 'start_kvm.sh' script that you copied into the place you're storing your VMs, there are self-explaining configuration options at the top of the file. so let me explain them. :)

* The first user-editable option is MEM, or how much ram you want to give your VM, in megabytes.
* The second option is CPUS, which sets how many CPUs you can see from inside of the VM. Note that this is not a hard reservation, so you can have two CPUs for two VMs, even if you only have two real CPUs.
* The third and forth options are what files to use as the virtual cd-rom and virtual hard disks.

The final two options we're going to examine configure the networking. each option is in a "eth<number>=<STRATEGY>" form. There are currently two strategies available:
  * HOSTBRIDGE -- This network interface is for the VM to talk over ethernet to the machine the VM is running on.
  * GUESTBRIDGE -- This network interface is connected to a virtual switch, which has any other VM that uses this strategy also plugged into it.

following our example network plan, we're going to leave proxybox with one interface configured for HOSTBRIDGE so it has internet access, and one interface configured for GUESTBRIDGE, so the machines we are installing wire on can communicate with it. we are going to comment out the HOSTBRIDGE interface on all other VMs, so that they only speak to the proxybox, via the GUESTBRIDGE.


#### Configuring the host to provide networking:

* Install bridge-utils, for GUESTBRIDGE and HOSTBRIDGE to work.
```
sudo apt install bridge-utils
```

##### LocalHost -> QEMU
== Skip this entire step if we are not providing internet and IP connectivity to any VM, AKA if you are not using LOCALBRIDGE ==

For LOCALBRIDGE, we are going to install and configure an ip-masquerading firewall, a DHCP server, and a DNS server, so that VMs using the LOCALBRIDGE strategy can access the internet, through services on the host machine.

* Install dependencies. the UFW firewall, ISC's DHCP server, and the Bind nameserver:
```
sudo apt install ufw isc-dhcp-server bind9
```

* make sure we can connect on port 22 tcp so we can ssh in.
```
sudo ufw allow 22/tcp
```

###### IP Masquerading

We're going to use the UFW product to provide internet to any machine using the LOCALBRIDGE strategy.

* Change "DEFAULT_FORWARD_POLICY=DROP" to 'DEFAULT_FORWARD_POLICY="ACCEPT"' in /etc/default/ufw

* edit /etc/ufw/sysctl.conf to Disable ipv6, and allow ipv4 forwarding. you should only have to uncomment the first line:
```
net.ipv4.ip_forward=1
#net/ipv6/conf/default/forwarding=1
#net/ipv6/conf/all/forwarding=1
```

* Add the following block of firewall rules right after the first comment block in /etc/ufw/before.rules.  Make sure to change the 'enp0s25' to match the interface you're using to get to the internet:
```

# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Masqeurade traffic from our qemu network of 172.16.0/24 to enp0s25. enp0s25 is probably not the name of your network card. check, and adjust.
-A POSTROUTING -s 172.16.0/24 -o enp0s25 -j MASQUERADE

# don't delete the 'COMMIT' line or these nat table rules won't
# be processed
COMMIT
```

* Restart the firewall to enable these changes:
```
sudo ufw disable && sudo ufw enable
```

###### DHCP services:

In order for VMs plugged into the LOCALBRIDGE to get an address, they will use DHCP. We're going to configure ISC's DHCPD to provide those addresses.

* edit /etc/dhcp/dhcpd.conf
* comment out the line at the top reading: 'option domain-name "example.org";'
* comment out the line near the top reading: 'option domain-name-servers ns1.example.org, ns2.example.org;'
* add the following to the end of the file:
```
# provide DHCP to our hosted kvm network.
subnet 172.16.0.0 netmask 255.255.255.0 {
  range 172.16.0.10 172.16.0.20;
  option routers 172.16.0.1;
  option domain-name-servers 172.16.0.1;
}
```    

* Edit /etc/default/isc-dhcp-server, and Add br0 to the list of ipv4 interfaces dhcpd can listen to.
```
INTERFACESv4="br0"
```

###### Name Services:
DNS services will be handled by BIND, which is configured properly by default. The only thing we need to do is poke a hole in the firewall, so that the LOCALBRIDGE can access it.


* add port 53 udp to the list of ports to allow remote connections from.
```
sudo ufw allow 53/udp
```

##### QEMU -> No Ethernet (on second interface)

Nothing needs done for this.


### Launch the VM, and install ubuntu.
```
./start_kvm.sh
```

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
