local component=require("component")
local computer=require("computer")
local config=require("config.config")

local M={last=-1e9,history={},data={}}

local function getController()
 if component.isAvailable("me_controller") then return component.me_controller end
 if component.isAvailable("me_interface") then return component.me_interface end
 return nil
end

local function makeDefaults()
 for _,r in ipairs(config.trackedResources or {}) do
  if M.data[r.key]==nil then
   M.data[r.key]={key=r.key,label=r.label or r.key,count=0,rateHour=0}
  end
 end
end

local function readAll(c)
 local ok,items=pcall(function() return c.getItemsInNetwork() end)
 if not ok or type(items)~="table" then return nil end
 return items
end

local function count(items,r)
 local wantedName=tostring(r.name or "")
 local wantedLabel=tostring(r.itemLabel or "")
 local total=0

 for _,item in ipairs(items) do
  local name=tostring(item.name or "")
  local label=tostring(item.label or "")

  local nameOK=(wantedName=="") or name==wantedName
  local labelOK=(wantedLabel=="") or label==wantedLabel

  if nameOK and labelOK then
   total=total+(tonumber(item.size) or 0)
  end
 end

 return total
end

function M.update(force)
 local now=computer.uptime()
 local interval=tonumber(config.resourceInterval) or 60

 makeDefaults()

 if not force and now-M.last<interval then return nil end
 M.last=now

 local c=getController()
 if not c then return {available=false,items=M.data} end

 local items=readAll(c)
 if not items then return {available=false,items=M.data} end

 local window=tonumber(config.resourceHistorySeconds) or 3600

 for _,r in ipairs(config.trackedResources or {}) do
  local v=count(items,r)
  local h=M.history[r.key] or {}

  h[#h+1]={time=now,count=v}
  while #h>1 and now-h[1].time>window do
   table.remove(h,1)
  end
  M.history[r.key]=h

  local dt=now-h[1].time
  local rate=dt>0 and (v-h[1].count)/dt*3600 or 0

  M.data[r.key]={
   key=r.key,
   label=r.label or r.key,
   count=v,
   rateHour=rate
  }
 end

 return {available=true,items=M.data}
end

makeDefaults()
return M
