#!/bin/sh

find ./xbian-package-initramfs-tools  -type f | grep -v DEBIAN/ | xargs md5sum > ./xbian-package-initramfs-tools/DEBIAN/md5sums 
dpkg-deb -b ./xbian-package-initramfs-tools xbian-package-initramfs-tools-1.0.deb