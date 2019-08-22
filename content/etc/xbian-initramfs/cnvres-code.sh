# part of code, which is relevant to block devices ... to keep init readable

telnetrun() {
    [ -f /bin/bash -a ! -h /bin/bash ] && shl=/bin/bash || shl=/bin/sh
    echo "ENV=/.profile exec $shl" > /cmd.sh; chmod +x /cmd.sh
    cttyhack telnetd -f /howto.txt -F -l /cmd.sh & pids2kill="$pids2kill $!"
}

vncrun() {
    modprobe -q vchiq
    modprobe -q uinput
    [ -e /etc/default/vnc-server ] && . /etc/default/vnc-server
    which vncserver >/dev/null && { vncserver $OPTIONS >/dev/null & } || echo "No VNC server available"
}

up() {
    echo "$(date) at initramfs/init $1: $(cat /proc/uptime)" >> /run/uptime-init.log
}

mount_root_btrfs() {
    test -z "$1" && device="LABEL=xbian-root-btrfs" || device="$1"
    /bin/mount -t btrfs -o compress=lzo,rw,noatime,space_cache $device $CONFIG_newroot
}

gen_resolv() {
    r=''
    for f in `ls /run/net-*.conf 2>/dev/null | grep -v net-lo.conf`; do
        . $f
        [ -z "$IPV4DNS0" ] || r="${r}nameserver $IPV4DNS0\n"
        [ -z "$IPV4DNS1" -o "$IPV4DNS1" = '0.0.0.0' ] || r="${r}nameserver $IPV4DNS1\n"
        [ -z "$DNSDOMAIN" ] || r="${r}domain $DNSDOMAIN\n"
        [ -z "$DOMAINSEARCH" ] && r="${r}search $DNSDOMAIN\n" || r="${r}search $DOMAINSEARCH\n"
        [ -z "$ROOTSERVER" ] || export CONFIG_server=$ROOTSERVER
    done
    if [ -z "$r" ]; then
        if [ -e /proc/net/pnp ]; then
            export CONFIG_server=$(awk '/bootserver/{print $2}' /proc/net/pnp)
            sed '/bootserver.*/d' /proc/net/pnp >$1
        fi
    else
        echo -en "$r" | awk '!x[$0]++' >$1
    fi
}

update_interfaces() {
    if [ "$1" = "rollback" ]; then
        test -e "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" && mv "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" "${CONFIG_newroot}/etc/network/interfaces"
        return
    fi
    #test "$CONFIG_cnet" = "dhcp" || return

    test -e "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" && return
    for f in `ls /run/net-eth?.conf`; do
        f=${f%%.conf}; f=${f##/run/net-};
        if [ "$(cat ${CONFIG_newroot}/etc/network/interfaces | grep $f | grep inet | grep -c iface)" -eq '1' ]; then
            grep -v  "$(cat ${CONFIG_newroot}/etc/network/interfaces | grep $f | grep inet | grep  iface)" "${CONFIG_newroot}/etc/network/interfaces" > "${CONFIG_newroot}/etc/network/interfaces.new"
            if [ "$(cat ${CONFIG_newroot}/etc/network/interfaces | grep $f | grep -c auto)" -eq '0' ]; then
                printf "%s\n" "auto $f" >> "${CONFIG_newroot}/etc/network/interfaces.new"
            fi
            printf "%s\n" "iface $f inet manual" >> "${CONFIG_newroot}/etc/network/interfaces.new"
            test -e "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig" || mv "${CONFIG_newroot}/etc/network/interfaces" "${CONFIG_newroot}/etc/network/interfaces.initramfs.autoconfig"
            mv "${CONFIG_newroot}/etc/network/interfaces.new" "${CONFIG_newroot}/etc/network/interfaces"
        fi
    done
}

modify_interfaces() {
    getused() {
        h=''
        for n in $(ip a | grep -vwE 'lo|dummy[0-9]|tun[0-9]' | awk '/^[0-9]/{ sub(":","",$2); print $2; }'); do
            [ x"$(ip a show $n | sed -n -e 's/:127\.0\.0\.1 //g' -e 's/ *inet \([0-9.]\+\).*/\1/gp')" = x"$1" ] && h=$n" $h"
        done
        echo $h
    }

    if [ "${CONFIG_rooton}" = nfs ]; then
        usedDEV=$(getused $(netstat -nt 2>/dev/null | grep -m1 $(grep -w ${CONFIG_newroot} /proc/mounts | awk '{ sub(".*,addr=",""); sub(",.*",""); print $1; }'):2049 | \
            awk '{ split($4, a, ":"); print a[1]; }'))
    elif [ "${CONFIG_rooton}" = iscsi ]; then
        usedDEV=$(getused $(netstat -nt 2>/dev/null | grep :$(iscsiadm -m session | awk '{ split($3, a, ":"); split(a[2], b, ","); print b[1]; }') | \
            awk '{ split($4, a, ":"); print a[1]; }'))
    else
        usedDEV=''
    fi

    for d in $usedDEV; do
        if ! grep -q "iface $d inet manual" /etc/network/interfaces; then
            sed -i "s%iface $d inet .*%no-auto-down $d\niface $d inet manual%" /etc/network/interfaces
            export CONFIG_devinuse="$d $CONFIG_devinuse"
        fi
    done

    if [ -n "$CONFIG_cnet" ]; then
        lif=$(grep -B100 "^# ...here" /etc/network/interfaces) 2>/dev/null
        rif=$(grep -B100 "^# ...here" $CONFIG_newroot/etc/network/interfaces) 2>/dev/null
        if [ ! -e $CONFIG_newroot/etc/network/interfaces.initbak ] || [ ! -e $CONFIG_newroot/etc/network/interfaces ] || [ "$lif" != "$rif" ]; then
            rpr=$(grep -A100 "^# ...here" $CONFIG_newroot/etc/network/interfaces 2>/dev/null | grep -v "^# ...here")
            mv $CONFIG_newroot/etc/network/interfaces $CONFIG_newroot/etc/network/interfaces.initbak 2>/dev/null
            cp /etc/network/interfaces $CONFIG_newroot/etc/network/ && echo "$rpr" >> $CONFIG_newroot/etc/network/interfaces
        fi
    fi

    [ -n "$CONFIG_cnet" ] && ! grep -q 'LAN=yes' ${CONFIG_newroot}/etc/default/xbian-initramfs && sed -i 's/LAN=.*/LAN=yes/g' ${CONFIG_newroot}/etc/default/xbian-initramfs
    [ "$CONFIG_rooton" = iscsi ] && { grep -q 'iSCSI=no' ${CONFIG_newroot}/etc/default/xbian-initramfs && sed -i 's/iSCSI=no/iSCSI=auto/g' ${CONFIG_newroot}/etc/default/xbian-initramfs; \
                                      [ -e ${CONFIG_newroot}/etc/iscsi/iscsi.initramfs ] || touch ${CONFIG_newroot}/etc/iscsi/iscsi.initramfs; }
}

create_fsck() {
    if [ ! -e "$1"/sbin/fsck.btrfs ]; then
        echo "#!/bin/sh

true
"       >> "$1"/sbin/fsck.btrfs
        chmod +x "$1"/sbin/fsck.btrfs
    fi
}

set_time() {
    if ! dmesg | grep -q 'setting system clock' && [ ! -e /run/hwclock.init -a -e $CONFIG_newroot/etc/default/hwclock.fake ]; then
        $CONFIG_newroot/bin/date --set="$(cat $CONFIG_newroot/etc/default/hwclock.fake)" >/dev/null && touch /run/hwclock.init
    fi
}

get_partdata() {
    parttbl="$(parted -sm ${DEV} unit s print)"
    export NRPART=$(echo "$parttbl" | awk -F: 'END{print $1}')
    export FSCHECK=$(echo "$parttbl" | awk -F: "/^$PART/"'{print $5}')
    export sectorTOTAL=$(echo "$parttbl" | awk -F: '/^\//{printf "%d", $2}')
    export sectorSTART=$(echo "$parttbl" | awk -F: "/^$PART/"'{printf "%d", $2}')
    export sectorEND=$(echo "$parttbl" | awk -F: "/^$PART/"'{printf "%d", $3}')
    export sectorSIZE=$(echo "$parttbl" | awk -F: "/^$PART/"'{printf "%d", $4}')
    export sectorUSED=$(echo "$parttbl" | awk -F: "/^$NRPART/"'{printf "%d", $3}')
    if [ "$NRPART" -gt 4 ]; then
        export PARTEX=$(echo "$parttbl" | awk -F: '/:::/{printf "%d", $1}')
        #export sectorexTOTAL=$(echo "$parttbl" | awk -F: '/:::/{printf "%d", $4}')
        export sectorexSIZE=$(echo "$parttbl" | awk -F: '/:::/{printf "%d", $4}')
        export sectorexSTART=$(echo "$parttbl" | awk -F: '/:::/{printf "%d", $2}')
        export sectorexEND=$(echo "$parttbl" | awk -F: '/:::/{printf "%d", $3}')
        export sectorexNEW=$(( $sectorTOTAL - $sectorexSTART - 2048 ))
        export sectorNEW=$(( $sectorexSIZE - $sectorSTART - 2048 ))
    else
        export sectorNEW=$(( $sectorTOTAL - $sectorSTART - 2048 ))
    fi
    ! echo "$parttbl" | grep -q "linux-swap(v[0-9])" || export haveSWAP=1
}

get_root() {
    [ -n "$CONFIG_roottxt" ] && export CONFIG_root="$CONFIG_roottxt" || export CONFIG_roottxt="$CONFIG_root"

    if echo $CONFIG_root | grep -q ^'iSCSI='; then
        export CONFIG_root=${CONFIG_root##iSCSI=}
        CONFIG_portal=${CONFIG_root%,*}
        export CONFIG_iqn=${CONFIG_portal%,*}
        export CONFIG_portal=${CONFIG_portal##*,}
        export CONFIG_root=${CONFIG_root##*,}
        [ ! -d /etc/iscsi/nodes/$CONFIG_iqn/$(echo $CONFIG_portal | tr ':' ','),*/ ] && iscsiadm -m discovery -t sendtargets -p $CONFIG_portal
        iscsiadm -m node -T $CONFIG_iqn -p $CONFIG_portal --login && sleep 0.5 && pgrep /sbin/iscsid >/run/sendsigs.omit.d/iscsid
    fi

    case $CONFIG_root in
        UUID=*|LABEL=*)
            export CONFIG_root=$(findfs $CONFIG_root 2>/dev/null)
        ;;
        PARTUUID=*) # busybox findfs currently does not support PARTUUID
            export CONFIG_root="$(readlink -fn /dev/disk/by-partuuid/${CONFIG_root##PARTUUID=})"
        ;;
        ZFS=*)
            export CONFIG_zfspool=${CONFIG_root##ZFS=}
            if [ ! -f /etc/zfs/zpool.cache ] || ! zpool list ${CONFIG_zfspool} 2>/dev/null; then
                zi=$(zpool import)
                export CONFIG_zfspoolid=$(echo "$zi" | grep -B2 "state: ONLINE" | grep -A1 "pool: ${CONFIG_zfspool}" | awk '/id:/{print $2}')
                [ -n "$CONFIG_zfspoolid" ] && zpool import -fN ${CONFIG_zfspoolid}
            fi
            if [ $? -ne 0 ]; then
                export CONFIG_zfspoolid=$(echo "$zi" | grep -B2 "state: ONLINE" | awk '/id:/{print $2}')
                ! zpool import -fN ${CONFIG_zfspoolid} ${CONFIG_zfspool} && return 1
            fi
            export CONFIG_rootfs=$(zpool list -H -o bootfs ${CONFIG_zfspool} 2>/dev/null)
            [ -z "$CONFIG_rootfs" -o "$CONFIG_rootfs" = - ] && return 1
            zfs list "$CONFIG_rootfs" >/dev/null 2>&1 || return 1
            zfs set mountpoint=/ "$CONFIG_rootfs" >/dev/null 2>&1 || return 1
            export CONFIG_rootfstype=zfs
            export CONFIG_rootfsopts=zfsutil
            [ "$(zfs get atime -H "$CONFIG_rootfs" | awk '{print $3}')" = off ] && export CONFIG_rootfsopts="$CONFIG_rootfsopts,noatime"
            export CONFIG_root=$(zpool status -P $CONFIG_zfspool | awk "/\/.*ONLINE/"'{dev=$1} END{print dev}')
        ;;
    esac

    [ -b "$CONFIG_root" ] || return 1

    if [ $CONFIG_rootfstype = btrfs ]; then
        btrfs dev scan || :
        READY=$(btrfs dev ready $CONFIG_root 2>&1)
        if [ $? -eq 1 ]; then
            echo $READY | grep -q Inappropriate || return 1
        fi
        [ "$(btrfs fi show $CONFIG_root | grep -c devid)" -gt 1 ] && export RESIZEERROR=1
    fi

    export DEV="${CONFIG_root%[0-9]}"; DEV="${DEV%[0-9]}"
    if [ ! -e ${DEV} ]; then
        export DEV=${DEV%p}
        export PARTdelim='p'
    else
        export PARTdelim=''
    fi
    export PART=${CONFIG_root##*[a-z]}

    get_partdata
}

convert_btrfs() {
    # Check for the existance of tune2fs through the RESIZEERROR variable
    if [ "$FSCHECK" != "btrfs" ] && [ "$CONFIG_convertfs" -eq '1' -a "${CONFIG_rootfstype}" = "btrfs" -a -x /sbin/e2fsck ]; then
        [ "$RESIZEERROR" -gt '0' -a "$RESIZEERROR_NONFATAL" -ne '1' ] && return 0
        if [ "${FSCHECK}" = 'ext4' ]; then
            # Make sure we have enough memory available for live conversion
            FREEMEM=`free -m | grep "Mem:" | awk '{printf "%d", $4}'`
            if [ ${FREEMEM} -lt '128' ]; then
                test ! -d /boot && mkdir /boot
                /bin/mount "${DEV}${PARTdelim}1" /boot
                # Save the old memory value to the cmdline.txt to restore it later on
                cp /boot/config.txt /boot/config.txt.convert
                sed -i "s/gpu_mem_256=[0-9]*/gpu_mem_256=32/g" /boot/config.txt
                umount /boot
                reboot -f
            fi

            test -n "$CONFIG_splash" && /usr/bin/splash --infinitebar --msgtxt="init: sd card convert..."
            test -n "$CONFIG_splash" || echo '
 .d8888b.   .d88888b.  888b    888 888     888 8888888888 8888888b. 88888888888
d88P  Y88b d88P" "Y88b 8888b   888 888     888 888        888   Y88b    888
888    888 888     888 88888b  888 888     888 888        888    888    888
888        888     888 888Y88b 888 Y88b   d88P 8888888    888   d88P    888
888        888     888 888 Y88b888  Y88b d88P  888        8888888P"     888
888    888 888     888 888  Y88888   Y88o88P   888        888 T88b      888
Y88b  d88P Y88b. .d88P 888   Y8888    Y888P    888        888  T88b     888
 "Y8888P"   "Y88888P"  888    Y888     Y8P     8888888888 888   T88b    888';
            e2fsck -p -f ${CONFIG_root}
            /splash_updater.sh &
            stdbuf -o 0 -e 0 btrfs-convert -d ${CONFIG_root} 2>&1 > /tmp/output.grab
            touch /run/splash_updater.kill
            get_partdata
        fi

        test ! -d /boot && mkdir /boot
        /bin/mount "${DEV}${PARTdelim}1" /boot
        test -e /boot/config.txt.convert && mv /boot/config.txt.convert /boot/config.txt
        test "$FSCHECK" = "ext4" && sed -i "s/rootfstype=btrfs/rootfstype=ext4/g" /boot/cmdline.txt
        if [ "$FSCHECK" = "btrfs" ]; then
            test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="init: post conversion tasks..."
            btrfs fi label ${CONFIG_root} xbian-root-btrfs
            mount_root_btrfs
            create_fsck $CONFIG_newroot
            btrfs sub delete $CONFIG_newroot/ext2_saved

            btrfs sub create $CONFIG_newroot/ROOT
            echo "Moving root..."
            test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="init: moving root..."
            btrfs sub snap $CONFIG_newroot $CONFIG_newroot/ROOT/@

            mount && echo '============================' && sleep 15
            for f in $(ls $CONFIG_newroot | grep -vw ROOT); do rm -fr $CONFIG_newroot/$f >/dev/null 2>&1; done

            mv $CONFIG_newroot/ROOT $CONFIG_newroot/root
            btrfs sub create $CONFIG_newroot/home
            btrfs sub create $CONFIG_newroot/home/@
            btrfs sub create $CONFIG_newroot/modules
            btrfs sub create $CONFIG_newroot/modules/@
            mv $CONFIG_newroot/root/@/home/* $CONFIG_newroot/home/@
            mv $CONFIG_newroot/root/@/lib/modules/* $CONFIG_newroot/modules/@
            cp $CONFIG_newroot/root/@/etc/fstab $CONFIG_newroot/root/@/etc/fstab.ext4
            # edit fstab
            sed -i "/\(\/var\/swapfile\)/d" $CONFIG_newroot/root/@/etc/fstab

            if grep -wq "/tmp" $CONFIG_newroot/root/@/etc/fstab; then
                grep -wv "/tmp" $CONFIG_newroot/root/@/etc/fstab > $CONFIG_newroot/root/@/etc/fstab.new
                mv $CONFIG_newroot/root/@/etc/fstab.new $CONFIG_newroot/root/@/etc/fstab
            fi

            if grep -wq 'root/@' $CONFIG_newroot/root/@/etc/fstab; then
                grep -wv 'root/@' $CONFIG_newroot/root/@/etc/fstab >> $CONFIG_newroot/root/@/etc/fstab.new
                mv $CONFIG_newroot/root/@/etc/fstab.new $CONFIG_newroot/root/@/etc/fstab
            fi

            #if [ $(grep -w '/dev/root' $CONFIG_newroot/root/@/etc/fstab | grep -wc '/home') -ne 1 -o $(grep -w '/dev/root' $CONFIG_newroot/root/@/etc/fstab | grep -w '/home' | grep -c 'subvol=') -ne 1 ]; then
            if grep -wq "/home" $CONFIG_newroot/root/@/etc/fstab; then
                grep -wv "/home" $CONFIG_newroot/root/@/etc/fstab > $CONFIG_newroot/root/@/etc/fstab.new
                mv $CONFIG_newroot/root/@/etc/fstab.new $CONFIG_newroot/root/@/etc/fstab
            fi
            echo "/dev/root             /home                   xbian   subvol=home/@,noatime,nobootwait           0       0" >> $CONFIG_newroot/root/@/etc/fstab
            #fi

            if grep -wq "/lib/modules" $CONFIG_newroot/root/@/etc/fstab; then
                grep -wv "/lib/modules" $CONFIG_newroot/root/@/etc/fstab > $CONFIG_newroot/root/@/etc/fstab.new
                mv $CONFIG_newroot/root/@/etc/fstab.new $CONFIG_newroot/root/@/etc/fstab
            fi
            echo "/dev/root             /lib/modules            xbian   subvol=modules/@,noatime,nobootwait        0       0" >> $CONFIG_newroot/root/@/etc/fstab

            if grep -wq "/" $CONFIG_newroot/root/@/etc/fstab; then
                grep -wv "/" $CONFIG_newroot/root/@/etc/fstab > $CONFIG_newroot/root/@/etc/fstab.new
                grep ^'//' $CONFIG_newroot/root/@/etc/fstab >> $CONFIG_newroot/root/@/etc/fstab.new
                mv $CONFIG_newroot/root/@/etc/fstab.new $CONFIG_newroot/root/@/etc/fstab
            fi
            echo "/dev/root             /                       xbian   noatime,nobootwait                         0       0" >> $CONFIG_newroot/root/@/etc/fstab

            if grep -wq "/proc" $CONFIG_newroot/root/@/etc/fstab; then
                grep -wv "/proc" $CONFIG_newroot/root/@/etc/fstab > $CONFIG_newroot/root/@/etc/fstab.new
                mv $CONFIG_newroot/root/@/etc/fstab.new $CONFIG_newroot/root/@/etc/fstab
            fi

            grep -wv "/boot" $CONFIG_newroot/root/@/etc/fstab > $CONFIG_newroot/root/@/etc/fstab.new
            mv $CONFIG_newroot/root/@/etc/fstab.new $CONFIG_newroot/root/@/etc/fstab
            echo "/dev/mmcblk0p1        /boot                   xbian   rw,nobootwait                              0       1" >> $CONFIG_newroot/root/@/etc/fstab

            if ! grep -wq "/run/user" $CONFIG_newroot/root/@/etc/fstab; then
                echo "none            /run/user                       tmpfs                   noauto                  0       0" >> $CONFIG_newroot/root/@/etc/fstab
            fi
            if ! grep -wq "/sys/kernel/security" $CONFIG_newroot/root/@/etc/fstab; then
                echo "none            /sys/kernel/security            securityfs              noauto                  0       0" >> $CONFIG_newroot/root/@/etc/fstab
            fi
            if ! grep -wq "/sys/kernel/debug" $CONFIG_newroot/root/@/etc/fstab; then
                echo "none            /sys/kernel/debug               debugfs                 noauto                  0       0" >> $CONFIG_newroot/root/@/etc/fstab
            fi
            if ! grep -wq "/run/shm" $CONFIG_newroot/root/@/etc/fstab; then
                echo "none            /run/shm                        tmpfs                   noauto                  0       0" >> $CONFIG_newroot/root/@/etc/fstab
            fi
            if ! grep -wq "/run/lock" $CONFIG_newroot/root/@/etc/fstab; then
                echo "none            /run/lock                       tmpfs                   noauto                  0       0" >> $CONFIG_newroot/root/@/etc/fstab
            fi
            # end edit fstab
            echo "rebalancing filesystem..."
            test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="init: rebalancing filesystem..."
            btrfs fi bal "$CONFIG_newroot"
            umount $CONFIG_newroot
        fi
        if [ "$FSCHECK" = btrfs ]; then
            echo "FILESYSTEM WAS SUCESSFULLY CONVERTED TO BTRFS"
            echo "ADAPTING rootflags IN CMDLINE.TXT"
            if grep -q rootflags /boot/cmdline.txt; then
                sed -i 's/rootflags=.*? /rootflags=subvol=root\/@,autodefrag,compress=lzo/g' /boot/cmdline.txt
            else
                l="$(cat /boot/cmdline.txt) rootflags=subvol=root/@,autodefrag,compress=lzo"
                echo $l > /boot/cmdline.txt
            fi
        fi
        test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="init: rebooting..."
        umount /boot
        sync
        reboot -nf
    fi
}

resize_part() {
    if [ "$RESIZEERROR" -eq '0' -a "$CONFIG_noresizesd" -eq '0' -a "${CONFIG_rootfstype}" != "nfs" ]; then

        if [ -n "$PARTEX" ] && [ $sectorexSIZE -lt $sectorexNEW -a -n "$CONFIG_extresize" ]; then
            echo "Expanding extended partition $PARTEX..."
            if ! parted -s $DEV unit % resizepart $PARTEX 100%; then
                echo "Resizing extended partition failed..."
            fi
            partprobe
            get_partdata
        fi

        if [ "$NRPART" -gt "$PART" ]; then
            if [ "$(findfs LABEL=RECOVERY 2>/dev/null)" = "${DEV}${PARTdelim}1" ]; then
                echo "NOTICE: running under NOOBS/PINN environment and root partition is not at the end" >&2
                return 0
            else
                test -z "$CONFIG_partswap" && echo "FATAL: only the last partition can be resized" >&2
                export RESIZEERROR='1'
                export RESIZEERROR_NONFATAL=1
                return 1
            fi
        fi

        if [ $sectorSIZE -lt $sectorNEW ]; then
            test -n "$CONFIG_splash" && /usr/bin/splash --infinitebar --msgtxt="init: sd card resize..."
            test -n "$CONFIG_splash" || echo '
8888888b.  8888888888  .d8888b.  8888888 8888888888P 8888888 888b    888  .d8888b.
888   Y88b 888        d88P  Y88b   888         d88P    888   8888b   888 d88P  Y88b
888    888 888        Y88b.        888        d88P     888   88888b  888 888    888
888   d88P 8888888     "Y888b.     888       d88P      888   888Y88b 888 888
8888888P"  888            "Y88b.   888      d88P       888   888 Y88b888 888  88888
888 T88b   888              "888   888     d88P        888   888  Y88888 888    888
888  T88b  888        Y88b  d88P   888    d88P         888   888   Y8888 Y88b  d88P
888   T88b 8888888888  "Y8888P"  8888888 d8888888888 8888888 888    Y888  "Y8888P88'

            #if parted -s $DEV unit s resizepart $PART $(( $sectorSTART + $sectorNEW ))s; then
            if parted -s $DEV unit % resizepart $PART 100%; then
                echo "Partition $PART resized..."
                export sectorRESIZED=1
            else
                echo "Resizing failed..."
                export RESIZEERROR="1"
            fi
            partprobe
            get_partdata
        else
            export RESIZEERROR="0"
        fi
    fi

    [ "$RESIZEERROR" -lt '0' ] && return 0 || return $RESIZEERROR
}

resize_ext4() {
    if [ "$FSCHECK" = "ext4" ] && [ "$RESIZEERROR" -eq "0" -o -n "$RESIZEERROR_NONFATAL" ] && [ "$CONFIG_noresizesd" -eq '0' -a -x /sbin/resize2fs ]; then

        # check if the partition needs resizing
        [ -e /etc/mtab ] || ln -s /proc/mounts /etc/mtab
        TUNE2FS=$(/sbin/tune2fs -l ${CONFIG_root})
        TUNEBLOCKSIZE=$(echo -e "${TUNE2FS}" | grep "Block size" | awk '{printf "%d", $3}')
        TUNEBLOCKCOUNT=$(echo -e "${TUNE2FS}" | grep "Block count" | awk '{printf "%d", $3}')
        export BLOCKNEW=$(($sectorNEW / ($TUNEBLOCKSIZE / 512) ))

        # resize root partition
        if [ "$TUNEBLOCKCOUNT" -lt "$BLOCKNEW" ]; then
            test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="init: fs resize..."
            test -n "$CONFIG_splash" || echo '
8888888b.  8888888888  .d8888b.  8888888 8888888888P 8888888 888b    888  .d8888b.
888   Y88b 888        d88P  Y88b   888         d88P    888   8888b   888 d88P  Y88b
888    888 888        Y88b.        888        d88P     888   88888b  888 888    888
888   d88P 8888888     "Y888b.     888       d88P      888   888Y88b 888 888
8888888P"  888            "Y88b.   888      d88P       888   888 Y88b888 888  88888
888 T88b   888              "888   888     d88P        888   888  Y88888 888    888
888  T88b  888        Y88b  d88P   888    d88P         888   888   Y8888 Y88b  d88P
888   T88b 8888888888  "Y8888P"  8888888 d8888888888 8888888 888    Y888  "Y8888P88';
            e2fsck -p -f ${CONFIG_root}
            /bin/mount -t ext4 ${CONFIG_root} "$CONFIG_newroot"
            TUNEBLOCKCOUNT=$(/sbin/resize2fs ${CONFIG_root} | grep now | rev | awk '{print $3}' | rev)
            if [ "$?" -eq '0' ]; then
                TUNEBLOCKCOUNT=${BLOCKNEW}
            fi
            umount ${CONFIG_root}

            # check if parition was actually resized
            if [ "${TUNEBLOCKCOUNT}" -lt "${BLOCKNEW}" ]; then
                echo "Resizing failed..."
                export RESIZEERROR="1"
            else
                echo "Filesystem resized..."
            fi
            #e2fsck -p -f ${CONFIG_root}
        fi
    fi
}

resize_btrfs() {
    if [ "$FSCHECK" = 'btrfs' ] && [ "$RESIZEERROR" -eq "0" -o -n "$RESIZEERROR_NONFATAL" ] && [ "$CONFIG_noresizesd" -eq '0' -a "$CONFIG_rootfstype" = "btrfs" ]; then

        if [ -n "$sectorRESIZED" ] || [ "$(df -B512 -P $CONFIG_newroot | awk 'END{print $2}')" -lt "$sectorSIZE" ]; then
            test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="init: $1"
            test -n "$CONFIG_splash" || echo '
8888888b.  8888888888  .d8888b.  8888888 8888888888P 8888888 888b    888  .d8888b.
888   Y88b 888        d88P  Y88b   888         d88P    888   8888b   888 d88P  Y88b
888    888 888        Y88b.        888        d88P     888   88888b  888 888    888
888   d88P 8888888     "Y888b.     888       d88P      888   888Y88b 888 888
8888888P"  888            "Y88b.   888      d88P       888   888 Y88b888 888  88888
888 T88b   888              "888   888     d88P        888   888  Y88888 888    888
888  T88b  888        Y88b  d88P   888    d88P         888   888   Y8888 Y88b  d88P
888   T88b 8888888888  "Y8888P"  8888888 d8888888888 8888888 888    Y888  "Y8888P88'
            if ! btrfs fi resize max $CONFIG_newroot; then
                export RESIZEERROR="1"
            fi
            btrfs fi sync $CONFIG_newroot
        fi
    fi
}

resize_zfspool() {
    if [ "$RESIZEERROR" -eq "0" -a "$CONFIG_noresizesd" -eq '0' -a "$CONFIG_rootfstype" = "zfs" ]; then
        if [ "$(zpool get -H -o value autoexpand $CONFIG_zfspool)" != on ]; then
            zpool set autoexpand=on $CONFIG_zfspool
            zpool export $CONFIG_zfspool
            dd if=/dev/zero of=${DEV} bs=512 count=2048 seek=$(( $sectorEND - 2047 )) 2>/dev/null
            sync
            #sync && sleep 0.5 && partprobe
            zpool import -fN $CONFIG_zfspoolid
            zfs list # Debug
            zpool online -e $CONFIG_zfspool "${DEV##*/}${PARTdelim}${PART}"
            zfs list # Debug
            #partprobe
            #sync && sleep 1.5 && partprobe
            #zfs list # Debug
        fi
    fi
}

move_root() {
    [ ! -e /etc/blkid.tab ] || cp /etc/blkid.tab $CONFIG_newroot/etc
    [ ! -e /etc/resolv.conf -o -e $CONFIG_newroot/etc/resolv.conf ] || cp /etc/resolv.conf $CONFIG_newroot/etc

    for d in run dev sys proc; do
        mount --move /$d $CONFIG_newroot/$d
        rm -fr /$d
        ln -s $CONFIG_newroot/$d /$d
    done

    udevadm control --exit
    if [ -e /etc/udev/udev.conf ]; then
        . /etc/udev/udev.conf
    fi
}

create_swap() {
    if [ "$RESIZEERROR" -eq "0" -a -n "$CONFIG_partswap" -a "$CONFIG_rootfstype" = "btrfs" -a "$FSCHECK" = 'btrfs' ]; then

        [ -n "$haveSWAP" ] && return 0
        [ "$PART" -eq 4 ] && return 1

        if [ "$NRPART" -gt 4 ]; then
            ptype=logical
        else
            ptype=primary
        fi
        if [ "$NRPART" -gt "$PART" ]; then
            pstart=$(( ( $sectorUSED/2048 + 1 ) * 2048 ))
            if ! parted -s ${DEV} -a none mkpart $ptype linux-swap ${pstart}s $(( $pstart + $CONFIG_partswap*1024*2 ))s 2>/dev/null; then
                pstart=$(( ( $sectorUSED/2048 + 2 ) * 2048 ))
                parted -s ${DEV} -a none mkpart $ptype linux-swap ${pstart}s $(( $pstart + $CONFIG_partswap*1024*2 ))s
            fi
            if [ $? -eq 0 ]; then
                partprobe
                swapoff -a  # make sure that swap is turned off when making swap
                mkswap ${DEV}${PARTdelim}$(($NRPART+1))
            fi
            if [ $? -ne 0 ]; then
                echo "Creating of swap failed..."
            fi
        else
            mount_root_btrfs $CONFIG_root && resize_btrfs "creating swap..."
            mountpoint -q $CONFIG_newroot || return 1

            swapsize=$(( $sectorSIZE /10/2/1024)); [ $swapsize -gt $CONFIG_partswap ] && swapsize=$CONFIG_partswap

            btrfs fi resize max $CONFIG_newroot && btrfs fi resize -${swapsize}M $CONFIG_newroot || { umount $CONFIG_newroot; return 1; }
            btrfs fi sync $CONFIG_newroot
            umount $CONFIG_newroot

            sectorSWAP=$(( ( $swapsize - 5 ) * 1024*2 ))
            if parted $DEV resizepart $PART $(( $sectorSTART + $(( $sectorSIZE - $sectorSWAP )) - 1 ))s yes 2>/dev/null; then
                echo "Partition $PART shrinked..."
                partprobe
                get_partdata
                if [ "$NRPART" -gt 4 ]; then
                    pend=$sectorexEND
                else
                    pend=$(( $sectorTOTAL - 1 ))
                fi
                pstart=$(( ( $sectorEND/2048 + 1 ) * 2048 ))
                if ! parted -s ${DEV} -a none unit s mkpart $ptype linux-swap ${pstart}s ${pend}s 2>/dev/null; then
                    pstart=$(( ( $sectorEND/2048 + 2 ) * 2048 ))
                    parted -s ${DEV} -a none unit s mkpart $ptype linux-swap ${pstart}s ${pend}s
                fi
                if [ $? -eq 0 ]; then
                    partprobe
                    swapoff -a	# make sure that swap is turned off when making swap
                    mkswap ${DEV}${PARTdelim}$(($PART+1))
                fi
                if [ $? -ne 0 ]; then
                    echo "Creating of swap failed..."
                fi
            else
                 export RESIZEERROR="1"
                 echo "Shrinking of partition $PART failed..."
            fi
            get_partdata
        fi
    elif [ "$RESIZEERROR" -eq "0" -a -n "$CONFIG_partswap" -a "$CONFIG_rootfstype" = "zfs" ]; then
        if [ ! -b /dev/zvol/$CONFIG_zfspool/swap ]; then
            test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="init: creating swap..."
            zfs create -V ${CONFIG_partswap}M -b $(getconf PAGESIZE) -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false $CONFIG_zfspool/swap
            sync && sleep 1.0
        fi
        if ! parted -m -s /dev/zvol/$CONFIG_zfspool/swap print 2>/dev/null | grep -q "linux-swap(v[0-9])"; then
            echo "format swap /dev/zvol/$CONFIG_zfspool/swap"
            mkswap /dev/zvol/$CONFIG_zfspool/swap
        fi
    fi
}

kill_splash() {
    test -n "$CONFIG_splash" && { kill $(pidof splash) 2>/dev/null; kill $(pidof splash-daemon) 2>/dev/null; }
    rm -fr /run/splash
    setconsole -r
}

drop_shell() {
    set +x
    touch /run/no_debug
    kill_splash

    mount_boot() {
        { grep -sq /boot.*nfs $CONFIG_newroot/etc/fstab && mount $(awk '/\/boot/{sub(",private","",$0);printf "%s -o %s,vers=4", $1, $4}' $CONFIG_newroot/etc/fstab) /boot; } \
          || { [ -e $CONFIG_newroot/etc/fstab ] && mount $(awk '/\/boot/{print $1}' $CONFIG_newroot/etc/fstab) /boot; } \
          || { grep -sq /boot.*nfs /etc/fstab && mount $(awk '/\/boot/{sub(",private","",$0);printf "%s -o %s,vers=4", $1, $4}' /etc/fstab) /boot; } \
          || { [ -e /etc/fstab ] && mount $(awk '/\/boot/{print $1}' /etc/fstab) /boot; } \
          || mount /dev/mmcblk0p1 /boot
    }

    mkdir -p /boot

    if [ "$1" != noumount ]; then
        mountpoint -q $CONFIG_newroot || $mount_bin -t ${CONFIG_rootfstype} -o rw,"$CONFIG_rootfsopts" "${CONFIG_root}" $CONFIG_newroot
        mount_boot
        mountpoint -q $CONFIG_newroot/proc || /bin/mount -o bind /proc $CONFIG_newroot/proc
        mountpoint -q $CONFIG_newroot/boot || /bin/mount -o bind /boot $CONFIG_newroot/boot
        mountpoint -q $CONFIG_newroot/dev || /bin/mount -o bind /dev $CONFIG_newroot/dev
        mountpoint -q $CONFIG_newroot/dev/pts || /bin/mount -o bind /dev $CONFIG_newroot/dev/pts
        mountpoint -q $CONFIG_newroot/sys || /bin/mount -o bind /sys $CONFIG_newroot/sys
        mountpoint -q $CONFIG_newroot/run || /bin/mount -o bind /run $CONFIG_newroot/run
        [ "$CONFIG_rootfstype" = btrfs ] && ! mountpoint -q $CONFIG_newroot/lib/modules  && /bin/mount -t ${CONFIG_rootfstype} -o rw,subvol=modules/@ "${CONFIG_root}" $CONFIG_newroot/lib/modules
    else
        mount_boot
    fi
    mountpoint -q $CONFIG_newroot && ln -s /rootfs /run/initramfs/rootfs
    set_time
    [ -n "${CONFIG_console}" ] && exec > /dev/$CONFIG_console
    cat /motd
    echo "===================================================================="
    cat /howto.txt
    if [ -f /bin/bash -a ! -h /bin/bash ]; then
        setsid cttyhack /bin/bash
    else
        ENV=/.profile setsid cttyhack /bin/sh
    fi
    rm -f /run/do_drop
    unset CONFIG_rescue_early; unset CONFIG_rescue; unset CONFIG_rescue_late
    pkill sshrun

    mountpoint -q /boot && umount /boot; [ -d /boot ] && rmdir /boot
    if [ "$1" != noumount ]; then
        mountpoint -q $CONFIG_newroot/boot && umount $CONFIG_newroot/boot
        mountpoint -q $CONFIG_newroot/proc && umount $CONFIG_newroot/proc
        mountpoint -q $CONFIG_newroot/dev/pts && umount $CONFIG_newroot/dev/pts
        mountpoint -q $CONFIG_newroot/dev && umount $CONFIG_newroot/dev
        mountpoint -q $CONFIG_newroot/sys && umount $CONFIG_newroot/sys
        mountpoint -q $CONFIG_newroot/run && umount $CONFIG_newroot/run
        mountpoint -q $CONFIG_newroot/lib/modules && umount $CONFIG_newroot/lib/modules
        mountpoint -q $CONFIG_newroot && umount -l $CONFIG_newroot
    fi
    return 0
}

load_modules() {
    export MODPROBE_OPTIONS='-qb'
    echo "Loading initram modules ... "
    grep '^[^#]' /etc/modules |
        while read module args; do
            [ -n "$module" ] || continue
            [ "$module" != usb_storage ] || continue
            /sbin/modprobe $MODPROBE_OPTIONS $module $args || :
        done
}
