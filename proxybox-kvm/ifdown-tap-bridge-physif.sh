#!/bin/sh
IP="/sbin/ip"
IFCONFIG="/sbin/ifconfig"
SUDO="/usr/bin/sudo"

. ./tap-bridge-physif-vars.sh

if [ "$SHAREDIF" eq "0" ] ; then
    echo -n ""
else
    $SUDO $IP link set $1 down promisc off
fi

$SUDO $IFCONFIG $PHYSIF down

# remove ourself from the bridge.
$SUDO $BRCTL delif $BRIDGE $1

# this script is not responsible for destroying the tap device.
#ip tuntap del dev $1

BRIDGEDEV=`$SUDO $BRCTL show|grep -E ^"$BRIDGE" | grep tap`


if [ -z "$BRIDGEDEV" ] ; then
    {
	# remove the physical device from the bridge.
	$SUDO $BRCTL delif $BRIDGE $PHYSIF

	# we are the last one out. burn the bridge.
        $SUDO $IFCONFIG $BRIDGE down
        $SUDO $BRCTL delif $BRIDGE $1
        $SUDO $BRCTL delbr $BRIDGE
    }
fi
