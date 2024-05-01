
local ftp_rw=luci.sys.exec("cat /etc/vsftpd.conf|grep ^write_enable|cut -d'=' -f2|tr 'A-Z' 'a-z'")
if ( string.sub(ftp_rw,1,2) == "no" ) then
	luci.sys.exec("uci set sysmonitor.sysmonitor.ftp_rw=0")
else
	luci.sys.exec("uci set sysmonitor.sysmonitor.ftp_rw=1")
end
luci.sys.exec("uci commit sysmonitor")

m = Map("sysmonitor",translate("NAS Settings"))

m:append(Template("sysmonitor/nas"))

s = m:section(TypedSection, "sysmonitor")
s.anonymous = true

o = s:option(Value, "initial_dir", translate("Music Initial directory"))
o.rmempty=false

o = s:option(ListValue, "webdav_rw", translate("WebDAV RW"))
o:value("0", translate("read only"))
o:value("1", translate("read & write"))
o.rmempty=true

o = s:option(ListValue, "ftp_rw", translate("FTP RW"))
o:value("0", translate("read only"))
o:value("1", translate("read & write"))
o.rmempty=true

o = s:option(ListValue, "samba_rw", translate("Samba RW"))
o:value("0", translate("read only"))
o:value("1", translate("read & write"))
o.rmempty=true

o = s:option(ListValue, "nfs_rw", translate("NFS RW"))
o:value("0", translate("read only"))
o:value("1", translate("read & write"))
o.rmempty=true

o = s:option(Value, "samba_rw_dir", translate("Samba Write directory"))
o.description = translate("Samba directory for Write: music,video")
o:depends("samba_rw", "0")
o.rmempty=true

o = s:option(Value, "nfs_rw_dir", translate("NFS Write directory"))
o.description = translate("NFS directory for Write: music,video")
o:depends("nfs_rw", "0")
o.rmempty=true

local apply = luci.http.formvalue("cbi.apply")
if apply then
	luci.sys.exec("touch /tmp/samba.sign")
end
return m
