-- Behaviour check for the YGE forward programming page (#2672): the Keep mAh flag (bit 2
-- of the flags byte) and the startup response (acceleration) have rows, so a pilot can see
-- and change what the ESC holds.
--
-- Run it:
--     lua5.4 bin/esc_yge_rows/verify_esc_yge_rows.lua
--     lua5.4 bin/esc_yge_rows/verify_esc_yge_rows.lua --self-test
--
-- The codec already read and wrote both values; the page just had no row for them. The
-- page hands its field list to the shared vendor page, which is stubbed here to record
-- that list. The codec is the real lib/msp_esc_parameters_yge.lua, and the round trip of
-- the two values through it is checked too.
--
-- Against the unpatched page the rows are missing and those checks fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/esc_forward_yge.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

local recorded = nil
local stubs = {
  ["app/pages/esc_forward_vendor.lua"] = {
    open = function(_, spec) recorded = spec end,
  },
  ["lib/esc_current_limit.lua"] = {remember = function() end},
}

local cache = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

local function openPage(source)
  recorded = nil
  local page = source and (assert(load(source, "@" .. PAGE_PATH))()) or dofile(PAGE_PATH)
  page.open({})
  return recorded and recorded.fields or {}
end

local function findRow(fields, key, bit)
  for _, row in ipairs(fields) do
    if row.key == key and (bit == nil or row.bit == bit) then return row end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- 1. The rows exist, bound to the right flag bit and the right field.
-- ---------------------------------------------------------------------------
print("rows")
do
  local fields = openPage()
  local keepMah = findRow(fields, "flags", 2)
  check("a Keep mAh row is bound to bit 2 of the flags byte", keepMah ~= nil,
    "no flags row with bit 2")
  if keepMah then
    check("Keep mAh is an Off/On choice", keepMah.choices ~= nil and #keepMah.choices == 2
      and keepMah.choices[2][2] == 1, "choices=" .. tostring(keepMah.choices and #keepMah.choices))
  end

  local startup = findRow(fields, "acceleration")
  check("a startup response row is bound to acceleration", startup ~= nil, "no acceleration row")
  if startup then
    check("the startup response has two choices: Normal (0) and Smooth (1)",
      startup.choices ~= nil and #startup.choices == 2 and startup.choices[1][2] == 0
        and startup.choices[2][2] == 1,
      "choices=" .. tostring(startup.choices and #startup.choices))
  end

  local direction = findRow(fields, "flags", 0)
  local f3c = findRow(fields, "flags", 1)
  check("the direction and F3C rows are still there", direction ~= nil and f3c ~= nil)
end

-- ---------------------------------------------------------------------------
-- 2. The codec keeps both values through a read and a write.
-- ---------------------------------------------------------------------------
print("codec round trip")
do
  local codec = assert(loadfile(SRC .. "/lib/msp_esc_parameters_yge.lua"))()
  local read = codec.buildReadMessage(function() end)
  local fixture = {}
  for i, b in ipairs(read.simulatorResponse) do fixture[i] = b end
  local decoded = nil
  codec.buildReadMessage(function(d) decoded = d end).processReply(nil, fixture)
  check("the fixture decodes", decoded ~= nil and decoded.flags ~= nil and decoded.acceleration ~= nil)
  if decoded then
    local data = {}
    for k, v in pairs(decoded) do data[k] = v end
    data.flags = 4
    data.acceleration = 1
    local write = codec.buildWriteMessage(data, function() end)
    check("a block with Keep mAh and Smooth encodes", write ~= nil and write.payload ~= nil)
    if write and write.payload then
      local back = nil
      codec.buildReadMessage(function(d) back = d end).processReply(nil, write.payload)
      check("the Keep mAh bit (4) survives the write", back ~= nil and back.flags == 4,
        "flags=" .. tostring(back and back.flags))
      check("the startup response (1, Smooth) survives the write", back ~= nil and back.acceleration == 1,
        "acceleration=" .. tostring(back and back.acceleration))
    end
  end
end

-- ---------------------------------------------------------------------------
-- self-test: without the Keep mAh row the row check must go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the rows check must go red without the rows")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub(
    '  {label = "@i18n%(app%.modules%.esc_tools%.mfg%.yge%.keep_mah%)@", key = "flags", bit = 2, choices = OFF_ON},\r?\n', "", 1)
  check("self-test: the Keep mAh row was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local fields = openPage(mutated)
    check("self-test: without the row there is no Keep mAh row (the check above goes red)",
      findRow(fields, "flags", 2) == nil, "a bit 2 row is still there")
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
