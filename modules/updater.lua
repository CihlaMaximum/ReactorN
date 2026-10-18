local filesystem=require("filesystem")
local shell=require("shell")
local computer=require("computer")
local config=require("config.config")
local M={}

local files={
  "main.lua",
  "config/config.lua",
  "lib/utils.lua",
  "modules/chat.lua",
  "modules/flux.lua",
  "modules/gui.lua",
  "modules/me.lua",
  "modules/players.lua",
  "modules/reactors.lua",
  "modules/coolant_monitor.lua",
  "modules/updater.lua"
}

local function ensure(path)
  local d=path:match("^(.*)/[^/]+$")
  if d and not filesystem.exists(d) then filesystem.makeDirectory(d) end
end

local function removeTree(path)
  if filesystem.exists(path) then shell.execute("rm -r "..path) end
end

local function readAll(path)
  local f=io.open(path,"rb")
  if not f then return nil end
  local body=f:read("*a")
  f:close()
  return body
end

local function writeAll(path,body)
  ensure(path)
  local f=io.open(path,"wb")
  if not f then return false,"cannot open destination" end
  f:write(body)
  f:close()
  return true
end

local function sameFile(a,b)
  local aa=readAll(a)
  local bb=readAll(b)
  return aa~=nil and bb~=nil and aa==bb
end

local function download(rel,destination,nonce)
  ensure(destination)
  local url=config.githubBase..rel.."?cb="..tostring(nonce)
  local ok=shell.execute("wget -fq '"..url.."' '"..destination.."'")
  if not ok or not filesystem.exists(destination) then
    return false,"Ошибка загрузки: "..rel
  end
  local body=readAll(destination) or ""
  if #body<20 then return false,"Пустой/слишком короткий файл: "..rel end
  return true
end

function M.run()
  local tempRoot="/home/update_tmp"
  local backupRoot="/home/update_backup"
  local nonce=math.floor((tonumber(computer.uptime()) or 0)*1000)

  removeTree(tempRoot)
  filesystem.makeDirectory(tempRoot)

  print("Проверка обновлений...")
  for i,rel in ipairs(files) do
    local destination=tempRoot.."/"..rel
    print(string.format("[%d/%d] %s",i,#files,rel))
    local ok,err=download(rel,destination,nonce+i)
    if not ok then removeTree(tempRoot); return false,err end
  end

  local changed={}
  for _,rel in ipairs(files) do
    local live="/home/"..rel
    local fresh=tempRoot.."/"..rel
    if not filesystem.exists(live) or not sameFile(live,fresh) then
      changed[#changed+1]=rel
      print("ИЗМЕНЕН: "..rel)
    else
      print("БЕЗ ИЗМЕНЕНИЙ: "..rel)
    end
  end

  if #changed==0 then
    removeTree(tempRoot)
    return true,"Новых изменений нет. Проверено файлов: "..tostring(#files)
  end

  removeTree(backupRoot)
  filesystem.makeDirectory(backupRoot)

  for _,rel in ipairs(changed) do
    local live="/home/"..rel
    if filesystem.exists(live) then
      local backup=backupRoot.."/"..rel
      ensure(backup)
      local ok,err=filesystem.copy(live,backup)
      if not ok then
        removeTree(tempRoot)
        return false,"Ошибка резервной копии "..rel..": "..tostring(err)
      end
    end
  end

  for _,rel in ipairs(changed) do
    local live="/home/"..rel
    local fresh=tempRoot.."/"..rel
    local body=readAll(fresh)
    if not body then
      removeTree(tempRoot)
      return false,"Не удалось прочитать скачанный файл: "..rel
    end
    local ok,err=writeAll(live,body)
    if not ok then
      removeTree(tempRoot)
      return false,"Ошибка установки "..rel..": "..tostring(err)
    end
    if not sameFile(live,fresh) then
      removeTree(tempRoot)
      return false,"Проверка после установки не пройдена: "..rel
    end
  end

  removeTree(tempRoot)
  return true,string.format("Обновление успешно. Обновлено %d из %d файлов.",#changed,#files)
end

return M
