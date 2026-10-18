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

-- Query ME only by item name. Label is checked locally.
-- This avoids relying on ME/OC filtering by label.
local function readResource(controller,r)
  local wantedName=tostring(r.name or "")
  local wantedLabel=tostring(r.itemLabel or "")
  if wantedName=="" then return nil end

  local ok,items=pcall(function()
    return controller.getItemsInNetwork({name=wantedName})
  end)
  if not ok or type(items)~="table" then return nil end

  local total=0
  for _,item in ipairs(items) do
    local name=tostring(item.name or "")
    local label=tostring(item.label or "")
    if name==wantedName and (wantedLabel=="" or label==wantedLabel) then
      total=total+(tonumber(item.size) or 0)
    end
  end
  return total
end

local function updateHistory(r,value,now)
  local window=tonumber(config.resourceHistorySeconds) or 3600
  local h=M.history[r.key] or {}
  h[#h+1]={time=now,count=value}
  while #h>1 and now-h[1].time>window do table.remove(h,1) end
  M.history[r.key]=h

  local dt=now-h[1].time
  local rate=dt>0 and (value-h[1].count)/dt*3600 or 0
  M.data[r.key]={key=r.key,label=r.label or r.key,count=value,rateHour=rate}
end

function M.update(force)
  local now=computer.uptime()
  local interval=tonumber(config.resourceInterval) or 60
  makeDefaults()

  if not force and now-M.last<interval then return nil end
  M.last=now

  local controller=getController()
  if not controller then return {available=false,items=M.data} end

  local anySuccess=false
  for _,r in ipairs(config.trackedResources or {}) do
    local value=readResource(controller,r)
    if value~=nil then
      anySuccess=true
      updateHistory(r,value,now)
    end
  end

  return {available=anySuccess,items=M.data}
end

makeDefaults()
return M
