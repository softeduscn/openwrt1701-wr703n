
m = Map("vsftpd")
m.title = translate("FTP Server - General Settings")

sl = m:section(NamedSection, "general", "vsftpd", translate(""))

o = sl:option(Flag, "enable6", translate("Enable IPv6"))
o.rmempty = false
o.default = true

o = sl:option(Value, "port", translate("Listen Port"))
o.datatype = "uinteger"
o.default = "21"

--o = sl:option(Value, "dataport", translate("Data Port"))
--o.datatype = "uinteger"
--o.default = "20"

local apply = luci.http.formvalue("cbi.apply")
if apply then
	luci.sys.exec("echo '1-/usr/share/vsftpd/vsftpd.sh general' >> /tmp/delay.sign")
end

return m

