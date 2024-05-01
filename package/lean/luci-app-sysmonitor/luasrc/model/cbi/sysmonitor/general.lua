
local m, s
local global = 'sysmonitor'
local uci = luci.model.uci.cursor()
local ip = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip")

m = Map("sysmonitor",translate("System Settings"))
m:append(Template("sysmonitor/status"))

s = m:section(TypedSection, "sysmonitor",translate(""))
s.anonymous = true

--o=s:option(Flag,"enable", translate("Enable"))
--o.rmempty=false

o = s:option(ListValue, "led", translate("led On/Off/Flash"))
o:value("0", translate("Off"))
o:value("1", translate("On"))
o:value("-", translate("Flash"))
o.rmempty=true

o = s:option(Value, "wan", translate("WAN IP Address"))
--o.description = translate("IP for local(192.168.1.118)")
o.datatype = "or(host)"
o.rmempty = false

o = s:option(Value, "mask", translate("WAN IP mask"))
--o.description = translate("MASK for local(255.255.255.0)")
o.datatype = "or(host)"
o.rmempty = false

o = s:option(Value, "gateway", translate("Gateway IP Address"))
--o.description = translate("IP for Internet(192.168.1.1)")
o.datatype = "or(host)"
o.rmempty = false

o = s:option(DynamicList, "dns", translate("DNS List"))
o.datatype = "or(host)"
o.rmempty = false

--o=s:option(Flag,"vpn_enable", translate("Enable vpn"))
--o.rmempty=false

--o = s:option(Value, "vpn", translate("VPN IP Address"))
--o.datatype = "or(host)"
--o.rmempty = false

local apply = luci.http.formvalue("cbi.apply")
if apply then
	luci.sys.exec("touch /tmp/network.sign")
end

return m
