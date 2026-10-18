local component = require("component")
local computer = require("computer")
local config = require("config.config")

local M = {
  last = -1e9,
  history = {},
  data = {},
  available = false,
  error = nil
}

local function getController()
  if component.isAvailable("me_controller") then return component.me_controller end
  if component.isAvailable("me_interface") then return component.me_interface end
  return nil
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function itemMatches(item, resource)
  local name = lower(item.name)
  local label = lower(item.label)
  local damage = tonumber(item.damage or item.metadata)

  if resource.name and name ~= lower(resource.name) then return false end
  if resource.damage ~= nil and damage ~= tonumber(resource.damage) then return false end

  local terms = resource.searchTerms or {resource.search or resource.key}
  for _, term in ipairs(terms) do
    local needle = lower(term)
    if needle ~= "" and (name:find(needle, 1, true) or label:find(needle, 1, true)) then
      return true
    end
  end
  return resource.name ~= nil
end

local function readAllItems(controller)
  if not controller or type(controller.getItemsInNetwork) ~= "function" then
    return nil, "ME getItemsInNetwork недоступен"
  end
  local ok, items = pcall(function() return controller.getItemsInNetwork() end)
  if not ok then return nil, "Ошибка ME: " .. tostring(items) end
  if type(items) ~= "table" then return nil, "ME вернул не таблицу предметов" end
  return items, nil
end

local function countResource(items, resource)
  local total = 0
  local matched = 0
  for _, item in pairs(items) do
    if type(item) == "table" and itemMatches(item, resource) then
      total = total + (tonumber(item.size) or 0)
      matched = matched + 1
    end
  end
  return total, matched
end

function M.update(force)
  local now = tonumber(computer.uptime()) or 0
  local interval = math.max(1, tonumber(config.resourceInterval) or 60)
  if not force and now - M.last < interval then return nil end
  M.last = now

  local controller = getController()
  if not controller then
    M.available = false
    M.error = "ME контроллер не найден"
    return {available=false, error=M.error, items=M.data}
  end

  local items, err = readAllItems(controller)
  if not items then
    M.available = false
    M.error = err
    return {available=false, error=M.error, items=M.data}
  end

  local window = math.max(interval, tonumber(config.resourceHistorySeconds) or 3600)
  for _, resource in ipairs(config.trackedResources or {}) do
    local count, matched = countResource(items, resource)
    local history = M.history[resource.key] or {}
    history[#history + 1] = {time=now, count=count}
    while #history > 1 and now - history[1].time > window do table.remove(history, 1) end
    M.history[resource.key] = history

    local elapsed = now - history[1].time
    local rate = elapsed > 0 and (count - history[1].count) / elapsed * 3600 or 0
    M.data[resource.key] = {
      key = resource.key,
      label = resource.label or resource.key,
      count = count,
      rateHour = rate,
      matched = matched
    }
  end

  M.available = true
  M.error = nil
  return {available=true, error=nil, items=M.data}
end

return M
