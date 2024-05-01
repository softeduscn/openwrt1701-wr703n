
m = Map("vsftpd")
m.title = translate("FTP Server - Anonymous Settings")

sa = m:section(NamedSection, "anonymous", "vsftpd", translate(""))

o = sa:option(Flag, "anonymous_enable", translate("Enable Anonymous"))
o.default = false

o = sa:option(Flag, "readable", translate("Readable only"))
o.default = false

o = sa:option(Flag, "upload", translate("Enable upload"))
o.default = false

o = sa:option(Flag, "writemkdir", translate("Enable write/mkdir"))
o.default = false

o = sa:option(Flag, "others", translate("Enable other rights"))
o.description = translate("Include rename, deletion ...")
o.default = false

o = sa:option(Flag, "nopassword", translate("No require password"))
o.default = false

o = sa:option(Value, "username", translate("Username"))
o.description = translate("An actual local user to handle anonymous user")
o.default = "ftp"

o = sa:option(Value, "umask", translate("File mode umask"))
o.default = "022"

o = sa:option(Value, "root", translate("Root directory"))
o.default = "/var/ftp"

local apply = luci.http.formvalue("cbi.apply")
if apply then
	luci.sys.exec("echo '1-/usr/share/vsftpd/vsftpd.sh anonymous' >> /tmp/delay.sign")
end

return m

