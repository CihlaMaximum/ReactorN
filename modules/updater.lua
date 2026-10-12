local filesystem=require("filesystem")
local shell=require("shell")
local config=require("config.config")
local updater={}
function updater.run()
  local temp="/home/main_download.lua"
  if filesystem.exists(temp) then filesystem.remove(temp) end
  if filesystem.exists(config.backupPath) then filesystem.remove(config.backupPath) end
  if filesystem.exists(config.programPath) then
    local ok,err=filesystem.copy(config.programPath,config.backupPath); if not ok then return false,"Ошибка резервной копии: "..tostring(err) end
  end
  local ok=shell.execute("wget -fq "..config.updateUrl.." "..temp)
  if not ok or not filesystem.exists(temp) then return false,"Ошибка загрузки" end
  local f=io.open(temp,"r"); local body=f and f:read("*a") or ""; if f then f:close() end
  if #body<100 then filesystem.remove(temp); return false,"Загруженный файл слишком короткий" end
  if filesystem.exists(config.programPath) then filesystem.remove(config.programPath) end
  local moved,err=filesystem.rename(temp,config.programPath)
  if not moved then if filesystem.exists(config.backupPath) then filesystem.copy(config.backupPath,config.programPath) end; return false,"Ошибка замены: "..tostring(err) end
  return true,"Обновление установлено"
end
return updater
