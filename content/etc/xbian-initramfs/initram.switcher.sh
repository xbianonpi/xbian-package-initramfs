#!/bin/sh

platform=$(xbian-arch) || platform=unknown

mountpoint -q /boot || exit 0
ramfs=yes

[ ! -e /etc/default/xbian-initramfs ] || . /etc/default/xbian-initramfs

if [ $platform = RPI ]; then
{ z=$(cat /boot/cmdline.txt); z=$(echo ${z##* root=} | awk '{print $1}'); }

case $z in
    UUID*|LABEL*)
	ramfs=yes
	root=$(findfs $z 2>/dev/null)
	case $root in 
	    /dev/mmcblk0*)
		eval $(echo "sed -i 's%root=$z%root=$root%'") /boot/cmdline.txt
		z=$root
		ramfs=no
	    ;;
	    *)
	    ;;
	esac
	;;
    /dev/mmcblk0*|/dev/nfs)
	grep -q vers=4 /boot/cmdline.txt && ramfs=yes || ramfs=no
	;;
    *)
	ramfs=yes
	;;
esac
elif [ $platform = iMX6 ]; then
    #grep -qx "setenv fstype btrfs" /boot/boot.scr.txt || ramfs=no
    ramfs=no
fi

{ [ -e /var/run/reboot-required ] || [ "$FORCEINITRAM" = yes ] || grep -wq 'bootmenu\|rescue' /boot/cmdline.txt 2>/dev/null; } && ramfs=yes || :

if [ $platform = RPI ]; then
    case $ramfs in
        yes)
            sed -i 's/^#initramfs /initramfs /' /boot/config.txt
        ;;
        no)
            sed -i 's/^initramfs /#initramfs /' /boot/config.txt
        ;;
    esac
elif [ $platform = iMX6 ]; then
    case $ramfs in
        yes)
            [ -e /boot/initramfs.gz.notinuse -a ! -e /boot/initramfs.gz ] && mv /boot/initramfs.gz.notinuse /boot/initramfs.gz
        ;;
        no)
            [ -e /boot/initramfs.gz ] && mv /boot/initramfs.gz /boot/initramfs.gz.notinuse
        ;;
    esac
fi

if grep -q ip= /boot/cmdline.txt 2>/dev/null && [ $z = $(findmnt -n -v -o SOURCE /) ]; then
    sed -i 's%iface eth0 inet dhcp%iface eth0 inet manual%' /etc/network/interfaces
else
    sed -i 's%iface eth0 inet manual%iface eth0 inet dhcp%' /etc/network/interfaces
fi

cd /boot
[ -n "$(find ./ -iname boot.scr.txt -newer boot.scr)" ] && ./mks
cd /; umount /boot
exit 0
