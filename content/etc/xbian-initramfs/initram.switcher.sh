#!/bin/bash

mountpoint -q /boot || exit 0

ramfs=yes

[ ! -e /etc/default/xbian-initramfs ] || . /etc/default/xbian-initramfs

function ramfs_check() {
    bootfile=$1
    { z=$(grep root= $bootfile); z=$(echo ${z##* root=} | awk '{print $1}'); }

    case $z in

        UUID=*|LABEL=*)
            root=$(findfs $(echo $z|tr -d '"') 2>/dev/null)
            case $root in
                /dev/mmcblk*|/dev/sd*)
	            sed -i "s%root=$z%root=$root%" $bootfile
	            z=$root
	            ramfs=no
                ;;
                *)
                ;;
            esac
        ;;

        PARTUUID=*)
            root=$(findfs $(echo $z|tr -d '"') 2>/dev/null)
            case $root in
                /dev/mmcblk0*|/dev/sd*)
	            z=$root
	            ramfs=no
                ;;
                *)
                ;;
            esac
        ;;

        ZFS=*)
            z=${z##ZFS=}
        ;;

        /dev/mmcblk*|/dev/sd*)
            grep -q "vers=4\|rootfstype=f2fs" $bootfile || ramfs=no
        ;;

        *)
        ;;
    esac

    { [ -e /var/run/reboot-required ] || [ "$FORCEINITRAM" = yes ] || grep -wq 'bootmenu\|rescue' /boot/cmdline.txt 2>/dev/null; } && ramfs=yes || :
    [ "$FORCEINITRAM" != disabled ] || ramfs=no
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

    *)
    ;;
esac

if grep -q ip= $bootfile 2>/dev/null; then
    if [ $z = $(findmnt -r -n -v -o SOURCE /) ] && grep -q 'iface eth0 inet dhcp' /etc/network/interfaces; then
        sed -i 's%iface eth0 inet dhcp%iface eth0 inet manual%' /etc/network/interfaces
        touch /etc/xbian-initramfs/eth0.swap.eth0
    fi
elif ! grep -q ip= $bootfile 2>/dev/null; then
    if [ $z = $(findmnt -r -n -v -o SOURCE /) -a -e /etc/xbian-initramfs/eth0.swap.eth0 ]; then
        sed -i 's%iface eth0 inet manual%iface eth0 inet dhcp%' /etc/network/interfaces
        rm -f /etc/xbian-initramfs/eth0.swap.eth0
    fi
fi

cd /boot; [ -n "$(find ./ -iname boot.scr.txt -newer boot.scr 2>/dev/null)" ] && ./mks

cd /; [ x"$1" = xupdate ] || umount /boot

exit 0
