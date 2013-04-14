# part of code, which is relevant to block devices ... to keep init readable

get_root() {
export DEV="${CONFIG_root%[0-9]}"
if [ ! -e ${DEV} ]; then
	export DEV=${DEV%p}
	export PARTdelim='p'
else
	export PARTdelim=''
fi
export PART=${CONFIG_root#${CONFIG_root%?}}
}

convert_btrfs() {
FSCHECK=`blkid -s TYPE -o value -p ${CONFIG_root} `
# Check for the existance of tune2fs through the RESIZEERROR variable
if [ "$RESIZEERROR" -eq '0' -a "$CONFIG_noconvertsd" -eq '0' -a "${CONFIG_rootfstype}" = "btrfs" -a "$FSCHECK" != "btrfs" ]; then

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
		e2fsck -y ${CONFIG_root}
		btrfs-convert ${CONFIG_root}
		FSCHECK=`blkid -s TYPE -o value -p ${CONFIG_root} `
	fi
	
	test ! -d /boot && mkdir /boot
	mount -t vfat "${DEV}${PARTdelim}1" /boot
	test -e /boot/config.txt.convert && mv /boot/config.txt.convert /boot/config.txt
	test "$FSCHECK" = "ext4" && sed -i "s/rootfstype=btrfs/rootfstype=ext4/g" /boot/cmdline.txt
	if [ "$FSCHECK" = "btrfs" ]; then
		/sbin/btrfs fi label ${CONFIG_root} xbian-root-btrfs
		mount -t btrfs -o compress=lzo,rw,noatime,relatime LABEL=xbian-root-btrfs /rootfs
		/sbin/btrfs sub delete /rootfs/ext2_saved

		/sbin/btrfs sub create /rootfs/HOME
		mkdir -p /rootfs/HOME/.btrfs/snapshot
		mv /rootfs/home/* /rootfs/HOME
		/sbin/btrfs sub snapshot /rootfs/HOME /rootfs/HOME/.btrfs/snapshot/@running
		/sbin/btrfs sub snapshot /rootfs/HOME/.btrfs/snapshot/@running /rootfs/HOME/.btrfs/snapshot/@safe
		printf "\nLABEL=xbian-root-btrfs\t/home\tbtrfs\tsubvol=HOME/.btrfs/snapshot/@running\t0\t0\n" >> /rootfs/etc/fstab

		mkdir -p /rootfs/.btrfs/snapshot
		/sbin/btrfs sub snapshot /rootfs /rootfs/.btrfs/snapshot/@running
		btrfsDEF=`btrfs sub list /rootfs | grep -v HOME | grep @running | awk '{print $2}'`
		/sbin/btrfs sub set-default "$btrfsDEF" /rootfs
		/sbin/btrfs sub snapshot /rootfs/.btrfs/snapshot/@running /rootfs/.btrfs/snapshot/@safe

		umount /rootfs
	fi
	umount /boot
	sync
	reboot -f
fi
}

resize_part() {
if [ "$RESIZEERROR" -eq '0' -a "$CONFIG_noresizesd" -eq '0' -a "${CONFIG_rootfstype}" != "nfs" ]; then
	
	#Save partition table to file
	/sbin/sfdisk -u S -d ${DEV} > /tmp/part.txt
	#Read partition sizes
	sectorTOTAL=`/sbin/fdisk -u sectors -l ${DEV} | grep total | awk '{printf "%s", $8}'`
	sectorSTART=`grep ${CONFIG_root} /tmp/part.txt | awk '{printf "%d", $4}'`
	sectorSIZE=`grep ${CONFIG_root} /tmp/part.txt | awk '{printf "%d", $6}'`
	sectorNEW=$(( $sectorTOTAL - $sectorSTART ))
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
		echo ",${sectorNEW},,," | sfdisk -uS -N${PART} --force --no-reread -q ${DEV}
		/sbin/partprobe || true
		nSIZE=`sfdisk -s ${CONFIG_root} | awk -F'\n' '{ sum += $1 } END {print sum}'`

		if [ ! $nSIZE -gt $pSIZE ]; then
			RESIZERROR="1"
		fi
	fi
fi
}

resize_ext4() {
if [ "$RESIZEERROR" -eq "0" -a "$CONFIG_noresizesd" -eq '0' -a "$CONFIG_rootfstype" = "ext4" ]; then

	if [ "${FSCHECK}" = 'ext4' ]; then
		# check if the partition needs resizing
		TUNE2FS=`/sbin/tune2fs -l ${CONFIG_root}`;
		TUNEBLOCKSIZE=`echo -e "${TUNE2FS}" | grep "Block size" | awk '{printf "%d", $3}'`;
		TUNEBLOCKCOUNT=`echo -e "${TUNE2FS}" | grep "Block count" | awk '{printf "%d", $3}'`;
		BLOCKNEW=$(($sectorNEW / ($TUNEBLOCKSIZE / 512) ))

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
			TUNEBLOCKCOUNT=`/sbin/resize2fs ${CONFIG_root} | grep now | rev | awk '{print $3}' | rev`

			# check if parition was actually resized
			if [ ${TUNEBLOCKCOUNT} -lt ${BLOCKNEW} ]; then
				RESIZEERROR="1"
			fi
		fi
	fi
fi
}

resize_btrfs() {
if [ "$RESIZEERROR" -eq "0" -a "$CONFIG_noresizesd" -eq '0' -a "$CONFIG_rootfstype" = "btrfs" -a "$FSCHECK" = 'btrfs' ]; then

	# check if the partition needs resizing
	sectorDF=`df -B512 -P | grep "/rootfs" | awk '{printf "%d", $2}'`
	
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
		/sbin/btrfs fi resize max /rootfs
		
		sectorDF=`df -B512 -P | grep "/rootfs" | awk '{printf "%d", $2}'`

		# check if parition was actually resized
		if [ "$sectorDF" -lt "$sectorNEW" ]; then
			RESIZEERROR="1"
		fi
	fi
fi
}
