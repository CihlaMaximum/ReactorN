local component=require("component")
local term=require("term")
local sgui=require("sgui")
local config=require("config.config")
local utils=require("lib.utils")
local M={}
local gpu=component.isAvailable("gpu") and component.gpu or nil
local F={energy={x=2,y=2,w=40,h=8,title="Энерго-сеть"},players={x=42,y=2,w=78,h=8,title="Игроки"},reactors={x=2,y=10,w=118,h=20,title="Реакторы"},me={x=2,y=30,w=118,h=10,title="МЭ Процессы создания"}}
local B={update={x=3,y=8,w=10,text="[ ОБН ]"},restart={x=14,y=8,w=11,text="[ РЕСТ ]"},exit={x=26,y=8,w=10,text="[ ВЫХ ]"}}
local function text(x,y,v) sgui.text(x,y,v) end
local function clear(x,y,w) text(x,y,string.rep(" ",w)) end

function M.init()
  term.clear()
  if not gpu then return false,"GPU не найден" end
  gpu.setResolution(tonumber(config.screenWidth) or 120,tonumber(config.screenHeight) or 40)
  sgui.drawMain("&d&4["..tostring(config.tableTitle or "Мониторинг").."]",sgui.colors["border"],"2")
  for _,f in pairs(F) do sgui.drawFrame(f.x,f.y,f.w,f.h,f.title,sgui.colors["border"]) end
  M.drawButtons(); return true
end
function M.drawButtons()
  text(B.update.x,B.update.y,"&0&2"..B.update.text)
  text(B.restart.x,B.restart.y,"&0&6"..B.restart.text)
  text(B.exit.x,B.exit.y,"&0&4"..B.exit.text)
end
function M.hitButton(x,y)
  for n,b in pairs(B) do if y==b.y and x>=b.x and x<b.x+b.w then return n end end
end
function M.drawFlux(s)
  for y=4,7 do clear(3,y,37) end
  text(3,4,"&aСеть: &e"..tostring(s.name))
  text(3,5,"&aВход: &2"..utils.energy(s.input,3))
  text(3,6,"&aБуфер: &2"..utils.energy(s.buffer,3):gsub("/t$",""))
  text(3,7,"&aМакс. вход: &2"..utils.energy(s.maxInput,3))
end
function M.drawPlayers(list)
  local f=F.players; for y=0,4 do clear(f.x+1,f.y+1+y,f.w-2) end
  local cols=4; local w=math.floor((f.w-2)/cols)
  for i,p in ipairs(list or {}) do local c=(i-1)%cols; local r=math.floor((i-1)/cols); if r<5 then text(f.x+1+c*w,f.y+2+r,(p.online and "&2" or "&4")..p.name) end end
end
function M.drawME(d)
  local f=F.me; for y=0,6 do clear(f.x+1,f.y+1+y,f.w-2) end
  for i,cpu in ipairs(d.processors or {}) do local c=(i-1)%5; local r=math.floor((i-1)/5); if r<5 then text(f.x+1+c*22,f.y+2+r,"&fCPU #"..i..": "..(cpu.busy and "&cВ работе" or "&aСвободен")) end end
  text(f.x+1,f.y+7,"&a"..d.idle.." &f/ &c"..d.busy.."   &9Всего: &a"..d.total)
end
function M.drawReactors(s)
  local f=F.reactors
  for i=1,6 do
    local c=(i-1)%3; local r=math.floor((i-1)/3); local x=f.x+3+c*38; local y=f.y+2+r*8
    for n=0,7 do clear(x,y+n,34) end
    local q=s.reactors[i]
    if q then
      text(x,y,(q.online and "&a" or "&4").."Реактор №"..q.id.." ("..q.kind..")")
      text(x,y+1,"&fВключен: "..(q.activated and "&aOn" or "&4Off"))
      text(x,y+2,"&fУровень: &e"..q.level)
      text(x,y+3,"&fЭнергия: &6"..utils.energy(q.energy))
      text(x,y+4,"&fТемп: "..(q.temp>=(tonumber(config.reactorTempWarn) or 950) and "&c" or "&f")..q.temp.."°C")
      text(x,y+5,"&fСтержни: "..q.rodColor..utils.secondsToHMS(q.rodTime))
      if q.liquid then text(x,y+6,"&fРасход: &b"..q.coolant.." mB/s") end
    end
  end
  clear(f.x+1,f.y+18,f.w-2)
  local limit=tonumber(config.minFluidDrop) or 1000000
  local fc=s.fluidCount<limit and "&c" or "&b"
  local forecast=s.coolantForecastSeconds
  local forecastText=forecast and utils.secondsToHMS(forecast) or "--:--:--"
  text(f.x+1,f.y+18,string.format("&fΣ: &6%s  &b%s mB/s  &fПрогноз: &e%s  &fРеакторов: &e%d  &fХладагент: %s%d &f/ &b%d",utils.energy(s.totalEnergy),s.totalCoolant,forecastText,s.count,fc,s.fluidCount,limit))
end
return M
