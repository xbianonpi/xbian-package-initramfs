#!/bin/bash

NP=/run/$$.pipe
mknod $NP p
tee <$NP /tmp/$(basename $0).log &
exec 1>$NP 2>/dev/null

if [ ! -e /usr/local/bin/busybox ]; then
    [ ! -e /bin/busybox ] && exit 99
    cp /bin/busybox /usr/local/bin/busybox
fi
if [ ! -e /etc/xbian_version ]; then
    sed -i 's/ --startup-event mountall//g' /boot/boot.scr.txt
fi

. /etc/default/xbian-initramfs

case "$(xbian-arch)" in
    RPI)  bootfile=/boot/cmdline.txt ;;
    *)    bootfile=/boot/boot.scr.txt; "INCLUDEFILES=/usr/bin/mkimage $INCLUDEFILES" ;;
esac

rootfs="$(findmnt / -no FSTYPE)"

test -e /run/trigger-xbian-update-initramfs && MODVER=$(cat /run/trigger-xbian-update-initramfs)
grep -q initramfs.gz /var/lib/dpkg/info/xbian-update.list && sed -i "/\(\/boot\/initramfs.gz\)/d" /var/lib/dpkg/info/xbian-update.list


if [ -z "$MODVER" ]; then
	test -z "$1" && MODVER="$(dpkg -l | awk '/^[hi]i.*(linux-image-[ab]|xbian-package-kernel)/{v=$3;sub("-.*","",v);sub("~","-",v);print v}')"
	test -z "$MODVER" && MODVER="$1"
fi

LOCALVERSIONS='-v8 -64'
MODVERSIONS=$MODVER
for LVER in $LOCALVERSIONS; do
	if [ -z "${MODVER##*$LVER*}" ]; then
		MODVER2="$(echo $MODVER | sed "s/$LVER//g")"
		if [ -d "/lib/modules/$MODVER2" ]; then
			MODVERSIONS="$MODVER $MODVER2"
		fi
	fi
done

for MODVER in $MODVERSIONS; do
	depmod -a $MODVER
done

echo "Updating initramfs as requested by trigger. Kernel modules $MODVERSIONS."
mod_done=''
lib_done=''

copy_moddeps() {
	for f in $1; do
		f=$(basename $f)
		f="${f%'.ko'}.ko"
		case $mod_done in
			*"/$f "*)
				continue
				;;
			*)
				;;
		esac
		modname=$(find /lib/modules/$MODVER -iname $f -printf '%P')
		[ -z "$modname" ] && modname=$(find /lib/modules/$MODVER -iname $(echo $f | tr '_' '-') -printf '%P')
		[ -z "$modname" ] && continue
		echo "copying module /lib/modules/$MODVER/$modname"
		cp -a --parents "/lib/modules/$MODVER/$modname" ./
		mod_done="$mod_done $modname "
		depends=$(grep "$modname:" "/lib/modules/$MODVER/modules.dep" | awk -F': ' '{print $2}')
		[ -z "$depends" ] && continue
		copy_moddeps "$depends"
	done
}

copy_modules() {
	mod_done_g=$mod_done
	for MODVER in $MODVERSIONS; do
		mod_done=$mod_done_g
		copy_moddeps "$1"
	done
}

put_to_modules(){
    for m in $1; do
        grep -qsx $m ./etc/modules || echo $m >> ./etc/modules
        copy_modules $m
    done
}

copy_file() {
        cp -d --remove-destination -v --parents $3 "$1" "$2"
        test -h "$1" || return
        dr=$(dirname "$1")
        fl=$(readlink "$1")
        test -e "$fl" || fl="$dr/$fl"
        case $lib_done in
                *" $fl "*)
                        echo "again $fl" >&2
                        return 
                        ;;
                *)
                        cp -d -v --remove-destination --parents $3 "$fl" "$2" 
                        lib_done="$lib_done $fl"
                        ;;
        esac
}

copy_with_libs() {

        dst="$2"
        test -z "$dst" && dst="./"

        [ -h "$dst" ] && rm "$dst"

        if [ -d "$1" ]; then
                cp -a --parents "$1"/* "$dst"
                return 0
        fi


        if [ -f "$1" ]; then 
                copy_file "$1" "$dst"
                [ -x $1 ] || return 0
                oldIFS=$IFS
                IFS=$'\n'
                for fff in $(ldd $1 2>&1| cat ); do
                        echo "$fff" | grep -q "not a dynamic exec" && continue

                        f1=$(echo "$fff" | awk '{print $1}')
                        f2=$(echo "$fff" | awk '{print $3}')
                        f3=$(echo "$fff" | awk '{print $4}')
                        if [ "$f3" = "" ]; then
                                f=$f1
                        else
                                f=$f2
                        fi
                        copy_file "$f" "$dst" "-n"
                        [ -e "$f1" ] && copy_file "$f1" "$dst" "-n"
                done
                IFS=$oldIFS
        fi
}

TMPDIR=$(mktemp -d)
cd $TMPDIR
trap "{ cd ..; { rm -fr '${TMPDIR}' & }; [ "$need_umount" = "yes" ] && umount /boot; rm -f $NP /run/initramfs.gz; exit 0; }" INT TERM EXIT

need_umount=''
if ! mountpoint -q /boot; then
        mount /boot || { echo "FATAL: /boot can't be mounted"; exit 1; }
        need_umount="yes"
fi
echo initramfs-tools >> /run/reboot-required

[ "$(dpkg --print-architecture)" = arm64 ] && ARMLIB=aarch64-linux-gnu || ARMLIB=arm-linux-gnueabihf

mkdir -p bin dev etc/network etc/wpa_supplicant etc/network/if-down.d etc/network/if-up.d etc/network/if-post-down.d etc/network/if-pre-up.d \
    lib/modules mnt proc rootfs run sbin sys tmp usr/bin usr/lib/${ARMLIB} var

cat << \EOF > ./.profile
export PS1='\w # '
export FTYPES=ext2,ext4,btrfs,zfs,f2fs
alias rum='umount -alt $FTYPES'
alias reb='umount -alt $FTYPES; sync; echo b >/proc/sysrq-trigger'
alias rch='chroot /rootfs /bin/bash'
EOF
cp .profile .bashrc
ln -s /run ./var/run

copy_with_libs /usr/local/bin/busybox
/usr/local/bin/busybox --install -s $(readlink -f ./bin)
( cd ./bin; ln -s /usr/local/bin/busybox ./; cd ./sbin; ln -s /usr/local/bin/busybox udhcpc; ln -s /usr/local/bin/busybox udhcpc6; )

cp -d --remove-destination --parents /etc/udev/* ./
cp -d --remove-destination --parents /etc/default/{tmpfs,rcS,xbian-rnd} ./

mkdir -p etc/udev/.dev
cp -d --remove-destination --parents /etc/modprobe.d/*.conf ./
cp -d --remove-destination /etc/xbian-initramfs/blacklist.conf ./etc/modprobe.d
for MODVER in $MODVERSIONS; do
    #cp -d --remove-destination -av --parents /lib/modules/$MODVER/kernel/drivers/hid ./
    cp -d --remove-destination -av --parents /lib/modules/$MODVER/kernel/drivers/scsi ./
    cp -d --remove-destination -av --parents /lib/modules/$MODVER/kernel/drivers/usb/storage ./
    cp -d --remove-destination -av --parents /lib/modules/$MODVER/modules.builtin ./
    cp --remove-destination -av --parents /lib/modules/$MODVER/modules.order ./
done
cp /etc/xbian_version ./etc/
cp /etc/resolv.conf ./etc/
cp /etc/nsswitch.conf ./etc/
cp /etc/passwd ./etc/

grep -sv ^'#' /etc/modules | grep -v lirc_ >> ./etc/modules

copy_modules "usb_storage vchiq phy-generic $INCLUDEMODULES"
put_to_modules "lz4 cfq-iosched ext4 f2fs evdev"
copy_modules "$(cat ./etc/modules)"
grep -shv ^'#' {/etc/fstab,/etc/fstab.d/*} | awk '/(nfs|nfs4|cifs)/{print $3}' | sort -u \
    | while read fstype; do
        case $fstype in
            nfs|nfs4)
                put_to_modules "nfsv4 nfsv3 nfs sunrpc rpcsec_gss_krb5"
                ;;
            cifs)
                put_to_modules "cifs"
                ;;
        esac
    done

## lvm
if [ "$LVM" = "yes" ] && [ -e /sbin/lvm ]; then
   if [ -e /etc/lvm/lvm.conf ]; then
	mkdir -p ./etc/lvm
	cp /etc/lvm/lvm.conf ./etc/lvm/
   fi

   mkdir -p ./lib/udev/rules.d/
   for rules in 56-lvm.rules 60-persistent-storage-lvm.rules; do
        if   [ -e /etc/udev/rules.d/$rules ]; then
                cp -p /etc/udev/rules.d/$rules ./lib/udev/rules.d/
        elif [ -e /lib/udev/rules.d/$rules ]; then
                cp -p /lib/udev/rules.d/$rules ./lib/udev/rules.d/
        fi
   done

   copy_with_libs /sbin/dmsetup
   copy_with_libs /sbin/lvm
   ln -s lvm ./sbin/vgchange

   copy_modules "dm-mod"
fi
### end lvm

cp -d --remove-destination -a --parents /lib/klibc* ./

for f in /usr/local/sbin/{xbian-hwrng,xbian-frandom,xbian-arch} /lib/${ARMLIB}/libresolv.so* /lib/${ARMLIB}/libnss_dns.so* /lib/${ARMLIB}/libnss_compat.so* /lib/${ARMLIB}/libnsl.so*; do
    copy_with_libs $f ./
done
#copy_with_libs /bin/bash ./
#copy_with_libs /bin/dash ./
#copy_with_libs /bin/sh ./
copy_with_libs /sbin/udevd ./
copy_with_libs /sbin/udevadm ./
copy_with_libs /lib/systemd/systemd-udevd ./

for f in lsmod rmmod insmod modprobe ip; do
    ln -s /bin/$f ./sbin/$f
done

copy_with_libs /usr/sbin/thd
copy_with_libs /lib/terminfo

cp --parents /usr/share/consolefonts/Lat2-Fixed16.psf.gz ./

copy_with_libs /usr/bin/splash
sed -i "s%\$sdc /bin/fuser -s 9999/tcp%pgrep splash-daemon >/dev/null%g" ./usr/bin/splash
copy_with_libs /sbin/parted
copy_with_libs /sbin/partprobe
cp -d --remove-destination --parents /etc/default/template.json ./
cp -d --remove-destination -aR --parents /usr/local/lib/splash ./
copy_with_libs /usr/local/bin/splash-send
if [ -e /usr/local/sbin/splash-daemon-static ]; then
    copy_with_libs /usr/local/sbin/splash-daemon-static
    mv ./usr/local/sbin/splash-daemon-static ./usr/local/sbin/splash-daemon
else
    copy_with_libs /usr/local/sbin/splash-daemon
fi

cat << \EOF > ./sbin/initctl
#!/bin/sh
true
EOF
chmod +x ./sbin/initctl

copy_with_libs /usr/local/bin/modes-cubox
cp -d --remove-destination -v --parents /lib/udev/{hotplug.functions,firmware.agent,ata_id,edd_id,scsi_id,vio_type,keymap,keyboard-force-release.sh,udev-acl} ./
#cp -d --remove-destination -v --parents -R /lib/udev/keymaps/* ./
cp -d --remove-destination -av --parents /lib/udev/rules.d/{50-udev-default.rules,60-persistent-storage.rules,80-drivers.rules,91-permissions.rules,60-persistent-storage-lvm.rules,60-persistent-input.rules,55-dm.rules,60-persistent-storage-dm.rules} ./
cp -d --remove-destination -av --parents /lib/udev/rules.d/{95-keymap.rules,95-keyboard-force-release.rules,??-local-xbian.rules} ./
#cat /lib/udev/findkeyboards | sed 's/--dry-run//g' > ./lib/udev/findkeyboards
#chmod +x ./lib/udev/findkeyboards

for fw in $INCLUDEFILES; do for f in "$fw"; do copy_with_libs "$f"; done; done
grep -v ^# /etc/fstab | grep /boot > ./etc/fstab

cp /etc/group ./etc

cp /etc/xbian-initramfs/init ./
grep . /etc/motd -m10 > ./motd
cp /etc/xbian-initramfs/howto.txt ./

cp /etc/xbian-initramfs/trigg.shift ./
cp /etc/xbian-initramfs/cnvres-code.sh ./
cp /etc/xbian-initramfs/splash_updater.sh ./

copy_with_libs /usr/bin/mkimage

##
# Include BOOTMENU stuff (optional)
##
if [ "$BOOTMENU" = yes ] || ( grep -q bootmenu $bootfile && [ "$BOOTMENU" != no ] ); then
    cp /etc/xbian-initramfs/bootmenu ./
    cp /etc/xbian-initramfs/bootmenu_timeout ./
    copy_with_libs /sbin/blkid
    copy_with_libs /usr/bin/whiptail ./
    copy_with_libs /usr/bin/setterm
    copy_with_libs /sbin/kexec ./
    copy_with_libs /sbin/killall5
fi

##
# Include VNC stuff (optional)
##
if [ "$VNC" = yes ] || ( grep -q vnc $bootfile && [ "$VNC" != no ] ); then
    case "$(xbian-arch)" in
        RPI)  copy_with_libs /usr/local/sbin/rpi-vncserver; mv ./usr/local/sbin/rpi-vncserver ./usr/local/sbin/vncserver ;;
        iMX6) copy_with_libs /usr/local/sbin/imx-vncserver; mv ./usr/local/sbin/imx-vncserver ./usr/local/sbin/vncserver ;;
    esac
    if [ -e ./usr/local/sbin/vncserver ]; then
        copy_with_libs /sbin/ldconfig
        cp --parents /etc/ld.so.conf.d/*xbian-firmware.conf ./
        cp --parents /etc/ld.so.conf ./
        chroot ./ /sbin/ldconfig
        rm -f ./sbin/ldconfig
        cp --parents /etc/default/vnc-server ./
        if [ -e ./etc/default/vnc-server ]; then
            . ./etc/default/vnc-server
            if ! echo "$OPTIONS" | grep -q "\-p"; then
                dpkg --compare-versions "$(dpkg -l | grep "xbian-package-xbmc " | awk '{print $3}')" ge "18" && OPTIONS="-p rel $OPTIONS"
                sed -i "s/^OPTIONS=.*/OPTIONS=\"$OPTIONS\"/g" ./etc/default/vnc-server
                cat ./etc/default/vnc-server >&2
            fi
        fi
    fi
fi

##
# Include iSCSI stuff (optional)
##
if [ "$iSCSI" = yes ] || grep -q "root=iSCSI=" $bootfile; then
    copy_modules "iscsi_tcp"
    copy_with_libs /sbin/iscsid
    copy_with_libs /usr/bin/iscsiadm

    cp --parents /etc/iscsi/* ./
fi

##
# Include (W)LAN stuff (optional)
##
if grep -q "ip=" $bootfile; then
    for f in /sys/class/net/eth*; do
        dev=$(basename $f)
        driver=$(readlink $f/device/driver/module)
        if [ $driver ]; then
            driver=$(basename $driver)
            if modinfo -k $MODVER $driver >/dev/null && grep -q "ip=.*$dev" $bootfile; then
                sed -i "s/ip=/cnet=/g" $bootfile
                break
            fi
        fi
    done
fi
if [ "$LAN" = yes ] || grep -qwE "wlan[0-9]|ra[0-9]|br[0-9]|bond[0-9]|cnet" $bootfile; then
    add_modules() {
        grep -q ^$(echo $1 | tr '-' '_') /{etc,proc}/modules && put_to_modules $1
    }
    copy_with_libs /sbin/wpa_supplicant
    copy_with_libs /sbin/wpa_cli
    cp -a /etc/wpa_supplicant ./etc
    if [ -e /etc/network/interfaces ] && grep -qm1 ^"[ \t]*wpa-ssid" /etc/network/interfaces && grep -qm1 ^"[ \t]*wpa-psk" /etc/network/interfaces; then
        SSID=$(grep -m1 ^"[ \t]*wpa-ssid" /etc/network/interfaces | awk '{print $2}')
        PSK=$(grep -m1 ^"[ \t]*wpa-psk" /etc/network/interfaces | awk '{print $2}')
        cat << \EOF > ./etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1

network={
        ssid="__SSID__"
        proto=RSN
        key_mgmt=WPA-PSK
        psk="__PSK__"
}
EOF
        sed -i "s/__SSID__/$SSID/;s/__PSK__/$PSK/;s/GROUP=netdev/GROUP=$(getent group netdev | awk -F: '{print $3}')/" ./etc/wpa_supplicant/wpa_supplicant.conf
    else
        sed -i "s/GROUP=netdev/GROUP=$(getent group netdev | awk -F: '{print $3}')/" ./etc/wpa_supplicant/wpa_supplicant.conf
    #    sed -i "/^\(ctrl_interface\|update_config\)/s/^\(.*\)/#\1/g" ./etc/wpa_supplicant/wpa_supplicant.conf || :
    fi
    put_to_modules "smsc95xx lan78xx genet"
    if add_modules brcmfmac; then
        put_to_modules "brcmfmac-wcc brcmfmac-cyw brcmfmac-bca"
        for f in /lib/firmware/brcm/brcmfmac434{30,36,55}-sdio*.* /lib/firmware/brcm/brcmfmac4330-sdio.*; do copy_with_libs $f; done
        for f in /lib/firmware/cypress/cyfmac434{30,36,55}-sdio*.* /lib/firmware/cypress/cyfmac4330-sdio.*; do copy_with_libs $f; done
    fi
    add_modules mt7601u     && copy_with_libs /lib/firmware/mt7601u.bin
    add_modules mt7610u_sta && copy_with_libs /etc/Wireless
    add_modules mt76x0      && copy_with_libs /lib/firmware/mediatek/mt7610u.bin
    add_modules mt76x0u     && for f in /lib/firmware/mediatek/mt7610*.bin; do copy_with_libs $f; done
    add_modules mt76x2u     && for f in /lib/firmware/mediatek/mt7662u*.bin; do copy_with_libs $f; done
    add_modules rtl8192cu   && { for f in /lib/firmware/rtlwifi/rtl8192cufw*.bin; do copy_with_libs $f; done; copy_with_libs /etc/modprobe.d/rtl8192cu.conf; }
    add_modules rtl8xxxu    && { for f in /lib/firmware/rtlwifi/rtl8*u*.bin; do copy_with_libs $f; done; copy_with_libs /etc/modprobe.d/rtl8xxxu.conf; }
    add_modules 8192cu      && copy_with_libs /etc/modprobe.d/8192cu.conf
    add_modules 8192eu      && copy_with_libs /etc/modprobe.d/8192eu.conf
    add_modules rt2800usb   && copy_with_libs /lib/firmware/rt2870.bin

    cp --parents /lib/firmware/regulatory.db{.p7s,} ./
    cp --parents /etc/xbian-udhcpc/xbian-udhcpc ./
    cp -d /etc/network/if-down.d/wpasupplicant ./etc/network/if-down.d
    cp -d /etc/network/if-post-down.d/wpasupplicant ./etc/network/if-post-down.d
    cp -d /etc/network/if-pre-up.d/wpasupplicant ./etc/network/if-pre-up.d
    cp -d /etc/network/if-up.d/wpasupplicant ./etc/network/if-up.d

    if grep -q "cnet=.*br[0-9]" $bootfile; then
        put_to_modules "bridge"
        #copy_with_libs /sbin/brctl
        #cp --parents /lib/bridge-utils/ifupdown.sh ./
        #cp --parents /lib/bridge-utils/bridge-utils.sh ./
        #cp -d /etc/network/if-pre-up.d/bridge ./etc/network/if-pre-up.d
        #cp -d /etc/network/if-post-down.d/bridge ./etc/network/if-post-down.d
    fi
    if grep -q "cnet=.*bond[0-9]" $bootfile; then
        put_to_modules "bonding"
        [ -e /etc/modprobe.d/bonding.conf ] || echo "options bonding mode=1 miimon=100 updelay=200 downdelay=200" > /etc/modprobe.d/bonding.conf
        cp --parents /etc/modprobe.d/bonding.conf ./
        cp -r /etc/xbian-initramfs/network ./etc/
    fi

    copy_with_libs /sbin/ethtool
else
    #cp --remove-destination /usr/lib/klibc/bin/kinit ./sbin	# FIXME: Do we really need this?
    cp --remove-destination /usr/lib/klibc/bin/ipconfig ./bin
    #cp --remove-destination /usr/lib/klibc/bin/nfsmount ./sbin	# FIXME: Do we really need this?
fi

##
# Include EXT fs tools (optional)
##
if [ "$EXTFS" = yes ] || [ -z "$rootfs" ] || [[ "$rootfs" =~ ext ]]; then
    copy_with_libs /sbin/tune2fs
    copy_with_libs /sbin/e2fsck
    copy_with_libs /sbin/resize2fs
    copy_with_libs /usr/bin/stdbuf
    copy_with_libs /usr/lib/${ARMLIB}/coreutils/libstdbuf.so
    copy_with_libs `which btrfs-convert`
fi

##
# Include BTRFS fs tools (optional)
##
if [ "$BTRFS" = yes ] || [ -z "$rootfs" ] || [[ "$rootfs" =~ btrfs ]]; then
    copy_with_libs `which btrfs`
fi

##
# Include ZFS stuff (optional)
##
if [ "$ZFS" = yes ] || grep -q  "root=ZFS=" $bootfile || grep -q ^zfs /{etc,proc}/modules || [[ "$rootfs" =~ zfs ]]; then
    mkdir -p ./lib/udev/rules.d/
    for rules in 60-zvol.rules 69-vdev.rules 90-zfs.rules; do
         if   [ -e /etc/udev/rules.d/$rules ]; then
             cp -p /etc/udev/rules.d/$rules ./lib/udev/rules.d/
         elif [ -e /lib/udev/rules.d/$rules ]; then
             cp -p /lib/udev/rules.d/$rules ./lib/udev/rules.d/
         fi
    done

    put_to_modules "zfs"

    copy_with_libs /lib/udev/vdev_id
    copy_with_libs /lib/udev/zvol_id

    copy_with_libs `which getconf`
    copy_with_libs `which zpool`
    copy_with_libs `which zfs`
    copy_with_libs `which mount.zfs`
    copy_with_libs /etc/zfs/zpool.cache
    copy_with_libs /etc/modprobe.d/zfs.conf
fi

##
# Include Video drivers (optional)
##
mv /run/reboot-required /run/reboot-required.save
if [ "$VIDEO" == yes ] || ( [ "$(/etc/xbian-initramfs/initram.switcher.sh update)" == yes ] && [ "$VIDEO" != no ] ); then
    copy_modules "vc4 v3d rpivid-hevc snd_soc_hdmi_codec"
fi
mv /run/reboot-required.save /run/reboot-required

for MODVER in $MODVERSIONS; do
	depmod -b ./ $MODVER
done

if [ "$MAKEBACKUP" = "yes" ]; then
    test -e /boot/initramfs.gz && mv /boot/initramfs.gz /boot/initramfs.gz.old
    test -e /boot/initramfs.gz.notinuse && mv /boot/initramfs.gz.notinuse /boot/initramfs.gz.old
else
    rm -f /boot/initramfs.gz.notinuse /boot/initramfs.gz.old
fi

create_initram() {
    modprobe -q configs
    case "$COMPRESS" in
        xz)         zcat /proc/config.gz | grep -q CONFIG_RD_XZ=y && find . | cpio -H newc -o | xz -cz --threads=0 --check=crc32 > $1 ;;
        lzma)       zcat /proc/config.gz | grep -q CONFIG_RD_LZMA=y && find . | cpio -H newc -o | lzma -cz --threads=0 --check=crc32 > $1 ;;
        lz4)        zcat /proc/config.gz | grep -q CONFIG_RD_LZ4=y && find . | cpio -H newc -o | lz4 -cl > $1 ;;
        bz2|bzip2)  zcat /proc/config.gz | grep -q CONFIG_RD_BZIP2=y && find . | cpio -H newc -o | bzip2 > $1 COMPRESS=bzip2 ;;
        *)          find . | cpio -H newc -o | gzip > $1; COMPRESS=gzip ;;
    esac
}

echo "Creating initram image /boot/initramfs.gz"
if ! create_initram /run/initramfs.gz; then
    COMPRESS=gzip
    create_initram /run/initramfs.gz
fi
if [ $? = 0 ]; then
    if [ "$(xbian-arch)" = RPI ]; then
        mv /run/initramfs.gz /boot
    else
        mkimage -O linux -A arm -T ramdisk -C $COMPRESS -d /run/initramfs.gz /boot/initramfs.gz && mks
    fi
    RC=$?
else
    echo "FATAL: can not create initram image /boot/initramfs.gz"
    RC=1
fi

sync

exit $RC

