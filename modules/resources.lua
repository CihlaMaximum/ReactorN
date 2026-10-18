local component=require("component")
local computer=require("computer")
local config=require("config.config")

local M={last=-1e9,nextIndex=1,history={},data={}}

-- Exact identifiers confirmed by the ME diagnostic test.
local DEFINITIONS={
  quartz={name="minecraft:quartz",itemLabel="Nether Quartz",label="Кварц"},
  lapis={name="minecraft:dye",itemLabel="Lapis Lazuli",label="Лазурит"}
}

local ORDER={"quartz","lapis"}

local function getController()
  if component.isAvailable("me_controller") then return component.me_controller end
  if component.isAvailable("me_interface") then return component.me_interface end
  return nil
end

local function configuredLabel(key)
  for _,r in ipairs(config.trackedResources or {}) do
    if r.key==key then return r.label or DEFINITIONS[key].label end
  end
  return DEFINITIONS[key].label
end

local function makeDefaults()
  for _,key in ipairs(ORDER) do
    if M.data[key]==nil then
      M.data[key]={key=key,label=configuredLabel(key),count=0,rateHour=0}
    end
  end
end

local function readResource(controller,key)
  local def=DEFINITIONS[key]
  local ok,items,apiError=pcall(function()
    return controller.getItemsInNetwork({name=def.name})
  end)

  if not ok then return nil,tostring(items) end
  if type(items)~="table" then return nil,tostring(apiError or items or "invalid response") end

  local total=0
  for _,item in ipairs(items) do
    local name=tostring(item.name or "")
    local label=tostring(item.label or "")
    if name==def.name and label==def.itemLabel then
      total=total+(tonumber(item.size) or 0)
    end
  end
  return total,nil
end

local function saveValue(key,value,now)
  local window=tonumber(config.resourceHistorySeconds) or 3600
  local h=M.history[key] or {}
  h[#h+1]={time=now,count=value}
  while #h>1 and now-h[1].time>window do table.remove(h,1) end
  M.history[key]=h

  local dt=now-h[1].time
  local rate=dt>0 and (value-h[1].count)/dt*3600 or 0
  M.data[key]={key=key,label=configuredLabel(key),count=value,rateHour=rate}
end

function M.update(force)
  local now=computer.uptime()
  local interval=tonumber(config.resourceInterval) or 5
  makeDefaults()

  if not force and now-M.last<interval then return nil end
  M.last=now

  local controller=getController()
  if not controller then return {available=false,items=M.data,error="ME unavailable"} end

  local key=ORDER[M.nextIndex]
  local value,err=readResource(controller,key)

  if value~=nil then
    saveValue(key,value,now)
    M.nextIndex=M.nextIndex%#ORDER+1
    return {available=true,items=M.data}
  end

  -- Cooldown or temporary ME error: keep previous values and retry same resource.
  return {available=false,items=M.data,error=err}
end

makeDefaults()
return M
