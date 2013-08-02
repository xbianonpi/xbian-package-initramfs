# part of code, which is relevant to block devices ... to keep init readable

up() {
echo "at initramfs/init $1: $(cat /proc/uptime)" >> /run/uptime_start.log
}

mount_root_btrfs() {
    test -z "$1" && device="LABEL=xbian-root-btrfs" || device="$1"
    /bin/mount -t btrfs -o compress=lzo,rw,noatime,autodefrag,space_cache,thread_pool=1 $device $CONFIG_newroot
}

update_resolv() {
for f in `ls /run/net-*.conf | grep -v net-lo.conf`; do cat $f | grep IPV.DNS | tr -d "'"| awk -F'=' '{print "nameserver "$2}' > /etc/resolv.conf; done
for f in `ls /run/net-*.conf | grep -v net-lo.conf`; do cat $f | grep DOMAINSEARCH | tr -d "'"| awk -F'=' '{print "search "$2}' >> /etc/resolv.conf; done
for f in `ls /run/net-*.conf | grep -v net-lo.conf`; do cat $f | grep DNSDOMAIN | tr -d "'"| awk -F'=' '{print "domain "$2}' >> /etc/resolv.conf; done
}

update_interfaces() {
if [ "$1" = "rollback" ]; then
	test -e "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" && mv "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" "${CONFIG_newroot}/etc/network/interfaces"
	return
fi
#test "$CONFIG_cnet" = "dhcp" || return

test -e "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" && return
for f in `ls /run/net-eth?.conf`; do
	f=${f%%.conf}; f=${f##/run/net-};
	if [ "$(cat ${CONFIG_newroot}/etc/network/interfaces | grep $f | grep inet | grep -c iface)" -eq '1' ]; then
		grep -v  "$(cat ${CONFIG_newroot}/etc/network/interfaces | grep $f | grep inet | grep  iface)" "${CONFIG_newroot}/etc/network/interfaces" > "${CONFIG_newroot}/etc/network/interfaces.new"
		if [ "$(cat ${CONFIG_newroot}/etc/network/interfaces | grep $f | grep -c auto)" -eq '0' ]; then
			printf "%s\n" "auto $f" >> "${CONFIG_newroot}/etc/network/interfaces.new"
		fi
		printf "%s\n" "iface $f inet manual" >> "${CONFIG_newroot}/etc/network/interfaces.new"
		test -e "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" || mv "${CONFIG_newroot}/etc/network/interfaces" "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig"
		mv "${CONFIG_newroot}/etc/network/interfaces.new" "${CONFIG_newroot}/etc/network/interfaces"
	fi
done
}

cp_splash() {
copyto="$1"

cp -d -a --parents /usr/bin/splash "$copyto"/
mkdir -p /run/initramfs/usr/share/fonts/splash
mkdir -p /run/initramfs/usr/share/images/splash
cp -d -aR --parents /usr/share/fonts/splash "$copyto"/
cp -d -aR --parents /usr/share/images/splash "$copyto"/
cp -d --parents /usr/bin/splash.images "$copyto"/
cp -d --parents /usr/bin/splash.fonts "$copyto"/
}

create_fsck() {
if [ ! -e "$1"/sbin/fsck.btrfs ]; then
echo "#!/bin/sh

true
" >> "$1"/sbin/fsck.btrfs
chmod +x "$1"/sbin/fsck.btrfs
fi
}

get_root() {
    if echo $CONFIG_root | grep -q 'UUID\|LABEL'; then
        export CONFIG_roottxt=$CONFIG_root
        export CONFIG_root=$(findfs $CONFIG_roottxt 2>/dev/null)
        [ -z $CONFIG_root ] && export CONFIG_root=$CONFIG_roottxt && return 1
    else
        [ -b $CONFIG_root ] || return 1
    fi

    if [ $CONFIG_rootfstype = btrfs ]; then
        btrfs fi show ${CONFIG_roottxt##*=} | grep -qi "devices missing" && return 1
        for b in $(btrfs fi show --all-devices ${CONFIG_roottxt##*=} | grep path | awk '{print $8}'); do
            [ -b $b ] || return 1
        done
        btrfs dev scan
    fi
    
    export DEV="${CONFIG_root%[0-9]}"
    if [ ! -e ${DEV} ]; then
	export DEV=${DEV%p}
	export PARTdelim='p'
    else
	export PARTdelim=''
    fi
    export PART=${CONFIG_root#${CONFIG_root%?}}

    return 0
}

convert_btrfs() {
# Check for the existance of tune2fs through the RESIZEERROR variable
if [ "$RESIZEERROR" -lt '1' -a "$CONFIG_noconvertsd" -eq '0' -a "${CONFIG_rootfstype}" = "btrfs" -a "$FSCHECK" != "btrfs" ]; then

	if [ "${FSCHECK}" = 'ext4' ]; then
		# Make sure we have enough memory available for live conversion
		FREEMEM=`free -m | grep "Mem:" | awk '{printf "%d", $4}'`
		if [ ${FREEMEM} -lt '128' ]; then
				test ! -d /boot && mkdir /boot
				/bin/mount -t vfat "${DEV}${PARTdelim}1" /boot
				# Save the old memory value to the cmdline.txt to restore it later on
				cp /boot/config.txt /boot/config.txt.convert
				sed -i "s/gpu_mem_256=[0-9]*/gpu_mem_256=32/g" /boot/config.txt
				umount /boot
				reboot -f
		fi	
	
		test -n "$CONFIG_splash" && /usr/bin/splash --infinitebar --msgtxt="sd card convert..."
		test -n "$CONFIG_splash" \
|| echo '
 .d8888b.   .d88888b.  888b    888 888     888 8888888888 8888888b. 88888888888
d88P  Y88b d88P" "Y88b 8888b   888 888     888 888        888   Y88b    888
888    888 888     888 88888b  888 888     888 888        888    888    888
888        888     888 888Y88b 888 Y88b   d88P 8888888    888   d88P    888
888        888     888 888 Y88b888  Y88b d88P  888        8888888P"     888
888    888 888     888 888  Y88888   Y88o88P   888        888 T88b      888
Y88b  d88P Y88b. .d88P 888   Y8888    Y888P    888        888  T88b     888
 "Y8888P"   "Y88888P"  888    Y888     Y8P     8888888888 888   T88b    888';
		e2fsck -p -f ${CONFIG_root}
		/splash_updater.sh &
		stdbuf -o 0 -e 0 btrfs-convert -d ${CONFIG_root} 2>&1 > /tmp/output.grab
		touch /run/splash_updater.kill
		export FSCHECK=`blkid -s TYPE -o value -p ${CONFIG_root} `
	fi
	
	test ! -d /boot && mkdir /boot
	/bin/mount -t vfat "${DEV}${PARTdelim}1" /boot
	test -e /boot/config.txt.convert && mv /boot/config.txt.convert /boot/config.txt
	test "$FSCHECK" = "ext4" && sed -i "s/rootfstype=btrfs/rootfstype=ext4/g" /boot/cmdline.txt
	if [ "$FSCHECK" = "btrfs" ]; then
		test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="post conversion tasks..."
		/sbin/btrfs fi label ${CONFIG_root} xbian-root-btrfs
		mount_root_btrfs
		create_fsck $CONFIG_newroot
		/sbin/btrfs sub delete $CONFIG_newroot/ext2_saved

		/sbin/btrfs sub create $CONFIG_newroot/ROOT
		echo "Moving root..."
		test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="moving root..."
		/sbin/btrfs sub snap $CONFIG_newroot $CONFIG_newroot/ROOT/@
		for f in $(ls $CONFIG_newroot/); do [ $f != "ROOT" ] && rm -fr $CONFIG_newroot/$f; done
		mv $CONFIG_newroot/ROOT $CONFIG_newroot/root
		/sbin/btrfs sub create $CONFIG_newroot/home
		/sbin/btrfs sub create $CONFIG_newroot/home/@
		mv $CONFIG_newroot/root/@/home/* $CONFIG_newroot/home/@
		cp $CONFIG_newroot/root/@/etc/fstab $CONFIG_newroot/root/@/etc/fstab.ext4
		if [ `sed -ne "s:\(.*[\ 	]\{1,\}\(/\)[\ 	]\{1,\}.*\):\1:p" $CONFIG_newroot/root/@/etc/fstab 2>/dev/null | wc -l` -eq '1' ]; then
			sed -i "s:\(.*[\ 	]\{1,\}\(/\)[\ 	]\{1,\}.*\):LABEL=xbian-root-btrfs	\/	btrfs	subvol=root/@,rw,thread_pool=1,compress=lzo,noatime,autodefrag,space_cache	0	0:" $CONFIG_newroot/root/@/etc/fstab
		else
			sed -i "\$aLABEL=xbian-root-btrfs	\/	btrfs	subvol=root/@,rw,compress=lzo,noatime,autodefrag,thread_pool=1,space_cache	0	0" $CONFIG_newroot/root/@/etc/fstab
		fi
		rm -f $CONFIG_newroot/root/@/var/swapfile
		sed -i "/\(\/var\/swapfile\)/d" $CONFIG_newroot/root/@/etc/fstab
		sed -i "\$aLABEL=xbian-root-btrfs	/home	btrfs	subvol=home/@,rw,compress=lzo,noatime,autodefrag,thread_pool=1,space_cache	0	0" $CONFIG_newroot/root/@/etc/fstab
		sed -i '1i#' $CONFIG_newroot/root/@/etc/fstab
		sed -i '1i#' $CONFIG_newroot/root/@/etc/fstab
		sed -i '1i#' $CONFIG_newroot/root/@/etc/fstab

		/sbin/btrfs sub snapshot $CONFIG_newroot/root/@ $CONFIG_newroot/root/@safe
		/sbin/btrfs sub snapshot $CONFIG_newroot/home/@ $CONFIG_newroot/home/@safe
		echo "rebalancing filesystem..."
		test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="rebalancing filesystem..."
		btrfs fi bal "$CONFIG_newroot"
		umount $CONFIG_newroot
	fi
	test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="rebooting..."
	umount /boot
	sync
	reboot -f
fi
}

resize_part() {
if [ "$RESIZEERROR" -eq '0' -a "$CONFIG_noresizesd" -eq '0' -a "${CONFIG_rootfstype}" != "nfs" ]; then
	
	nrpart=$(sfdisk -s $DEV$PARTdelim? | grep -c .)
	if [ "$nrpart" -gt "$PART" ]; then
		test -z "$CONFIG_partswap" && echo "FATAL: only the last partition can be resized"
		export RESIZEERROR='1'
		return 1
	fi

	#Save partition table to file
	/sbin/sfdisk -u S -d ${DEV} > /tmp/part.txt
	#Read partition sizes
	sectorTOTAL=`blockdev --getsz ${DEV}`
	sectorSTART=`grep ${CONFIG_root} /tmp/part.txt | awk '{printf "%d", $4}'`
	sectorSIZE=`grep ${CONFIG_root} /tmp/part.txt | awk '{printf "%d", $6}'`
	export sectorNEW=$(( $sectorTOTAL - $sectorSTART ))
	rm /tmp/part.txt &>/dev/null

	if [ $sectorSIZE -lt $sectorNEW ]; then
		test -n "$CONFIG_splash" && /usr/bin/splash --infinitebar --msgtxt="sd card resize..."
		test -n "$CONFIG_splash" \
|| echo '
8888888b.  8888888888  .d8888b.  8888888 8888888888P 8888888 888b    888  .d8888b.
888   Y88b 888        d88P  Y88b   888         d88P    888   8888b   888 d88P  Y88b
888    888 888        Y88b.        888        d88P     888   88888b  888 888    888
888   d88P 8888888     "Y888b.     888       d88P      888   888Y88b 888 888
8888888P"  888            "Y88b.   888      d88P       888   888 Y88b888 888  88888
888 T88b   888              "888   888     d88P        888   888  Y88888 888    888
888  T88b  888        Y88b  d88P   888    d88P         888   888   Y8888 Y88b  d88P
888   T88b 8888888888  "Y8888P"  8888888 d8888888888 8888888 888    Y888  "Y8888P88'

		pSIZE=`sfdisk -s ${CONFIG_root} | awk -F'\n' '{ sum += $1 } END {print sum}'`
		echo ",${sectorNEW},,," | sfdisk -uS -N${PART} --force -q ${DEV}
		nSIZE=`sfdisk -s ${CONFIG_root} | awk -F'\n' '{ sum += $1 } END {print sum}'`

		if [ ! $nSIZE -gt $pSIZE ]; then
			echo "Resizing failed..."
			export RESIZEERROR="1"
		else
			echo "Partition resized..."
		fi
	else
		export RESIZEERROR="0"
	fi
fi

[ "$RESIZEERROR" -lt '0' ] && return 0 || return $RESIZEERROR
}

resize_ext4() {
if [ "$RESIZEERROR" -eq "0" -a "$CONFIG_noresizesd" -eq '0' -a "$FSCHECK" = "ext4" ]; then

	if [ "${FSCHECK}" = 'ext4' ]; then
		# check if the partition needs resizing
		TUNE2FS=`/sbin/tune2fs -l ${CONFIG_root}`;
		TUNEBLOCKSIZE=`echo -e "${TUNE2FS}" | grep "Block size" | awk '{printf "%d", $3}'`;
		TUNEBLOCKCOUNT=`echo -e "${TUNE2FS}" | grep "Block count" | awk '{printf "%d", $3}'`;
		export BLOCKNEW=$(($sectorNEW / ($TUNEBLOCKSIZE / 512) ))

		# resize root partition
		if [ "$TUNEBLOCKCOUNT" -lt "$BLOCKNEW" ]; then
			test -n "$CONFIG_splash" && /usr/bin/splash --infinitebar --msgtxt="sd card resize..."
			test -n "$CONFIG_splash" \
|| echo '
8888888b.  8888888888  .d8888b.  8888888 8888888888P 8888888 888b    888  .d8888b.
888   Y88b 888        d88P  Y88b   888         d88P    888   8888b   888 d88P  Y88b
888    888 888        Y88b.        888        d88P     888   88888b  888 888    888
888   d88P 8888888     "Y888b.     888       d88P      888   888Y88b 888 888
8888888P"  888            "Y88b.   888      d88P       888   888 Y88b888 888  88888
888 T88b   888              "888   888     d88P        888   888  Y88888 888    888
888  T88b  888        Y88b  d88P   888    d88P         888   888   Y8888 Y88b  d88P
888   T88b 8888888888  "Y8888P"  8888888 d8888888888 8888888 888    Y888  "Y8888P88';
			e2fsck -p -f ${CONFIG_root}
			/bin/mount -t ext4 ${CONFIG_root} "$CONFIG_newroot"
			TUNEBLOCKCOUNT=`/sbin/resize2fs ${CONFIG_root} | grep now | rev | awk '{print $3}' | rev`
			if [ "$?" -eq '0' ]; then
				TUNEBLOCKCOUNT=${BLOCKNEW}
			fi
			umount ${CONFIG_root}

			# check if parition was actually resized
			if [ "${TUNEBLOCKCOUNT}" -lt "${BLOCKNEW}" ]; then
				echo "Resizing failed..."
				export RESIZEERROR="1"
			else
				echo "Filesystem resized..."
			fi
			#e2fsck -p -f ${CONFIG_root}
		fi
	fi
fi
}

resize_btrfs() {
if [ "$RESIZEERROR" -eq "0" -a "$CONFIG_noresizesd" -eq '0' -a "$CONFIG_rootfstype" = "btrfs" -a "$FSCHECK" = 'btrfs' ]; then

	# check if the partition needs resizing
	sectorDF=`df -B512 -P | grep "$CONFIG_newroot" | awk '{printf "%d", $2}'`
	
	# resize root partition
	if [ "$sectorDF" -lt "$sectorNEW" ]; then
		test -n "$CONFIG_splash" && /usr/bin/splash --infinitebar --msgtxt="sd card resize..."
		test -n "$CONFIG_splash" \
|| echo '
8888888b.  8888888888  .d8888b.  8888888 8888888888P 8888888 888b    888  .d8888b.
888   Y88b 888        d88P  Y88b   888         d88P    888   8888b   888 d88P  Y88b
888    888 888        Y88b.        888        d88P     888   88888b  888 888    888
888   d88P 8888888     "Y888b.     888       d88P      888   888Y88b 888 888
8888888P"  888            "Y88b.   888      d88P       888   888 Y88b888 888  88888
888 T88b   888              "888   888     d88P        888   888  Y88888 888    888
888  T88b  888        Y88b  d88P   888    d88P         888   888   Y8888 Y88b  d88P
888   T88b 8888888888  "Y8888P"  8888888 d8888888888 8888888 888    Y888  "Y8888P88'
		/sbin/btrfs fi resize max $CONFIG_newroot
		
		sectorDF=`df -B512 -P | grep "$CONFIG_newroot" | awk '{printf "%d", $2}'`

		# check if parition was actually resized
		if [ "$sectorDF" -lt "$sectorNEW" ]; then
			export RESIZEERROR="1"
		fi
	fi
fi
}

move_root() {
ln -s "${CONFIG_root}" /dev/root
[ ! -e /etc/blkid.tab ] || cp /etc/blkid.tab $CONFIG_newroot/etc

/bin/mount --move /run $CONFIG_newroot/run
rm -fr /run
ln -s $CONFIG_newroot/run /run

udevadm control --exit
if [ -e /etc/udev/udev.conf ]; then
  . /etc/udev/udev.conf
fi

/bin/mount --move /dev $CONFIG_newroot/dev
rm -fr /dev
ln -s $CONFIG_newroot/dev /dev

/bin/mount --move /sys $CONFIG_newroot/sys
rm -fr /sys
ln -s $CONFIG_newroot/sys /sys

/bin/mount --move /proc $CONFIG_newroot/proc
rm -fr /proc
ln -s $CONFIG_newroot/proc /proc
}

create_swap() {
if [ "$RESIZEERROR" -eq "0" -a "$CONFIG_partswap" -eq '1' -a "$CONFIG_rootfstype" = "btrfs" -a "$FSCHECK" = 'btrfs' ]; then
    nrpart=$(sfdisk -s $DEV$PARTdelim? | grep -c .)
    [ $nrpart -gt $PART -o $PART -gt 3 ] && return 1
    [ "$(blkid -s TYPE -o value -p $DEV$PARTdelim$nrpart)" = swap ] && return 0
    mount_root_btrfs $CONFIG_root
    mountpoint -q $CONFIG_newroot || return 1
    /sbin/btrfs fi resize -257M $CONFIG_newroot || { umount $CONFIG_newroot; return 1; }
    umount $CONFIG_newroot
    echo ",-256,,," | sfdisk -uM -N${PART} --force ${DEV} >> /run/part_resize.txt 2>&1
    pend=$(sfdisk -l -uS ${DEV} 2>/dev/null| grep $CONFIG_root | awk '{print $3}')
    pstart=$(( ($pend/2048 + 1) * 2048));pPART=$(($PART+1))
    echo "$pstart,+,S,," | sfdisk -uS -N${pPART} --force ${DEV} >> /run/part_resize.txt 2>&1
    mkswap ${DEV}${PARTdelim}${pPART}
fi
}

kill_splash() {
	test -n "$CONFIG_splash" && /bin/kill -SIGTERM $(pidof splash)
	rm -fr /run/splash
}

drop_shell() {
	kill_splash
	set +x

	[ ! -d /boot ] && mkdir /boot
	/bin/mount -t vfat /dev/mmcblk0p1 /boot

	if [ "$1" != noumount ]; then
	    mountpoint -q ${CONFIG_rootfstype} || mount -t ${CONFIG_rootfstype} -o rw,"$CONFIG_rootfsopts" "${CONFIG_root}" $CONFIG_newroot
	    /bin/mount -o bind /proc $CONFIG_newroot/proc
	    /bin/mount -o bind /boot $CONFIG_newroot/boot
	    /bin/mount -o bind /dev $CONFIG_newroot/dev
	    /bin/mount -o bind /sys $CONFIG_newroot/sys
	    [ "$CONFIG_rootfstype" = btrfs ] && /bin/mount -t ${CONFIG_rootfstype} -o rw,subvol=modules/@ "${CONFIG_root}" $CONFIG_newroot/lib/modules
	fi
	mountpoint -q $CONFIG_newroot && ln -s /rootfs /run/initramfs/rootfs
	exec > /dev/console 2>&1
	cat /motd
	echo "the root partition as defined in cmdline.txt is now mounted under /rootfs"
	echo "boot partition is mounted under /boot and bond to /rootfs/boot as well. the same applies for /proc, /sys, /dev and /run."
	echo "you can chroot into your installation with 'chroot /rootfs'. this will allow you work with you're xbian installation"
	echo "like in full booted mode (restricted to text console). effective uid=0 (root)."
	echo ""
	echo "network can be started with 'ipconfig eth0' for dhcp mode, or 'ipconfig ip=ip:mask:gw:::eth0' for static address (where "
	echo "[ip] is you ip address, [mask] is your network mask and [gw] is ip address of your gateway (router)"
	echo ""
	echo "after you finish your work, exit from chroot with 'exit' and then exit again from recovery console shell. your boot will"
	echo "continue."
	echo ""
	echo "in this environment, three aliases are already predefined. just run:"
	echo ""
	echo "'reb' to run 'umount -a; sync; reboot -f' (unmount all filesystems, sync writes and reboot"
	echo "'rum' to run 'umount -a'"
	echo "'rch' to run 'chroot $CONFIG_newroot'"
	if [ -e /bin/bash ]; then
		/bin/bash -i
	else 
		ENV=/.profile /bin/sh -i
	fi
	rm -fr /run/do_drop

	mountpoint -q $CONFIG_newroot/boot && umount $CONFIG_newroot/boot
	mountpoint -q $CONFIG_newroot/proc && umount $CONFIG_newroot/proc
	mountpoint -q $CONFIG_newroot/dev && umount $CONFIG_newroot/dev
	mountpoint -q $CONFIG_newroot/sys && umount $CONFIG_newroot/sys
	mountpoint -q $CONFIG_newroot/sys && umount $CONFIG_newroot/sys
	mountpoint -q $CONFIG_newroot/lib/modules && umount $CONFIG_newroot/lib/modules

	mountpoint -q /boot && umount /boot; [ -d /boot ] && rmdir /boot
	[ "$1" != noumount ] || return 0
	mountpoint -q $CONFIG_newroot && umount $CONFIG_newroot
}

load_modules() {
export MODPROBE_OPTIONS='-qb'
echo "Loading initram modules ... "
grep '^[^#]' /etc/modules |
    while read module args; do
        [ "$module" ] || continue
        modprobe $module $args || :
    done
}
