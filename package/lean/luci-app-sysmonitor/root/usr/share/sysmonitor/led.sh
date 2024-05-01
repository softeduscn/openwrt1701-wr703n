#!/bin/sh

[ -f /tmp/led.run ] && exit
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
	exit 0
}
echolog "led control is up."
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
	if [ -f /tmp/delay.sign ]; then 
		cat /tmp/delay.sign >> /tmp/delay.list
		rm /tmp/delay.sign
	fi
	if [ -f /tmp/delay.list ]; then
		touch /tmp/delay.tmp
		while read line
		do
   			num=$(echo $line|cut -d'-' -f1)
			prog=$(echo $line|cut -d'-' -f2-)
			if [ "$num" != 0 ];  then
				num=$((num-1))
				tmp=$num'-'$prog
				echo $tmp >> /tmp/delay.tmp
			else
				$prog
			fi
		done < /tmp/delay.list
		if [ -n "$(cat /tmp/delay.tmp)" ]; then
			mv /tmp/delay.tmp /tmp/delay.list
		else
			rm /tmp/delay.tmp
			rm /tmp/delay.list
		fi	
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
	sleep 1
	num=$((num+1))
done
