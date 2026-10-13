-- Behaviour check for the accelerometer calibration wait (issue #2347).
--
-- Run it:
--     lua5.4 bin/acc_calibration_wait/verify_acc_calibration_wait.lua
--     lua5.4 bin/acc_calibration_wait/verify_acc_calibration_wait.lua --self-test
--
-- What it drives: the real lib/acc_calibration_wait.lua with a simulated clock.
-- The page only commits to EEPROM on "done"; this check pins when "done" comes:
--   * never while the calibrating bit is set (bit 12 of arming_disable_flags);
--   * on the first poll after the bit clears, once it has been seen set;
--   * from NOT_SEEN_DONE seconds on, when the bit was never seen set (the stated
--     timing assumption: a calibration shorter than one poll);
--   * "timeout" after TIMEOUT seconds when the bit stays set or polls fail;
--   * polls keep the POLL_INTERVAL and never run before it.
--
-- --self-test replaces the module's onStatus with a naive version that reports
-- "done" the moment the bit is clear, and requires the first check to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SELF_TEST = arg and arg[1] == "--self-test"

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
  return ok
end

local SET = 4096          -- ARMING_DISABLED_CALIBRATING, 1 << 12
local CLEAR = 512         -- an unrelated flag only (0x200)

-- Loads the real module. The package.loaded guard in the module returns the
-- cached table, so each case gets a fresh copy from its own loadfile.
local function loadModule()
  local chunk, err = loadfile(ROOT .. "/src/rfsuite/lib/acc_calibration_wait.lua")
  assert(chunk, err)
  package.loaded["rfsuite.lib.acc_calibration_wait"] = nil
  return chunk()
end

-- Runs a scripted sequence of polls: each entry is {t = seconds, flags = value}
-- (flags nil means the poll failed). Returns the decisions in order.
local function run(m, script, start)
  local state = m.new(start)
  local decisions = {}
  for _, step in ipairs(script) do
    assert(m.shouldPoll(state, step.t), "scripted poll at " .. step.t .. " is not due")
    local d
    if step.flags == nil then
      d = m.onError(state, step.t)
    else
      d = m.onStatus(state, step.flags, step.t)
    end
    decisions[#decisions + 1] = d
    if d ~= "wait" then break end
  end
  return decisions, state
end

-- Replaces onStatus with the naive version for the self-test.
local function naiveOnStatus(m)
  local real = m.onStatus
  m.onStatus = function(state, flags, now)
    if m.isCalibrating(flags) == false then return "done" end
    return real(state, flags, now)
  end
end

local m = loadModule()
if SELF_TEST then
  -- The naive version reports "done" on the first clear poll, before the bit
  -- was ever seen set. The real rule waits there. The self-test passes only if
  -- the naive version is caught, i.e. it reports "done" where the rule says "wait".
  naiveOnStatus(m)
  local decisions = run(m, {{t = 0.0, flags = CLEAR}}, 0.0)
  local caught = decisions[1] == "done"
  print(string.format("\nself-test: naive done-when-clear %s the never-seen-set check",
    caught and "is caught by" or "is NOT caught by"))
  print(string.format("%d checks, %d failed", checks, failures))
  os.exit(caught and 0 or 1)
end

print("Accelerometer calibration wait: lib/acc_calibration_wait.lua")

do
  -- Bit set at 0.5 s and still set at 3 s and 10 s: no decision yet, never done.
  local decisions = run(m, {
    {t = 0.0, flags = CLEAR}, {t = 0.5, flags = SET},
    {t = 1.0, flags = SET}, {t = 3.0, flags = SET}, {t = 10.0, flags = SET},
  }, 0.0)
  local anyDone = false
  for _, d in ipairs(decisions) do if d == "done" then anyDone = true end end
  check("while the bit is set the wait never reports done", not anyDone,
    "decisions: " .. table.concat(decisions, ","))
end

do
  -- Bit seen set, then clear at 2.0 s: done on exactly that poll.
  local decisions = run(m, {
    {t = 0.0, flags = CLEAR}, {t = 0.5, flags = SET},
    {t = 1.0, flags = SET}, {t = 2.0, flags = CLEAR},
  }, 0.0)
  check("done on the first poll after the bit clears, once seen set",
    decisions[#decisions] == "done" and #decisions == 4,
    "decisions: " .. table.concat(decisions, ","))
end

do
  -- Never seen set; before NOT_SEEN_DONE the wait continues.
  local decisions = run(m, {{t = 0.0, flags = CLEAR}, {t = 1.0, flags = CLEAR}, {t = 2.0, flags = CLEAR}}, 0.0)
  check("a bit never seen set keeps waiting before the fallback time",
    #decisions == 3 and decisions[3] == "wait",
    "decisions: " .. table.concat(decisions, ","))
end

do
  -- Never seen set; from NOT_SEEN_DONE on the calibration is taken as finished.
  local decisions = run(m, {{t = 0.0, flags = CLEAR}, {t = m.NOT_SEEN_DONE, flags = CLEAR}}, 0.0)
  check("a bit never seen set reports done from NOT_SEEN_DONE seconds on",
    decisions[#decisions] == "done", "decisions: " .. table.concat(decisions, ","))
end

do
  -- Bit stays set until the timeout: timeout, not done.
  local script = {{t = 0.0, flags = CLEAR}}
  for t = 0.5, m.TIMEOUT + 0.5, 0.5 do script[#script + 1] = {t = t, flags = SET} end
  local decisions = run(m, script, 0.0)
  check("a bit that stays set times out after TIMEOUT seconds",
    decisions[#decisions] == "timeout" and not (function()
      for _, d in ipairs(decisions) do if d == "done" then return true end end
    end)(),
    "last decision: " .. tostring(decisions[#decisions]))
end

do
  -- Polls that fail keep waiting, and time out after TIMEOUT seconds.
  local state = m.new(0.0)
  local last = nil
  local t = 0.0
  while t < m.TIMEOUT + 1 do
    t = t + m.POLL_INTERVAL
    last = m.onError(state, t)
    if last ~= "wait" then break end
  end
  check("failed polls keep waiting and time out after TIMEOUT seconds",
    last == "timeout" and t >= m.TIMEOUT, "last " .. tostring(last) .. " at " .. t)
end

do
  -- A reply without the flags field is treated as a failed poll.
  local state = m.new(0.0)
  local d = m.onStatus(state, nil, 0.5)
  check("a reply without arming flags counts as a failed poll", d == "wait", "got " .. tostring(d))
end

do
  -- The poll schedule: not due before POLL_INTERVAL has passed.
  local state = m.new(0.0)
  m.onStatus(state, SET, 0.2)
  check("the next poll is not due before POLL_INTERVAL has passed",
    m.shouldPoll(state, 0.2 + m.POLL_INTERVAL - 0.01) == false)
  check("the next poll is due once POLL_INTERVAL has passed",
    m.shouldPoll(state, 0.2 + m.POLL_INTERVAL) == true)
end

do
  check("isCalibrating reads bit 12", m.isCalibrating(SET) == true and m.isCalibrating(CLEAR) == false)
  check("isCalibrating returns nil for an unknown value", m.isCalibrating(nil) == nil)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
