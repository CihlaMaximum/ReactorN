local filesystem=require("filesystem");local shell=require("shell");local config=require("config.config");local M={}
local files={"main.lua","config/config.lua","lib/utils.lua","modules/chat.lua","modules/flux.lua","modules/gui.lua","modules/me.lua","modules/players.lua","modules/reactors.lua","modules/updater.lua"}
local function ensure(path)local d=path:match("^(.*)/[^/]+$");if d and not filesystem.exists(d)then filesystem.makeDirectory(d)end end
function M.run()local tempRoot="/home/update_tmp";if filesystem.exists(tempRoot)then shell.execute("rm -r "..tempRoot)end;filesystem.makeDirectory(tempRoot)
 for _,rel in ipairs(files)do local dest=tempRoot.."/"..rel;ensure(dest);local ok=shell.execute("wget -fq "..config.githubBase..rel.." "..dest);if not ok or not filesystem.exists(dest)then filesystem.remove(tempRoot);return false,"Ошибка загрузки: "..rel end;local f=io.open(dest,"r");local body=f and f:read("*a")or"";if f then f:close()end;if #body<20 then filesystem.remove(tempRoot);return false,"Пустой файл: "..rel end end
 local backup="/home/update_backup";if filesystem.exists(backup)then shell.execute("rm -r "..backup)end;filesystem.makeDirectory(backup)
 for _,rel in ipairs(files)do local live="/home/"..rel;local bak=backup.."/"..rel;ensure(bak);if filesystem.exists(live)then filesystem.copy(live,bak)end;ensure(live);if filesystem.exists(live)then filesystem.remove(live)end;local ok,err=filesystem.copy(tempRoot.."/"..rel,live);if not ok then return false,"Ошибка установки "..rel..": "..tostring(err)end end
 shell.execute("rm -r "..tempRoot);return true,"Все файлы обновлены"
end
return M
