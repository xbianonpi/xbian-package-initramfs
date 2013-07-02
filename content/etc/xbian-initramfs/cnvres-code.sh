# part of code, which is relevant to block devices ... to keep init readable

up() {
echo "at initramfs/init $1: $(cat /proc/uptime)" >> /run/uptime_start.log
}

update_resolv() {
for f in `ls /run/net-*.conf`; do cat $f | grep IPV.DNS | tr -d "'"| awk -F'=' '{print "nameserver "$2}' > /etc/resolv.conf; done
for f in `ls /run/net-*.conf`; do cat $f | grep DOMAINSEARCH | tr -d "'"| awk -F'=' '{print "search "$2}' >> /etc/resolv.conf; done
for f in `ls /run/net-*.conf`; do cat $f | grep DNSDOMAIN | tr -d "'"| awk -F'=' '{print "domain "$2}' >> /etc/resolv.conf; done
}

update_interfaces() {
if [ "$1" = "rollback" ]; then
	test -e "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" && mv "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" "${CONFIG_newroot}/etc/network/interfaces"
	return
fi
#test "$CONFIG_ip" = "dhcp" || return

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
export CONFIG_roottxt=`echo "$CONFIG_root" | awk '$1 ~ /LABEL/ || $1 ~ /UUID/ {print $1}'`
[ -n "$CONFIG_roottxt" ] && { CONFIG_roottxt=`findfs $CONFIG_roottxt 2>/dev/null` || return 1; CONFIG_root="$CONFIG_roottxt"; }

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
				mount -t vfat "${DEV}${PARTdelim}1" /boot
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
	mount -t vfat "${DEV}${PARTdelim}1" /boot
	test -e /boot/config.txt.convert && mv /boot/config.txt.convert /boot/config.txt
	test "$FSCHECK" = "ext4" && sed -i "s/rootfstype=btrfs/rootfstype=ext4/g" /boot/cmdline.txt
	if [ "$FSCHECK" = "btrfs" ]; then
		test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="post conversion tasks..."
		/sbin/btrfs fi label ${CONFIG_root} xbian-root-btrfs
		mount -t btrfs -o compress=lzo,rw,noatime,autodefrag,space_cache,thread_pool=1 LABEL=xbian-root-btrfs $CONFIG_newroot
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
		echo "FATAL: only the last partition can be resized"
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
			mount -t ext4 ${CONFIG_root} "$CONFIG_newroot"
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

mount -n -o move /run $CONFIG_newroot/run
rm -fr /run
ln -s $CONFIG_newroot/run /run

udevadm control --exit
udev_root="/dev"
if [ -e /etc/udev/udev.conf ]; then
  . /etc/udev/udev.conf
fi

mount -n -o move /dev $CONFIG_newroot/dev
rm -fr /dev
ln -s $CONFIG_newroot/dev /dev
  
mount -n -o move /sys $CONFIG_newroot/sys
rmdir /sys
ln -s $CONFIG_newroot/sys /sys

mount -n -o move /proc $CONFIG_newroot/proc
rmdir /proc
ln -s $CONFIG_newroot/proc /proc
}

kill_splash() {
	test -n "$CONFIG_splash" && /bin/kill -SIGTERM $(pidof splash)
	rm -fr /run/splash
}

drop_shell() {
	kill_splash
	set +x
	if [ -e /bin/bash ]; then
		/bin/bash
	else 
		/bin/sh
	fi
	rm /run/do_drop
}
