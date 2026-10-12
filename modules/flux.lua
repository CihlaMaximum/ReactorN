local component=require("component")
local computer=require("computer")
local config=require("config.config")
local utils=require("lib.utils")
local flux={last=-1e9,maxInput=0}
local file=config.dataDir.."/energyInfo.txt"
local names={"flux_network","fluxnetwork","flux_controller","fluxnetworks","flux_plug"}
local proxy=nil
for _,name in ipairs(names) do if component.isAvailable(name) then proxy=component[name]; break end end
flux.maxInput=utils.readNumber(file,0)

function flux.update(force)
  local now=computer.uptime()
  if not force and now-flux.last<config.fluxInterval then return nil end
  flux.last=now
  if not proxy then return {name="Flux недоступен",input=0,buffer=0,maxInput=flux.maxInput} end
  local info,ok1=utils.safeCall({},function() return proxy.getNetworkInfo() end)
  local energy,ok2=utils.safeCall({},function() return proxy.getEnergyInfo() end)
  if not ok1 or not ok2 then return {name="Ошибка Flux",input=0,buffer=0,maxInput=flux.maxInput} end
  local input=tonumber(energy.energyInput) or 0
  if input>flux.maxInput then flux.maxInput=input; utils.write(file,input) end
  return {name=info.name or "Без имени",input=input,buffer=tonumber(energy.totalBuffer) or 0,maxInput=flux.maxInput}
end
return flux
