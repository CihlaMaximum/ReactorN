local shell=require("shell");local filesystem=require("filesystem")
local base="https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/"
local files={"main.lua","config/config.lua","lib/utils.lua","modules/chat.lua","modules/flux.lua","modules/gui.lua","modules/me.lua","modules/players.lua","modules/reactors.lua","modules/updater.lua"}
local function ensure(path)local d=path:match("^(.*)/[^/]+$");if d and not filesystem.exists(d)then filesystem.makeDirectory(d)end end
local good=0
for i,rel in ipairs(files)do local path="/home/"..rel;ensure(path);if filesystem.exists(path)then filesystem.remove(path)end;print(string.format("[%d/%d] %s",i,#files,rel));local ok=shell.execute("wget -f "..base..rel.." "..path);if ok and filesystem.exists(path)then good=good+1;print("OK")else print("ОШИБКА")end end
print(string.format("Установлено %d/%d файлов",good,#files));if good==#files then print("Запуск: lua /home/main.lua")end
