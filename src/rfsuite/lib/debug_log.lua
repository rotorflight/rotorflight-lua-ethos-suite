-- Settings-backed developer debug print gate. Self-cached so callers share one
-- bus subscription and one small settings snapshot.

if package.loaded["rfsuite.lib.debug_log"] then
  return package.loaded["rfsuite.lib.debug_log"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local settings = nil

local function currentSettings()
  if not settings then settings = settingsStore.load() end
  return settings
end

local debug_log = {}

function debug_log.enabled()
  return settingsStore.debugLogsEnabled(currentSettings())
end

function debug_log.mspEnabled()
  return settingsStore.mspLogsEnabled(currentSettings())
end

function debug_log.print(message)
  if debug_log.enabled() then print(message) end
end

function debug_log.format(fmt, ...)
  if debug_log.enabled() then print(string.format(fmt, ...)) end
end

local function bytesToString(bytes)
  if type(bytes) ~= "table" or #bytes == 0 then return "" end
  local parts = {}
  local limit = math.min(#bytes, 64)
  for i = 1, limit do parts[i] = tostring(bytes[i] or 0) end
  local text = table.concat(parts, ",")
  if #bytes > limit then
    text = text .. ",...(" .. tostring(#bytes) .. " bytes)"
  end
  return text
end

function debug_log.msp(direction, command, payload, note)
  if not debug_log.mspEnabled() then return end
  local line = "[msp] " .. tostring(direction) .. " " .. tostring(command) .. " {" .. bytesToString(payload) .. "}"
  if note then line = line .. " " .. tostring(note) end
  print(line)
end

bus.subscribe("settings.update", function(snapshot)
  settings = snapshot or {}
end)

package.loaded["rfsuite.lib.debug_log"] = debug_log
return debug_log
