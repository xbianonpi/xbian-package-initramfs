#!/bin/sh

package=$(cat ./content/DEBIAN/control | grep Package | awk '{print $2}')
version=$(cat ./content/DEBIAN/control | grep Version | awk '{print $2}')

fakeroot find ./content  | grep -v DEBIAN/ | xargs md5sum > ./content/DEBIAN/md5sums 
fakeroot dpkg-deb -b ./content "${package}""${version}".deb
