local filesystem=require("filesystem")
local shell=require("shell")
local config=require("config.config")
local M={}
local files={"main.lua","config/config.lua","lib/utils.lua","modules/chat.lua","modules/flux.lua","modules/gui.lua","modules/me.lua","modules/players.lua","modules/reactors.lua","modules/coolant_monitor.lua","modules/updater.lua"}
local function ensure(path) local d=path:match("^(.*)/[^/]+$"); if d and not filesystem.exists(d) then filesystem.makeDirectory(d) end end
local function removeTree(path) if filesystem.exists(path) then shell.execute("rm -r "..path) end end
function M.run()
  local tempRoot="/home/update_tmp"; local backupRoot="/home/update_backup"
  removeTree(tempRoot); filesystem.makeDirectory(tempRoot)
  for _,rel in ipairs(files) do
    local destination=tempRoot.."/"..rel; ensure(destination)
    local ok=shell.execute("wget -fq "..config.githubBase..rel.." "..destination)
    if not ok or not filesystem.exists(destination) then removeTree(tempRoot); return false,"Ошибка загрузки: "..rel end
    local f=io.open(destination,"r"); local body=f and f:read("*a") or ""; if f then f:close() end
    if #body<20 then removeTree(tempRoot); return false,"Пустой файл: "..rel end
  end
  removeTree(backupRoot); filesystem.makeDirectory(backupRoot)
  for _,rel in ipairs(files) do local live="/home/"..rel; local backup=backupRoot.."/"..rel; ensure(backup); if filesystem.exists(live) then filesystem.copy(live,backup) end end
  for _,rel in ipairs(files) do local live="/home/"..rel; ensure(live); if filesystem.exists(live) then filesystem.remove(live) end; local ok,err=filesystem.copy(tempRoot.."/"..rel,live); if not ok then return false,"Ошибка установки "..rel..": "..tostring(err) end end
  removeTree(tempRoot); return true,"Все файлы обновлены"
end
return M
