local component=require("component")
local term=require("term")
local sgui=require("sgui")
local config=require("config.config")
local utils=require("lib.utils")
local M={}
local gpu=component.isAvailable("gpu") and component.gpu or nil
local W=tonumber(config.screenWidth) or 120
local H=tonumber(config.screenHeight) or 40
local state={flux={},me={},players={},reactors=nil,resources={}}
local function text(x,y,v) sgui.text(x,y,tostring(v or "")) end
local function clear(x,y,w) text(x,y,string.rep(" ",math.max(0,w or 0))) end
local function fmt(v) local n=math.floor(math.abs(tonumber(v) or 0)+0.5);local s=tostring(n);repeat local c;s,c=s:gsub("^(%d+)(%d%d%d)","%1 %2") until c==0;return ((tonumber(v) or 0)<0 and "-" or "")..s end
local function rate(v) v=tonumber(v) or 0;if v>0 then return "&a+"..fmt(v).."/ч" elseif v<0 then return "&c-"..fmt(-v).."/ч" end return "&8 0/ч" end
local B={update={x=4,y=39,w=16,text="[ ОБНОВИТЬ ]"},restart={x=50,y=39,w=18,text="[ ПЕРЕЗАПУСК ]"},exit={x=104,y=39,w=12,text="[ ВЫХОД ]"}}
function M.init()
 term.clear();if not gpu then return false,"GPU не найден" end
 local ok,err=pcall(function()gpu.setResolution(W,H)end);if not ok then return false,tostring(err) end
 sgui.drawMain("&d&4["..tostring(config.tableTitle or "Мониторинг").."]",sgui.colors["border"],"2")
 sgui.drawFrame(2,5,118,7,"Хладагент / ресурсы ME",sgui.colors["border"])
 sgui.drawFrame(2,12,118,20,"Реакторы",sgui.colors["border"])
 M.drawButtons();return true
end
function M.drawButtons() clear(3,39,116);for _,b in pairs(B)do text(b.x,b.y,"&0&2"..b.text)end end
function M.hitButton(x,y)for n,b in pairs(B)do if y==b.y and x>=b.x and x<b.x+b.w then return n end end end
function M.drawResources(data)
 state.resources=(data and data.items) or state.resources
 clear(4,10,114);local x=4
 for _,cfg in ipairs(config.trackedResources or {})do local r=state.resources[cfg.key];if r then local s="&f"..tostring(r.label)..": &b"..fmt(r.count).." "..rate(r.rateHour);text(x,10,s);x=x+38 end end
end
function M.drawME(d) if d then state.me=d end end
function M.drawFlux(d) if d then state.flux=d end end
function M.drawPlayers(d) state.players=d or {} end
function M.drawReactors(d)
 if not d then return end;state.reactors=d
 clear(4,7,114);text(4,7,"&fЗапас: &b"..fmt(d.fluidCount).." mB");text(44,7,"&fРасход: &b"..fmt(d.totalCoolant).." mB/s");text(82,7,"&fПрогноз: &e"..(d.coolantForecastSeconds and utils.secondsToHMS(d.coolantForecastSeconds) or "--:--:--"))
 for i=1,6 do local q=d.reactors and d.reactors[i];local col=(i-1)%3;local row=math.floor((i-1)/3);local x=4+col*39;local y=14+row*9;for yy=0,7 do clear(x,y+yy,36)end;if q then text(x,y,(q.activated and "&a● " or "&8○ ").."РЕАКТОР "..i);text(x,y+1,q.liquid and "&bЖИДКОСТНЫЙ" or "&eВОЗДУШНЫЙ");text(x,y+2,"&fМощность: &6"..utils.energy(q.energy or 0));text(x,y+3,"&fТемпература: &e"..math.floor(tonumber(q.temp) or 0).."°C");if q.liquid then text(x,y+4,"&fРасход: &b"..fmt(q.activated and q.coolant or 0).." mB/s");text(x,y+5,"&fОхлаждение: &b"..math.floor((tonumber(q.coolantRatio)or 0)*100+0.5).."%") else text(x,y+4,"&fУровень: &e"..tostring(q.level or 0)) end;text(x,y+7,"&fСтержни: &a"..utils.secondsToHMS(q.rodTime or 0)) else text(x,y,"&c× РЕАКТОР "..i.." НЕТ") end end
 clear(4,33,114);text(4,33,"&fΣ МОЩНОСТЬ: &6"..utils.energy(d.totalEnergy or 0));text(44,33,"&fАКТИВНЫЙ РАСХОД: &b"..fmt(d.totalCoolant or 0).." mB/s");text(88,33,"&fМАКС.Т: &e"..math.floor(tonumber(d.hottest)or 0).."°C")
 M.drawResources({items=state.resources})
end
return M
