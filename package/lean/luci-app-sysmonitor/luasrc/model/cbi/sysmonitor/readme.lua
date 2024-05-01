local datatypes = require "luci.cbi.datatypes"

local readme = "/etc/sysmonitor/readme"

m = Map("sysmonitor")

s = m:section(TypedSection, "sysmonitor", translate(""))
s.anonymous = true

s:tab("readme", translate("Readme"))

o = s:taboption("readme", TextValue, "readme", "", translate(""))
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section) return nixio.fs.readfile(readme) or "" end
o.write = function(self, section, value) nixio.fs.writefile(readme , value:gsub("\r\n", "\n")) end
o.remove = function(self, section, value) nixio.fs.writefile(readme , "") end
o.validate = function(self, value)
    return value
end

return m
