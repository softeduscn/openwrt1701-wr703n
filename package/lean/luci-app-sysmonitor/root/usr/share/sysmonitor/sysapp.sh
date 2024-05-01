#!/bin/sh

NAME=sysmonitor
APP_PATH=/usr/share/$NAME
SYSLOG='/var/log/sysmonitor.log'
[ ! -f /tmp/sysmonitor.pid ] && echo 0 >/tmp/sysmonitor.pid

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$SYSLOG
	number=$(cat $SYSLOG|wc -l)
	[ $number -gt 25 ] && sed -i '1,10d' $SYSLOG
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

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_get_by_type() {
	local ret=$(uci get $1.@$2[0].$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

uci_set_by_type() {
	uci set $1.@$2[0].$3=$4 2>/dev/null
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


getip() {
	ifname=$(uci get network.wan6.ifname)
	ip=$(check_ip $(ip -o -4 addr list $ifname | cut -d ' ' -f7 | cut -d'/' -f1))
	[ ! -n "$ip" ] && ip=$(gethost $(ip -o -4 addr list br-lan | cut -d ' ' -f7|cut -d'/' -f1))
	echo $ip
}

getip6() {
	ifname=$(uci get network.wan6.ifname)
	echo $(ip -o -6 addr list $ifname | cut -d ' ' -f7 | cut -d'/' -f1 |head -n1)
}

getgateway() {
	echo $(route |grep default|sed 's/default[[:space:]]*//'|sed 's/[[:space:]].*$//')
}

wanswitch() {
	if [ -n "$1" ]; then
		proto=$1
	else
		proto="dhcp"
		[ "$(uci get network.wan.proto)" == 'dhcp' ] && proto="static"		
	fi
	if [ $proto == "static" ] ; then
		sed -i '/wan/,$d' /etc/config/network
		wanip=$(uci_get_by_name $NAME $NAME wan '192.168.1.188')
		gatewayip=$(uci_get_by_name $NAME $NAME gateway '192.168.1.1')
		mask=$(uci_get_by_name $NAME $NAME mask '255.255.255.0')
		dnslist=$(uci_get_by_name $NAME $NAME dns '192.168.1.1')
cat >> /etc/config/network <<EOF
config interface 'wan'
	option ifname 'eth0'
	option proto 'static'
	option ipaddr '$wanip'
	option netmask '$mask'
	option gateway '$gatewayip'
	option dns '$dnslist'
	option type 'bridge'

config interface 'wan6'
	option proto 'dhcpv6'
	option reqaddress 'try'
	option reqprefix 'auto'
	option ifname 'br-wan'
EOF
		echo "set to static"
		ifup wan
	else
		sed -i '/wan/,$d' /etc/config/network
cat >> /etc/config/network <<EOF
config interface 'wan'
	option ifname 'eth0'
	option proto 'dhcp'
	option hostname 'MUSIC'
	option type 'bridge'

config interface 'wan6'
	option proto 'dhcpv6'
	option ifname 'br-wan'
	option reqaddress 'try'
	option reqprefix 'auto'
EOF
		echo "set to dhcp"
		ifup wan
	fi
	if [ ! $(uci get dhcp.lan.ra) == 'relay' ]; then
	uci set dhcp.lan.dhcpv6='relay'
	uci set dhcp.lan.ndp='relay'
	uci set dhcp.lan.ra='relay'
	uci set dhcp.wan.dhcpv6='relay'
	uci set dhcp.wan.ndp='relay'
	uci set dhcp.wan.ra='relay'
	uci set dhcp.wan.master='1'
	uci commit dhcp
	fi
	/etc/init.d/odhcpd restart
	echolog "wan proto set to "$(uci get network.wan.proto)
}

unftp() {
	webdavrw=$(uci_get_by_name $NAME $NAME webdav_rw 0)
	sed -i "s|#||g" /etc/lighttpd/conf.d/30-webdav.conf
	if [ "$webdavrw" == 1 ]; then
		sed -i "s|^webdav.is-readonly|#webdav.is-readonly|g" /etc/lighttpd/conf.d/30-webdav.conf
	else
		sed -i "s|^#webdav.is-readonly|webdav.is-readonly|g" /etc/lighttpd/conf.d/30-webdav.conf
	fi
	/etc/init.d/lighttpd restart
	ftprw=$(uci_get_by_name $NAME $NAME ftp_rw 0)
	if [ "$ftprw" == 0 ]; then
		sed -i "s|^write_enable=.*|write_enable=NO|g" /etc/vsftpd.conf
	else
		sed -i "s|^write_enable=.*|write_enable=YES|g" /etc/vsftpd.conf
	fi
	name=$(ls -F /var/ftp|grep '/$')
#	name=$(ls -F /var/ftp|grep '/$'|sed '/upload/d')
	for n in $name
	do
		umount /var/ftp/$n
		rmdir /var/ftp/$n 
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

check_dir() {
	str=$(uci_get_by_name $NAME $NAME $1 '')','
	str=$(echo $str|sed 's/,,/,/g')
	num=$(echo $str|awk -F"," '{print NF-1}')
	a=1
	while [ $a -le $num ]
	do
 	  	dir=$(echo $str|cut -d',' -f $a)
		[ $dir == $2 ] && {
			echo $2
			break
		}
   		a=`expr $a + 1`
	done
	echo ""
}

samba() {
	[ -f /tmp/music ] && exit
	touch /tmp/music
	[ ! -d /var/ftp ] && {
		mkdir /var/ftp
		chmod 755 /var/ftp
#		touch /var/ftp/welcome
	}
#	[ ! -d /var/ftp/upload ] && {
#		mkdir /var/ftp/upload
#		chmod 777 /var/ftp/upload
#	}

	syspath='/mnt/'
	rmdir $syspath* 2>/dev/null
	sed -i '/sambashare/,$d' /etc/config/samba
	unftp
echo "" >/etc/exports
cat > /etc/config/nfs <<EOF
config share
	option clients '*'
	option options 'rw,sync,root_squash,all_squash,insecure,no_subtree_check'
	option enabled '1'
	option path '/mnt'
EOF
	[ $(uci_get_by_name $NAME $NAME nfs 0) == 0 ] && /etc/init.d/nfs stop &
	[ $(uci_get_by_name $NAME $NAME ftp 0) == 0 ] && /etc/init.d/vsftpd stop &
	[ $(uci_get_by_name $NAME $NAME samba 0) == 0 ] && /etc/init.d/samba stop &
	status=$(ls -F $syspath|grep '/$'| grep 'sd[a-z][1-9]')
	[ "$status" == "" ] && {
		status=$(cat /var/log/sysmonitor.log|sed '/^[  ]*$/d'|sed -n '$p'|grep "No usb devices finded! please insert")
		[ ! -n "$status"  ] &&  echolog "No usb devices finded! please insert ..."
#		[ $(uci_get_by_name $NAME $NAME nfs 0) == 1 ] && /etc/init.d/nfs start &
		[ $(uci_get_by_name $NAME $NAME ftp 0) == 1 ] && /etc/init.d/vsftpd start &
		[ $(uci_get_by_name $NAME $NAME samba 0) == 1 ] && /etc/init.d/samba start &
		rm /tmp/music
		echo "1 50 50" > /tmp/led.flash
		exit
	}
	echo "1 100 100" > /tmp/led.flash
	syspath=$syspath$status
	name=$(uci_get_by_name $NAME $NAME initial_dir '')
	name=$(echo $name|sed 's/ //g')
	name=$(echo $name|sed 's/\///g')
	name=$(echo $name|sed 's/,,/,/g')
	name=$(echo $name|sed 's/,/ /g')
#for aria2
#	[ ! -n "$name"  ] && name='music aria2'
	[ ! -n "$name"  ] && name='music'
	for n in $name
	do
	[ ! -d $syspath$n ] && {
		mkdir $syspath$n
		chmod -R 777 $syspath$n
	}
	done
#	[ $(ps |grep aria2|grep -v grep|wc -l) == 0 ] && /etc/init.d/aria2 restart &
#	[ -n $(pgrep aria2) ] && /etc/init.d/aria2 restart &
	name=$(ls $syspath |sed '/System Volume/d')
	[ "$name" == "" ] && {
		status=$(cat /var/log/sysmonitor.log|sed '/^[  ]*$/d'|sed -n '$p'|grep "No samba/nfs share directory")
		[ ! -n "$status"  ] &&  echolog "No samba/nfs/vsftpd share directory..."
		[ $(uci_get_by_name $NAME $NAME nfs 0) == 1 ] && /etc/init.d/nfs start &
		[ $(uci_get_by_name $NAME $NAME ftp 0) == 1 ] && /etc/init.d/vsftpd start &
		[ $(uci_get_by_name $NAME $NAME samba 0) == 1 ] && /etc/init.d/samba start &
		rm /tmp/music
		exit
	}
echo "" > /etc/config/nfs
for n in $name
do
if [ -d "$syspath$n" ]; then
	[ $(uci_get_by_name $NAME $NAME samba 0) == 1 ] && {
	right=$(uci_get_by_name $NAME $NAME samba_rw 0)
	if [ $right == 0 ]; then
		right='yes'
		status=$(check_dir samba_rw_dir $n)
		[ -n "$status" ] && right='no'
	else
		right='no'
	fi
cat >> /etc/config/samba <<EOF
config sambashare
	option name '$n'
	option path '$syspath$n'
	option read_only '$right'
	option guest_ok 'yes'
	option create_mask '0777'
	option dir_mask '0777'

EOF
	echolog "Samba name: ["$n"] path:["$syspath$n"]"
	}

	[ $(uci_get_by_name $NAME $NAME nfs 0) == 1 ] && {
	right=$(uci_get_by_name $NAME $NAME nfs_rw 0)
	if [ $right == 0 ]; then
		right='ro'
		status=$(check_dir nfs_rw_dir $n)
		[ -n "$status" ] && right='rw'
	else
		right='rw'
	fi
cat >> /etc/config/nfs <<EOF
config share
	option clients '*'
	option options '$right,sync,root_squash,all_squash,insecure,no_subtree_check'
	option enabled '1'
	option path '$syspath$n'

EOF
	echolog "NSF path: ["$syspath$n"]"
	}

	if [ $(uci_get_by_name $NAME $NAME ftp 0) == 1 ]; then
		mkdir /var/ftp/$n
		mount --bind $syspath$n /var/ftp/$n
		echolog "FTP path: [/var/ftp/"$n"]"
	fi
fi
done
	if [ $(uci_get_by_name $NAME $NAME samba 0) == 1 ]; then
	 	/etc/init.d/samba restart &
	else
		echolog "Samba stop....."
	fi
	if [ $(uci_get_by_name $NAME $NAME nfs 0) == 1 ]; then
		/etc/init.d/nfs restart &
	else
		echolog "NFS stop......"
	fi
	if [ $(uci_get_by_name $NAME $NAME ftp 0) == 1 ]; then
		/etc/init.d/vsftpd restart &
	else
		echolog "FTP stop......"
	fi
	rm /tmp/music
}

webdav() {
	syspath=$1
	file='/etc/lighttpd/lighttpd.conf'
	[ -n "$syspath" ] && {
		echolog "Webdav path: ["$syspath"]"
		cat $file | grep $syspath >/dev/null
		if [ ! $? -eq 0 ];then
			sed -i "s|server.document-root.*$|server.document-root        = \"$syspath\"|" $file
			/etc/init.d/lighttpd restart &
		fi
	}
}

vsftpd() {
	syspath=$1
	[ -n "$syspath" ] && {
		echolog "Vsftpd path: ["$syspath"]"
		file='/etc/vsftpd.conf'
		cat $file | grep $syspath >/dev/null
		if [ ! $? -eq 0 ];then
			sed -i "/local_root=/d" $file
			echo "local_root="$syspath >> $file
			/etc/init.d/vsftpd restart &
		fi
	}
}

setdns() {
	dnslist=$(uci_get_by_name $NAME $NAME dns '192.168.1.1')
	if [ "$(uci get network.wan.proto)" == "static" ];then
		echolog "WAN DNS="$dnslist
		uci set network.wan.dns="$dnslist"
		uci commit network
		/etc/init.d/odhcpd start
		ifup wan
		ifup wan6
	fi
}

re_sysmonitor() {
arg=$(cat /tmp/sysmonitor.pid)
case $arg in
	0)
		#[ "$(ps |grep -v grep|grep sysmonitor.sh|wc -l)" != 0 ] && arg=2
		[ -n "$(pgrep -f sysmonitor.sh)" ] && arg=2
		;;
	*)
		#[ "$(ps |grep -v grep|grep sysmonitor.sh|wc -l)" == 0 ] && arg=0
		[ ! -n "$(pgrep -f sysmonitor.sh)" ] && arg=0
		;;
esac
case $arg in
	0)
		[ -f /tmp/sysmonitor.run ] && rm -rf /tmp/sysmonitor.run
		echo 0 > /tmp/sysmonitor.pid
		/usr/share/sysmonitor/monitor.sh
	;;
	1)
		echo "Update sysmonitor."
		touch /tmp/sysmonitor
	;;
	*)
		echo "Killed sysmonitor & restart it!"
		echolog "sysmonitor is killed & start!"
		killall sysmonitor.sh
		[ -f /tmp/sysmonitor.run ] && rm /tmp/sysmonitor.run
		echo 0 > /tmp/sysmonitor.pid
		/usr/share/sysmonitor/monitor.sh
	;;
esac
}

gethost() {
	if [ -n "$1" ]; then
		hostip=$1		
	else
		hostip=$(uci get network.lan.ipaddr)
	fi
	host=$(nslookup $hostip|grep name|cut -d'=' -f2|cut -d' ' -f2)
	[ ! -n "$host" ] && host=$hostip
	echo $host
}

sysbutton() {
	case $1 in
	wantitle)
		proto='Set dhcp'
		ip=$(getip)
		[ "$(uci get network.wan.proto)" == 'dhcp' ] && proto='Set static'
		result='<button class=button1><a href="http://'$ip':7681"  target="_blank">Terminal</a></button> <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/sys?sys=wanswitch">'$proto'</a></button>'
		;;
	wan)
		ip=$(getip)
		proto=$(uci get network.wan.proto)
		result='wifi: <a href="/cgi-bin/luci/admin/network/wireless" target="_blank">'$(iw dev|grep ssid|cut -d' ' -f2)'</a> channel: <font color=9699cc>'$(iw dev|grep channel|cut -d'(' -f1)'</font>'
		conn_num=$(iwinfo wlan0 assoclist|grep dBm|wc -l)
		color=''
		[ "$conn_num" != 0 ] && color='<font color=green>connect: '$conn_num'</font>'
		result=$result$color
		result=$result'<BR>lan: <font color=9699cc>'$(uci get network.lan.ipaddr)'</font>'
		result=$result'<BR>wan('
		if [ "$proto" == "dhcp" ]; then
			result=$result'<a href="/cgi-bin/luci/admin/network" target="_blank">'$proto'</a>): <font color=9699cc>'$ip'</font><BR>wan6:<font color=9699cc>['$(getip6)']</font>'
		else
			result=$result'<a href="/cgi-bin/luci/admin/network" target="_blank">'$proto'</a>): <font color=9699cc>'$ip'</font><BR>wan6:<font color=9699cc>['$(getip6)']</font><br>gateway: <font color=9699cc>'$(uci get network.wan.gateway)'</font> <BR>dns:<font color=9699cc>'$(uci get network.wan.dns)'</font>'
		fi
		;;
	nastitle)
		ip=$(getip)
		result='<button class=button1><a href="http://'$ip':7681"  target="_blank">Terminal</a></button>'
		;;
	nas)
		button='<button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/sys?sys=NASrestart">NAS(restart)</a></button>'
		if [ -f /etc/init.d/lighttpd ]; then
			#if [ "$(ps |grep lighttpd|grep -v grep|wc -l)" == 0 ]; then
			if [ ! -n "$(pgrep -f lighttpd)" ]; then
				color='button2'
			else
				color='button1'
			fi
			button=$button' <button class='$color'><a href="/cgi-bin/luci/admin/sys/sysmonitor/sys?sys=NASwebdav">WebDAV</a></button>'
		fi
		if [ -f /etc/init.d/vsftpd ]; then
			#if [ "$(ps |grep vsftpd|grep -v grep|wc -l)" == 0 ]; then
			if [ ! -n "$(pgrep -f vsftpd)" ]; then
				button=$button' <button class=button2><a href="/cgi-bin/luci/admin/sys/sysmonitor/sys?sys=NASvsftp">VSFTP</a></button>'
			else
				button=$button' <button class="button1"><a href="/cgi-bin/luci/admin/services/vsftpd" target="_blank">VSFTP</a></button>'		
			fi
		fi
		if [ -f /etc/init.d/samba ]; then
			#if [ "$(ps |grep smbd|grep -v grep|wc -l)" == 0 ]; then
			if [ ! -n "$(pgrep -f smbd)" ]; then
				button=$button' <button class=button2><a href="/cgi-bin/luci/admin/sys/sysmonitor/sys?sys=NASsamba">SAMBA</a></button>'
			else
				button=$button' <button class=button1><a href="/cgi-bin/luci/admin/services/samba" target="_blank">SAMBA</a></button>'
			fi
		fi
		if [ -f /etc/init.d/nfsd ]; then
			#if [ "$(ps |grep nfsd|grep -v grep|wc -l)" == 0 ]; then
			if [ ! -n "$(pgrep -f nfsd)" ]; then
				button=$button' <button class=button2><a href="/cgi-bin/luci/admin/sys/sysmonitor/sys?sys=NASnfs">NFS</a></button>'
			else
				button=$button' <button class=button1><a href="/cgi-bin/luci/admin/services/nfs" target="_blank">NFS</a></button>'
			fi
		fi
		result=$button
		;;
	esac
echo $result
}

sysmenu() {
case $1 in
	NASrestart)
		echo "1 50 50" > /tmp/led.flash
		/etc/init.d/lighttpd stop
		/etc/init.d/lighttpd start
		/etc/init.d/samba stop
		/etc/init.d/samba start
		/etc/init.d/vsftpd stop
		/etc/init.d/vsftpd start
		/etc/init.d/nfsd stop
		/etc/init.d/nfsd start
		;;
	NASwebdav)
		echo "1 50 50" > /tmp/led.flash
		/etc/init.d/lighttpd stop
		/etc/init.d/lighttpd start
		;;
	NASvsftp)
		echo "1 50 50" > /tmp/led.flash
		/etc/init.d/vsftpd stop
		/etc/init.d/vsftpd start
		;;
	NASsamba)
		echo "1 50 50" > /tmp/led.flash
		/etc/init.d/samba stop
		/etc/init.d/samba start
		;;
	NASnfs)
		echo "1 50 50" > /tmp/led.flash
		/etc/init.d/nfsd stop
		/etc/init.d/nfsd start
		;;
	wanswitch)
		echo "1 50 50" > /tmp/led.flash
		wanswitch
		;;
esac
}

firstrun(){
	[ -n "$(pgrep -f ttyd)" ] && killall ttyd
	/usr/bin/ttyd /bin/login &
	#[ "$(ps |grep -v grep|grep cron|wc -l)" == 0 ] && /etc/init.d/cron start
	[ ! -n "$(pgrep -f cron)" ] && /etc/init.d/cron start
	#sed -i /re_sysmonitor/d /etc/crontabs/root
	#echo "* * * * * /usr/share/sysmonitor/sysapp.sh re_sysmonitor" >> /etc/crontabs/root
	#crontab /etc/crontabs/root
	ifup lan
	wifi reload
	samba
}

[ "$(cat /tmp/sysmonitor.pid)" == 0 ] && re_sysmonitor
arg1=$1
shift
case $arg1 in
sysmenu)
	sysmenu $1
	;;
sysbutton)
	sysbutton $1
	;;	
re_sysmonitor)
	re_sysmonitor
	[ "$(iw dev|grep channel|wc -l)" == 0 ] && wifi reload
	[ -f /tmp/delay.list ] && sed -i '/re_sysmonitor/d' /tmp/delay.list
	echo '55-/usr/share/sysmonitor/sysapp.sh re_sysmonitor' >> /tmp/delay.sign
	;;
setdns)
	setdns
	;;
smartdns)
	smartdns
	;;
vsftpd)
	vsftpd $1
	;;
webdav)
	webdav $1
	;;
samba)
	samba
	;;
wanswitch)
	wanswitch $1
	;;
getip)
	getip
	;;
getip6)
	getip6
	;;
gethost)
	gethost
	;;
getgateway)
	getgateway
	;;
check_dir)
	check_dir $1 $2
	;;
check_ip)
	check_ip $1
	;;
firstrun)
	firstrun
	;;
*)
	echo "error function call"
	;;
esac
