local shell=require("shell");local filesystem=require("filesystem");local computer=require("computer")
local base="https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/"
local files={"main.lua","config/config.lua","lib/utils.lua","modules/chat.lua","modules/flux.lua","modules/gui.lua","modules/me.lua","modules/resources.lua","modules/players.lua","modules/reactors.lua","modules/coolant_monitor.lua","modules/updater.lua"}
local function ensure(path)local d=path:match("^(.*)/[^/]+$");if d and not filesystem.exists(d)then filesystem.makeDirectory(d)end end
local good=0;local nonce=math.floor((tonumber(computer.uptime())or 0)*1000)
for i,rel in ipairs(files)do local path="/home/"..rel;ensure(path);if filesystem.exists(path)then filesystem.remove(path)end;print(string.format("[%d/%d] %s",i,#files,rel));local ok=shell.execute("wget -fq '"..base..rel.."?cb="..tostring(nonce+i).."' '"..path.."'");if ok and filesystem.exists(path)then local f=io.open(path,"rb");local body=f and f:read("*a")or"";if f then f:close()end;if #body>=20 then good=good+1;print("OK")else print("ОШИБКА: пустой файл")end else print("ОШИБКА")end end
print(string.format("Установлено %d/%d файлов",good,#files));if good==#files then print("Запуск: lua /home/main.lua")end
