#!/bin/bash

. /etc/default/xbian-initramfs

copy_file() {
        cp -d --parents $3 "$1" "$2"
        test -h "$1" || return
        g=$(basename "$1")
        d=${1%$g}
        fl=$(ls -la "$1" | awk '{print $11}')
        tmp1=${fl##/*}
        if [ -n "$tmp1" ]; then
                test -h ".$2/$fl" && rm -f ".$2/$fl"
                cp -d --parents $3 "$d$fl" "$2"
        else
                test -h ".$fl" && rm -f ".$fl"
                cp -d --parents $3 "$fl" "./"
        fi
        echo "$fl"
}

copy_with_libs() {

        dst="$2"
        test -z "$dst" && dst="./"

        if [ -d "$1" ]; then
                cp -a --parents "$1"/* "$dst"
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
                        copy_file "$f" "$dst" "-n"
                        [ -e "$f1" ] && copy_file "$f1" "$dst" "-n"
                done
                IFS=$oldIFS
        fi
}

TMPDIR=$(mktemp -d)
cd $TMPDIR
trap "{ cd ..; rm -fr '${TMPDIR}'; exit 0; }" INT TERM

mkdir bin dev etc lib proc rootfs run sbin sys tmp usr mnt var
ln -s /run ./var/run
mkdir usr/bin
mkdir -p usr/bin
mkdir -p usr/lib/arm-linux-gnueabihf
copy_with_libs /bin/sh
touch etc/mdev.conf

cp -d --remove-destination -a --parents /lib/klibc* ./

copy_with_libs /usr/bin/whiptail ./
copy_with_libs /sbin/kexec ./
copy_with_libs /sbin/udevd ./
copy_with_libs /sbin/udevadm ./
copy_with_libs /sbin/findfs
copy_with_libs /sbin/blkid 
cp -d --remove-destination -arv /usr/lib/klibc/bin/* ./bin

cp -d --remove-destination -arv --parents /lib/udev/*_id ./
cp -d --remove-destination -arv --parents /lib/udev/{mtd_probe,net.agent,keyboard-force-release.sh,findkeyboards,keymaps} ./
cp -d --remove-destination -arv --parents /lib/udev/rules.d/{75-probe_mtd.rules,95-keyboard-force-release.rules,80-networking.rules,80-drivers.rules,60-persistent-input.rules,60-persistent-storage.rules} ./
cp -d --remove-destination -arv --parents /lib/udev/rules.d/70-btrfs.rules ./

cp /etc/xbian-initramfs/init-bootmenu ./init
cp /etc/xbian-initramfs/bootmenu ./
cp /etc/xbian-initramfs/bootmenu_timeout ./
cp /etc/xbian-initramfs/cnvres-code.sh ./

exit 0

