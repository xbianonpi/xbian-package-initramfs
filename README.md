```
cd /opt/
mkdir initramfs
cd initramfs

apt-get install fakeroot busybox udhcpc

fakeroot
mkdir bin dev etc lib proc rootfs run sbin sys tmp
mkdir etc/udhcpc etc/network etc/wpa_supplicant
mkdir etc/network/if-down.d etc/network/if-up.d etc/network/if-post-down.d etc/network/if-pre-up.d
mkdir lib/modules
mkdir run/network
mkdir -p usr/bin
mkdir -p usr/lib/arm-linux-gnueabihf
cp /etc/udhcpc/default.script etc/udhcpc/
cp -R /etc/network etc/
cp -R /etc/wpa_supplicant etc/
sed -i 's/\/etc\/resolv.conf/\/rootfs\/etc\/resolv.conf/g' etc/udhcpc/default.script
touch etc/mdev.conf
cp /bin/busybox bin/
/bin/busybox --install -s ./bin
cp /etc/modules etc/
cp -av --parents /lib/modules/$(uname -r)/kernel/fs ./
cp -av --parents /lib/modules/$(uname -r)/kernel/lib ./
cp -av --parents /lib/modules/$(uname -r)/kernel/drivers/usb ./
cp -av --parents /lib/modules/$(uname -r)/kernel/drivers/scsi ./
cp -av --parents /lib/modules/$(uname -r)/kernel/drivers/net ./
cp -av --parents /lib/modules/$(uname -r)/kernel/drivers/hid ./
cp -av --parents /lib/modules/$(uname -r)/kernel/drivers/block ./
cp -av --parents /lib/modules/$(uname -r)/modules.builtin ./
cp -av --parents /lib/modules/$(uname -r)/modules.order ./
cp -av --parents /lib/firmware ./
depmod -ab ./

touch etc/mtab

mkdir -p lib/arm-linux-gnueabihf
cp /lib/ld-linux-armhf.so.3 lib/
cp -a --parents /lib/{.,arm-linux-gnueabihf}/{librt*,libpthread*,ld-*,libc-*,libgcc_s.so*,libc.so*,libdl*} ./
cp -a --parents /lib/{.,arm-linux-gnueabihf}/{libm-*,libm.so*,libpam.so*,libpam_misc*,libkmod*} ./
cp -a --parents /lib/{.,arm-linux-gnueabihf}/{libblkid*,libuuid*,libe2p*,libext2fs*,libcom_err*,libpthread*,libselinux*} ./
cp -a --parents /lib/{.,arm-linux-gnueabihf}/{libdbus-1*,libnl-genl-3*,libnl-3*,libz.so*,librt.so*,libiw.so*,libtinfo.so*} ./

cp -a --parents /usr/lib/arm-linux-gnueabihf/libcrypto.so* ./ 
cp -a --parents /usr/lib/arm-linux-gnueabihf/libpcsclite.so* ./ 
cp -a --parents /usr/lib/arm-linux-gnueabihf/libssl.so* ./ 

#ln -s lib/arm-linux-gnueabihf/libc.so.6 lib/
#ln -s lib/arm-linux-gnueabihf/libgcc_s.so.1 lib/
#ln -s lib/arm-linux-gnueabihf/libdl.so.2 lib/
#ln -s lib/arm-linux-gnueabihf/libnl-3.so.200 lib/
#ln -s lib/arm-linux-gnueabihf/libnl-genl-3.so.200 lib/

cp -a --parents /sbin/{rmmod,insmod,modprobe,udevd,udevadm} ./
cp -a --parents /bin/kmod ./
cp /usr/bin/xargs usr/bin
cp /bin/bash bin/
cp /usr/bin/key usr/bin/
cp /sbin/MAKEDEV sbin/
cp /sbin/MAKEDEV sbin/
cp /sbin/sfdisk sbin/
cp /sbin/tune2fs sbin/
cp /sbin/e2fsck sbin/
cp /sbin/resize2fs sbin/
cp /sbin/ifdown sbin/
cp /sbin/ifup sbin/
cp /sbin/btrfs sbin/
cp /sbin/ifconfig sbin/
cp /sbin/ethtool sbin/
cp /sbin/iwconfig sbin/
cp /sbin/wpa_supplicant sbin/

cp -arv --parents /lib/udev/*_id ./
cp -arv --parents /lib/udev/{net.agent,keyboard-force-release.sh,findkeyboards,keymaps} ./
cp -arv --parents /lib/udev/rules.d/{99-local-xbian.rules,95-keymap.rules,95-keyboard-force-release.rules,80-networking.rules,80-drivers.rules,60-persistent-input.rules,42-qemu-usb.rules,10-local-rpi.rules} ./

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/init > init
chmod a+x init

find . | cpio -H newc -o | gzip -2v > /boot/initramfs.gz
```
