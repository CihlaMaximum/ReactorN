local config = require("config.config")

local M = {
  history = {},
  forecastSeconds = nil,
  lastFluid = 0,
  lastConsumption = 0
}

function M.update(fluid, consumption)
  fluid = math.max(0, tonumber(fluid) or 0)
  consumption = math.max(0, tonumber(consumption) or 0)
  M.lastFluid = fluid
  M.lastConsumption = consumption

  table.insert(M.history, {
    fluid = fluid,
    consumption = consumption
  })
  while #M.history > config.coolantHistorySize do
    table.remove(M.history, 1)
  end

  if consumption >= config.coolantForecastMinConsumption then
    M.forecastSeconds = math.floor(fluid / consumption)
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
  if #M.history < 2 then return 0 end
  return M.history[#M.history].fluid - M.history[1].fluid
end

return M
