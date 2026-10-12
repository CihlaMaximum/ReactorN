local component=require("component")
local computer=require("computer")
local config=require("config.config")
local me={last=-1e9,fluid=0,cpu={processors={},idle=0,busy=0,total=0}}

local function controller()
  return component.isAvailable("me_controller") and component.me_controller or nil
end

function me.update(force)
  local now=computer.uptime()
  if not force and now-me.last<config.meInterval then return nil end
  me.last=now
  local c=controller()
  if not c then me.fluid=0; me.cpu={processors={},idle=0,busy=0,total=0}; return {fluid=me.fluid,cpu=me.cpu} end
  local ok,cpus=pcall(function() return c.getCpus() end)
  cpus=ok and cpus or {}
  local data={processors={},idle=0,busy=0,total=#cpus}
  for i,cpu in ipairs(cpus) do
    data.processors[i]={busy=cpu.busy==true}
    if cpu.busy then data.busy=data.busy+1 else data.idle=data.idle+1 end
  end
  local ok2,items=pcall(function() return c.getItemsInNetwork({name=config.fluidItemName}) end)
  local total=0
  if ok2 and type(items)=="table" then
    for _,item in ipairs(items) do
      if item and item.size and (not item.label or item.label:find(config.fluidLabel,1,true)) then total=total+(tonumber(item.size) or 0) end
    end
  end
  me.fluid=total; me.cpu=data
  return {fluid=me.fluid,cpu=me.cpu}
end

function me.getFluid() return me.fluid end
function me.getCPU() return me.cpu end
return me
