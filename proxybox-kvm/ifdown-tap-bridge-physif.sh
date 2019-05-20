#!/bin/sh
IP="/sbin/ip"
IFCONFIG="/sbin/ifconfig"
SUDO="/usr/bin/sudo"

. ./tap-bridge-physif-vars.sh

if [ "$SHAREDIF" -eq "0" ] ; then
    echo -n ""
else
    # remove the physical device from the bridge.
    $SUDO $BRCTL delif $BRIDGE $PHYSIF
    # shut down the physical device.
    $SUDO $IFCONFIG $PHYSIF down
fi

$SUDO $IP link set $1 down promisc off

# remove ourself from the bridge.
$SUDO $BRCTL delif $BRIDGE $1

# this script is not responsible for destroying the tap device.
#ip tuntap del dev $1

BRIDGEDEV=`$SUDO $BRCTL show $BRIDGE | grep tap`

if [ -z "$BRIDGEDEV" ] ; then
    {
	# we are the last one out. burn the bridge.
        $SUDO $IFCONFIG $BRIDGE down
        $SUDO $BRCTL delif $BRIDGE $1
        $SUDO $BRCTL delbr $BRIDGE
    }
fi
