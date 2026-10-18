local component = require("component")
local computer = require("computer")
local config = require("config.config")
local utils = require("lib.utils")
local function setting(name, fallback)
  local value = tonumber(config[name])
  if value == nil then return fallback end
  return value
end
local M = {
  last = -1e9,
  lastScan = -1e9,
  lastRodRefresh = -1e9,
  entries = {},
  rodCache = {},
  shutdownByME = {},
  shutdownByCoolant = {}
}
local countFile = config.dataDir .. "/reactorInfo.txt"
local function scan(force)
  local now = computer.uptime()
  if not force and now - M.lastScan < setting("reactorScanInterval", 30) then return M.entries end
  M.lastScan = now
  local out = {}
  for address, kind in component.list() do
    if kind == "htc_reactors_nuclear_reactor" then
      local ok, proxy = pcall(component.proxy, address)
      if ok then out[#out + 1] = {address = address, proxy = proxy} end
    end
  end
  table.sort(out, function(a, b) return a.address < b.address end)
  M.entries = out
  return out
end
local function safe(default, fn)
  if utils.safe then return utils.safe(default, fn) end
  if utils.safeCall then return utils.safeCall(default, fn) end
  local ok, value = pcall(fn)
  if ok and value ~= nil then return value, true end
  return default, false
end
local function realRodTime(r)
  local ok, rods = pcall(function() return r.getAllFuelRodsStatus() end)
  if not ok or type(rods) ~= "table" then return nil end
  local maximum = 0
  for _, rod in ipairs(rods) do maximum = math.max(maximum, tonumber(rod[6]) or 0) end
  return math.floor(maximum)
end
local function syncRods(entries, force)
  local now = computer.uptime()
  if not force and now - M.lastRodRefresh < setting("rodRefreshInterval", 60) then return end
  M.lastRodRefresh = now
  for _, entry in ipairs(entries) do
    local real = realRodTime(entry.proxy)
    if real ~= nil then M.rodCache[entry.address] = real end
  end
end

local function applySafety(entries, data, fluidConfirmedLow)
  for i, entry in ipairs(entries) do
    local r = entry.proxy
    local d = data[i]
    if d and d.liquid then
      local address = entry.address
      local working = d.activated == true
      local stopRatio = setting("reactorCoolantStopRatio", 0.68)
      local restoreRatio = setting("reactorCoolantRestoreRatio", 0.80)
      local lowBuffer = d.coolantCapacity > 0 and d.coolantRatio <= stopRatio

      -- Stop after confirmed low ME coolant level.
      if fluidConfirmedLow and working then
        local ok = pcall(function() r.deactivate() end)
        if ok then
          M.shutdownByME[address] = true
          d.activated, d.online = false, false
          working = false
        end
      end

      -- Stop if the reactor's internal coolant buffer is too low.
      if lowBuffer and working then
        local ok = pcall(function() r.deactivate() end)
        if ok then
          M.shutdownByCoolant[address] = true
          d.activated, d.online = false, false
          working = false
        end
      end

      local meRestored = not fluidConfirmedLow
      local coolantRestored = d.coolantCapacity > 0 and d.coolantRatio >= restoreRatio
      local stoppedBySystem = M.shutdownByME[address] or M.shutdownByCoolant[address]

      -- Auto-restart only reactors previously stopped by ReactorN.
      -- Do not clear stop flags merely because activate() did not throw:
      -- confirm the reactor actually reports hasWork() == true.
      if config.autoRestartReactors ~= false
        and not working
        and stoppedBySystem
        and meRestored
        and coolantRestored then

        pcall(function() r.activate() end)

        local started = select(1, safe(false, function()
          return r.hasWork()
        end))

        if started then
          M.shutdownByME[address] = nil
          M.shutdownByCoolant[address] = nil
          d.activated, d.online = true, true
          working = true
        else
          -- Keep flags so the next update can retry activation.
          d.activated, d.online = false, false
        end
      end
    end
  end
end

function M.update(fluid, force, fluidConfirmedLow)
  local now = computer.uptime()
  if not force and now - M.last < setting("reactorInterval", 1) then return nil end
  local delta = M.last < 0 and 0 or math.max(0, now - M.last)
  M.last = now
  for address, value in pairs(M.rodCache) do
    M.rodCache[address] = math.max(0, value - delta)
  end
  local entries = scan(force)
  syncRods(entries, force)
  local result = {
    reactors = {}, count = #entries, totalEnergy = 0,
    totalCoolant = 0, hottest = 0, fluidCount = fluid or 0,
    fluidConfirmedLow = fluidConfirmedLow == true
  }
  for i, entry in ipairs(entries) do
    local r = entry.proxy
    if M.rodCache[entry.address] == nil then M.rodCache[entry.address] = realRodTime(r) or 0 end
    local energy = select(1, safe(0, function() return r.getEnergyGeneration() end))
    local consume = select(1, safe(0, function() return r.getFluidCoolantConsume() end))
    local temp = select(1, safe(0, function() return r.getTemperature() end))
    local active = select(1, safe(false, function() return r.hasWork() end))
    local level = select(1, safe(0, function() return r.getReactorLevel() end))
    local liquid = select(1, safe(false, function() return r.isActiveCooling() end))
    local stored = liquid and select(1, safe(0, function() return r.getFluidCoolant() end)) or 0
    local capacity = liquid and select(1, safe(0, function() return r.getMaxFluidCoolant() end)) or 0
    local ratio = capacity > 0 and stored / capacity or 1
    local rod = M.rodCache[entry.address] or 0
    local rodColor = rod < setting("rodCriticalSeconds", 21600) and "&c"
      or (rod < setting("rodWarningSeconds", 86400) and "&e" or "&a")
    result.reactors[i] = {
      id = i, address = entry.address, online = active, activated = active,
      level = level, liquid = liquid,
      kind = liquid and "&bЖидкостный" or "&eВоздушный",
      energy = energy, temp = temp, coolant = consume,
      coolantStored = stored, coolantCapacity = capacity, coolantRatio = ratio,
      rodTime = rod, rodColor = rodColor
    }
    result.totalEnergy = result.totalEnergy + energy
    if liquid and active and consume > 0 then
      result.totalCoolant = result.totalCoolant + consume
    end
    result.hottest = math.max(result.hottest, temp)
  end
  applySafety(entries, result.reactors, fluidConfirmedLow == true)
  local storedCount = utils.readNumber(countFile, 0)
  if storedCount == 0 or result.count > storedCount then
    storedCount = math.max(result.count, setting("expectedReactors", 6))
    utils.write(countFile, storedCount)
  end
  result.missing = math.max(0, storedCount - result.count)
  return result
end
return M
