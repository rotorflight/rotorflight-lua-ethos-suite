-- Check for #2694: the Setup Wizard's throttle range is blocked whenever the FC's throttle reading
-- would stop it arming.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_throttle_range/verify_setup_wizard_throttle_range.lua
--     lua5.4 bin/setup_wizard_throttle_range/verify_setup_wizard_throttle_range.lua --self-test
--
-- The wizard writes rc_min = measured low + 20 us. The FC arms only while the throttle reads below
-- rc_min minus a 5 us deadband, i.e. below low + 15 us in the radio's reading. So a stick at the
-- radio's low end arms only while the FC reads it at most 14 us above the radio. The guard must let
-- every such case through and block every case from 15 us up.
--
-- It pins:
--   1. the range the wizard writes is the measured travel 20 us in from each end;
--   2. for an FC reading 0..14 us above the radio the guard passes, and from 15 us up it blocks;
--   3. the receiver step blocks the range on the throttle channel's own gap, not on the first
--      channel that differs (throttleOff is kept apart from mismatch).
--
-- --self-test raises the guard back to the old 30 us tolerance and requires check 2 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local HELI = ROOT .. "/src/rfsuite/lib/setup_wizard_heli.lua"
local RECEIVER = ROOT .. "/src/rfsuite/app/pages/setup_wizard_receiver.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

-- Loads the heli helper from the given source and returns it.
local function loadHeli(source)
  package.loaded["rfsuite.lib.setup_wizard_heli"] = nil
  local chunk = assert(load(source, "@setup_wizard_heli.lua", "t"))
  return chunk()
end

local function runRange(heli)
  local before = failures
  local low, high = 1100, 1900
  local minUs, maxUs = heli.throttleFromMeasured(1000, 2000)
  check("the written range is the measured travel 20 us in from each end",
    minUs == 1020 and maxUs == 1980, "min=" .. tostring(minUs) .. " max=" .. tostring(maxUs))
  check("a travel under 300 us gives no range", heli.throttleFromMeasured(1000, 1200) == nil)

  -- The stick at the radio's low end reads `low`; the FC reads low + d.
  local rcMin = low + heli.RANGE_MARGIN_US
  local armBelow = rcMin - heli.ARM_DEADBAND_US
  for d = 0, 30 do
    local fc = low + d
    local arms = fc < armBelow
    local passes = heli.throttleOffsetOk(fc, low)
    if d <= 14 then
      check("an FC reading " .. d .. " us above the radio passes the guard", passes,
        "arms=" .. tostring(arms))
    else
      check("an FC reading " .. d .. " us above the radio is blocked", not passes,
        "arms=" .. tostring(arms))
    end
  end
  return failures - before
end

local function runReceiver(source)
  local before = failures
  check("the throttle gap is judged on its own channel",
    source:find("throttleOff = not heli.throttleOffsetOk(fc, now)", 1, true) ~= nil)
  check("the range is blocked by throttleOff, not by the first mismatch",
    source:find("and not throttleOff", 1, true) ~= nil and source:find("mismatch ~= THROTTLE_SLOT", 1, true) == nil)
  return failures - before
end

local heliSource = readFile(HELI)
local receiverSource = readFile(RECEIVER)

if not SELF_TEST then
  local n = runRange(loadHeli(heliSource)) + runReceiver(receiverSource)
  if n == 0 then
    print("OK  throttle range: the guard blocks every FC offset that would stop the FC arming (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- The old tolerance: 30 us, the same for every channel.
local mutated, n = heliSource:gsub("M%.THROTTLE_TOLERANCE_US = M%.RANGE_MARGIN_US %- M%.ARM_DEADBAND_US %- 1",
  "M.THROTTLE_TOLERANCE_US = 30")
if n ~= 1 then
  print("FAIL  self-test: the tolerance line was not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = runRange(loadHeli(mutated))
if caught > 0 then
  print("ok    mutant red: 30 us tolerance lets the FC stop arming (" .. caught .. " failed checks)")
  print("OK  self-test: the old tolerance goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: 30 us tolerance")
os.exit(1)
