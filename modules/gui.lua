local component = require("component")
local term = require("term")
local sgui = require("sgui")
local config = require("config.config")
local utils = require("lib.utils")
local gui = {}
local gpu = component.isAvailable("gpu") and component.gpu or nil

local frames = {
  energy={x=2,y=2,w=40,h=8,title="Энерго-сеть"},
  players={x=42,y=2,w=78,h=8,title="Игроки"},
  reactors={x=2,y=10,w=118,h=20,title="Реакторы"},
  me={x=2,y=30,w=118,h=10,title="МЭ Процессы создания"}
}
local buttons = {
  update={x=3,y=8,w=10,text="[ ОБН ]"},
  restart={x=14,y=8,w=11,text="[ РЕСТ ]"},
  exit={x=26,y=8,w=10,text="[ ВЫХ ]"}
}

local function text(x,y,value) sgui.text(x,y,value) end
local function clearLine(x,y,width) text(x,y,string.rep(" ",width)) end

function gui.init()
  term.clear()
  if not gpu then return false, "GPU не найден" end
  gpu.setResolution(config.screenWidth, config.screenHeight)
  sgui.drawMain("&d&4["..config.tableTitle.."]", sgui.colors["border"], "2")
  for _,f in pairs(frames) do sgui.drawFrame(f.x,f.y,f.w,f.h,f.title,sgui.colors["border"]) end
  gui.drawButtons()
  return true
end

function gui.drawButtons()
  text(buttons.update.x,buttons.update.y,"&0&2"..buttons.update.text)
  text(buttons.restart.x,buttons.restart.y,"&0&6"..buttons.restart.text)
  text(buttons.exit.x,buttons.exit.y,"&0&4"..buttons.exit.text)
end

function gui.hitButton(x,y)
  for name,b in pairs(buttons) do
    if y==b.y and x>=b.x and x<b.x+b.w then return name end
  end
end

function gui.drawFlux(s)
  clearLine(3,4,37); clearLine(3,5,37); clearLine(3,6,37); clearLine(3,7,37)
  text(3,4,"&aСеть: &e"..tostring(s.name or "Нет данных"))
  text(3,5,"&aВход: &2"..utils.energy(s.input,3))
  text(3,6,"&aБуфер: &2"..utils.energy(s.buffer,3):gsub("/t$",""))
  text(3,7,"&aМакс. вход: &2"..utils.energy(s.maxInput,3))
end

function gui.drawPlayers(list)
  local f=frames.players; local cols=4; local width=math.floor((f.w-2)/cols)
  for row=0,4 do clearLine(f.x+1,f.y+1+row,f.w-2) end
  for i,p in ipairs(list) do
    local col=(i-1)%cols; local row=math.floor((i-1)/cols)
    if row<5 then text(f.x+1+col*width,f.y+2+row,(p.online and "&2" or "&4")..p.name) end
  end
end

function gui.drawME(data)
  local f=frames.me
  for row=0,6 do clearLine(f.x+1,f.y+1+row,f.w-2) end
  local cols=5; local width=22
  for i,cpu in ipairs(data.processors or {}) do
    local col=(i-1)%cols; local row=math.floor((i-1)/cols)
    if row<5 then text(f.x+1+col*width,f.y+2+row,"&fCPU #"..i..": "..(cpu.busy and "&cВ работе" or "&aСвободен")) end
  end
  text(f.x+1,f.y+7,"&a"..data.idle.." &f/ &c"..data.busy.."   &9Всего: &a"..data.total)
end

function gui.drawReactors(stats)
  local f=frames.reactors; local cols=3; local rw=34; local rh=8
  for i=1,6 do
    local col=(i-1)%cols; local row=math.floor((i-1)/cols)
    local x=f.x+3+col*38; local y=f.y+2+row*8
    for n=0,rh-1 do clearLine(x,y+n,rw) end
    local r=stats.reactors[i]
    if r then
      text(x,y,(r.online and "&a" or "&4").."Реактор №"..r.id.." ("..r.kind..")")
      text(x,y+1,"&fВключен: "..(r.activated and "&aOn" or "&4Off"))
      text(x,y+2,"&fУровень: &e"..tostring(r.level))
      text(x,y+3,"&fЭнергия: &6"..utils.energy(r.energy))
      text(x,y+4,"&fТемп: "..(r.temp>=config.reactorTempWarn and "&c" or "&f")..tostring(r.temp).."°C")
      text(x,y+5,"&eСтержни: "..utils.secondsToHMS(r.rodTime))
      if r.liquid then text(x,y+6,"&fРасход: &b"..tostring(r.coolant).." mB/s") end
    end
  end
  clearLine(f.x+1,f.y+18,f.w-2)
  text(f.x+1,f.y+18,string.format("&fΣ: &6%s  &b%s mB/s   &fРеакторов: &e%d   &fЖидкости: &b%d / %d",utils.energy(stats.totalEnergy),stats.totalCoolant,stats.count,stats.fluidCount,config.minFluidDrop))
end

return gui
