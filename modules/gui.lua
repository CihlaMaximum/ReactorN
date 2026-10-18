local component = require("component")
local term = require("term")
local sgui = require("sgui")
local config = require("config.config")
local utils = require("lib.utils")

local M = {}
local gpu = component.isAvailable("gpu") and component.gpu or nil

local SCREEN_W = tonumber(config.screenWidth) or 120
local SCREEN_H = tonumber(config.screenHeight) or 40

local C = {
  normal="&a", warning="&e", critical="&c", info="&b",
  value="&f", muted="&8", energy="&6", button="&0"
}

local F = {
  status={x=2,y=2,w=118,h=3,title=""},
  coolant={x=2,y=5,w=118,h=7,title="Хладагент"},
  reactors={x=2,y=12,w=118,h=20,title="Реакторы"},
  summary={x=2,y=32,w=118,h=3,title=""},
  systems={x=2,y=35,w=118,h=3,title=""}
}

local B = {
  update={x=4,y=39,w=16,text="[ ОБНОВИТЬ ]",color="&2"},
  restart={x=50,y=39,w=18,text="[ ПЕРЕЗАПУСК ]",color="&6"},
  exit={x=104,y=39,w=12,text="[ ВЫХОД ]",color="&4"}
}

local state = {
  flux={name="Нет данных",input=0,buffer=0,maxInput=0,available=false},
  me={processors={},idle=0,busy=0,total=0,available=false},
  players={}, reactors=nil, resources={}
}

local function text(x,y,value) sgui.text(x,y,tostring(value or "")) end
local function clear(x,y,width) text(x,y,string.rep(" ",math.max(0,width or 0))) end
local function clearArea(x,y,width,height)
  for row=0,height-1 do clear(x,y+row,width) end
end
local function clamp(v,min,max)
  v=tonumber(v) or 0
  if v<min then return min end
  if v>max then return max end
  return v
end
local function percent(v) return math.floor(clamp(v,0,1)*100+0.5) end
local function shortNumber(v)
  v=tonumber(v) or 0
  if v>=1e12 then return string.format("%.2f T",v/1e12)
  elseif v>=1e9 then return string.format("%.2f G",v/1e9)
  elseif v>=1e6 then return string.format("%.2f M",v/1e6)
  elseif v>=1e3 then return string.format("%.1f k",v/1e3) end
  return string.format("%.0f",v)
end
local function formatInteger(v)
  local n=math.floor(tonumber(v) or 0)
  local sign=""
  if n<0 then sign="-"; n=math.abs(n) end
  local s=tostring(n)
  while true do
    local changed
    s,changed=s:gsub("^(-?%d+)(%d%d%d)","%1 %2")
    if changed==0 then break end
  end
  return sign..s
end
local function makeBar(ratio,width)
  ratio=clamp(ratio,0,1); width=math.max(1,math.floor(width or 10))
  local filled=math.floor(ratio*width+0.5)
  return string.rep("█",filled)..string.rep("░",width-filled)
end
local function coolantColor(ratio)
  ratio=tonumber(ratio) or 0
  local stop=tonumber(config.reactorCoolantStopRatio) or 0.68
  local restore=tonumber(config.reactorCoolantRestoreRatio) or 0.80
  if ratio<=stop then return C.critical elseif ratio<restore then return C.warning end
  return C.normal
end
local function temperatureColor(temp)
  temp=tonumber(temp) or 0
  local critical=tonumber(config.reactorTempWarn) or 950
  local warning=tonumber(config.reactorTempPreWarn) or math.floor(critical*0.90)
  if temp>=critical then return C.critical elseif temp>=warning then return C.warning end
  return C.normal
end
local function rodColor(seconds)
  seconds=tonumber(seconds) or 0
  local critical=tonumber(config.rodCriticalSeconds) or 21600
  local warning=tonumber(config.rodWarningSeconds) or 86400
  if seconds<=critical then return C.critical elseif seconds<=warning then return C.warning end
  return C.normal
end

local function getReactorStatus(q,data)
  if not q then return {color=C.critical,symbol="×",short="НЕТ",reason="РЕАКТОР НЕ ОБНАРУЖЕН"} end
  local stop=tonumber(config.reactorCoolantStopRatio) or 0.68
  if q.liquid and (tonumber(q.coolantCapacity) or 0)>0 and (tonumber(q.coolantRatio) or 0)<=stop then
    return {color=C.critical,symbol="■",short="STOP",reason="НИЗКИЙ БУФЕР"}
  end
  if data and data.fluidConfirmedLow and q.liquid then
    return {color=C.critical,symbol="■",short="STOP",reason="НИЗКИЙ ХЛАДАГЕНТ ME"}
  end
  if q.activated then return {color=C.normal,symbol="●",short="ON",reason="РАБОТАЕТ"} end
  return {color=C.muted,symbol="○",short="OFF",reason="ВЫКЛЮЧЕН"}
end

local function getSystemStatus(data)
  if not data then return C.warning,"ОЖИДАНИЕ ДАННЫХ" end
  if (tonumber(data.missing) or 0)>0 then return C.critical,"ОТСУТСТВУЮТ РЕАКТОРЫ: "..tostring(data.missing) end
  if data.fluidConfirmedLow then return C.critical,"НИЗКИЙ ХЛАДАГЕНТ" end
  local stop=tonumber(config.reactorCoolantStopRatio) or 0.68
  local restore=tonumber(config.reactorCoolantRestoreRatio) or 0.80
  local warning=false
  for _,q in ipairs(data.reactors or {}) do
    if q.liquid then
      local ratio=tonumber(q.coolantRatio) or 0
      if ratio<=stop then return C.critical,"АВАРИЯ ОХЛАЖДЕНИЯ" elseif ratio<restore then warning=true end
    end
  end
  if warning then return C.warning,"НИЗКИЙ БУФЕР ОХЛАЖДЕНИЯ" end
  local hottest=tonumber(data.hottest) or 0
  local critical=tonumber(config.reactorTempWarn) or 950
  if hottest>=critical then return C.critical,"ВЫСОКАЯ ТЕМПЕРАТУРА" end
  if hottest>=critical*0.90 then return C.warning,"ПОВЫШЕННАЯ ТЕМПЕРАТУРА" end
  return C.normal,"НОРМА"
end

local function drawStatus()
  local data=state.reactors
  local color,status=getSystemStatus(data)
  clearArea(3,3,116,1)
  local count=data and tonumber(data.count) or 0
  local expected=tonumber(config.expectedReactors) or 6
  local meStatus=state.me.available and "&a● OK" or "&e● ОЖИДАНИЕ"
  local fluxStatus=state.flux.available and "&a● OK" or "&e● ОЖИДАНИЕ"
  text(4,3,color.."● СИСТЕМА: "..status)
  text(47,3,"&fРЕАКТОРЫ: "..(count>=expected and "&a" or "&c")..tostring(count).."&f/"..tostring(expected))
  text(70,3,"&fME: "..meStatus)
  text(91,3,"&fFLUX: "..fluxStatus)
end


local function drawResources()
  local q=state.resources.quartz
  local l=state.resources.lapis
  clear(5,10,110)
  local function rateText(v)
    v=tonumber(v) or 0
    if v>0 then return C.normal.."+"..formatInteger(v).."/ч" end
    if v<0 then return C.critical..formatInteger(v).."/ч" end
    return C.muted.."0/ч"
  end
  if q then text(5,10,"&fКварц: &b"..formatInteger(q.count).."  "..rateText(q.rateHour)) end
  if l then text(48,10,"&fЛазурит: &b"..formatInteger(l.count).."  "..rateText(l.rateHour)) end
end
local function drawCoolantPanel(data)
  local f=F.coolant
  clearArea(f.x+1,f.y+1,f.w-2,f.h-2)
  if not data then text(f.x+3,f.y+3,"&eОжидание данных реакторов..."); return end
  local fluid=math.max(0,tonumber(data.fluidCount) or 0)
  local limit=math.max(0,tonumber(config.minFluidDrop) or 1000000)
  local consumption=math.max(0,tonumber(data.totalCoolant) or 0)
  local forecast=data.coolantForecastSeconds
  local fluidColor=(data.fluidConfirmedLow or fluid<=limit) and C.critical or (fluid<=limit*1.25 and C.warning or C.info)
  local forecastText="--:--:--"
  if forecast~=nil then forecastText=utils.secondsToHMS(tonumber(forecast) or 0)
  elseif consumption<=0 then forecastText="РАСХОДА НЕТ" end
  text(f.x+3,f.y+2,"&fЗапас: "..fluidColor..formatInteger(fluid).." mB")
  text(f.x+40,f.y+2,"&fРасход активных: &b"..formatInteger(consumption).." mB/s")
  local fc=C.normal
  if forecast~=nil then local n=tonumber(forecast) or 0; if n<=21600 then fc=C.critical elseif n<=86400 then fc=C.warning end end
  text(f.x+83,f.y+2,"&fПрогноз: "..fc..forecastText)
  local displayMaximum=math.max(limit*2,fluid,1)
  text(f.x+3,f.y+4,fluidColor..makeBar(clamp(fluid/displayMaximum,0,1),83))
  text(f.x+89,f.y+4,"&fSTOP: &c"..shortNumber(limit).." mB")
  drawResources()
end

local function drawReactorCard(index,q,data)
  local f=F.reactors
  local col=(index-1)%3; local row=math.floor((index-1)/3)
  local x=f.x+2+col*39; local y=f.y+2+row*9; local w=37
  clearArea(x,y,w,8)
  if not q then text(x,y,"&c× РЕАКТОР "..index.."     НЕТ"); text(x,y+3,"&cКОМПОНЕНТ НЕ ОБНАРУЖЕН"); return end
  local status=getReactorStatus(q,data)
  local sx=x+w-#tostring(status.short)-1
  text(x,y,status.color..status.symbol.." РЕАКТОР "..tostring(q.id or index))
  text(sx,y,status.color..status.short)
  text(x,y+1,q.liquid and "&bЖИДКОСТНЫЙ" or "&eВОЗДУШНЫЙ")
  text(x,y+2,"&fМощность: &6"..utils.energy(q.energy or 0))
  text(x,y+3,"&fТемпература: "..temperatureColor(q.temp)..tostring(math.floor(tonumber(q.temp) or 0)).."°C")
  if q.liquid then
    local realConsumption=(q.activated and (tonumber(q.coolant) or 0)>0) and (tonumber(q.coolant) or 0) or 0
    local ratio=clamp(tonumber(q.coolantRatio) or 0,0,1)
    local rc=coolantColor(ratio)
    text(x,y+4,"&fРасход: &b"..formatInteger(realConsumption).." mB/s")
    text(x,y+5,"&fОхлаждение: "..rc..tostring(percent(ratio)).."%")
    text(x,y+6,rc..makeBar(ratio,24))
  else
    text(x,y+4,"&fУровень: &e"..tostring(q.level or 0))
    text(x,y+5,"&8Охлаждающая жидкость не используется")
  end
  if status.short=="STOP" then text(x,y+7,status.color.."STOP: "..status.reason)
  else text(x,y+7,"&fСтержни: "..rodColor(q.rodTime)..utils.secondsToHMS(q.rodTime or 0)) end
end

local function drawSummary(data)
  local f=F.summary; clearArea(f.x+1,f.y+1,f.w-2,1)
  if not data then text(f.x+3,f.y+1,"&eСводка ожидает данные..."); return end
  text(f.x+3,f.y+1,"&fΣ МОЩНОСТЬ: &6"..utils.energy(data.totalEnergy or 0))
  text(f.x+40,f.y+1,"&fАКТИВНЫЙ РАСХОД: &b"..formatInteger(data.totalCoolant or 0).." mB/s")
  text(f.x+85,f.y+1,"&fМАКС. ТЕМП.: "..temperatureColor(data.hottest)..tostring(math.floor(tonumber(data.hottest) or 0)).."°C")
end

local function drawSystems()
  local f=F.systems; clearArea(f.x+1,f.y+1,f.w-2,1)
  local online={}; local offline=0
  for _,p in ipairs(state.players or {}) do if p.online then online[#online+1]=tostring(p.name) else offline=offline+1 end end
  local playerText=#online==0 and "&8нет игроков онлайн" or "&a"..table.concat(online,", ")
  if offline>0 then playerText=playerText.." &8(offline: "..offline..")" end
  text(f.x+3,f.y+1,"&fFLUX: &6"..utils.energy(state.flux.input or 0).." &8/ MAX "..utils.energy(state.flux.maxInput or 0))
  text(f.x+48,f.y+1,"&fME CPU: &c"..tostring(state.me.busy or 0).."&f/"..tostring(state.me.total or 0))
  text(f.x+68,f.y+1,"&fИгроки: "..playerText)
end

function M.init()
  term.clear()
  if not gpu then return false,"GPU не найден" end
  local ok,err=pcall(function() gpu.setResolution(SCREEN_W,SCREEN_H) end)
  if not ok then return false,"Не удалось установить разрешение "..SCREEN_W.."x"..SCREEN_H..": "..tostring(err) end
  sgui.drawMain("&d&4["..tostring(config.tableTitle or "Reactor Monitor").."]",sgui.colors["border"],"2")
  for _,frame in pairs(F) do sgui.drawFrame(frame.x,frame.y,frame.w,frame.h,frame.title,sgui.colors["border"]) end
  drawStatus(); drawCoolantPanel(nil); drawSummary(nil); drawSystems(); M.drawButtons()
  return true
end

function M.drawButtons()
  clear(3,39,116)
  for _,b in pairs(B) do text(b.x,b.y,C.button..b.color..b.text) end
end
function M.hitButton(x,y)
  for name,b in pairs(B) do if y==b.y and x>=b.x and x<b.x+b.w then return name end end
  return nil
end
function M.drawFlux(data)
  if not data then return end
  state.flux={name=data.name or "Без имени",input=tonumber(data.input) or 0,buffer=tonumber(data.buffer) or 0,maxInput=tonumber(data.maxInput) or 0,available=data.name~="Flux недоступен" and data.name~="Ошибка Flux"}
  drawStatus(); drawSystems()
end
function M.drawPlayers(list) state.players=list or {}; drawSystems() end
function M.drawME(data)
  if not data then return end
  state.me={processors=data.processors or {},idle=tonumber(data.idle) or 0,busy=tonumber(data.busy) or 0,total=tonumber(data.total) or 0,available=true}
  drawStatus(); drawSystems()
end
function M.drawResources(data)
  if not data then return end
  state.resources=data.items or {}
  drawResources()
end
function M.drawReactors(data)
  if not data then return end
  state.reactors=data; drawStatus(); drawCoolantPanel(data)
  for i=1,6 do drawReactorCard(i,data.reactors and data.reactors[i] or nil,data) end
  drawSummary(data); drawSystems()
end

return M
