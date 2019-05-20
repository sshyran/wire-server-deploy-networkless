#!/bin/bash

IP="/sbin/ip"
SUDO="/usr/bin/sudo"

USER=`whoami`

# The interface definitions. Comment out the ones you do not want to use, and change the last three octets of the MACs of the ones you do want to use.
## talk to the local machine on a private interface.
BR0="-netdev tap,id=n1,ifname=tap0,script=./ifup-tap-bridge.sh,downscript=./ifdown-tap-bridge.sh -device rtl8139,netdev=n1"
## talk to a physical ethernet port.
BR1="-netdev tap,id=n2,ifname=tap1,script=./ifup-tap-bridge-physif.sh,downscript=./ifdown-tap-bridge-physif.sh -device rtl8139,netdev=n2"

# Uncomment if you want to use the ncurses frontend, EG, you are trying to run this without a GUI.
#CURSES="-curses"

# The CDROM image. Used for installing.
CDROM=ubuntu-18.04.02-live-server-amd64.iso

# The disk image.
DISK=proxybox.img

# You should not have to modify anything below this line.

#=====================================LINE================================

if [ -n "$BR0" ] ; then
    $SUDO $IP tuntap add dev tap0 mode tap user $USER
fi
if [ -n "$BR1" ] ; then
    $SUDO $IP tuntap add dev tap1 mode tap user $USER
fi

# boot from the CDROM if the user did not specify.
if [ -z "$DRIVE" ] ; then
    DRIVE=d
fi

/usr/bin/kvm -m 1024 -boot $DRIVE -drive file=$DISK,index=0,media=disk,format=raw -drive file=$CDROM,index=1,media=cdrom -rtc base=localtime $BR0 $BR1 $CURSES

if [ -n "$BR1" ] ; then
    $SUDO ip tuntap del dev tap1 mode tap
fi
if [ -n "$BR0" ] ; then
    $SUDO ip tuntap del dev tap0 mode tap
fi


