local computer = require("computer")
local config = require("config.config")

local M = {
  history = {},
  forecastSeconds = nil,
  lastHistoryUpdate = -1000000000
}

local function setting(name, fallback)
  local value = tonumber(config[name])
  if value == nil then return fallback end
  return value
end

function M.update(fluid, consumption)
  local fluidNumber = tonumber(fluid) or 0
  local consumptionNumber = tonumber(consumption) or 0
  if fluidNumber < 0 then fluidNumber = 0 end
  if consumptionNumber < 0 then consumptionNumber = 0 end

  local historySize = math.max(1, math.floor(setting("coolantHistorySize", 300)))
  local minConsumption = math.max(0, setting("coolantForecastMinConsumption", 1))
  local historyInterval = math.max(1, setting("meInterval", 5))
  local shutdownLimit = math.max(0, setting("minFluidDrop", 1000000))
  local now = tonumber(computer.uptime()) or 0

  if now - (tonumber(M.lastHistoryUpdate) or -1000000000) >= historyInterval then
    M.lastHistoryUpdate = now
    M.history[#M.history + 1] = {
      time = now,
      fluid = fluidNumber,
      consumption = consumptionNumber
    }
    while #M.history > historySize do table.remove(M.history, 1) end
  end

  local usableFluid = math.max(0, fluidNumber - shutdownLimit)
  if consumptionNumber >= minConsumption and consumptionNumber > 0 then
    M.forecastSeconds = math.floor(usableFluid / consumptionNumber)
  else
    M.forecastSeconds = nil
  end

  return M.forecastSeconds
end

function M.getForecastSeconds() return M.forecastSeconds end
function M.getHistory() return M.history end
return M
