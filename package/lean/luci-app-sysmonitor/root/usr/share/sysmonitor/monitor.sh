#!/bin/sh

[ -f /tmp/sysmonitor.run ] && exit
[ "$(cat /tmp/sysmonitor.pid)" != 0 ] && exit

NAME=sysmonitor
APP_PATH=/usr/share/$NAME
$APP_PATH/sysmonitor.sh &

#[ ! -f /tmp/led.run ] && $APP_PATH/led.sh &
