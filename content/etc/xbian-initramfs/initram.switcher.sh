#!/bin/sh

mountpoint -q /boot || exit 0

exec 2>/dev/null

ramfs=yes

[ ! -e /etc/default/xbian-initramfs ] || . /etc/default/xbian-initramfs

ramfs_check() {
    bootfile=$1
    root=$(awk -F 'root=' '/root=/{sub(" .*","",$2);print $2}' $bootfile)

    echo "configured root=$root" >&2

    case $root in

        UUID=*|LABEL=*)
            r=$(findfs $(echo $root | tr -d '"'))
            case $r in
                /dev/mmcblk*|/dev/sd*)
	            sed -i "s%root=$root%root=$r%" $bootfile
	            root=$r
	            ramfs=no
                ;;
            esac
        ;;

        PARTUUID=*)
            r=$(findfs $(echo $root | tr -d '"'))
            case $r in
                /dev/mmcblk0*|/dev/sd*)
	            root=$r
	            ramfs=no
                ;;
            esac
        ;;

        ZFS=*|iSCSI=*,ZFS=*)
            root=$(zpool list -H -o bootfs ${root##*ZFS=})
            echo "ZFS root=$root" >&2
        ;;

        iSCSI=*)
            root=${root##iSCSI=}; root=${root##*,}; root=$(findfs $(echo $root | tr -d '"'))
            echo "iSCSI root=$root" >&2
        ;;

        /dev/mmcblk*|/dev/sd*)
            grep -q "rootfstype=f2fs" $bootfile || ramfs=no
        ;;

        /dev/nfs)
            modinfo -k $(dpkg -l | awk '/(linux-image-|xbian-package-kernel)/{v=$3;sub("-.*","",v);sub("~","-",v);print v}') nfs >/dev/null || ramfs=no
            r=$(awk -F 'nfsroot=' '/nfsroot=/{sub(",.*","",$2);print $2}' $bootfile)
            if ! echo $r | grep -q ^"[0-9.]*:/"; then
                root="$(grep -oE "ip=[^ ]*|cnet=[^ ]*" $bootfile | awk -F ':' '{print $2}'):$r"
            fi
            echo "NFSROOT root=$root" >&2
        ;;

    esac

    [ "$FORCEINITRAM" = disabled ] && ramfs=no
    { [ -e /var/run/reboot-required ] || dpkg --compare-versions "$(dpkg-query -f='${Version}' --show xbian-package-xbmc)" ge "21" \
                                      || [ "$FORCEINITRAM" = yes ] || grep -wqsE 'bootmenu|rescue|vnc|cnet' $bootfile; } && ramfs=yes || :
}

case $(xbian-arch) in
    RPI)
        ramfs_check /boot/cmdline.txt
        case $ramfs in
            yes)
                grep -q "^#initramfs " /boot/config.txt && sed -i 's/^#initramfs /initramfs /' /boot/config.txt
            ;;
            no)
                grep -q "^initramfs " /boot/config.txt && sed -i 's/^initramfs /#initramfs /' /boot/config.txt
            ;;
        esac
    ;;

    iMX6)
        ramfs_check /boot/boot.scr.txt
        case $ramfs in
            yes)
                [ -e /boot/initramfs.gz.notinuse -a ! -e /boot/initramfs.gz ] && mv /boot/initramfs.gz.notinuse /boot/initramfs.gz
            ;;
            no)
                [ -e /boot/initramfs.gz ] && mv /boot/initramfs.gz /boot/initramfs.gz.notinuse
            ;;
        esac
    ;;
esac

if grep -qE 'ip=|cnet=' $bootfile; then
    n=$(grep -oE "ip=[^ ]*|cnet=[^ ]*" $bootfile | grep -oE "eth[0-9]|wlan[0-9]|ra[0-9]")
    [ -n "$n" ] || n='eth0'
    if [ "$root" = $(findmnt -r -n -v -o SOURCE /) ] && grep -qE "iface $n inet dhcp|iface $n inet static" /etc/network/interfaces; then
        grep -qs "iface $n inet manual" /etc/xbian-initramfs/netXset2manual || grep "iface $n inet " /etc/network/interfaces >> /etc/xbian-initramfs/netXset2manual
        sed -i "s%iface $n inet .*%iface $n inet manual%" /etc/network/interfaces
    fi
else
    if [ "$root" = $(findmnt -r -n -v -o SOURCE /) -a -e /etc/xbian-initramfs/netXset2manual ]; then
        while read l; do
            sed -i "s%iface $(echo "$l" | awk '{print $2}') inet manual%$l%" /etc/network/interfaces
        done < /etc/xbian-initramfs/netXset2manual
        rm -f /etc/xbian-initramfs/netXset2manual
    fi
fi

[ -e /boot/boot.scr.txt ] && ( cd /boot; [ -n "$(find ./ -iname boot.scr.txt -newer boot.scr)" ] && ./mks )

[ "$1" = update ] && echo "$ramfs" || umount /boot

exit 0
