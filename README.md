```
cd /opt/
mkdir initramfs
cd initramfs

apt-get install fakeroot busybox udhcpc btrfs-tools

fakeroot
mkdir bin dev etc lib proc rootfs run sbin sys tmp usr
mkdir usr/bin
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
cp /etc/modules etc/
cp /usr/bin/xargs usr/bin/
mkdir lib/modules/$(uname -r)
mkdir -p lib/modules/$(uname -r)/kernel/fs/{btrfs,fuse}
mkdir -p lib/modules/$(uname -r)/kernel/lib
cp -avR --parents /lib/modules/$(uname -r)/kernel/fs/btrfs .
cp -avR --parents /lib/modules/$(uname -r)/kernel/fs/fuse .
cp -avR --parents /lib/modules/$(uname -r)/kernel/lib .
cp -av --parents /lib/modules/$(uname -r)/modules.builtin .
cp -av --parents /lib/modules/$(uname -r)/modules.order .
depmod -ab ./

ln -s busybox bin/[
ln -s busybox bin/[[
ln -s busybox bin/adjtimex
ln -s busybox bin/ar
ln -s busybox bin/arp
ln -s busybox bin/arping
ln -s busybox bin/ash
ln -s busybox bin/awk
ln -s busybox bin/basename
ln -s busybox bin/blockdev
ln -s busybox bin/brctl
ln -s busybox bin/bunzip2
ln -s busybox bin/bzcat
ln -s busybox bin/bzip2
ln -s busybox bin/cal
ln -s busybox bin/cat
ln -s busybox bin/chgrp
ln -s busybox bin/chmod
ln -s busybox bin/chown
ln -s busybox bin/chroot
ln -s busybox bin/chvt
ln -s busybox bin/clear
ln -s busybox bin/cmp
ln -s busybox bin/cp
ln -s busybox bin/cpio
ln -s busybox bin/cttyhack
ln -s busybox bin/cut
ln -s busybox bin/date
ln -s busybox bin/dc
ln -s busybox bin/dd
ln -s busybox bin/deallocvt
ln -s busybox bin/depmod
ln -s busybox bin/df
ln -s busybox bin/diff
ln -s busybox bin/dirname
ln -s busybox bin/dmesg
ln -s busybox bin/dnsdomainname
ln -s busybox bin/dos2unix
ln -s busybox bin/du
ln -s busybox bin/dumpkmap
ln -s busybox bin/dumpleases
ln -s busybox bin/echo
ln -s busybox bin/egrep
ln -s busybox bin/env
ln -s busybox bin/expand
ln -s busybox bin/expr
ln -s busybox bin/false
ln -s busybox bin/fgrep
ln -s busybox bin/find
ln -s busybox bin/fold
ln -s busybox bin/free
ln -s busybox bin/freeramdisk
ln -s busybox bin/ftpget
ln -s busybox bin/ftpput
ln -s busybox bin/getopt
ln -s busybox bin/getty
ln -s busybox bin/grep
ln -s busybox bin/groups
ln -s busybox bin/gunzip
ln -s busybox bin/gzip
ln -s busybox bin/halt
ln -s busybox bin/head
ln -s busybox bin/hexdump
ln -s busybox bin/hostid
ln -s busybox bin/hostname
ln -s busybox bin/httpd
ln -s busybox bin/hwclock
ln -s busybox bin/id
ln -s busybox bin/ifconfig
ln -s busybox bin/init
ln -s busybox bin/insmod
ln -s busybox bin/ionice
ln -s busybox bin/ip
ln -s busybox bin/ipcalc
ln -s busybox bin/kill
ln -s busybox bin/killall
ln -s busybox bin/klogd
ln -s busybox bin/last
ln -s busybox bin/less
ln -s busybox bin/ln
ln -s busybox bin/loadfont
ln -s busybox bin/loadkmap
ln -s busybox bin/logger
ln -s busybox bin/login
ln -s busybox bin/logname
ln -s busybox bin/logread
ln -s busybox bin/losetup
ln -s busybox bin/ls
ln -s busybox bin/lsmod
ln -s busybox bin/lzcat
ln -s busybox bin/lzma
ln -s busybox bin/md5sum
ln -s busybox bin/mdev
ln -s busybox bin/microcom
ln -s busybox bin/mkdir
ln -s busybox bin/mkfifo
ln -s busybox bin/mknod
ln -s busybox bin/mkswap
ln -s busybox bin/mktemp
ln -s busybox bin/modinfo
ln -s busybox bin/modprobe
ln -s busybox bin/more
ln -s busybox bin/mount
ln -s busybox bin/mt
ln -s busybox bin/mv
ln -s busybox bin/nameif
ln -s busybox bin/nc
ln -s busybox bin/netstat
ln -s busybox bin/nslookup
ln -s busybox bin/od
ln -s busybox bin/openvt
ln -s busybox bin/patch
ln -s busybox bin/pidof
ln -s busybox bin/ping
ln -s busybox bin/ping6
ln -s busybox bin/pivot_root
ln -s busybox bin/poweroff
ln -s busybox bin/printf
ln -s busybox bin/ps
ln -s busybox bin/pwd
ln -s busybox bin/rdate
ln -s busybox bin/readlink
ln -s busybox bin/realpath
ln -s busybox bin/reboot
ln -s busybox bin/renice
ln -s busybox bin/reset
ln -s busybox bin/rev
ln -s busybox bin/rm
ln -s busybox bin/rmdir
ln -s busybox bin/rmmod
ln -s busybox bin/route
ln -s busybox bin/rpm
ln -s busybox bin/rpm2cpio
ln -s busybox bin/run-parts
ln -s busybox bin/sed
ln -s busybox bin/seq
ln -s busybox bin/setkeycodes
ln -s busybox bin/setsid
ln -s busybox bin/sh
ln -s busybox bin/sha1sum
ln -s busybox bin/sha256sum
ln -s busybox bin/sha512sum
ln -s busybox bin/sleep
ln -s busybox bin/sort
ln -s busybox bin/start-stop-daemon
ln -s busybox bin/stat
ln -s busybox bin/strings
ln -s busybox bin/stty
ln -s busybox bin/swapoff
ln -s busybox bin/swapon
ln -s busybox bin/switch_root
ln -s busybox bin/sync
ln -s busybox bin/sysctl
ln -s busybox bin/syslogd
ln -s busybox bin/tac
ln -s busybox bin/tail
ln -s busybox bin/tar
ln -s busybox bin/taskset
ln -s busybox bin/tee
ln -s busybox bin/telnet
ln -s busybox bin/test
ln -s busybox bin/tftp
ln -s busybox bin/time
ln -s busybox bin/timeout
ln -s busybox bin/top
ln -s busybox bin/touch
ln -s busybox bin/tr
ln -s busybox bin/traceroute
ln -s busybox bin/traceroute6
ln -s busybox bin/true
ln -s busybox bin/tty
ln -s busybox bin/udhcpc
ln -s busybox bin/udhcpd
ln -s busybox bin/umount
ln -s busybox bin/uname
ln -s busybox bin/uncompress
ln -s busybox bin/unexpand
ln -s busybox bin/uniq
ln -s busybox bin/unix2dos
ln -s busybox bin/unlzma
ln -s busybox bin/unxz
ln -s busybox bin/unzip
ln -s busybox bin/uptime
ln -s busybox bin/usleep
ln -s busybox bin/uudecode
ln -s busybox bin/uuencode
ln -s busybox bin/vconfig
ln -s busybox bin/vi
ln -s busybox bin/watch
ln -s busybox bin/watchdog
ln -s busybox bin/wc
ln -s busybox bin/wget
ln -s busybox bin/which
ln -s busybox bin/who
ln -s busybox bin/whoami
ln -s busybox bin/xargs
ln -s busybox bin/xz
ln -s busybox bin/xzcat
ln -s busybox bin/yes
ln -s busybox bin/zcat 

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
cp /lib/arm-linux-gnueabihf/libdbus-1.so.3 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libnl-genl-3.so.200 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libnl-3.so.200.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libz.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/librt.so.1 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libiw.so.30 lib/arm-linux-gnueabihf/
cp /lib/arm-linux-gnueabihf/libtinfo.so.5 lib/arm-linux-gnueabihf/

cp /usr/lib/arm-linux-gnueabihf/libcrypto.so.1.0.0 usr/lib/arm-linux-gnueabihf/
cp /usr/lib/arm-linux-gnueabihf/libpcsclite.so.1 usr/lib/arm-linux-gnueabihf/
cp /usr/lib/arm-linux-gnueabihf/libssl.so.1.0.0 usr/lib/arm-linux-gnueabihf/

ln -s lib/arm-linux-gnueabihf/libc.so.6 lib/
ln -s lib/arm-linux-gnueabihf/libgcc_s.so.1 lib/
ln -s lib/arm-linux-gnueabihf/libdl.so.2 lib/
ln -s lib/arm-linux-gnueabihf/libnl-3.so.200 lib/
ln -s lib/arm-linux-gnueabihf/libnl-genl-3.so.200 lib/

cp /bin/bash bin/
cp /sbin/fdisk sbin/
cp /sbin/sfdisk sbin/
cp /sbin/tune2fs sbin/
cp /sbin/e2fsck sbin/
cp /sbin/resize2fs sbin/
cp /sbin/ifdown sbin/
cp /sbin/ifup sbin/
cp /sbin/btrfs sbin/
cp /sbin/iwconfig sbin/
cp /sbin/wpa_supplicant sbin/
cp /sbin/udevadm sbin/
cp /sbin/udevd sbin/

wget -O - https://raw.github.com/xbianonpi/xbian-initramfs/master/init > init
chmod a+x init

find . | cpio -H newc -o > ../initramfs.cpio
cat ../initramfs.cpio | gzip > /boot/initramfs.gz
```
