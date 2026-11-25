-- Check the Setup Wizard's stick center card (Receiver step): it reads the FC's channels, not the
-- radio's, and writes rc_center only when roll, pitch and yaw agree.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_rx_centre/verify_setup_wizard_rx_centre.lua
--     lua5.4 bin/setup_wizard_rx_centre/verify_setup_wizard_rx_centre.lua --self-test
--
-- Radios don't all send 1500 us with the sticks centered: some ELRS setups send 1520. The offset is
-- in what reaches the FC, so the card reads MSP_RX_CHANNELS. The real page, codecs and
-- lib/setup_wizard_heli.lua run here; the screen, the bus and the wizard shell are stubs. The FC
-- answers MSP_RX_CHANNELS with roll, pitch and yaw (CH1-CH3 in the default map) as set below.
--
-- It pins:
--   1. Next on the throttle card opens the center card, and one read there gives the hint when the
--      resting sticks read 1520 against an rc_center of 1500;
--   2. with pitch trimmed to 1540, Detect names Pitch and writes nothing;
--   3. with all three at 1520, Detect writes MSP_SET_RC_CONFIG with rc_center 1520 and the rest of
--      the RC config as read, registered with wiz.change() for Discard, after CENTRE_READS reads;
--   4. Done lists the stick center.
--
-- --self-test makes centreIsOff() always false, and requires check 3 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local SRC = scriptDir() .. "/../../src/rfsuite/"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

-- The page loads "lib/x.lua" relative to the suite's folder, as on the radio.
local realLoadfile = loadfile
loadfile = function(path, ...)
  if type(path) == "string" and not path:match("^/") and not path:match("^%a:") then
    path = SRC .. path
  end
  return realLoadfile(path, ...)
end

local clock = 0
os.clock = function() return clock end
system = {getVersion = function() return {simulation = false} end, getSource = function() return nil end}

-- The bus: every MSP request is kept, reads of MSP_RX_CHANNELS are answered at once.
local sent = {}
local channels = {1500, 1500, 1500, 1000, 1000, 1000, 1000, 1000}
local function u16list(list)
  local out = {}
  for _, v in ipairs(list) do out[#out + 1] = v & 0xFF; out[#out + 1] = (v >> 8) & 0xFF end
  return out
end
package.loaded["rfsuite.lib.bus"] = {
  publish = function(topic, m)
    if topic ~= "msp.request" then return end
    sent[#sent + 1] = m
    if m.command == 114 and m.processReply then m.processReply(nil, u16list(channels)) end
  end,
  subscribe = function() end,
  unsubscribe = function() end,
}

-- The screen: what build() puts on it.
local shown
local Screen = {}
Screen.__index = Screen
function Screen:begin() shown = {checks = {}} end
function Screen:text(title, body, accent) shown.title, shown.body, shown.accent = title, body, accent end
function Screen:checks(list) shown.checks = list end
function Screen:row(back, specs, forward) shown.back, shown.forward = back, forward end
setmetatable(Screen, {__index = function() return function() end end})
package.loaded["rfsuite.app.setup_wizard_ui"] = {
  new = function() return setmetatable({}, Screen) end,
  notLoaded = function(keys) return keys end,
  fit = function(s) return s end,
  gauge = function() end,
}
package.loaded["rfsuite.app.setup_wizard_art"] = {image = function() return {} end}

local function run()
  local failures, checks = 0, 0
  local function check(label, ok, detail)
    checks = checks + 1
    if not ok then
      failures = failures + 1
      print("FAIL  " .. label .. (detail and ("  -- " .. tostring(detail)) or ""))
    end
  end

  for k in pairs(package.loaded) do
    if type(k) == "string" and k:match("^rfsuite%.") and not k:match("bus$") and not k:match("setup_wizard_ui$")
        and not k:match("setup_wizard_art$") then
      package.loaded[k] = nil
    end
  end
  sent = {}
  if SELF_TEST then
    local heli = assert(loadfile("lib/setup_wizard_heli.lua"))()
    heli.centreIsOff = function() return false end
  end

  local page = assert(loadfile("app/pages/setup_wizard_receiver.lua"))()
  local step
  local changes = {}
  local wiz = setmetatable({
    takeResume = function() return "throttle" end,
    -- The fetch answers inside new(), before `step` is set: built just after.
    rebuild = function() if step then step.build() end end,
    canMove = function() return true end,
    apiAtLeast = function() return true end,
    hasPending = function() return #changes > 0 end,
    change = function(key) changes[#changes + 1] = key end,
    fetch = function(specs, done)
      local results = {}
      for key, build in pairs(specs) do
        local m = build(function(data) results[key] = data end)
        local reply = {}
        for i, b in ipairs(m.simulatorResponse) do reply[i] = b end
        m.processReply(nil, reply)
      end
      done(results, false)
    end,
  }, {__index = function() return function() end end})

  step = page.new(wiz)
  step.build()
  local function tick(seconds)
    clock = clock + (seconds or 0.1)
    step.wakeup(clock)
  end
  local function pressCheck(answer)
    for _, c in ipairs(shown.checks) do
      if c.answer == answer then return c.press() end
    end
    error("no check " .. answer)
  end
  local T = function(key) return "@i18n(app.modules.setup_wizard." .. key .. ")@" end

  -- 1. The throttle card's Next opens the center card; the hint once the sticks rest at 1520.
  check("starts on the throttle card", shown.title == T("rcv_throttle_title"), shown.title)
  channels[1], channels[2], channels[3] = 1520, 1520, 1520
  shown.forward.press()
  check("Next opens the center card", shown.title == T("rcv_centre_title"), shown.title)
  for _ = 1, 5 do tick() end
  local reads = 0
  for _, m in ipairs(sent) do if m.command == 114 then reads = reads + 1 end end
  check("one read for the hint", reads == 1, reads)
  check("the hint", shown.accent == T("rcv_centre_hint_fmt"), shown.accent)

  -- 2. Pitch trimmed up: named, nothing written.
  channels[2] = 1540
  local before = #sent
  pressCheck(T("rcv_centre_detect"))
  check("sampling", shown.accent == T("rcv_centre_sampling"), shown.accent)
  for _ = 1, 20 do tick() end
  check("an off trim is named", shown.accent == T("rcv_centre_trim_fmt"), shown.accent)
  local writes = 0
  for i = before + 1, #sent do if sent[i].command == 67 then writes = writes + 1 end end
  check("nothing written for an off trim", writes == 0, writes)

  -- 3. All three at 1520: rc_center 1520 written, the rest as read.
  channels[2] = 1520
  before = #sent
  pressCheck(T("rcv_centre_detect"))
  for _ = 1, 20 do tick() end
  local write, readsNow = nil, 0
  for i = before + 1, #sent do
    if sent[i].command == 67 then write = sent[i] end
    if sent[i].command == 114 then readsNow = readsNow + 1 end
  end
  check("five reads", readsNow == 5, readsNow)
  check("rc_center 1520 written", write and (write.payload[1] | (write.payload[2] << 8)) == 1520,
    write and table.concat(write.payload, ","))
  check("rc_deflection kept", write and (write.payload[3] | (write.payload[4] << 8)) == 510,
    write and table.concat(write.payload, ","))
  check("registered for Discard", changes[#changes] == "rc_config", changes[#changes])
  check("says it is set", shown.accent == T("rcv_centre_set_fmt"), shown.accent)

  -- 4. Done lists the stick center.
  shown.forward.press()
  local listed = false
  for _, c in ipairs(shown.checks) do
    if c.label == T("rcv_centre_title") and c.value == "1520 us" then listed = true end
  end
  check("Done lists the stick center", listed)

  return failures, checks
end

local failures, checks = run()
if SELF_TEST then
  if failures == 0 then
    print("self-test: the broken module passed, so the checks cannot go red")
    os.exit(1)
  end
  print(string.format("OK  self-test: %d check(s) went red with centreIsOff() broken", failures))
  os.exit(0)
end
if failures > 0 then
  print(string.format("%d of %d check(s) failed", failures, checks))
  os.exit(1)
end
print(string.format("OK  stick center: %d checks passed", checks))
os.exit(0)
