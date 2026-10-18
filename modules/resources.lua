local component = require("component")
local computer = require("computer")
local config = require("config.config")

local M = {last=-1e9, history={}, data={}}

local function controller()
  if component.isAvailable("me_controller") then return component.me_controller end
  if component.isAvailable("me_interface") then return component.me_interface end
  return nil
end

local function matchItem(item, r)
  local name=string.lower(tostring(item.name or ""))
  local label=string.lower(tostring(item.label or ""))
  local needle=string.lower(tostring(r.search or r.key or ""))
  return needle~="" and (name:find(needle,1,true)~=nil or label:find(needle,1,true)~=nil)
end

local function readCount(c,r)
  if not c or not c.getItemsInNetwork then return nil end
  local ok,items=pcall(function() return c.getItemsInNetwork() end)
  if not ok or type(items)~="table" then return nil end
  local total=0
  for _,item in ipairs(items) do
    if item and matchItem(item,r) then total=total+(tonumber(item.size) or 0) end
  end
  return total
end

function M.update(force)
  local now=tonumber(computer.uptime()) or 0
  local interval=math.max(1,tonumber(config.resourceInterval) or 60)
  if not force and now-M.last<interval then return nil end
  M.last=now
  local c=controller()
  if not c then return {available=false,items=M.data} end
  local window=math.max(interval,tonumber(config.resourceHistorySeconds) or 3600)
  for _,r in ipairs(config.trackedResources or {}) do
    local count=readCount(c,r)
    if count~=nil then
      local h=M.history[r.key] or {}
      h[#h+1]={time=now,count=count}
      while #h>1 and now-h[1].time>window do table.remove(h,1) end
      M.history[r.key]=h
      local first=h[1]
      local elapsed=math.max(0,now-first.time)
      local rate=0
      if elapsed>0 then rate=(count-first.count)/elapsed*3600 end
      M.data[r.key]={key=r.key,label=r.label or r.key,count=count,rateHour=rate,elapsed=elapsed}
    end
  end
  return {available=true,items=M.data}
end
return M
