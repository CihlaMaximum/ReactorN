local computer = require("computer")

local M = {
  history = {},
  forecastSeconds = nil,
  lastFluid = 0,
  lastConsumption = 0,
  lastHistoryUpdate = -1000000000
}

local HISTORY_SIZE = 300
local MIN_CONSUMPTION = 1
local HISTORY_INTERVAL = 5

function M.update(fluid, consumption)
  local fluidNumber = tonumber(fluid)
  local consumptionNumber = tonumber(consumption)

  if fluidNumber == nil or fluidNumber < 0 then
    fluidNumber = 0
  end

  if consumptionNumber == nil or consumptionNumber < 0 then
    consumptionNumber = 0
  end

  M.lastFluid = fluidNumber
  M.lastConsumption = consumptionNumber

  local now = tonumber(computer.uptime()) or 0
  local lastUpdate = tonumber(M.lastHistoryUpdate) or -1000000000

  if now - lastUpdate >= HISTORY_INTERVAL then
    M.lastHistoryUpdate = now
    M.history[#M.history + 1] = {
      time = now,
      fluid = fluidNumber,
      consumption = consumptionNumber
    }

    while #M.history > HISTORY_SIZE do
      table.remove(M.history, 1)
    end
  end

  if consumptionNumber > 0 and consumptionNumber >= MIN_CONSUMPTION then
    M.forecastSeconds = math.floor(fluidNumber / consumptionNumber)
  else
    M.forecastSeconds = nil
  end

  return M.forecastSeconds
end

function M.getForecastSeconds()
  return M.forecastSeconds
end

function M.getHistory()
  return M.history
end

function M.getTrend()
  if #M.history < 2 then
    return 0
  end

  local newest = tonumber(M.history[#M.history].fluid) or 0
  local oldest = tonumber(M.history[1].fluid) or 0
  return newest - oldest
end

return M
