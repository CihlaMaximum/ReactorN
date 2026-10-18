local component=require("component")
local computer=require("computer")
local config=require("config.config")

local M={
  last=-1e9,
  nextIndex=1,
  history={},
  data={}
}

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

local function readResource(controller,r)
  local wantedName=tostring(r.name or "")
  local wantedLabel=tostring(r.itemLabel or "")
  if wantedName=="" then return nil,"no item name" end

  local ok,items,apiError=pcall(function()
    return controller.getItemsInNetwork({name=wantedName})
  end)

  if not ok then return nil,tostring(items) end
  if type(items)~="table" then return nil,tostring(apiError or items or "invalid response") end

  local total=0
  for _,item in ipairs(items) do
    local name=tostring(item.name or "")
    local label=tostring(item.label or "")
    if name==wantedName and (wantedLabel=="" or label==wantedLabel) then
      total=total+(tonumber(item.size) or 0)
    end
  end

  return total,nil
end

local function updateHistory(r,value,now)
  local window=tonumber(config.resourceHistorySeconds) or 3600
  local h=M.history[r.key] or {}
  h[#h+1]={time=now,count=value}

  while #h>1 and now-h[1].time>window do
    table.remove(h,1)
  end
  M.history[r.key]=h

  local rate=0
  local dt=now-h[1].time
  if dt>0 then rate=(value-h[1].count)/dt*3600 end

  M.data[r.key]={
    key=r.key,
    label=r.label or r.key,
    count=value,
    rateHour=rate
  }
end

function M.update(force)
  local now=computer.uptime()
  local interval=tonumber(config.resourceInterval) or 5
  makeDefaults()

  if not force and now-M.last<interval then return nil end
  M.last=now

  local resources=config.trackedResources or {}
  if #resources==0 then return {available=false,items=M.data} end

  if M.nextIndex>#resources then M.nextIndex=1 end
  local r=resources[M.nextIndex]

  local controller=getController()
  if not controller then return {available=false,items=M.data} end

  local value,err=readResource(controller,r)

  if value~=nil then
    updateHistory(r,value,now)
    -- Move to the next resource only after a successful ME query.
    M.nextIndex=M.nextIndex+1
    if M.nextIndex>#resources then M.nextIndex=1 end
    return {available=true,items=M.data}
  end

  -- On cooldown or another temporary error keep the old value and
  -- retry the SAME resource during the next resource interval.
  return {available=false,items=M.data,error=err}
end

makeDefaults()
return M
