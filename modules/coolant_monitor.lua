local computer = require("computer")
local config = require("config.config")

local M = {
  history = {},
  forecastSeconds = nil,
  lastFluid = 0,
  lastConsumption = 0,
  lastHistoryUpdate = -1e9
}

local function numberSetting(name, fallback)
  local value = tonumber(config[name])
  if value == nil then return fallback end
  return value
end

function M.update(fluid, consumption)
  fluid = math.max(0, tonumber(fluid) or 0)
  consumption = math.max(0, tonumber(consumption) or 0)

  local historySize = math.max(1, math.floor(numberSetting("coolantHistorySize", 300)))
  local minimumConsumption = math.max(0, numberSetting("coolantForecastMinConsumption", 1))
  local historyInterval = math.max(1, numberSetting("meInterval", 5))

  M.lastFluid = fluid
  M.lastConsumption = consumption

  local now = computer.uptime()
  if now - M.lastHistoryUpdate >= historyInterval then
    M.lastHistoryUpdate = now
    table.insert(M.history, {
      time = now,
      fluid = fluid,
      consumption = consumption
    })
    while #M.history > historySize do
      table.remove(M.history, 1)
    end
  end

  if consumption >= minimumConsumption and consumption > 0 then
    M.forecastSeconds = math.floor(fluid / consumption)
  else
    M.forecastSeconds = nil
  end

  return M.forecastSeconds
end

function M.getForecastSeconds() return M.forecastSeconds end
function M.getHistory() return M.history end
function M.getTrend()
  if #M.history < 2 then return 0 end
  return M.history[#M.history].fluid - M.history[1].fluid
end

return M
