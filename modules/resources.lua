local component=require("component")
local computer=require("computer")
local config=require("config.config")
local M={last=-1e9,history={},data={}}

local function getController()
 if component.isAvailable("me_controller") then return component.me_controller end
 if component.isAvailable("me_interface") then return component.me_interface end
 return nil
end

local function count(c,r)
 local ok,items=pcall(function() return c.getItemsInNetwork() end)
 if not ok or type(items)~="table" then return nil end

 local total=0
 for _,i in ipairs(items) do
  local name=tostring(i.name or "")
  local label=tostring(i.label or "")
  local match=false

  if r.key=="quartz" then
   match=(name=="minecraft:quartz" and label=="Nether Quartz")
  elseif r.key=="lapis" then
   match=(name=="minecraft:dye" and label=="Lapis Lazuli")
  end

  if match then total=total+(tonumber(i.size) or 0) end
 end
 return total
end

function M.update(force)
 local now=computer.uptime();local interval=tonumber(config.resourceInterval) or 60
 if not force and now-M.last<interval then return nil end;M.last=now
 local c=getController();if not c then return {available=false,items=M.data} end
 local window=tonumber(config.resourceHistorySeconds) or 3600
 for _,r in ipairs(config.trackedResources or {}) do
  local v=count(c,r)
  if v~=nil then
   local h=M.history[r.key] or {}
   h[#h+1]={time=now,count=v}
   while #h>1 and now-h[1].time>window do table.remove(h,1) end
   M.history[r.key]=h
   local dt=now-h[1].time
   local rate=dt>0 and (v-h[1].count)/dt*3600 or 0
   M.data[r.key]={key=r.key,label=r.label or r.key,count=v,rateHour=rate}
  end
 end
 return {available=true,items=M.data}
end

return M
