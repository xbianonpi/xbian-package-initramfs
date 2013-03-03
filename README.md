```
cd /opt/
mkdir initramfs
cd initramfs

apt-get install fakeroot busybox udhcpc

fakeroot
mkdir bin dev etc lib proc rootfs run sbin sys tmp usr
mkdir etc/udhcpc etc/network etc/wpa_supplicant
mkdir etc/network/if-down.d etc/network/if-up.d etc/network/if-post-down.d etc/network/if-pre-up.d
mkdir lib/modules
mkdir run/network
mkdir usr/lib/arm-linux-gnueabihf
cp /etc/udhcpc/default.script etc/udhcpc/
cp -R /etc/network etc/
cp -R /etc/wpa_supplicant etc/
sed -i 's/\/etc\/resolv.conf/\/rootfs\/etc\/resolv.conf/g' etc/udhcpc/default.script
touch etc/mdev.conf
cp /bin/busybox bin/
ln -s busybox bin/sh
touch etc/mtab

mkdir -p lib/arm-linux-gnueabihf
cp /lib/ld-linux-armhf.so.3 lib/
cp -a /lib/arm-linux-gnueabihf/{ld-*,libc-*,libgcc_s.so*,libc.so*,libdl*} lib/arm-linux-gnueabihf
cp -a /lib/arm-linux-gnueabihf/{libm-*,libm.so*,libpam.so*,libpam_misc*} lib/arm-linux-gnueabihf
cp /lib/arm-linux-gnueabihf/libblkid.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libuuid.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libe2p.so.2 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libext2fs.so.2 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libcom_err.so.2 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libpthread.so.0 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libselinux.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libkmod.so.2 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libdbus-1.so.3 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libnl-genl-3.so.200 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libnl-3.so.200.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libz.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/librt.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libiw.so.30 lib/arm-linux-gnueabihf/

cp /usr/lib/arm-linux-gnueabihf/libcrypto.so.1.0.0 usr/lib/arm-linux-gnueabihf/
cp /usr/lib/arm-linux-gnueabihf/libpcsclite.so.1 usr/lib/arm-linux-gnueabihf/
cp /usr/lib/arm-linux-gnueabihf/libssl.so.1.0.0 usr/lib/arm-linux-gnueabihf/

ln -s lib/arm-linux-gnueabihf/libc.so.6 lib/
ln -s lib/arm-linux-gnueabihf/libgcc_s.so.1 lib/
ln -s lib/arm-linux-gnueabihf/libdl.so.2 lib/
ln -s lib/arm-linux-gnueabihf/libnl-3.so.200 lib/
ln -s lib/arm-linux-gnueabihf/libnl-genl-3.so.200 lib/

cp /sbin/fdisk sbin/
cp /sbin/sfdisk sbin/
cp /sbin/tune2fs sbin/
cp /sbin/e2fsck sbin/
cp /sbin/resize2fs sbin/
cp /sbin/swapon sbin/
cp /sbin/mkswap sbin/
cp /sbin/modprobe sbin/
cp /sbin/udhcpc sbin/
cp /sbin/ifconfig sbin/
cp /sbin/ifdown sbin/
cp /sbin/ifup sbin/
cp /sbin/iwconfig sbin/
cp /sbin/wpa_supplicant sbin/
cp /bin/ping bin/

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/init > init
chmod a+x init

find . | cpio -H newc -o > ../initramfs.cpio
cat ../initramfs.cpio | gzip > /boot/initramfs.gz
```
