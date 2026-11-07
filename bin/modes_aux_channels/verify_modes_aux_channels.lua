-- Behaviour check for #2749: Controls > Modes offers AUX 1 to AUX 13, the firmware's
-- channel count, and a mode range written above it is clamped to the last one.
--
-- Run it (from the repository root):
--     lua5.4 bin/modes_aux_channels/verify_modes_aux_channels.lua
--     lua5.4 bin/modes_aux_channels/verify_modes_aux_channels.lua --self-test
--
-- What it pins:
--   1. the codec writes the mode range's AUX index clamped to 0..12 (AUX 1..13);
--   2. indexes already in range are written unchanged, including AUX 1 and AUX 13;
--   3. the mode range has no always-on choice, so 255 is clamped too;
--   4. the page's picker count is 13 (read from the page's source, since the page needs the radio UI).
--
-- --self-test removes the clamp and requires check 1 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local CODEC = ROOT .. "/src/rfsuite/lib/msp_modes.lua"
local PAGE = ROOT .. "/src/rfsuite/app/pages/modes.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local failures, checks = 0, 0
local silent = false
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    if not silent then print("FAIL  " .. label .. (detail and ("  -- " .. detail) or "")) end
  end
end

-- The codec, loaded from the given source (the self-test loads a mutant).
local mspcodec = assert(loadfile(ROOT .. "/src/rfsuite/lib/mspcodec.lua"))()
local function loadCodec(source)
  package.loaded["rfsuite.lib.msp_modes"] = nil
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/mspcodec.lua" then return mspcodec end
    error("unexpected require: " .. tostring(name))
  end
  local chunk = assert(load(source, "@msp_modes.lua", "t"))
  return chunk()
end

-- Payload bytes of a SET_MODE_RANGE write: [1] slot, [2] mode id, [3] AUX index.
local function writtenIndex(msp, auxChannelIndex)
  local msg = msp.buildSetModeRangeMessage(1, {id = 0, auxChannelIndex = auxChannelIndex,
    range = {start = 900, ["end"] = 900}}, nil, nil, nil)
  return msg.payload[3]
end

local function runTests(codecSource)
  local msp = loadCodec(codecSource)

  local aux = writtenIndex(msp, 13)
  check("1. AUX 14 and AUX 21 are written clamped to AUX 13 (index 12)", aux == 12 and writtenIndex(msp, 20) == 12,
    "aux=" .. tostring(aux))

  check("2. AUX 1 and AUX 13 are written unchanged", writtenIndex(msp, 0) == 0 and writtenIndex(msp, 12) == 12,
    "AUX 1=" .. tostring(writtenIndex(msp, 0)) .. " AUX 13=" .. tostring(writtenIndex(msp, 12)))

  check("3. 255 is clamped too: mode ranges have no always-on choice", writtenIndex(msp, 255) == 12,
    "aux=" .. tostring(writtenIndex(msp, 255)))

  check("nil index is written as AUX 1", writtenIndex(msp, nil) == 0)
end

-- 4. The page's picker count.
local pageSource = readFile(PAGE)
local pageCount = pageSource:match("\nlocal AUX_CHANNEL_COUNT = (%d+)")
check("4. the page's AUX picker count is the firmware's 13", pageCount == "13", "count=" .. tostring(pageCount))

local codecSource = readFile(CODEC)
if SELF_TEST then
  local mutant, count = codecSource:gsub("clamp%(range%.auxChannelIndex or 0, 0, AUX_CHANNEL_COUNT %- 1%)", "(range.auxChannelIndex or 0)")
  assert(count == 1, "could not apply self-test mutation to the mode range write")
  silent = true
  local before = failures
  runTests(mutant)
  local caught = failures - before
  silent = false
  if caught == 0 then
    print("SELF-TEST FAILED: the unclamped mutant did not produce any failure")
    os.exit(1)
  end
  print(string.format("self-test ok: unclamped mutant caught %d failure(s)", caught))
  os.exit(0)
end

runTests(codecSource)

if failures > 0 then
  print(string.format("\nFAILED: %d of %d checks failed", failures, checks))
  os.exit(1)
else
  print(string.format("ALL %d CHECKS PASSED", checks))
end
