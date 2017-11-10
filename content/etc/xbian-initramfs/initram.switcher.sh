#!/bin/sh

platform=$(xbian-arch) || platform=unknown

mountpoint -q /boot || exit 0
ramfs=yes

[ ! -e /etc/default/xbian-initramfs ] || . /etc/default/xbian-initramfs

if [ $platform = RPI ]; then
{ z=$(cat /boot/cmdline.txt); z=$(echo ${z##* root=} | awk '{print $1}'); }

case $z in
    UUID=*|LABEL=*)
	root=$(findfs $(echo $z|tr -d '"') 2>/dev/null)
	case $root in 
	    /dev/mmcblk0*|/dev/sd*)
		sed -i "s%root=$z%root=$root%" /boot/cmdline.txt
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
    /dev/mmcblk0*|/dev/sd*|/dev/nfs)
	grep -q "vers=4\|rootfstype=f2fs" /boot/cmdline.txt || ramfs=no
	;;
    *)
	;;
esac
elif [ $platform = iMX6 ]; then
    #grep -qx "setenv fstype btrfs" /boot/boot.scr.txt || ramfs=no
    { z=$(grep root= /boot/boot.scr.txt); z=$(echo ${z##* root=} | awk '{print $1}'); }
    case $z in
        ZFS=*)
            z=${z##ZFS=}
            ramfs=yes
            ;;
        UUID=*|LABEL=*)
            z=$(findfs $(echo $z|tr -d '"') 2>/dev/null)
            ramfs=yes
            ;;
        /dev/mmcblk0*|/dev/nfs)
            grep -q "vers=4\|rootfstype=f2fs" /boot/boot.scr.txt && ramfs=yes || ramfs=no
            ;;
        *)
            ramfs=no
            ;;
    esac
fi

{ [ -e /var/run/reboot-required ] || [ "$FORCEINITRAM" = yes ] || grep -wq 'bootmenu\|rescue' /boot/cmdline.txt 2>/dev/null; } && ramfs=yes || :
[ "$FORCEINITRAM" != disabled ] || ramfs=no

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

if grep -q ip= /boot/cmdline.txt 2>/dev/null || grep -q ip= /boot/boot.scr.txt 2>/dev/null; then
    if [ $z = $(findmnt -r -n -v -o SOURCE /) ] && grep -q 'iface eth0 inet dhcp' /etc/network/interfaces; then
        sed -i 's%iface eth0 inet dhcp%iface eth0 inet manual%' /etc/network/interfaces
        touch /etc/xbian-initramfs/eth0.swap.eth0
    fi
elif ! grep -q ip= /boot/cmdline.txt 2>/dev/null && ! grep -q ip= /boot/boot.scr.txt 2>/dev/null; then
    if [ $z = $(findmnt -r -n -v -o SOURCE /) -a -e /etc/xbian-initramfs/eth0.swap.eth0 ]; then
        sed -i 's%iface eth0 inet manual%iface eth0 inet dhcp%' /etc/network/interfaces
        rm -f /etc/xbian-initramfs/eth0.swap.eth0
    fi
fi

cd /boot
[ -n "$(find ./ -iname boot.scr.txt -newer boot.scr 2>/dev/null)" ] && ./mks
cd /; umount /boot
exit 0
