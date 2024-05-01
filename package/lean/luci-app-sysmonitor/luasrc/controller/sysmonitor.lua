-- Copyright (C) 2017
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.sysmonitor", package.seeall)
function index()
	if not nixio.fs.access("/etc/config/sysmonitor") then
		return
	end
	entry({"admin", "sys"}, firstchild(), "SYS", 10).dependent = false
   	entry({"admin", "sys","sysmonitor"}, alias("admin", "sys","sysmonitor", "general"),_("SYSMonitor"), 20).dependent = true
	entry({"admin", "sys", "sysmonitor","general"}, cbi("sysmonitor/general"), _("General Settings"), 30).dependent = true
	entry({"admin", "sys", "sysmonitor", "nas"}, cbi("sysmonitor/nas"),_("NAS Settings"), 40).leaf = true
	entry({"admin", "sys", "sysmonitor", "update"}, form("sysmonitor/filetransfer"),_("Update"), 50).leaf = true
	entry({"admin", "sys", "sysmonitor", "readme"},cbi("sysmonitor/readme"),_("Readme"), 60).leaf = true
	entry({"admin", "sys", "sysmonitor", "log"},cbi("sysmonitor/log"),_("Log"), 70).leaf = true
	
	entry({"admin", "sys", "sysmonitor", "wanip_status"}, call("action_wanip_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_status"}, call("action_service_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_nas"}, call("service_nas")).leaf = true

	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "sys"}, call("sys"))
end
function action_wanip_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
	wanip_title=luci.sys.exec("/usr/share/sysmonitor/sysapp.sh sysbutton wantitle");
	wanip_state=luci.sys.exec("/usr/share/sysmonitor/sysapp.sh sysbutton wan")
	})

end
function service_nas()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		nas_title=luci.sys.exec("/usr/share/sysmonitor/sysapp.sh sysbutton nastitle");
		nas_state=luci.sys.exec("/usr/share/sysmonitor/sysapp.sh sysbutton nas")
	})
end
function get_log()
	luci.http.write(luci.sys.exec("[ -f '/var/log/sysmonitor.log' ] && cat /var/log/sysmonitor.log"))
end
function clear_log()
	luci.sys.exec("echo '' > /var/log/sysmonitor.log")
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "log"))
end
function sys()
	sys=luci.http.formvalue("sys")
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh sysmenu "..sys)
	if ( string.sub(sys,1,3) == "NAS" ) then
		luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor","nas"))
	else
		luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	end
end
