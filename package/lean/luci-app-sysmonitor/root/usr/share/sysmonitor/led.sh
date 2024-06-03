#!/bin/sh

[ -f /tmp/led.run ] && exit
[ ! -f /tmp/led.pid ] && echo 0 >/tmp/led.pid
[ "$(cat /tmp/led.pid)" != 0 ] && exit

touch /tmp/led.run
NAME=sysmonitor
APP_PATH=/usr/share/$NAME
SYSLOG='/var/log/sysmonitor.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$SYSLOG
	number=$(cat $SYSLOG|wc -l)
	[ $number -gt 25 ] && sed -i '1,10d' $SYSLOG
}


uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

sys_exit() {
	[ -f /tmp/led.run ] && rm -rf /tmp/led.run
	syspid=$(cat /tmp/led.pid)
	syspid=$((syspid-1))
	echo $syspid > /tmp/led.pid

	exit 0
}
echolog "led control is up."
syspid=$(cat /tmp/led.pid)
syspid=$((syspid+1))
echo $syspid > /tmp/led.pid

sw1=$(cat /sys/kernel/debug/gpio|grep sw1|sed 's/in//g'|sed 's/[[:space:]]//g'|cut -d')' -f2)
sw2=$(cat /sys/kernel/debug/gpio|grep sw2|sed 's/in//g'|sed 's/[[:space:]]//g'|cut -d')' -f2)
case $sw1 in
	hi)
		case $sw2 in
			hi)
				uci set sysmonitor.sysmonitor.led=1
				uci commit sysmonitor
				touch /tmp/ledonoff.sign
				;;
			lo)
				uci set sysmonitor.sysmonitor.led=0
				uci commit sysmonitor
				touch /tmp/ledonoff.sign
				;;
		esac
		;;
	lo)
		uci set sysmonitor.sysmonitor.led=1
		uci commit sysmonitor
		touch /tmp/ledonoff.sign
		case $sw2 in
			hi)
				uci set sysmonitor.sysmonitor.led='-'
				uci commit sysmonitor
				echo "- 100 3000" > /tmp/led.flash
				;;
		esac
		;;
esac
num=0
while [ "1" == "1" ]; do
	prog='sysmonitor'
	for i in $prog
	do
		progsh=$i'.sh'
		progpid='/tmp/'$i'.pid'
		[ "$(pgrep -f $progsh|wc -l)" == 0 ] && echo 0 > $progpid
		[ ! -f $progpid ] && echo 0 > $progpid
		arg=$(cat $progpid)
		case $arg in
			0)
				[ "$(pgrep -f $progsh|wc -l)" != 0 ] && killall $progsh
				progrun='/tmp/'$i'.run'
				[ -f $progrun ] && rm $progrun
				[ -f $progpid ] && rm $progpid
				$APP_PATH/$progsh &
				;;
			1)
				;;
			*)
				killall $progsh
				echo 0 > $progpid
				;;
		esac	
	done
	if [ -f /tmp/delay.sign ]; then
		while read i
		do
			prog=$(echo $i|cut -d'=' -f2)
			[ -n $(echo $prog|cut -d' ' -f2) ] && prog=$(echo $prog|cut -d' ' -f2)
			sed -i "/$prog/d" /tmp/delay.list
			echo $i >> /tmp/delay.list
		done < /tmp/delay.sign
		rm /tmp/delay.sign
	fi
	if [ -f /tmp/delay.list ]; then
		touch /tmp/delay.tmp
		while read line
		do
   			num=$(echo $line|cut -d'=' -f1)
			prog=$(echo $line|cut -d'=' -f2-)
			if [ "$num" -gt 0 ];  then
				num=$((num-1))
				tmp=$num'='$prog
				echo $tmp >> /tmp/delay.tmp
			else
			[ "$num" == 0 ] && $prog &
			fi
		done < /tmp/delay.list
		mv /tmp/delay.tmp /tmp/delay.list	
	fi
	if [ -f /tmp/ledonoff.sign ]; then
		led=$(uci_get_by_name $NAME $NAME led 1)
		case $led in
			0)
				echo 0 > /sys/class/leds/tp-link:blue:system/brightness
				;;
			1)
				echo 0 > /sys/class/leds/tp-link:blue:system/brightness
				echo 255 > /sys/class/leds/tp-link:blue:system/brightness
				;;
			*)
				echo "- 100 2000" > /tmp/led.flash
				;;
		esac
		rm /tmp/ledonoff.sign
	fi
	if [ -f /tmp/led.flash ]; then
		led=$(cat /tmp/led.flash)
		ledtime=$(echo $led|cut -d' ' -f1)
		ledon=$(echo $led|cut -d' ' -f2)
		ledoff=$(echo $led|cut -d' ' -f3)		
		echo timer > /sys/class/leds/tp-link:blue:system/trigger
		echo $ledon > /sys/class/leds/tp-link:blue:system/delay_on
		echo $ledoff > /sys/class/leds/tp-link:blue:system/delay_off
		rm /tmp/led.flash
		touch /tmp/ledflash.sign
	fi
	if [ -f /tmp/ledflash.sign ]; then
	case $ledtime in
		-)
			rm /tmp/ledflash.sign
			;;
		0)
			touch /tmp/ledonoff.sign
			rm /tmp/ledflash.sign
			;;
		*)
			ledtime=$((ledtime-1))
	esac
	fi
	[ ! -f /tmp/led.run ] && sys_exit
	[ "$(cat /tmp/led.pid)" -gt 1 ] && sys_exit
	sleep 1
	num=$((num+1))
done
