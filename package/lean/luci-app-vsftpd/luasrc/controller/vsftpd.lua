
require("luci.sys")

module("luci.controller.vsftpd", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/vsftpd") then
		return
	end
	entry({"admin", "services", "vsftpd"}, 10).dependent = true
	entry({"admin", "services", "vsftpd"}, alias("admin", "services", "vsftpd", "general"), _("FTP Server"))
	entry({"admin", "services", "vsftpd", "general"}, cbi("vsftpd/general"), _("General Settings"), 10).leaf = true
	entry({"admin", "services", "vsftpd", "local"}, cbi("vsftpd/local"), _("Local User"), 20).leaf = true
	entry({"admin", "services", "vsftpd", "anonymous"}, cbi("vsftpd/anonymous"), _("Anonymous User"), 30).leaf = true
end
