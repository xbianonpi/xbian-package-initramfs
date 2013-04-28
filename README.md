```

copy_file() {
        cp  -vd --parents "$1" "$2"
        test ! -h "$1" && return
        g=$(basename "$1")
        d=${1%$g}
        fl=$(ls -la $f | awk '{print $11}')
        rm -f ".$d/$fl"
        cp -v --parents  "$d$fl" "$2"
}

copy_with_libs() {
    
        dst="$2"
        test -z "$dst" && dst="./"

        if [ -d "$1" ]; then
                cp -va --parents "$1"/* "$dst"
        fi
        
        if [ -f "$1" ]; then 
                copy_file "$1" "$dst"
                oldIFS=$IFS
                IFS=$'\n'
                for fff in $(ldd $1 | cat ); do
                        echo "$fff" | grep "not a dynamic exec"
                        rc="$?"
                        test $rc -eq 0 && continue

                        f1=$(echo "$fff" | awk '{print $1}')
                        f2=$(echo "$fff" | awk '{print $3}')
                        f3=$(echo "$fff" | awk '{print $4}')
                        if [ "$f3" = "" ]; then
                                f=$f1
                        else
                                f=$f2
                        fi
                        copy_file "$f" "$dst"
                done
                IFS=$oldIFS
        fi
}


cd /opt/
mkdir initramfs
cd initramfs

apt-get install fakeroot busybox udhcpc udev makedev parted btrfs-tools klibc-utils ethtool build-essential

fakeroot
mkdir bin dev etc lib proc rootfs run sbin sys tmp usr
mkdir usr/bin
mkdir etc/udhcpc etc/network etc/wpa_supplicant
mkdir etc/network/if-down.d etc/network/if-up.d etc/network/if-post-down.d etc/network/if-pre-up.d
mkdir lib/modules
mkdir -p usr/bin
mkdir -p usr/lib/arm-linux-gnueabihf
cp -d --remove-destination /bin/busybox bin/
/bin/busybox --install -s bin/
cp -d --remove-destination /etc/udhcpc/default.script etc/udhcpc/
cp -d --remove-destination -R /etc/network etc/
cp -d --remove-destination -R /etc/hostname etc/
cp -d --remove-destination -R /etc/wpa_supplicant etc/
cp -d --remove-destination -R /etc/udev etc/
cp -d --remove-destination -R /etc/fstab etc/
sed -i 's/\/etc\/resolv.conf/\/rootfs\/etc\/resolv.conf/g' etc/udhcpc/default.script
touch etc/mdev.conf
cp -d --remove-destination /etc/modules etc/
cp -d --remove-destination -av --parents /etc/default ./
copy_with_libs /lib/init
copy_with_libs /lib/lsb
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/fs ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/lib ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/usb ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/scsi ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/net ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/hid ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/block ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/modules.builtin ./
cp -d --remove-destination -av --parents /lib/modules/$(uname -r)/modules.order ./
cp -d --remove-destination -av --parents /lib/firmware ./
depmod -ab ./

cp -d --remove-destination -a --parents /lib/klibc* ./

copy_with_libs /sbin/rmmod ./
copy_with_libs /sbin/insmod ./
copy_with_libs /sbin/modprobe ./
copy_with_libs /sbin/udevd ./
copy_with_libs /sbin/udevadm ./
copy_with_libs /bin/kmod ./
copy_with_libs /sbin/fdisk
copy_with_libs /sbin/findfs
copy_with_libs /sbin/blkid 
copy_with_libs /sbin/MAKEDEV 
copy_with_libs /sbin/sfdisk
copy_with_libs /sbin/tune2fs
copy_with_libs /sbin/e2fsck 
copy_with_libs /sbin/resize2fs 
copy_with_libs /sbin/btrfs 
copy_with_libs /sbin/btrfs-convert 
copy_with_libs /sbin/ethtool 
copy_with_libs /sbin/iwconfig 
copy_with_libs /sbin/wpa_supplicant 
copy_with_libs /sbin/partprobe 
cp --remove-destination /usr/lib/klibc/bin/ipconfig ./bin
cp --remove-destination /usr/lib/klibc/bin/run-init ./sbin

copy_with_libs /usr/bin/splash
mkdir -p ./usr/share/fonts/splash
mkdir -p ./usr/share/images/splash
cp -d --remove-destination -aR --parents /usr/share/fonts/splash ./
cp -d --remove-destination -aR --parents /usr/share/images/splash ./
cp -d --remove-destination --parents /usr/bin/splash.images ./
cp -d --remove-destination --parents /usr/bin/splash.fonts ./

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/key.c > /home/xbian/key.c
cc -o usr/bin/key /home/xbian/key.c

cp -d --remove-destination -arv --parents /lib/udev/*_id ./
cp -d --remove-destination -arv --parents /lib/udev/{mtd_probe,net.agent,keyboard-force-release.sh,findkeyboards,keymaps} ./
cp -d --remove-destination -arv --parents /lib/udev/rules.d/{75-probe_mtd.rules,99-local-xbian.rules,95-keymap.rules,95-keyboard-force-release.rules,80-networking.rules,80-drivers.rules,60-persistent-input.rules,42-qemu-usb.rules,10-local-rpi.rules,60-persistent-storage.rules} ./
cp -d --remove-destination -arv --parents /lib/udev/rules.d/70-btrfs.rules ./

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/init > init
wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/cnvres-code.sh > cnvres-code.sh
chmod a+x init

cat /etc/modules | grep -i evdev || echo evdev >> ./etc/modules

find . | cpio -H newc -o | gzip -9v > /boot/initramfs.gz
```
