local component=require("component")
local computer=require("computer")
local config=require("config.config")
local utils=require("lib.utils")
local reactors={last=-1e9,lastRodRefresh=-1e9,rodCache={},shutdown={},knownCount=0,notified=false}
local countFile=config.dataDir.."/reactorInfo.txt"

local function list()
  local out={}
  for address,kind in component.list() do
    if kind=="htc_reactors_nuclear_reactor" then out[#out+1]={address=address,proxy=component.proxy(address)} end
  end
  table.sort(out,function(a,b) return a.address<b.address end)
  return out
end

local function rodTime(r)
  local ok,rods=pcall(function() return r.getAllFuelRodsStatus() end)
  if not ok or type(rods)~="table" then return 0 end
  local maximum=0
  for _,rod in ipairs(rods) do maximum=math.max(maximum,tonumber(rod[6]) or 0) end
  return math.floor(maximum)
end

function reactors.setCoolingSafety(fluid)
  for _,entry in ipairs(list()) do
    local r=entry.proxy
    local liquid=select(1,utils.safeCall(false,function() return r.isActiveCooling() end))
    local working=select(1,utils.safeCall(false,function() return r.hasWork() end))
    if liquid and fluid<=config.minFluidDrop and working then
      local ok=pcall(function() r.deactivate() end); if ok then reactors.shutdown[entry.address]=true end
    elseif fluid>config.minFluidDrop and reactors.shutdown[entry.address] then
      local ok=pcall(function() r.activate() end); if ok then reactors.shutdown[entry.address]=nil end
    end
  end
end

function reactors.update(fluid,force)
  local now=computer.uptime()
  if not force and now-reactors.last<config.reactorInterval then return nil end
  local delta=math.max(0,now-reactors.last); reactors.last=now
  for key,value in pairs(reactors.rodCache) do reactors.rodCache[key]=math.max(0,value-delta) end
  local refreshRods=force or now-reactors.lastRodRefresh>=config.rodRefreshInterval
  if refreshRods then reactors.lastRodRefresh=now end
  local entries=list(); local result={reactors={},count=#entries,totalEnergy=0,totalCoolant=0,hottest=0,fluidCount=fluid or 0}
  for i,entry in ipairs(entries) do
    local r=entry.proxy
    if refreshRods or reactors.rodCache[entry.address]==nil then reactors.rodCache[entry.address]=rodTime(r) end
    local energy=select(1,utils.safeCall(0,function() return r.getEnergyGeneration() end))
    local coolant=select(1,utils.safeCall(0,function() return r.getFluidCoolantConsume() end))
    local temp=select(1,utils.safeCall(0,function() return r.getTemperature() end))
    local active=select(1,utils.safeCall(false,function() return r.hasWork() end))
    local level=select(1,utils.safeCall(0,function() return r.getReactorLevel() end))
    local liquid=select(1,utils.safeCall(false,function() return r.isActiveCooling() end))
    result.reactors[i]={id=i,address=entry.address,online=active,activated=active,level=level,liquid=liquid,kind=liquid and "&bЖидкостный" or "&eВоздушный",energy=energy,temp=temp,coolant=coolant,rodTime=reactors.rodCache[entry.address] or 0}
    result.totalEnergy=result.totalEnergy+energy; result.totalCoolant=result.totalCoolant+coolant; result.hottest=math.max(result.hottest,temp)
  end
  reactors.setCoolingSafety(result.fluidCount)
  local stored=utils.readNumber(countFile,0)
  if stored==0 or result.count>stored then stored=math.max(result.count,config.expectedReactors); utils.write(countFile,stored) end
  result.missing=math.max(0,stored-result.count)
  return result
end
return reactors
