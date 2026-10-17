local filesystem=require("filesystem")
local M={}
function M.ensureDirectory(path) if not filesystem.exists(path) then filesystem.makeDirectory(path) end end
function M.readNumber(path,default) local f=io.open(path,"r"); if not f then return default or 0 end local v=tonumber(f:read("*a")); f:close(); return v or default or 0 end
function M.write(path,value) local d=path:match("^(.*)/[^/]+$"); if d then M.ensureDirectory(d) end local f=io.open(path,"w"); if not f then return false end f:write(tostring(value)); f:close(); return true end
function M.energy(v,d) v=tonumber(v) or 0; d=d or 2; local fmt="%."..d.."f %s"; if v>=1e12 then return string.format(fmt,v/1e12,"TRF/t") elseif v>=1e9 then return string.format(fmt,v/1e9,"GRF/t") elseif v>=1e6 then return string.format(fmt,v/1e6,"MRF/t") elseif v>=1e3 then return string.format(fmt,v/1e3,"kRF/t") end return string.format("%.0f RF/t",v) end
function M.secondsToHMS(s) s=math.max(0,math.floor(tonumber(s) or 0)); return string.format("%02d:%02d:%02d",math.floor(s/3600),math.floor((s%3600)/60),s%60) end
function M.safe(default,fn) local ok,v=pcall(fn); if ok and v~=nil then return v,true end return default,false end
return M
