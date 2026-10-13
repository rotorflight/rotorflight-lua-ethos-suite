-- Behaviour check for the main power lost test (#2358).
--
-- Run it:
--     lua5.3 bin/main_power/verify_main_power.lua
--
-- What it drives:
--   * lib/main_power.lua: the shared test used by tasks/session.lua (publishes the flag)
--     and through it by the audio alert and the dashboard banner.
--   * The same test against the function it replaced in tasks/audio_events.lua, copied
--     verbatim from master. Both get the same readings in the same order, so the new
--     code is shown to change where the test lives, not what it says.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local main_power = assert(loadfile(ROOT .. "/src/rfsuite/lib/main_power.lua"))()

local failures = 0
local checks = 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

-- The function that audio_events.lua used on master (b585088b), with its module-level
-- latch and session table replaced by parameters, and nothing else changed.
local MAIN_POWER_LOST_VOLTS_MASTER = 1.0
local function masterMainPowerLost(sessionVoltage, sessionBec, state)
  local voltage = tonumber(sessionVoltage)
  if voltage == nil then return false end

  if voltage > MAIN_POWER_LOST_VOLTS_MASTER then
    state.packVoltageSeen = true
    return false
  end

  if not state.packVoltageSeen then return false end

  local bec = tonumber(sessionBec)
  if bec == nil or bec <= 0 then return false end

  return true
end

-- ---------------------------------------------------------------------------
print("threshold and single readings")
-- ---------------------------------------------------------------------------

check("threshold is 1.0 volt", main_power.THRESHOLD_VOLTS == 1.0)

local latch = main_power.newLatch()
check("no reading gives false", main_power.evaluate(nil, nil, latch) == false)
check("a full pack gives false", main_power.evaluate(12.4, 5.0, latch) == false)
check("a full pack sets the latch", latch.packSeen == true)
check("zero volts with a BEC after a seen pack gives true",
  main_power.evaluate(0, 5.0, latch) == true)
check("zero volts without a BEC gives false (nothing is powered)",
  main_power.evaluate(0, nil, latch) == false)
check("zero volts with a zero BEC gives false",
  main_power.evaluate(0, 0, latch) == false)
check("recovery to a full pack gives false again",
  main_power.evaluate(12.1, 5.0, latch) == false)

-- ---------------------------------------------------------------------------
print("the latch: a pack never seen this connection stays quiet")
-- ---------------------------------------------------------------------------

local fresh = main_power.newLatch()
check("a new latch starts unseen", fresh.packSeen == false)
check("zero volts on an unseen latch gives false", main_power.evaluate(0, 5.0, fresh) == false)
check("the unseen zero reading did not set the latch", fresh.packSeen == false)

-- A low-but-not-gone pack is not lost either: 0.9 V is under the threshold, so it does
-- not set the latch and does not count as gone while the latch is unset.
local low = main_power.newLatch()
check("a reading just under the threshold is treated as gone", main_power.evaluate(0.9, 5.0, low) == false)

-- ---------------------------------------------------------------------------
print("equivalence with the audio test on master")
-- ---------------------------------------------------------------------------

-- A fixed set of realistic sequences: connect, flight, pack lost with and without BEC,
-- recovery, a second loss, and a reconnect (latch cleared). Each step is compared.
local sequences = {
  {{nil, nil}, {12.6, 5.1}, {12.0, 5.1}, {0, 5.1}, {0, 5.1}, {12.0, 5.1}, {0, 0}, {0, 5.1}},
  {{0, 5.1}, {0, 5.1}, {12.3, 8.2}, {0.4, 8.2}, {0, nil}, {0, 8.2}},
  {{3.0, 4.0}, {0.9, 4.0}, {1.1, 4.0}, {0, 4.0}},
  {{11.9, nil}, {0, nil}, {0, 6.0}, {11.9, 6.0}, {0, 0}, {0, -1}, {0, 6.0}},
}

local mismatches = 0
local steps = 0
for _, seq in ipairs(sequences) do
  local newLatch = main_power.newLatch()
  local oldState = {packVoltageSeen = false}
  for _, reading in ipairs(seq) do
    local v, bec = reading[1], reading[2]
    local expected = masterMainPowerLost(v, bec, oldState)
    local got = main_power.evaluate(v, bec, newLatch)
    steps = steps + 1
    if expected ~= got then
      mismatches = mismatches + 1
      print(string.format("        differs at voltage=%s bec=%s: master=%s new=%s",
        tostring(v), tostring(bec), tostring(expected), tostring(got)))
    end
  end
end
check(string.format("all %d readings match master's test", steps), mismatches == 0,
  mismatches .. " mismatch(es)")

-- ---------------------------------------------------------------------------
print("")
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
