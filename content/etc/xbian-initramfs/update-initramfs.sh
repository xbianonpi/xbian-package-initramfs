#!/bin/bash

. /etc/default/xbian-initramfs

test -e /run/trigger-xbian-update-initramfs && MODVER=$(cat /run/trigger-xbian-update-initramfs)
grep -q initramfs.gz /var/lib/dpkg/info/xbian-update.list && sed -i "/\(\/boot\/initramfs.gz\)/d" /var/lib/dpkg/info/xbian-update.list


if [ -z "$MODVER" ]; then
	test -z "$1" && MODVER=$(uname -r)
	test -z "$MODVER" && MODVER="$1"
fi

echo "Updating initramfs as requested by trigger. Kernel modules $MODVER."
mod_done=''
lib_done=''

copy_modules() {

        tlist="$1"
        for f in $tlist; do
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
                [ -z "$modname" ] && continue
                echo "copying module /lib/modules/$MODVER/$modname"
                cp -a --parents "/lib/modules/$MODVER/$modname" ./
                mod_done="$mod_done $modname "

                depends=$(grep "$modname:" "/lib/modules/$MODVER/modules.dep" | awk -F': ' '{print $2}')
                [ -z "$depends" ] && continue
                copy_modules "$depends"
        done

}

put_to_modules(){
    for m in $1; do
        echo "$(cat ./etc/modules 2>/dev/null)" | grep -qx $m  || echo $m >> ./etc/modules
	copy_modules $m
    done
}

copy_file() {
        cp -d -v --parents $3 "$1" "$2"
        test -h "$1" || return
        dr=$(dirname "$1")
        fl=$(readlink "$1")
        test -e "$fl" || fl="$dr/$fl"
        case $lib_done in
                *" $fl "*)
                        return 
                        ;;
                *)
                        cp -d -v --parents $3 "$fl" "$2" 
                        lib_done="$lib_done $fl"
                        ;;
        esac
}

copy_with_libs() {

        dst="$2"
        test -z "$dst" && dst="./"

        if [ -d "$1" ]; then
                cp -a --parents "$1"/* "$dst"
        fi

        if [ -f "$1" ]; then 
                copy_file "$1" "$dst"
                [ -x $1 ] || return 0
                oldIFS=$IFS
                IFS=$'\n'
                for fff in $(ldd $1 2>&1| cat ); do
                        echo "$fff" | grep "not a dynamic exec" && continue

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
trap "{ cd ..; { rm -fr '${TMPDIR}' & }; exit 0; }" INT TERM EXIT

mkdir bin dev etc lib proc rootfs run sbin sys tmp usr mnt var
cat << \EOF > ./.profile
alias rum='umount -a'
alias reb='umount -a; sync; reboot -f'
alias rch='chroot /rootfs'
EOF
ln -s /run ./var/run
mkdir usr/bin
mkdir etc/udhcpc etc/network etc/wpa_supplicant
mkdir etc/network/if-down.d etc/network/if-up.d etc/network/if-post-down.d etc/network/if-pre-up.d
mkdir lib/modules
mkdir -p usr/bin
mkdir -p usr/lib/arm-linux-gnueabihf
copy_with_libs /bin/busybox 
/bin/busybox --install -s bin/
cp -d --remove-destination --parents /etc/udev/* ./
cp -d --remove-destination --parents /etc/default/{tmpfs,rcS,xbian-rnd} ./

mkdir -p etc/udev/.dev
cp -d --remove-destination --parents /etc/modprobe.d/*.conf ./
#cp -d --remove-destination -av --parents /lib/modules/$MODVER/kernel/drivers/hid ./
cp -d --remove-destination -av --parents /lib/modules/$MODVER/kernel/drivers/scsi ./
cp -d --remove-destination -av --parents /lib/modules/$MODVER/kernel/drivers/usb/storage ./
cp --remove-destination -av --parents /lib/modules/$MODVER/modules.builtin ./
cp --remove-destination -av --parents /lib/modules/$MODVER/modules.order ./


cat /etc/modules | grep -v ^# | grep -v lirc_ >> ./etc/modules
copy_modules "ext4 usb_storage"
put_to_modules "nfs sunrpc rpcsec_gss_krb5 lz4 cfq-iosched"
copy_modules "$(cat ./etc/modules)"
echo "$(cat /etc/fstab) $(cat /etc/fstab.d/*)" | awk '{print $3}' | uniq | grep -v ^$ | grep 'nfs\|nfs4\|cifs' \
    | while read fstype; do
        case $fstype in
            nfs|nfs4)
                list="nfsv4 nfsv3 nfs sunrpc rpcsec_gss_krb5"
                copy_modules "$list"
                put_to_modules "$list"
                ;;
            cifs)
                list=cifs
                copy_modules "$list"
                put_to_modules "$list"
                ;;
        esac
    done
depmod -b ./ $MODVER

cp -d --remove-destination -a --parents /lib/klibc* ./

#copy_with_libs /usr/bin/whiptail ./
for f in $(find /usr/local/sbin -iname xbian\*); do
    copy_with_libs $f ./
done
#copy_with_libs /sbin/kexec ./
copy_with_libs /bin/mountpoint ./
copy_with_libs /sbin/udevd ./
copy_with_libs /sbin/udevadm ./
copy_with_libs /sbin/findfs
copy_with_libs /sbin/blkid 
copy_with_libs /sbin/sfdisk
copy_with_libs /sbin/tune2fs
copy_with_libs /sbin/e2fsck 
copy_with_libs /sbin/resize2fs 
copy_with_libs /bin/kmod
rm -fr ./bin/modprobe
copy_with_libs /sbin/modprobe
rm -fr ./bin/mount
rm -fr ./bin/date
copy_with_libs /bin/mount
copy_with_libs /bin/date
copy_with_libs /sbin/killall5
copy_with_libs /sbin/switch_root
copy_with_libs /sbin/rmmod
copy_with_libs /sbin/insmod
copy_with_libs /sbin/btrfs 
copy_with_libs /sbin/btrfs-convert 
copy_with_libs /usr/sbin/thd
copy_with_libs /usr/sbin/th-cmd
copy_with_libs /usr/bin/nice
#copy_with_libs /sbin/iwconfig 
#copy_with_libs /sbin/wpa_supplicant 
cp --remove-destination /usr/lib/klibc/bin/ipconfig ./bin
cp --remove-destination /usr/lib/klibc/bin/run-init ./sbin
cp --remove-destination /usr/lib/klibc/bin/kinit ./sbin
cp --remove-destination /usr/lib/klibc/bin/nuke ./sbin
cp --remove-destination /usr/lib/klibc/bin/nfsmount ./sbin

copy_with_libs /usr/bin/splash
mkdir -p ./usr/share/fonts/splash
mkdir -p ./usr/share/images/splash
cp -d --remove-destination -aR --parents /usr/share/fonts/splash ./
cp -d --remove-destination -aR --parents /usr/share/images/splash ./
cp -d --remove-destination --parents /usr/bin/splash.images ./
cp -d --remove-destination --parents /usr/bin/splash.fonts ./

cp -d --remove-destination -v --parents /lib/udev/{hotplug.functions,firmware.agent,ata_id,edd_id,scsi_id,vio_type,keymap,keyboard-force-release.sh,udev-acl} ./
#cp -d --remove-destination -v --parents -R /lib/udev/keymaps/* ./
cp -d --remove-destination -av --parents /lib/udev/rules.d/{50-udev-default.rules,60-persistent-storage.rules,80-drivers.rules,91-permissions.rules,60-persistent-storage-lvm.rules,60-persistent-input.rules,55-dm.rules,60-persistent-storage-dm.rules} ./
cp -d --remove-destination -av --parents /lib/udev/rules.d/{95-keymap.rules,95-keyboard-force-release.rules,70-btrfs.rules,10-local-xbian.rules} ./
#cat /lib/udev/findkeyboards | sed 's/--dry-run//g' > ./lib/udev/findkeyboards
#chmod +x ./lib/udev/findkeyboards

cp /etc/xbian-initramfs/init ./
grep . /etc/motd -m11 > ./motd
cp /etc/xbian-initramfs/trigg.shift ./
cp /etc/xbian-initramfs/bootmenu ./
cp /etc/xbian-initramfs/bootmenu_timeout ./
cp /etc/xbian-initramfs/cnvres-code.sh ./
cp /etc/xbian-initramfs/splash_updater.sh ./
copy_with_libs /usr/bin/stdbuf
copy_with_libs /usr/lib/coreutils/libstdbuf.so

need_umount=''
if ! mountpoint -q /boot; then
        mount /boot || { echo "FATAL: /boot can't be mounted"; exit 1; }
        need_umount="yes"
fi
test "$MAKEBACKUP" = "yes" && mv /boot/initramfs.gz /boot/initramfs.gz.old
echo "Creating initram fs."
#find . | cpio -H newc -o | xz --arm --check=none --lzma2 -1v --memlimit=25MiB > /boot/initramfs.gz
find . | cpio -H newc -o | gzip -1v > /boot/initramfs.gz
#find . | cpio -H newc -o | lzop > /boot/initramfs.gz
#if [ ! -e /boot.cfg ]; then
#        touch /boot.cfg
#        echo "name=Standard\ Xbian\ boot" >> /boot.cfg
#        echo "kernel=/kernel.img" >> /boot.cfg
#        echo "initrd=/initramfs.gz" >> /boot.cfg
#fi
[ "$need_umount" = "yes" ] && umount /boot

exit 0

