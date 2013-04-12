```
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
sed -i 's/\/etc\/resolv.conf/\/rootfs\/etc\/resolv.conf/g' etc/udhcpc/default.script
touch etc/mdev.conf
cp -d --remove-destination /etc/modules etc/
cp -d --remove-destination -av --parents /etc/default ./
cp -d --remove-destination -av --parents /lib/init ./
cp -d --remove-destination -av --parents /lib/lsb ./
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

mkdir -p lib/arm-linux-gnueabihf
cp -d --remove-destination /lib/ld-linux-armhf.so.3 lib/
cp -d --remove-destination -a --parents /lib/*/{librt*,libpthread*,ld-*,libc-*,libgcc_s.so*,libc.so*,libdl*} ./
cp -d --remove-destination -a --parents /lib/*/{libm-*,libm.so*,libpam.so*,libpam_misc*,libkmod*} ./
cp -d --remove-destination -a --parents /lib/*/{libblkid*,libuuid*,libe2p*,libext2fs*,libcom_err*,libpthread*,libselinux*} ./
cp -d --remove-destination -a --parents /lib/*/{libdbus-1*,libnl-genl-3*,libnl-3*,libz.so*,librt.so*,libiw.so*,libtinfo.so*} ./
cp -d --remove-destination -a --parents /lib/*/{libparted.so*,libdevmapper*,libreadline*,libudev*} ./
cp -d --remove-destination -a --parents /lib/klibc* ./

cp -d --remove-destination -a --parents /usr/lib/arm-linux-gnueabihf/libcrypto.so* ./ 
cp -d --remove-destination -a --parents /usr/lib/arm-linux-gnueabihf/libpcsclite.so* ./ 
cp -d --remove-destination -a --parents /usr/lib/arm-linux-gnueabihf/libssl.so* ./ 

cp -d --remove-destination -a --parents /sbin/{rmmod,insmod,modprobe,udevd,udevadm} ./
cp -d --remove-destination -a --parents /bin/kmod ./
cp -d --remove-destination /usr/bin/xargs usr/bin
cp -d --remove-destination /sbin/fdisk sbin/
cp -d --remove-destination /sbin/blkid sbin/
cp -d --remove-destination /sbin/MAKEDEV sbin/
cp -d --remove-destination /sbin/sfdisk sbin/
cp -d --remove-destination /sbin/tune2fs sbin/
cp -d --remove-destination /sbin/e2fsck sbin/
cp -d --remove-destination /sbin/resize2fs sbin/
cp -d --remove-destination /sbin/btrfs sbin/
cp -d --remove-destination /sbin/btrfs-debug-tree sbin/
cp -d --remove-destination /sbin/ethtool sbin/
cp -d --remove-destination /sbin/iwconfig sbin/
cp -d --remove-destination /sbin/wpa_supplicant sbin/
cp -d --remove-destination /sbin/partprobe sbin/
cp -d --remove-destination /usr/lib/klibc/bin/ipconfig ./bin
cp -d --remove-destination /bin/*sh bin/

cp -d --remove-destination -a --parents /usr/bin/splash ./
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
chmod a+x init

cat /etc/modules | grep -i evdev || echo evdev >> ./etc/modules

find . | cpio -H newc -o | gzip -2v > /boot/initramfs.new.gz
```
