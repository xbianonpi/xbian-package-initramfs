#!/bin/sh

mountpoint -q /boot || exit 0

ramfs=yes

{ z=$(cat /boot/cmdline.txt); z=$(echo ${z##* root=} | awk '{print $1}'); }

case $z in
    UUID*|LABEL*)
	ramfs=yes
	root=$(findfs $z 2>/dev/null)
	case $root in 
	    /dev/mmcblk0*)
		eval $(echo "sed -i 's%root=$z%root=$root%'") /boot/cmdline.txt
		ramfs=no
	    ;;
	    *)
	    ;;
	esac
	;;
    /dev/mmcblk0*|/dev/nfs)
	ramfs=no
	;;
    *)
	ramfs=yes
	;;
esac

[ ! -e /var/run/reboot-required ] || ramfs=yes

case $ramfs in
    yes)
	sed -i 's/^#initramfs /initramfs /' /boot/config.txt
	;;
    no)
	sed -i 's/^initramfs /#initramfs /' /boot/config.txt
	;;
esac

umount /boot
