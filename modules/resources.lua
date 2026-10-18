local component = require("component")
local computer = require("computer")
local config = require("config.config")

local M = {
  last = -1e9,
  history = {},
  data = {}
}

local function getController()
  if component.isAvailable("me_controller") then
    return component.me_controller
  end
  if component.isAvailable("me_interface") then
    return component.me_interface
  end
  return nil
end

-- Exact ME identifiers confirmed by diagnostics:
-- Quartz: minecraft:quartz / Nether Quartz
-- Lapis:  minecraft:dye    / Lapis Lazuli
local exactResources = {
  quartz = {
    name = "minecraft:quartz",
    label = "Nether Quartz"
  },
  lapis = {
    name = "minecraft:dye",
    label = "Lapis Lazuli"
  }
}

local function count(controller, resource)
  local exact = exactResources[resource.key]
  if not exact then
    return 0
  end

  local ok, items = pcall(function()
    return controller.getItemsInNetwork({name = exact.name})
  end)

  -- Some ME implementations may not accept/use the filter reliably.
  -- Fall back to the complete item list and apply exact matching locally.
  if not ok or type(items) ~= "table" then
    ok, items = pcall(function()
      return controller.getItemsInNetwork()
    end)
  end

  if not ok or type(items) ~= "table" then
    return nil
  end

  local total = 0

  for _, item in ipairs(items) do
    local name = tostring(item.name or "")
    local label = tostring(item.label or "")

    if name == exact.name and label == exact.label then
      total = total + (tonumber(item.size) or 0)
    end
  end

  return total
end

function M.update(force)
  local now = computer.uptime()
  local interval = tonumber(config.resourceInterval) or 5

  if not force and now - M.last < interval then
    return nil
  end

  M.last = now

  local controller = getController()
  if not controller then
    return {
      available = false,
      items = M.data
    }
  end

  local window = tonumber(config.resourceHistorySeconds) or 3600

  for _, resource in ipairs(config.trackedResources or {}) do
    local value = count(controller, resource)

    if value ~= nil then
      local history = M.history[resource.key] or {}

      history[#history + 1] = {
        time = now,
        count = value
      }

      while #history > 1 and now - history[1].time > window do
        table.remove(history, 1)
      end

      M.history[resource.key] = history

      local dt = now - history[1].time
      local rate = 0

      if dt > 0 then
        rate = (value - history[1].count) / dt * 3600
      end

      M.data[resource.key] = {
        key = resource.key,
        label = resource.label or resource.key,
        count = value,
        rateHour = rate
      }
    end
  end

  return {
    available = true,
    items = M.data
  }
end

return M
