# two tap devices. tap0 to go to the local system, tap1 for the ethernet interface.
#sudo tunctl -t tap0 -u demo
IP="/sbin/ip"
SUDO="/usr/bin/sudo"

USER=`whoami`

$SUDO $IP tuntap add dev tap0 mode tap user $USER
$SUDO $IP tuntap add dev tap1 mode tap user $USER

if [ -z "$DRIVE" ] ; then
    DRIVE=d
fi

/usr/bin/kvm -m 1024 -boot $DRIVE -drive file=proxybox.img,index=0,media=disk,format=raw -drive file=ubuntu-18.04.2-live-server-amd64.iso,index=1,media=cdrom -rtc base=localtime -netdev tap,id=n1,ifname=tap0,script=./ifup-tap-bridge.sh,downscript=./ifdown-tap-bridge.sh -device rtl8139,netdev=n1 -netdev tap,id=n2,ifname=tap1,script=./ifup-tap-bridge-physif.sh,downscript=./ifdown-tap-bridge-physif.sh -device rtl8139,netdev=n2

#-net nic,macaddr=52:54:00:12:35:A,model=rtl8139 -net tap,ifname=tap0,script=./ifup-tap-bridge.sh,downscript=./ifdown-tap-bridge.sh  -net nic,macaddr=52:54:00:12:35:B,model=rtl8139 -net tap,ifname=tap1,script=./ifup-tap-bridge-physif.sh,downscript=./ifdown-tap-bridge-physif.sh  

$SUDO ip tuntap del dev tap1 mode tap
$SUDO ip tuntap del dev tap0 mode tap

#-net nic,macaddr=52:54:00:12:35:A,model=rtl8139 -net tap,script=./ifup-bridge.sh,downscript=./ifdown-bridge.sh 
