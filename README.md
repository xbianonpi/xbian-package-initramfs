cd /opt/<br />
mkdir initramfs<br />
cd initramfs<br />
fakeroot<br />
mkdir bin dev etc lib proc rootfs sbin sys<br />
touch etc/mdev.conf<br />
cp /bin/busybox bin/<br />
ln -s busybox bin/sh<br />
mkdir -p lib/arm-linux-gnueabihf<br />
cp /lib/ld-linux-armhf.so.3 lib/<br />
cp -a /lib/arm-linux-gnueabihf/{ld-*,libc-*,libgcc_s.so*,libc.so*,libdl*} lib/arm-linux-gnueabihf<br />
cp -a /lib/arm-linux-gnueabihf/{libm-*,libm.so*,libpam.so*,libpam_misc*} lib/arm-linux-gnueabihf<br />
ln -s lib/arm-linux-gnueabihf/libc.so.6 lib/libc.so.6<br />
ln -sl lib/arm-linux-gnueabihf/libgcc_s.so.1 lib/libgcc_s.so.1<br />
<br />
wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/init > init<br />
chmod a+x init<br />
<br />
rm -r .git<br />
<br />
find . | cpio -H newc -o > ../initramfs.cpio<br />
cat ../initramfs.cpio | gzip > /boot/initramfs.gz<br />
