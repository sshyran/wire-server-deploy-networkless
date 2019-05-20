#!/bin/sh
IP="/sbin/ip"
IFCONFIG="/sbin/ifconfig"
SUDO="/usr/bin/sudo"

. ./tap-bridge-physif-vars.sh

if [ "$SHAREDIF" eq "0" ] ; then
    echo -n ""
else
    $SUDO $IFCONFIG $1 0.0.0.0 promisc down
fi

$SUDO $IFCONFIG $PHYSIF down

# remove ourself from the bridge.
$SUDO $BRCTL delif $BRIDGE $1

# remove the physical device from the bridge.
$SUDO $BRCTL delif $BRIDGE $PHYSIF

# this script is not responsible for destroying the tap device.
#ip tuntap del dev $1

BRIDGEDEV=`$SUDO $BRCTL show|grep -E ^"$BRIDGE" | grep tap`


if [ -z "$BRIDGEDEV" ] ; then
    {
	# we are the last one out. burn the bridge.
        $SUDO $IFCONFIG $BRIDGE down
        $SUDO $BRCTL delif $BRIDGE $1
        $SUDO $BRCTL delbr $BRIDGE
    }
fi
