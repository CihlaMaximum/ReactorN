local component=require("component")
local computer=require("computer")
local config=require("config.config")
local utils=require("lib.utils")
local M={last=-1e9,lastScan=-1e9,lastRodRefresh=-1e9,entries={},rodCache={},shutdown={}}
local countFile=config.dataDir.."/reactorInfo.txt"
local function scan(force)
 local now=computer.uptime(); if not force and now-M.lastScan<config.reactorScanInterval then return M.entries end
 M.lastScan=now; local out={}; for address,kind in component.list() do if kind=="htc_reactors_nuclear_reactor" then local ok,p=pcall(component.proxy,address); if ok then out[#out+1]={address=address,proxy=p} end end end
 table.sort(out,function(a,b)return a.address<b.address end); M.entries=out; return out
end
local function realRodTime(r)
 local ok,rods=pcall(function()return r.getAllFuelRodsStatus()end); if not ok or type(rods)~="table" then return nil end
 local maximum=0; for _,rod in ipairs(rods) do maximum=math.max(maximum,tonumber(rod[6]) or 0) end; return math.floor(maximum)
end
local function syncRods(entries,force)
 local now=computer.uptime(); if not force and now-M.lastRodRefresh<config.rodRefreshInterval then return end; M.lastRodRefresh=now
 for _,e in ipairs(entries) do local real=realRodTime(e.proxy); if real then local cached=M.rodCache[e.address]; if cached==nil or math.abs(real-cached)>config.rodHardSyncDifference then M.rodCache[e.address]=real else M.rodCache[e.address]=real end end end
end
local function coolingSafety(entries,fluid)
 for _,e in ipairs(entries) do local r=e.proxy; local liquid=select(1,utils.safe(false,function()return r.isActiveCooling()end)); local working=select(1,utils.safe(false,function()return r.hasWork()end))
  if liquid and fluid<config.minFluidDrop and working then local ok=pcall(function()r.deactivate()end); if ok then M.shutdown[e.address]=true end
  elseif fluid>=config.minFluidDrop and M.shutdown[e.address] then local ok=pcall(function()r.activate()end); if ok then M.shutdown[e.address]=nil end end
 end
end
function M.update(fluid,force)
 local now=computer.uptime(); if not force and now-M.last<config.reactorInterval then return nil end
 local delta=(M.last<0) and 0 or math.max(0,now-M.last); M.last=now
 for address,value in pairs(M.rodCache) do M.rodCache[address]=math.max(0,value-delta) end
 local entries=scan(force); syncRods(entries,force)
 local result={reactors={},count=#entries,totalEnergy=0,totalCoolant=0,hottest=0,fluidCount=fluid or 0}
 for i,e in ipairs(entries) do local r=e.proxy; if M.rodCache[e.address]==nil then M.rodCache[e.address]=realRodTime(r) or 0 end
  local energy=select(1,utils.safe(0,function()return r.getEnergyGeneration()end)); local coolant=select(1,utils.safe(0,function()return r.getFluidCoolantConsume()end)); local temp=select(1,utils.safe(0,function()return r.getTemperature()end)); local active=select(1,utils.safe(false,function()return r.hasWork()end)); local level=select(1,utils.safe(0,function()return r.getReactorLevel()end)); local liquid=select(1,utils.safe(false,function()return r.isActiveCooling()end))
  local rod=M.rodCache[e.address] or 0; local rodColor=rod<config.rodCriticalSeconds and "&c" or (rod<config.rodWarningSeconds and "&e" or "&a")
  result.reactors[i]={id=i,address=e.address,online=active,activated=active,level=level,liquid=liquid,kind=liquid and "&bЖидкостный" or "&eВоздушный",energy=energy,temp=temp,coolant=coolant,rodTime=rod,rodColor=rodColor}
  result.totalEnergy=result.totalEnergy+energy; result.totalCoolant=result.totalCoolant+coolant; result.hottest=math.max(result.hottest,temp)
 end
 coolingSafety(entries,result.fluidCount)
 local stored=utils.readNumber(countFile,0); if stored==0 or result.count>stored then stored=math.max(result.count,config.expectedReactors); utils.write(countFile,stored) end; result.missing=math.max(0,stored-result.count)
 return result
end
return M
