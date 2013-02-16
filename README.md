```
cd /opt/
mkdir initramfs
cd initramfs

apt-get install fakeroot busybox

fakeroot
mkdir bin dev etc lib proc rootfs sbin sys
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
cp /sbin/fdisk sbin/
cp /sbin/resize2fs sbin/
ln -s lib/arm-linux-gnueabihf/libc.so.6 lib/libc.so.6
ln -s lib/arm-linux-gnueabihf/libgcc_s.so.1 lib/libgcc_s.so.1

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/init > init
chmod a+x init

find . | cpio -H newc -o > ../initramfs.cpio
cat ../initramfs.cpio | gzip > /boot/initramfs.gz
```
