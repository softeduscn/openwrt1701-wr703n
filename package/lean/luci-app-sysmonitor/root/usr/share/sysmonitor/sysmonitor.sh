#!/bin/sh

[ -f /tmp/sysmonitor.run ] && exit
[ ! -f /tmp/sysmonitor.pid ] && echo 0 >/tmp/sysmonitor.pid
[ "$(cat /tmp/sysmonitor.pid)" != 0 ] && exit

sleep_unit=1
NAME=sysmonitor
APP_PATH=/usr/share/$NAME
SYSLOG='/var/log/sysmonitor.log'
touch /tmp/sysmonitor.run
/etc/init.d/nfs disable &

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

ping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(ping -c 1 -W 1 $url | grep -o 'time=[0-9]*.*' | awk -F '=' '{print$2}'|cut -d ' ' -f 1)
		[ "$status" == "" ] && status=0
		[ "$status" != 0 ] && break
	done
	echo $status
}

mask() {
    num=$((4294967296 - 2 ** (32 - $1)))
    for i in $(seq 3 -1 0); do
        echo -n $((num / 256 ** i))
        num=$((num % 256 ** i))
        if [ "$i" -eq "0" ]; then
            echo
        else
            echo -n .
        fi
    done
}

check_ip() {
	if [ ! -n "$1" ]; then
		#echo "NO IP!"
		echo ""
	else
 		IP=$1
    		VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
		if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
			if [ ${VALID_CHECK:-no} == "yes" ]; then
				# echo "IP $IP available."
				echo $IP
			else
				#echo "IP $IP not available!"
				echo ""
			fi
		else
			#echo "IP is name convert ip!"
			dnsip=$(nslookup $IP|grep Address|sed -n '2,2p'|cut -d' ' -f2)
			if [ ! -n "$dnsip" ]; then
				#echo "Inull"
				echo $test
			else
				#echo "again check"
				echo $(check_ip $dnsip)
			fi
		fi
	fi
}

setdns() {
	uci set network.wan.ipaddr=$(uci_get_by_name $NAME $NAME wan '192.168.1.188')
	uci set network.wan.netmask=$(uci_get_by_name $NAME $NAME mask '255.255.255.0')
	uci set network.wan.gateway=$(uci_get_by_name $NAME $NAME gateway '192.168.1.1')
	dnslist=$(uci_get_by_name $NAME $NAME dns '192.168.1.1')
	uci del network.wan.dns
	for n in $dnslist
	do 		
		uci add_list network.wan.dns=$n
	done
	uci commit network
	ifup wan
	ifup wan6
	/etc/init.d/odhcpd restart
}

sys_exit() {
	echolog "Sysmonitor is down."
	[ -f /tmp/sysmonitor.run ] && rm -rf /tmp/sysmonitor.run
	syspid=$(cat /tmp/sysmonitor.pid)
	let syspid=syspid-1
	echo $syspid > /tmp/sysmonitor.pid
	echo "2 50 50" > /tmp/led.flash
	exit 0
}

echolog "Sysmonitor is up."
syspid=$(cat /tmp/sysmonitor.pid)
let syspid=syspid+1
echo $syspid > /tmp/sysmonitor.pid
sysnetwork=1
while [ "1" == "1" ]; do
	ifname='br-wan'
	ip=$(ip -o -4 addr list $ifname | cut -d ' ' -f7|cut -d'/' -f1)
	if [ -n "$ip" ]; then
		cat /www/ip.html | grep "$ip" > /dev/null
		[ $? -ne 0 ] && {
			echo $ip > /www/ip.html
			eecholog "ip="$ip
		}
		ipv6=$(ip -o -6 addr list $ifname | cut -d ' ' -f7)
		if [ ! "$ipv6" == "" ]; then
			cat /www/ip6.html | grep $(echo $ipv6| cut -d'/' -f1 |head -n1) > /dev/null
			[ $? -ne 0 ] && {
				echo $ipv6| cut -d'/' -f1 |head -n1 > /www/ip6.html
				echolog "ip6="$ipv6	
			}
		fi
	fi
	proto=$(uci get network.wan.proto)
	case $proto in
		static)
			sysnetwork=1
			;;
		dhcp)
			if [ "$sysnetwork" == 1 ]; then
				ip=$(ip -o -4 addr list $ifname | cut -d ' ' -f7)
				if [ -n "$ip" ]; then
					wanip=$(check_ip $(echo $ip|cut -d'/' -f1))
					if [ -n "$wanip" ]; then
						mask=$(mask $(echo $ip|cut -d'/' -f2))
						gateway=$(check_ip $(ip route|grep default|cut -d' ' -f3))
						if [ -n "$gateway" ]; then
							echo "1 50 50" > /tmp/led.flash
							uci set sysmonitor.sysmonitor.wan=$wanip
							uci set sysmonitor.sysmonitor.mask=$mask
							uci set sysmonitor.sysmonitor.gateway=$gateway
							uci commit sysmonitor
							sysnetwork=0
						fi
					fi
				fi
			fi
			;;
	esac
	num=0
	check_time=$(uci_get_by_name $NAME $NAME systime 10)
	while [ $num -le $check_time ]; do
		prog='led'
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
		[ "$(iw dev|grep channel|wc -l)" == 0 ] && wifi reload
		[ -n "$(pgrep -f lighttpd)" ] && [ ! -n "$(pgrep -f uhttpd)" ] && /etc/init.d/uhttpd start
		[ ! -n "$(pgrep -f lighttpd)" ] && {
			/etc/init.d/uhttpd stop
			/etc/init.d/lighttpd start
			}
		if [ -f /tmp/network.sign ]; then
			rm /tmp/network.sign
			touch /tmp/ledonoff.sign
			[ "$(uci get network.wan.proto)" == 'static' ] && setdns
		fi
		[ ! -f /tmp/sysmonitor.run ] && sys_exit		
		[ "$(uci_get_by_name $NAME $NAME enable 0)" == 0 ] && sys_exit
		[ "$(cat /tmp/sysmonitor.pid)" -gt 1 ] && sys_exit
		if [ -f /tmp/samba.sign ]; then
			$APP_PATH/sysapp.sh samba &
			rm /tmp/samba.sign
			break
		fi
		let num=num+sleep_unit
		if [ -f "/tmp/sysmonitor" ]; then
			rm /tmp/sysmonitor
			break
		fi
		sleep $sleep_unit
	done
done
