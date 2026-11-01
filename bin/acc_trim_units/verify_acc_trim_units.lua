-- Check that accelerometer trims are shown as raw tenths-of-a-degree values.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

package.loaded["rfsuite.lib.require"] = function(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(SUITE .. "/" .. name)
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end

local codec = dofile(SUITE .. "/lib/msp_acc_trim.lua")
for _, axis in ipairs({{label = "Roll", key = "roll"}, {label = "Pitch", key = "pitch"}}) do
  local key = axis.key
  local meta = codec.FIELD_META[key]
  assert(meta.min == -300 and meta.max == 300, key .. " trim range changed")
  assert(meta.default == 0, key .. " trim default changed")
  assert(meta.suffix == nil, key .. " trim must not be labelled in degrees")
end

local f = assert(io.open(ROOT .. "/docs/pages/setup/accelerometer.md", "r"))
local docs = f:read("*a")
f:close()
for _, axis in ipairs({{label = "Roll", key = "roll"}, {label = "Pitch", key = "pitch"}}) do
  local row
  for line in docs:gmatch("[^\r\n]+") do
    if line:match("^| " .. axis.label .. " |") then
      row = line
      break
    end
  end
  assert(row, axis.label .. " trim docs row missing")
  assert(row:find("tenths of a degree", 1, true), axis.label .. " trim docs must state tenths of a degree")
  assert(row:find("Range: -300 to 300", 1, true), axis.label .. " trim docs must state the -300 to 300 range")
  assert(row:find("Default: 0", 1, true), axis.label .. " trim docs must state the zero default")
  assert(not row:find("-300 to 300 °", 1, true), axis.label .. " trim docs must not label raw values as degrees")
end

print("accelerometer trim units are documented and displayed correctly")
