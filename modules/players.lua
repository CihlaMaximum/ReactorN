local computer=require("computer")
local filesystem=require("filesystem")
local computerUptime=computer.uptime
local config=require("config.config")
local players={last=-1e9,data={},permissions={}}
local path=config.dataDir.."/playersData.txt"
if not filesystem.exists(config.dataDir) then filesystem.makeDirectory(config.dataDir) end

local function save()
  local f=io.open(path,"w"); if not f then return false end
  for _,p in ipairs(players.data) do f:write(string.format("%s|%s|%s|%s\n",p.name,p.greeting,p.farewell,tostring(p.online))) end
  f:close(); return true
end

function players.load()
  players.data={}
  local f=io.open(path,"r")
  if f then
    for line in f:lines() do
      local n,g,b,s=line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
      if n then players.data[#players.data+1]={name=n,greeting=g,farewell=b,online=s=="true"} end
    end
    f:close()
  end
  if #players.data==0 then players.data={{name="Stawlie_",greeting="Царь батюшка на сервере",farewell="Покинул коноху",online=false}}; save() end
  players.permissions={}
  for _,p in ipairs(players.data) do players.permissions[p.name]=true end
  if config.debugUser then players.permissions[config.debugUser]=true end
end

function players.add(name,greeting,farewell)
  for _,p in ipairs(players.data) do if p.name==name then return false,"Игрок уже существует" end end
  players.data[#players.data+1]={name=name,greeting=greeting or "Зашёл не в ту дверь",farewell=farewell or "Покинул сервер",online=false}
  players.permissions[name]=true; save(); return true,"Игрок добавлен"
end
function players.remove(name)
  for i,p in ipairs(players.data) do if p.name==name then table.remove(players.data,i); players.permissions[name]=nil; save(); return true,"Игрок удалён" end end
  return false,"Игрок не найден"
end
function players.setGreeting(name,text) for _,p in ipairs(players.data) do if p.name==name then p.greeting=text; save(); return true,"Приветствие обновлено" end end return false,"Игрок не найден" end
function players.setFarewell(name,text) for _,p in ipairs(players.data) do if p.name==name then p.farewell=text; save(); return true,"Прощание обновлено" end end return false,"Игрок не найден" end
function players.allowed(name) return players.permissions[name]==true end

function players.update(force)
  local now=computerUptime(); if not force and now-players.last<config.playerInterval then return nil end; players.last=now
  local changes={}
  for _,p in ipairs(players.data) do
    pcall(computer.removeUser,p.name)
    local ok,online=pcall(computer.addUser,p.name); online=ok and online==true
    if online~=p.online then changes[#changes+1]={type=online and "joined" or "left",player=p.name,message=online and p.greeting or p.farewell}; p.online=online end
    pcall(computer.addUser,p.name)
  end
  save(); return players.data,changes
end
players.load()
return players
