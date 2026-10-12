local component=require("component")
local event=require("event")
local thread=require("thread")
local computer=require("computer")
local config=require("config.config")
local chat={}
local box=component.isAvailable("chat_box") and component.chat_box or nil
local running=false

local function say(message) if box then pcall(box.say,message) end end
function chat.notifyChanges(changes)
  for _,c in ipairs(changes or {}) do say("§e"..c.player..(c.type=="joined" and "§a§l " or "§c§l ")..c.message) end
end
function chat.notifyMissing(count,found,expected)
  if count<=0 then return end
  say("§c§l⚠ ВНИМАНИЕ: отсутствует реакторов: "..count..". Обнаружено "..found.." из "..expected)
end
function chat.start(players)
  if running or not box then return end; running=true
  box.setName("§9§l"..config.chatTitle.."§7§o")
  thread.create(function()
    while running do
      local _,_,nick,msg=event.pull(1,"chat_message")
      if nick and msg and players.allowed(nick) then
        if msg=="@sleep" then computer.shutdown(true)
        elseif msg=="@help" then say("@add, @remove, @greeting, @farewell, @sleep")
        elseif msg:match("^@add ") then local _,m=players.add(msg:match("^@add%s+(.+)$")); say(m)
        elseif msg:match("^@remove ") then local _,m=players.remove(msg:match("^@remove%s+(.+)$")); say(m)
        elseif msg:match("^@greeting ") then local n,t=msg:match("^@greeting%s+(%S+)%s+(.+)$"); local _,m=players.setGreeting(n,t); say(m)
        elseif msg:match("^@farewell ") then local n,t=msg:match("^@farewell%s+(%S+)%s+(.+)$"); local _,m=players.setFarewell(n,t); say(m) end
      end
    end
  end)
end
return chat
