
local ftp_rw=luci.sys.exec("cat /etc/vsftpd.conf|grep ^write_enable|cut -d'=' -f2|tr 'A-Z' 'a-z'")
if ( string.sub(ftp_rw,1,2) == "no" ) then
	luci.sys.exec("uci set vsftpd.local.write=0")
else
	luci.sys.exec("uci set vsftpd.local.write=1")
end
luci.sys.exec("uci commit vsftpd")

m = Map("vsftpd")
m.title = translate("FTP Server - Local User Settings")

sl = m:section(NamedSection, "local", "vsftpd", translate(""))

o = sl:option(Flag, "local_enable", translate("Enable local user"))
o.rmempty = false

o = sl:option(Flag, "write", translate("Enable write"))
o.description = translate("When disabled, all write request will give permission denied.")
o.default = true

o = sl:option(Flag, "download", translate("Enable download"))
o.description = translate("When disabled, all download request will give permission denied.")
o.default = true

--o = sl:option(Flag, "dirlist", translate("Enable directory list"))
--o.description = translate("When disabled, list commands will give permission denied.")
--o.default = true

o = sl:option(Value, "umask", translate("File mode umask"))
o.description = translate("Uploaded file mode will be 666 - &lt;umask&gt;; directory mode will be 777 - &lt;umask&gt;.")
o.default = "022"

o = sl:option(Value, "mode", translate("File open mode"))
o.default = "0755"

o = sl:option(Value, "root", translate("Root directory"))
o.default = ""

local apply = luci.http.formvalue("cbi.apply")
if apply then
	luci.sys.exec("echo '1-/usr/share/vsftpd/vsftpd.sh locals' >> /tmp/delay.sign")
end

return m
