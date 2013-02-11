xbian-initramfs
===============

```
cd /opt/
git clone https://github.com/xbianonpi/xbian-initramfs.git
cd xbian-initramfs
mkdir dev proc rootfs sbin sys
chmod a+x init
find . | cpio -H newc -o > ../initramfs.cpio
cat ../initramfs.cpio | gzip > /boot/initramfs.gz
```
