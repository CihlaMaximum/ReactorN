local filesystem = require("filesystem")
local utils = {}

function utils.ensureDirectory(path)
  if not filesystem.exists(path) then filesystem.makeDirectory(path) end
end

function utils.readNumber(path, default)
  local f = io.open(path, "r")
  if not f then return default or 0 end
  local value = tonumber(f:read("*a"))
  f:close()
  return value or default or 0
end

function utils.write(path, value)
  local dir = path:match("^(.*)/[^/]+$")
  if dir then utils.ensureDirectory(dir) end
  local f = io.open(path, "w")
  if not f then return false end
  f:write(tostring(value))
  f:close()
  return true
end

function utils.energy(rf, decimals)
  rf = tonumber(rf) or 0
  decimals = decimals or 2
  local fmt = "%." .. decimals .. "f %s"
  if rf >= 1e12 then return string.format(fmt, rf / 1e12, "TRF/t") end
  if rf >= 1e9 then return string.format(fmt, rf / 1e9, "GRF/t") end
  if rf >= 1e6 then return string.format(fmt, rf / 1e6, "MRF/t") end
  if rf >= 1e3 then return string.format(fmt, rf / 1e3, "kRF/t") end
  return string.format("%.0f RF/t", rf)
end

function utils.secondsToHMS(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
end

function utils.safeCall(default, fn)
  local ok, value = pcall(fn)
  if ok and value ~= nil then return value, true end
  return default, false
end

return utils
