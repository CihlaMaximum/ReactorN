local component = require("component")
local computer = require("computer")
local config = require("config.config")
local utils = require("lib.utils")

local M = {
  sent = {},
  lastRepeat = {}
}
local box = component.isAvailable("chat_box") and component.chat_box or nil

local function setting(name, fallback)
  return tonumber(config[name]) or fallback
end

local function say(text)
  if box then pcall(box.say, text) end
end

local function once(key, text)
  if not M.sent[key] then
    M.sent[key] = true
    say(text)
  end
end

local function resetAbove(prefix, value, thresholds)
  for key, limit in pairs(thresholds) do
    if value > limit then
      M.sent[prefix .. key] = nil
      M.lastRepeat[prefix .. key] = nil
    end
  end
end

local function repeatCritical(key, interval, text)
  local now = computer.uptime()
  local last = M.lastRepeat[key] or -1e9
  if now - last >= interval then
    M.lastRepeat[key] = now
    say(text)
  end
end

local function minimumRod(reactors)
  local bestTime, bestId = nil, nil
  for _, r in ipairs(reactors or {}) do
    local value = tonumber(r.rodTime)
    if value and value > 0 and (not bestTime or value < bestTime) then
      bestTime, bestId = value, r.id
    end
  end
  return bestTime, bestId
end

function M.update(stats, forecastSeconds)
  if not stats then return end

  if forecastSeconds and forecastSeconds > 0 then
    local thresholds = {
      ["12h"] = setting("coolantNotify12h", 43200),
      ["3h"] = setting("coolantNotify3h", 10800),
      ["1h"] = setting("coolantNotify1h", 3600)
    }
    resetAbove("coolant_", forecastSeconds, thresholds)

    if forecastSeconds <= setting("coolantNotify12h", 43200) then
      once("coolant_12h", "§e⚠ Хладагента осталось менее чем на 12 часов: §f" .. utils.secondsToHMS(forecastSeconds))
    end
    if forecastSeconds <= setting("coolantNotify3h", 10800) then
      once("coolant_3h", "§6⚠ Хладагента осталось менее чем на 3 часа: §f" .. utils.secondsToHMS(forecastSeconds))
    end
    if forecastSeconds <= setting("coolantNotify1h", 3600) then
      once("coolant_1h", "§c§l⚠ ХЛАДАГЕНТА МЕНЕЕ ЧЕМ НА 1 ЧАС: §f" .. utils.secondsToHMS(forecastSeconds))
      repeatCritical("coolant_repeat", setting("coolantCriticalRepeat", 600),
        "§c⚠ Критический запас хладагента: §f" .. utils.secondsToHMS(forecastSeconds))
    else
      M.lastRepeat.coolant_repeat = nil
    end
  end

  local rodTime, reactorId = minimumRod(stats.reactors)
  if rodTime then
    local thresholds = {
      ["12h"] = setting("rodNotify12h", 43200),
      ["6h"] = setting("rodNotify6h", 21600),
      ["3h"] = setting("rodNotify3h", 10800),
      ["1h"] = setting("rodNotify1h", 3600)
    }
    resetAbove("rod_" .. tostring(reactorId) .. "_", rodTime, thresholds)
    local prefix = "§e⚠ Реактор №" .. tostring(reactorId) .. ": стержни "

    if rodTime <= setting("rodNotify12h", 43200) then
      once("rod_" .. reactorId .. "_12h", prefix .. "менее 12 часов, осталось §f" .. utils.secondsToHMS(rodTime))
    end
    if rodTime <= setting("rodNotify6h", 21600) then
      once("rod_" .. reactorId .. "_6h", prefix .. "менее 6 часов, осталось §f" .. utils.secondsToHMS(rodTime))
    end
    if rodTime <= setting("rodNotify3h", 10800) then
      once("rod_" .. reactorId .. "_3h", "§6⚠ Реактор №" .. reactorId .. ": замените стержни, осталось §f" .. utils.secondsToHMS(rodTime))
    end
    if rodTime <= setting("rodNotify1h", 3600) then
      once("rod_" .. reactorId .. "_1h", "§c§l⚠ Реактор №" .. reactorId .. ": СТЕРЖНИ МЕНЕЕ 1 ЧАСА, осталось §f" .. utils.secondsToHMS(rodTime))
      repeatCritical("rod_repeat_" .. reactorId, setting("rodCriticalRepeat", 600),
        "§c⚠ Реактор №" .. reactorId .. ": критическое время стержней §f" .. utils.secondsToHMS(rodTime))
    else
      M.lastRepeat["rod_repeat_" .. reactorId] = nil
    end
  end
end

return M
