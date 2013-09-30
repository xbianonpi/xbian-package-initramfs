#!/bin/sh

touch /tmp/output.grab
tail -f /tmp/output.grab &

info="start"
while [ ! -e /run/splash_updater.kill ]; do
	oldinfo="$info"
	info=$(tail -n1 /tmp/output.grab)
	test -n "$info" && test "$info" != "$oldinfo" && test -n "$CONFIG_splash" && /usr/bin/splash --msgtxt="$info"
	sleep 1
done

pkill tail
rm /run/splash_updater.kill
