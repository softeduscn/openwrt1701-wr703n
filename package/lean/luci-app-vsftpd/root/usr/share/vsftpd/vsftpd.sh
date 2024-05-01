#!/bin/sh

NAME=vsftpd
APP_PATH=/usr/share/$NAME
file=/etc/vsftpd.conf

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

general() {
	enable6=$(uci_get_by_name $NAME general enable6 1)
	enable='NO'
	[ "$enable6" == 1 ] && enable='YES'
	vsftpd_enable6='listen_ipv6='$enable
	sed -i "s|^listen_ipv6=.*|$vsftpd_enable6|g" $file
	
	port=$(uci_get_by_name $NAME general port 21)
	vsftpd_port='listen_port='$port
	sed -i "s|^listen_port=.*|$vsftpd_port|g" $file
	
#	dataport=$(uci_get_by_name $NAME general dataport 20)
#	vsftpd_dataport='ftp_data_port='$dataport
#	sed -i "s|ftp_data_port=.*|$vsftpd_dataport|g" $file
	/etc/init.d/vsftpd reload
}

locals() {
	enabled=$(uci_get_by_name $NAME local local_enable 0)
	enable='NO'
	[ "$enabled" == 1 ] && enable='YES'
	vsftpd_enable='local_enable='$enable
	sed -i "s|^local_enable=.*|$vsftpd_enable|g" $file
	
	write=$(uci_get_by_name $NAME local write 0)
	enable='NO'
	[ "$write" == 1 ] && enable='YES'
	vsftpd_write='write_enable='$enable
	sed -i "s|^write_enable=.*|$vsftpd_write|g" $file
	
	download=$(uci_get_by_name $NAME local download 0)
	enable='NO'
	[ "$download" == 1 ] && enable='YES'
	vsftpd_download='download_enable='$enable
	sed -i "s|^download_enable=.*|$vsftpd_download|g" $file
	
#	dirlist=$(uci_get_by_name $NAME local dirlist 0)
	
	root=$(uci_get_by_name $NAME local root '/var')
	vsftpd_root='local_root='$root
	sed -i "s|^local_root=.*|$vsftpd_root|g" $file
	
	umask=$(uci_get_by_name $NAME local umask '033')
	vsftpd_umask='local_umask='$umask
	sed -i "s|^local_umask=.*|$vsftpd_umask|g" $file
	
	mode=$(uci_get_by_name $NAME local mode '0666')
	vsftpd_mode='file_open_mode='$mode
	sed -i "s|^file_open_mode=.*|$vsftpd_mode|g" $file
	/etc/init.d/vsftpd reload
}

anonymous() {
	enabled=$(uci_get_by_name $NAME anonymous anonymous_enable 0)
	enable='NO'
	[ "$enabled" == 1 ] && enable='YES'
	vsftpd_enable='anonymous_enable='$enable
	sed -i "s|^anonymous_enable=.*|$vsftpd_enable|g" $file
	
	readable=$(uci_get_by_name $NAME anonymous readable 0)
	enable='NO'
	[ "$readable" == 1 ] && enable='YES'
	vsftpd_readable='anon_world_readable_only='$enable
	sed -i "s|^anon_world_readable_only=.*|$vsftpd_readable|g" $file
	
	upload=$(uci_get_by_name $NAME anonymous upload 0)
	enable='NO'
	[ "$upload" == 1 ] && enable='YES'
	vsftpd_upload='anon_upload_enable='$enable
	sed -i "s|^anon_upload_enable=.*|$vsftpd_upload|g" $file
	
	writemkdir=$(uci_get_by_name $NAME anonymous writemkdir 0)
	enable='NO'
	[ "$writemkdir" == 1 ] && enable='YES'
	vsftpd_writemkdir='anon_mkdir_write_enable='$enable
	sed -i "s|^anon_mkdir_write_enable=.*|$vsftpd_writemkdir|g" $file
	
	others=$(uci_get_by_name $NAME anonymous others 0)
	enable='NO'
	[ "$others" == 1 ] && enable='YES'
	vsftpd_others='anon_other_write_enable='$enable
	sed -i "s|^anon_other_write_enable=.*|$vsftpd_others|g" $file
	
	nopassword=$(uci_get_by_name $NAME anonymous nopassword 0)
	enable='NO'
	[ "$nopassword" == 1 ] && enable='YES'
	vsftpd_nopassword='no_anon_password='$enable
	sed -i "s|^no_anon_password=.*|$vsftpd_nopassword|g" $file
	
	umask=$(uci_get_by_name $NAME  anonymous umask '033')
	vsftpd_umask='anon_umask='$umask
	sed -i "s|^anon_umask=.*|$vsftpd_umask|g" $file
	
	root=$(uci_get_by_name $NAME anonymous root '/var')
	vsftpd_root='anon_root='$root
	sed -i "s|^anon_root=.*|$vsftpd_root|g" $file
	
	username=$(uci_get_by_name $NAME anonymous username 'root')
	vsftpd_username='ftp_username='$username
	sed -i "s|^ftp_username=.*|$vsftpd_username|g" $file
	
	/etc/init.d/vsftpd reload
}

arg1=$1
shift
case $arg1 in
general)
	general $1
	;;
locals)
	locals $1
	;;
anonymous)
	anonymous $1
	;;
*)
	echo "No this function!"
	;;
esac
