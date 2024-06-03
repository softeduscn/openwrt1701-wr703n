#!/bin/sh

[ -f /tmp/sysmonitor.run ] && exit
[ "$(pgrep -f $progsh|wc -l)" == 0 ] && echo 0 > /tmp/sysmonitor.pid
[ -f /tmp/sysmonitor.run ] && exit

NAME=sysmonitor
APP_PATH=/usr/share/$NAME
$APP_PATH/sysmonitor.sh &

