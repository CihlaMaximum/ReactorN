local component = require("component")
local computer = require("computer")
local config = require("config.config")

local function setting(name, fallback)
  local value = tonumber(config[name])
  if value == nil then return fallback end
  return value
end

local M = {
  last = -1e9,
  fluid = 0,
  rawFluid = nil,
  lastValidFluid = 0,
  lowReadCounter = 0,
  readingValid = false,
  fluidConfirmedLow = false,
  cpu = {processors = {}, idle = 0, busy = 0, total = 0}
}

local function getController()
  if component.isAvailable("me_controller") then return component.me_controller end
  if component.isAvailable("me_interface") then return component.me_interface end
  return nil
end

local function readCPUs(controller)
  local data = {processors = {}, idle = 0, busy = 0, total = 0}
  if not controller or not controller.getCpus then return data end
  local ok, cpus = pcall(function() return controller.getCpus() end)
  if not ok or type(cpus) ~= "table" then return data end
  data.total = #cpus
  for i, cpu in ipairs(cpus) do
    local busy = cpu.busy == true
    data.processors[i] = {busy = busy}
    if busy then data.busy = data.busy + 1 else data.idle = data.idle + 1 end
  end
  return data
end

local function readFluid(controller)
  if not controller or not controller.getItemsInNetwork then
    return nil, false, "ME controller unavailable"
  end

  local ok, items = pcall(function()
    return controller.getItemsInNetwork({
      name = config.fluidItemName
    })
  end)

  if not ok or type(items) ~= "table" then
    return nil, false, "ME query failed"
  end
if #items == 0 then
  return nil, false, "No fluid items returned"
end
  
  local total = 0
  local found = false

  for _, item in ipairs(items) do
    if item and item.size then

      local name = tostring(item.name or "")

      -- Временно можно раскомментировать
       --print(
       --  "NAME=" .. tostring(item.name)
       --  .. " LABEL=" .. tostring(item.label)
      --   .. " SIZE=" .. tostring(item.size)
     --  )

      if name == config.fluidItemName then
        total = total + (tonumber(item.size) or 0)
        found = true
      end
    end
  end

  -- Если AE временно вернул пустой список,
  -- не считаем это реальным нулем
  if not found then
    return nil, false, "Fluid item not found"
  end

  if total > setting(
      "fluidMaxValidValue",
      1000000000000
     ) then
    return nil, false,
      "ME value above safety maximum"
  end

  return total, true, nil
end

local function processFluid(value, valid)
  M.readingValid = valid
  M.rawFluid = value

  if not valid or value == nil then
    M.fluid = M.lastValidFluid
    return
  end

  if value >= setting("minFluidDrop", 1000000) then
    M.fluid = value
    M.lastValidFluid = value
    M.lowReadCounter = 0
    M.fluidConfirmedLow = false
    return
  end

  M.lowReadCounter = M.lowReadCounter + 1
  if M.lowReadCounter < setting("fluidLowConfirmations", 5) then
    M.fluid = M.lastValidFluid
    M.fluidConfirmedLow = false
  else
    M.fluid = value
    M.fluidConfirmedLow = true
  end
end

function M.update(force)
  local now = computer.uptime()
  if not force and now - M.last < setting("meInterval", 5) then return nil end
  M.last = now
  local controller = getController()
  M.cpu = readCPUs(controller)
  local value, valid, err = readFluid(controller)
  processFluid(value, valid)
  return {
    fluid = M.fluid,
    rawFluid = M.rawFluid,
    lastValidFluid = M.lastValidFluid,
    lowReadCounter = M.lowReadCounter,
    lowReadLimit = setting("fluidLowConfirmations", 5),
    readingValid = M.readingValid,
    fluidConfirmedLow = M.fluidConfirmedLow,
    error = err,
    cpu = M.cpu,
    available = controller ~= nil
  }
end

function M.getFluid() return M.fluid end
function M.getCPU() return M.cpu end
function M.isFluidConfirmedLow() return M.fluidConfirmedLow end
function M.getLowReadCounter() return M.lowReadCounter end
return M
