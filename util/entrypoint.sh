#!/bin/bash
set -e

# create user and group if necessary
if [ ! $(getent group $GID) ]; then
    addgroup -g $GID syncthing
fi
GROUP_NAME=$(getent group $GID | cut -f 1 -d ":")
if [ ! $(getent passwd $UID) ]; then
    adduser -D -H -u $UID -G $GROUP_NAME syncthing
fi

# Single argument to command line is interface name
if [ -n "$1" ]; then
    # loop until interface is found, or we give up
    NEXT_WAIT_TIME=1
    until [ -e "/sys/class/net/$1" ] || [ $NEXT_WAIT_TIME -eq 4 ]; do
        sleep $(( NEXT_WAIT_TIME++ ))
        echo "Waiting for $1 to become available.... ${NEXT_WAIT_TIME}"
    done
    if [ -e "/sys/class/net/$1" ]; then
        IFACE=$1
    fi
fi

# No arguments mean all interfaces
if [ -z "$1" ]; then
    IFACE=" "
fi

init="/sbin/my_init --skip-startup-files --skip-runit"

if [ -n "$IFACE" ]; then
    # Run dhcpd for specified interface or all interfaces

    data_dir="/data"
    if [ ! -d "$data_dir" ]; then
        echo "Please ensure '$data_dir' folder is available."
        echo 'If you just want to keep your configuration in "data/", add -v "$(pwd)/data:/data" to the docker run command line.'
        exit 1
    fi

    dhcpd_conf="$data_dir/dhcpd.conf"
    if [ ! -r "$dhcpd_conf" ]; then
        echo "Please ensure '$dhcpd_conf' exists and is readable."
        exit 1
    fi

    uid=$(stat -c%u "$data_dir")
    gid=$(stat -c%g "$data_dir")
    if [ $gid -ne 0 ]; then
        groupmod -g $gid dhcpd
    fi
    if [ $uid -ne 0 ]; then
        usermod -u $uid dhcpd
    fi

    [ -e "$data_dir/dhcpd.leases" ] || touch "$data_dir/dhcpd.leases"
    chown dhcpd:dhcpd "$data_dir/dhcpd.leases"
    if [ -e "$data_dir/dhcpd.leases~" ]; then
        chown dhcpd:dhcpd "$data_dir/dhcpd.leases~"
    fi

    container_id=$(grep docker /proc/self/cgroup | sort -n | head -n 1 | cut -d: -f3 | cut -d/ -f3)
    if perl -e '($id,$name)=@ARGV;$short=substr $id,0,length $name;exit 1 if $name ne $short;exit 0' $container_id $HOSTNAME; then
        echo "You must add the 'docker run' option '--net=host' if you want to provide DHCP service to the host network."
    fi

    exec $init -- /usr/sbin/dhcpd -4 -f -d --no-pid -cf "$data_dir/dhcpd.conf" -lf "$data_dir/dhcpd.leases" $IFACE
else
    # Run another binary
    exec $init -- "$@"
fi
