#!/bin/bash

IP="/sbin/ip"
SUDO="/usr/bin/sudo"

USER=`whoami`

# The interface definitions. Comment out the ones you do not want to use, and change the last three octets of the MACs of the ones you do want to use. also, ensure TAP interfaces are unique per machine.
## talk to the local machine on a private interface.
BR0TAP="tap0"
BR0="-netdev tap,id=n1,ifname=$BR0TAP,script=./ifup-tap-bridge.sh,downscript=./ifdown-tap-bridge.sh -device rtl8139,mac=52:54:00:12:22:32,netdev=n1"
## talk to a physical ethernet port.
BR1TAP="tap1"
BR1="-netdev tap,id=n2,ifname=$BR1TAP,script=./ifup-tap-bridge-physif.sh,downscript=./ifdown-tap-bridge-physif.sh -device rtl8139,mac=52:54:00:55:44:33,netdev=n2"

# Uncomment if you want to use the ncurses frontend, EG, you are trying to run this without a GUI.
#CURSES="-curses"

# The CDROM image. Used for installing.
CDROM=ubuntu-18.04.2-live-server-amd64.iso

# The disk image.
DISK=proxybox.img

# How much memory to allocate to this VM.
MEM=2048

# You should not have to modify anything below this line.

#=====================================LINE================================

if [ -n "$BR0" ] ; then
    $SUDO $IP tuntap add dev $BR0TAP mode tap user $USER
fi
if [ -n "$BR1" ] ; then
    $SUDO $IP tuntap add dev $BR1TAP mode tap user $USER
fi

# boot from the CDROM if the user did not specify.
if [ -z "$DRIVE" ] ; then
    DRIVE=d
fi

/usr/bin/kvm -m $MEM -boot $DRIVE -drive file=$DISK,index=0,media=disk,format=raw -drive file=$CDROM,index=1,media=cdrom -rtc base=localtime $BR0 $BR1 $CURSES

if [ -n "$BR1" ] ; then
    $SUDO ip tuntap del dev $BR1TAP mode tap
fi
if [ -n "$BR0" ] ; then
    $SUDO ip tuntap del dev $BR0TAP mode tap
fi


