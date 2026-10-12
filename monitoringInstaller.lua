-- wget -f https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/monitoringInstaller.lua monitoringInstaller.lua 
-- GitHub Downloader для OpenComputers (через wget)
-- Скачивает файлы с GitHub и размещает их по нужным папкам

local shell = require("shell")
local filesystem = require("filesystem")

-- Список файлов для скачивания
local files = {
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/main.lua",
        path = "/home/main.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/config/config.lua",
        path = "/home/config/config.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/lib/utils.lua",
        path = "/home/lib/utils.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/modules/chat.lua",
        path = "/home/modules/chat.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/modules/flux.lua",
        path = "/home/modules/flux.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/modules/gui.lua",
        path = "/modules/gui.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/modules/me.lua",
        path = "/home/modules/me.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/modules/players.lua",
        path = "/home/modules/players.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/modules/reactors.lua",
        path = "/home/modules/reactors.lua"
    },
    {
        url = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/modules/updater.lua",
        path = "/home/modules/updater.lua"
    }
    
}

-- Функция для создания папки, если она не существует
local function createDirectory(path)
    local dir = filesystem.path(path)
    if dir and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
        print("Создана папка: " .. dir)
    end
end

-- Функция для скачивания файла через wget
local function downloadFile(url, filePath)
    print("Скачивание: " .. filesystem.name(filePath))
    print("URL: " .. url)
    print("Путь: " .. filePath)
    
    -- Создаем папку, если необходимо
    createDirectory(filePath)
    
    -- Удаляем старый файл, если он существует
    if filesystem.exists(filePath) then
        filesystem.remove(filePath)
        print("Удален старый файл: " .. filePath)
    end
    
    -- Скачиваем файл через wget
    local success = shell.execute("wget -f " .. url .. " " .. filePath)
    
    if success and filesystem.exists(filePath) then
        print("✓ Успешно скачано: " .. filePath)
        return true
    else
        print("✗ Ошибка скачивания: " .. filePath)
        return false
    end
end

local function main()
    print("=== GitHub Downloader (wget) ===")
    print("Начинаем скачивание файлов...")
    print("")
    
    local successCount = 0
    local totalCount = #files
    
    for i, fileInfo in ipairs(files) do
        print(string.format("--- [%d/%d] ---", i, totalCount))
        
        if downloadFile(fileInfo.url, fileInfo.path) then
            successCount = successCount + 1
        end
        
        print("")
        os.sleep(1) -- Пауза между загрузками
    end
    
    print("=== Результаты ===")
    print(string.format("Успешно скачано: %d/%d файлов", successCount, totalCount))
    
    if successCount == totalCount then
        print("🎉 Все файлы успешно скачаны и установлены!")
    else
        print("⚠️  Некоторые файлы не удалось скачать.")
        print("Проверьте интернет-соединение и URL-адреса.")
    end
    
    print("\nГотово! Можете запускать main.lua")
end

main()
