```
cd /opt/
mkdir initramfs
cd initramfs

apt-get install fakeroot busybox udhcpc udev makedev parted btrfs-tools

fakeroot
mkdir bin dev etc lib proc rootfs run sbin sys tmp usr
mkdir usr/bin
mkdir etc/udhcpc etc/network etc/wpa_supplicant
mkdir etc/network/if-down.d etc/network/if-up.d etc/network/if-post-down.d etc/network/if-pre-up.d
mkdir lib/modules
mkdir run/network
mkdir -p usr/bin
mkdir -p usr/lib/arm-linux-gnueabihf
cp --remove-destination /bin/busybox bin/
/bin/busybox --install -s bin
cp --remove-destination /etc/udhcpc/default.script etc/udhcpc/
cp --remove-destination -R /etc/network etc/
cp --remove-destination -R /etc/hostname etc/
cp --remove-destination -R /etc/wpa_supplicant etc/
sed -i 's/\/etc\/resolv.conf/\/rootfs\/etc\/resolv.conf/g' etc/udhcpc/default.script
touch etc/mdev.conf
cp --remove-destination /etc/modules etc/
cp --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/fs ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/lib ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/usb ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/scsi ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/net ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/hid ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/kernel/drivers/block ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/modules.builtin ./
cp --remove-destination -av --parents /lib/modules/$(uname -r)/modules.order ./
cp --remove-destination -av --parents /lib/firmware ./
depmod -ab ./

touch etc/mtab

mkdir -p lib/arm-linux-gnueabihf
cp --remove-destination /lib/ld-linux-armhf.so.3 lib/
cp --remove-destination -a --parents /lib/*/{librt*,libpthread*,ld-*,libc-*,libgcc_s.so*,libc.so*,libdl*} ./
cp --remove-destination -a --parents /lib/*/{libm-*,libm.so*,libpam.so*,libpam_misc*,libkmod*} ./
cp --remove-destination -a --parents /lib/*/{libblkid*,libuuid*,libe2p*,libext2fs*,libcom_err*,libpthread*,libselinux*} ./
cp --remove-destination -a --parents /lib/*/{libdbus-1*,libnl-genl-3*,libnl-3*,libz.so*,librt.so*,libiw.so*,libtinfo.so*} ./
cp --remove-destination -a --parents /lib/*/{libparted.so*,libdevmapper.so*,libreadline.so*,libsepol.so*,libmount.so*} ./

cp --remove-destination -a --parents /usr/lib/arm-linux-gnueabihf/libcrypto.so* ./ 
cp --remove-destination -a --parents /usr/lib/arm-linux-gnueabihf/libpcsclite.so* ./ 
cp --remove-destination -a --parents /usr/lib/arm-linux-gnueabihf/libssl.so* ./ 

cp --remove-destination -a --parents /sbin/{rmmod,insmod,modprobe,udevd,udevadm} ./
cp --remove-destination -a --parents /bin/kmod ./
cp --remove-destination /usr/bin/xargs usr/bin
cp --remove-destination /bin/bash bin/
cp --remove-destination /sbin/fdisk sbin/
cp --remove-destination /sbin/blkid sbin/
cp --remove-destination /sbin/MAKEDEV sbin/
cp --remove-destination /sbin/sfdisk sbin/
cp --remove-destination /sbin/tune2fs sbin/
cp --remove-destination /sbin/e2fsck sbin/
cp --remove-destination /sbin/resize2fs sbin/
cp --remove-destination /sbin/ifdown sbin/
cp --remove-destination /sbin/ifup sbin/
cp --remove-destination /sbin/btrfs sbin/
cp --remove-destination /sbin/ifconfig sbin/
cp --remove-destination /sbin/ethtool sbin/
cp --remove-destination /sbin/iwconfig sbin/
cp --remove-destination /sbin/wpa_supplicant sbin/
cp --remove-destination /sbin/partprobe sbin/
cp --remove-destination /bin/mount bin/
cp --remove-destination /sbin/mount* sbin/

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/key.c > /home/xbian/key.c
cc -o usr/bin/key /home/xbian/key.c

cp --remove-destination -arv --parents /lib/udev/*_id ./
cp --remove-destination -arv --parents /lib/udev/{mtd_probe,net.agent,keyboard-force-release.sh,findkeyboards,keymaps} ./
cp --remove-destination -arv --parents /lib/udev/rules.d/{75-probe_mtd.rules,99-local-xbian.rules,95-keymap.rules,95-keyboard-force-release.rules,80-networking.rules,80-drivers.rules,60-persistent-input.rules,42-qemu-usb.rules,10-local-rpi.rules,60-persistent-storage.rules} ./
cp --remove-destination -arv --parents /lib/udev/rules.d/70-btrfs.rules ./

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/init > init
chmod a+x init

cat /etc/modules | grep -i evdev || echo evdev >> ./etc/modules

find . | cpio -H newc -o | gzip -2v > /boot/initramfs.gz
```
