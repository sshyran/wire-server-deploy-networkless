# Uncomment if you want to use the ncurses frontend, EG, you are trying to run this without a GUI.
#CURSES="-curses"

# What bridge device to use for communicating between the VM(s) and the physical host.
HOSTBRIDGE_BR=br0

#### you should not have to modify these. tell the author if you have to. ####

function try_to_acquire () {
	$SUDO $IP tuntap add dev $1 mode tap user $USER
	return $?
}

function claim_tap() {
    
    TAPDEVS=$($IP tuntap | $GREP -E ^tap | $SED "s/:.*//")
    TAPDEVCOUNT=$(echo -n "$TAPDEVS" | $WC -l)
    # First, try to fill in any gaps.
    LASTTAP=$(echo -n "$TAPDEVS" | $SED "s/t..//" | $SORT -g | $TAIL -n 1)
    for each in $($SEQ 0 $LASTTAP); do
	if [ $(($TAPSTRIED + $TAPDEVCOUNT)) == $LASTTAP ]; then
	    break
	fi
	if [ -z "$($IP tuntap | $GREP -E ^tap$each)" ]; then
	    try_to_acquire tap$each
	    if [ $? -eq 0 ]; then
		echo tap$each
		return 0
	    fi
	    TAPSTRIED=$(($TAPSTRIED+1))
	fi
    done

    # Then, try to claim one on the end. up to 99
    for each in $($SEQ $(($LASTTAP+1)) 99); do
	try_to_acquire tap$each 
	if [ $? -eq 0 ]; then
	    echo tap$each
	    return 0
	fi
    done
}

release_tap () {
    echo tap0
}



# paths to binaries we use.
IP="/sbin/ip"
SUDO="/usr/bin/sudo"
WHOAMI="/usr/bin/whoami"
GREP="/bin/grep"
WC="/usr/bin/wc"
SEQ="/usr/bin/seq"
SORT="/usr/bin/sort"
TAIL="/usr/bin/tail"
SED="/bin/sed"

# The user who is running this script.
USER=$(${WHOAMI})

