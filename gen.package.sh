#!/bin/sh

package=$(cat ./content/DEBIAN/control | grep Package | awk '{print $2}')
version=$(cat ./content/DEBIAN/control | grep Version | awk '{print $2}')

cat ./content/DEBIAN/control | grep -v "Installed-Size:" > ./content/DEBIAN/control.new
mv ./content/DEBIAN/control.new ./content/DEBIAN/control
printf "Installed-Size: %d\n" $(du -s ./content | awk '{print $1}') >> ./content/DEBIAN/control

fakeroot find ./content  | grep -v DEBIAN/ | sort | xargs md5sum > ./content/DEBIAN/md5sums 
fakeroot dpkg-deb -b ./content "${package}""${version}".deb
