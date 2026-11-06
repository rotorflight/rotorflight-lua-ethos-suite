-- Behaviour check for #2673: Controls > Adjustments offers AUX 1 to AUX 13, the firmware's
-- channel count, and a channel written above it is clamped to the last one.
--
-- Run it (from the repository root):
--     lua5.4 bin/adjustments_aux_channels/verify_adjustments_aux_channels.lua
--     lua5.4 bin/adjustments_aux_channels/verify_adjustments_aux_channels.lua --self-test
--
-- What it pins:
--   1. the codec writes enaChannel and adjChannel clamped to 0..12 (AUX 1..13);
--   2. channels already in range are written unchanged, including AUX 1 and AUX 13;
--   3. 255, always on, is written as is;
--   4. the page's picker count is 13 (read from the page's source, since the page needs the radio UI).
--
-- --self-test removes the clamp and requires check 1 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local CODEC = ROOT .. "/src/rfsuite/lib/msp_adjustments.lua"
local PAGE = ROOT .. "/src/rfsuite/app/pages/adjustments.lua"

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
  package.loaded["rfsuite.lib.msp_adjustments"] = nil
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/mspcodec.lua" then return mspcodec end
    error("unexpected require: " .. tostring(name))
  end
  local chunk = assert(load(source, "@msp_adjustments.lua", "t"))
  return chunk()
end

-- Payload bytes of a slot write: [1] slot, [2] function, [3] enable channel, [6] adjustment channel.
local function writtenChannels(msp, enaChannel, adjChannel)
  local msg = msp.buildWriteMessage(1, {enaChannel = enaChannel, adjChannel = adjChannel}, nil, nil)
  return msg.payload[3], msg.payload[6]
end

local function runTests(codecSource)
  local msp = loadCodec(codecSource)

  local ena, adj = writtenChannels(msp, 13, 20)
  check("1. AUX 14 and AUX 21 are written clamped to AUX 13 (byte 12)", ena == 12 and adj == 12,
    "ena=" .. tostring(ena) .. " adj=" .. tostring(adj))

  ena, adj = writtenChannels(msp, 0, 12)
  check("2. AUX 1 and AUX 13 are written unchanged", ena == 0 and adj == 12,
    "ena=" .. tostring(ena) .. " adj=" .. tostring(adj))

  ena, adj = writtenChannels(msp, 255, 5)
  check("3. always on (255) is written as is, and AUX 6 unchanged", ena == 255 and adj == 5,
    "ena=" .. tostring(ena) .. " adj=" .. tostring(adj))

  ena, adj = writtenChannels(msp, nil, nil)
  check("nil channels are written as AUX 1", ena == 0 and adj == 0)
end

-- 4. The page's picker count.
local pageSource = readFile(PAGE)
local pageCount = pageSource:match("\nlocal AUX_CHANNEL_COUNT = (%d+)")
check("4. the page's AUX picker count is the firmware's 13", pageCount == "13", "count=" .. tostring(pageCount))

local codecSource = readFile(CODEC)
if SELF_TEST then
  local mutant, count = codecSource:gsub("  return clamp%(v, 0, AUX_CHANNEL_COUNT %- 1%)", "  return v")
  assert(count == 1, "could not apply self-test mutation to channelByte")
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
