-- Behaviour check for #2690: the Setup Wizard's holds on servo and mixer overrides carry a
-- timeout, and are re-sent before it runs out.
--
-- Run it (from the repository root):
--     lua5.4 bin/wizard_override_timeout/verify_wizard_override_timeout.lua
--     lua5.4 bin/wizard_override_timeout/verify_wizard_override_timeout.lua --self-test
--
-- What it pins:
--   1. the mixer and servo write builders send the timeout as a third u16 when given, and
--      exactly the old 3-byte payload when not (the other pages keep their bytes);
--   2. the hold tracker re-sends a hold every REFRESH_S, before TIMEOUT_MS runs out, and drops a
--      released hold from the refresh;
--   3. the Setup Wizard sends its holds with the timeout and re-sends them from wakeup.
--
-- --self-test drops the timeout from the builder and requires check 1 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local LIB = ROOT .. "/src/rfsuite/lib/"
local WIZARD = ROOT .. "/src/rfsuite/app/pages/setup_wizard.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return s
end

-- The real codec, so the bytes are the ones the wire carries.
local mspcodec = assert(loadfile(LIB .. "mspcodec.lua"))()
local stubs = { ["lib/mspcodec.lua"] = mspcodec }
package.loaded["rfsuite.lib.require"] = function(path)
  local s = stubs[path]
  if not s then error("unexpected require: " .. tostring(path)) end
  return s
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local function bytesOf(payload)
  local out = {}
  for i, b in ipairs(payload) do out[i] = string.format("%02X", b) end
  return table.concat(out, " ")
end

-- 1. Builders. `mixer` and `servo` are loaded fresh from the given source each time.
local function runBuilders(mixerSource, servoSource)
  local before = failures
  local mixer = assert(load(mixerSource, "@msp_mixer_override.lua", "t"))()
  package.loaded["rfsuite.lib.msp_mixer_override"] = nil
  local servo = assert(load(servoSource, "@msp_servo_override.lua", "t"))()
  package.loaded["rfsuite.lib.msp_servo_override"] = nil

  -- Mixer: index 1, value 1000 (0x03E8), timeout 3000 (0x0BB8).
  local withT = mixer.buildWriteMessage(1, 1000, nil, nil, 3000).payload
  check("mixer hold with a timeout is 5 bytes (index, value, timeout)",
    #withT == 5 and withT[1] == 1 and withT[2] == 0xE8 and withT[3] == 0x03
      and withT[4] == 0xB8 and withT[5] == 0x0B, "payload " .. bytesOf(withT))
  local noT = mixer.buildWriteMessage(1, 1000).payload
  check("mixer write without a timeout is the old 3 bytes",
    #noT == 3 and noT[1] == 1 and noT[2] == 0xE8 and noT[3] == 0x03, "payload " .. bytesOf(noT))

  -- Servo: index 2, value 1000, timeout 3000.
  local sWith = servo.buildWriteMessage(2, 1000, nil, nil, 3000).payload
  check("servo hold with a timeout is 5 bytes (index, value, timeout)",
    #sWith == 5 and sWith[1] == 2 and sWith[2] == 0xE8 and sWith[3] == 0x03
      and sWith[4] == 0xB8 and sWith[5] == 0x0B, "payload " .. bytesOf(sWith))
  local sNo = servo.buildWriteMessage(2, 1000).payload
  check("servo write without a timeout is the old 3 bytes",
    #sNo == 3 and sNo[1] == 2 and sNo[2] == 0xE8 and sNo[3] == 0x03, "payload " .. bytesOf(sNo))
  return failures - before
end

-- 2. The tracker: refresh timing and release.
local function runTracker()
  local before = failures
  local hold = assert(loadfile(LIB .. "override_hold.lua"))()
  check("override_hold caches itself in package.loaded", package.loaded["rfsuite.lib.override_hold"] == hold)
  check("the timeout outlasts the refresh with room to spare",
    hold.TIMEOUT_MS / 1000 >= 2 * hold.REFRESH_S, "timeout=" .. hold.TIMEOUT_MS)

  local t = hold.new()
  t:hold("mixer", 1, 1000, 10.0)
  check("nothing is due right after the hold is sent", #t:due(10.5) == 0)
  check("a hold is due a refresh after it was sent", #t:due(11.0) == 1)
  check("nothing is due again straight after a refresh", #t:due(11.2) == 0)
  check("a hold is refreshed again on the next interval", #t:due(12.0) == 1)

  t:hold("servo", 2, 500, 12.0)
  check("a servo hold is tracked apart from a mixer hold", #t:list("mixer") == 1 and #t:list("servo") == 1)
  local value = t:release("mixer", 1)
  check("releasing a mixer hold returns its value", value == 1000)
  local refreshed = t:due(13.5)
  check("after the release only the servo hold is refreshed",
    #refreshed == 1 and refreshed[1].kind == "servo", "refreshed=" .. #refreshed)
  check("a released hold is not held any more", not t:isHeld("mixer", 1))
  return failures - before
end

-- 3. The wizard wires its holds to the timeout and to the refresh.
local function runWiring(source)
  local before = failures
  local _, timeoutUses = source:gsub("holdTimeout%(%)", "")
  check("the wizard sends its holds with the timeout", timeoutUses >= 4, "holdTimeout uses=" .. timeoutUses)
  check("the wizard re-sends its holds from wakeup", source:find("holds:due%(now%)") ~= nil)
  check("the wizard uses the hold tracker", source:find("overrideHold.new()", 1, true) ~= nil)
  check("the wizard gates the timeout behind API 12.10",
    source:find("apiMinor >= 10") ~= nil or source:find("apiAtLeast%(10%)") ~= nil)
  return failures - before
end

local mixerSource = readFile(LIB .. "msp_mixer_override.lua")
local servoSource = readFile(LIB .. "msp_servo_override.lua")
local wizardSource = readFile(WIZARD)

if not SELF_TEST then
  local n = runBuilders(mixerSource, servoSource) + runTracker() + runWiring(wizardSource)
  if n == 0 then
    print("OK  wizard overrides: timed holds on the wire, re-sent before the timeout (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- Negative control: the builder drops the timeout.
local mutated, n = mixerSource:gsub("if timeoutMs then mspcodec%.writeU16%(payload, timeoutMs%) end",
  "if false then mspcodec.writeU16(payload, timeoutMs) end")
if n ~= 1 then
  print("FAIL  self-test: the timeout line was not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = runBuilders(mutated, servoSource)
if caught > 0 then
  print("ok    mutant red: builder drops the timeout (" .. caught .. " failed checks)")
  print("OK  self-test: the old builder goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: builder drops the timeout")
os.exit(1)
