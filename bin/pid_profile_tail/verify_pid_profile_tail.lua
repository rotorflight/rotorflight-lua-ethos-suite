-- Behaviour check for #2550: the optional trailing bytes of MSP_PID_PROFILE
-- (error_decay_gain_cyclic, then the cyclic/yaw master gains) are read and
-- written back by reply length, and the PID Controller page greys the master
-- gains out on firmware that does not report them.
--
-- Run it:
--     lua5.4 bin/pid_profile_tail/verify_pid_profile_tail.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/lib/msp_pid_profile.lua against the three reply
--     shapes firmware sends: 43 bytes (API 12.09), 44 bytes (API 12.10 master,
--     error_decay_gain_cyclic appended) and 46 bytes (rotorflight-firmware#538,
--     master gains appended). The API version alone does not tell 44 from 46,
--     so the codec gates on length. Each case must decode every byte it was
--     given and encode a write of exactly the same length and contents --
--     six pages share this codec, and the fields a page never shows must
--     round-trip unchanged.
--   * The real src/rfsuite/app/pages/pid_controller.lua through the real
--     page_runtime and field_layout, answering its read with each reply: the
--     two master-gain fields must end disabled on 43 and 44 bytes and enabled
--     on 46.
--   * src/rfsuite/tasks/adjfunctions/wavs.lua: adjustment functions 83/84
--     (ADJUSTMENT_CYCLIC_MASTER_GAIN / ADJUSTMENT_YAW_MASTER_GAIN) must be
--     announced, and every word they name must exist as a recorded wav.
--
-- The 44-byte checks go red on the first revision of #2550, which gated
-- error_decay_gain_cyclic behind the 46-byte master-gain check.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local SUITE_PREFIX = SUITE .. "/"

local checks, failures = 0, 0
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

-- ── Ethos environment ──────────────────────────────────────────────────

package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

_G.print = function() end
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  playHaptic = function() end,
}
_G.lcd = {
  loadMask = function(p) return {path = p} end,
  getWindowSize = function() return 800, 480 end,
  getTextSize = function(text) return #tostring(text) * 8, 16 end,
  font = function() end,
  color = function() end,
  RGB = function(r, g, b, a) return r, g, b, a end,
  drawFilledRectangle = function() end,
  drawText = function() end,
  invalidate = function() end,
}

-- Every widget remembers its last enable() state; nil means never called.
local function newWidget(name)
  local w = { name = name }
  setmetatable(w, { __index = function() return function() return w end end })
  w.enable = function(_, v) w.enabled = v end
  return w
end

local lineCounter = 0
_G.form = {
  addLine = function() lineCounter = lineCounter + 1; return lineCounter end,
  getFieldSlots = function(_, hints)
    local slots = {}
    for i = 1, #hints do slots[i] = { x = (i - 1) * 60, y = 0, w = 60, h = 20 } end
    return slots
  end,
  addStaticText = function() return newWidget("text") end,
  addButton = function() return newWidget("button") end,
  addTextButton = function() return newWidget("textbutton") end,
  addNumberField = function() return newWidget("number") end,
  addChoiceField = function() return newWidget("choice") end,
  addBooleanField = function() return newWidget("boolean") end,
  clear = function() end,
  height = function() return 320 end,
  openDialog = function() return newWidget("dialog") end,
  openProgressDialog = function() return newWidget("progressdialog") end,
}

_G.TIME_LEFT, _G.TEXT_LEFT, _G.LEFT, _G.CENTERED, _G.RIGHT, _G.TOP_LEFT = 1, 2, 3, 4, 5, 6
_G.FONT_XS, _G.FONT_S, _G.FONT_M, _G.FONT_L, _G.FONT_XL = 10, 20, 30, 40, 50
_G.EVT_CLOSE, _G.EVT_KEY, _G.EVT_EXIT_BREAK, _G.EVT_KEY_DOWN_BREAK = 1, 2, 3, 4
_G.KEY_ENTER_LONG, _G.KEY_RTN_BREAK, _G.KEY_EXIT_BREAK, _G.KEY_ENTER_BREAK = 5, 6, 7, 8

-- ── module stubs ───────────────────────────────────────────────────────

-- The FC: answers MSP_PID_PROFILE (94) with `reply`, accepts every write.
local reply = nil
package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    if message.command == 94 and reply then
      local buf = {}
      for i = 1, #reply do buf[i] = reply[i] end
      message.processReply(nil, buf)
    elseif message.processReply then
      message.processReply(nil, {})
    end
  end,
}
package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = {
  print = function() end,
  format = function() end,
  msp = function() end,
  enabled = function() return false end,
  mspEnabled = function() return false end,
}
package.loaded["rfsuite.lib.settings_store"] = {
  saveConfirmEnabled = function() return false end,
  reloadConfirmEnabled = function() return false end,
  load = function() return {} end,
  save = function() end,
}
package.loaded["rfsuite.app.close_key"] = { shouldHandleClose = function() return false end }
package.loaded["rfsuite.app.progress_dialog"] = {
  SPEED = { DEFAULT = 1.0, FAST = 2.0, SLOW = 0.75, VSLOW = 0.5 },
  open = function() return { value = function() end, close = function() end } end,
}

-- ── replies ────────────────────────────────────────────────────────────

local function replyOf(length)
  local r = {}
  for i = 1, length do r[i] = (i * 7) % 250 + 1 end   -- every byte distinct from its neighbours
  return r
end

-- ── 1. the codec ───────────────────────────────────────────────────────

local codec = assert(loadfile("lib/msp_pid_profile.lua"))()
local FIELDS = codec.FIELDS

check("the fixed part of the reply is 43 bytes", #FIELDS == 43, "#FIELDS=" .. #FIELDS)

local function roundTrip(length)
  local bytes = replyOf(length)
  local buf = {}
  for i = 1, length do buf[i] = bytes[i] end
  local data = codec.decode(buf)
  local payload = codec.encode(data)
  local same = #payload == length
  local firstDiff
  for i = 1, math.max(#payload, length) do
    if payload[i] ~= bytes[i] then same = false; firstDiff = firstDiff or i end
  end
  return data, payload, bytes, same, firstDiff
end

for _, case in ipairs({
  { length = 43, name = "43 bytes (API 12.09)", decay = false, gains = false },
  { length = 44, name = "44 bytes (API 12.10)", decay = true,  gains = false },
  { length = 46, name = "46 bytes (#538)",      decay = true,  gains = true  },
}) do
  out(case.name)
  local data, payload, bytes, same, firstDiff = roundTrip(case.length)
  if case.decay then
    check("error_decay_gain_cyclic decoded from byte 44",
          data.error_decay_gain_cyclic == bytes[44], tostring(data.error_decay_gain_cyclic))
  else
    check("error_decay_gain_cyclic absent", data.error_decay_gain_cyclic == nil,
          tostring(data.error_decay_gain_cyclic))
  end
  check("has_master_gain is " .. tostring(case.gains), data.has_master_gain == case.gains,
        tostring(data.has_master_gain))
  if case.gains then
    check("cyclic/yaw master gains decoded from bytes 45/46",
          data.cyclic_master_gain == bytes[45] and data.yaw_master_gain == bytes[46],
          tostring(data.cyclic_master_gain) .. "/" .. tostring(data.yaw_master_gain))
  end
  check(string.format("the write is the same %d bytes it read", case.length), same,
        "payload=" .. #payload .. " bytes, first difference at byte " .. tostring(firstDiff))
end

-- ── 2. the page greys the master gains out ─────────────────────────────

local PageRuntime = assert(loadfile("app/page_runtime.lua"))()
local realNew = PageRuntime.new
local lastRuntime
PageRuntime.new = function(config)
  lastRuntime = realNew(config)
  return lastRuntime
end

local function openPage(length)
  reply = replyOf(length)
  lastRuntime = nil
  package.loaded["rfsuite.lib.msp_pid_profile"] = nil
  local page = assert(loadfile("app/pages/pid_controller.lua"))()
  local opts = {}
  opts.onBack = function() end
  opts.setEventHandler = function(fn) opts.event = fn end
  opts.setWakeupHandler = function(fn) opts.wakeup = fn end
  opts.setPaintHandler = function() end
  opts.setCleanupHandler = function(fn) opts.cleanup = fn end
  page.open(opts)
  for _ = 1, 5 do if opts.wakeup then opts.wakeup() end end
  return lastRuntime, opts
end

for _, case in ipairs({
  { length = 43, enabled = false },
  { length = 44, enabled = false },
  { length = 46, enabled = true  },
}) do
  out(string.format("PID Controller page, %d-byte reply", case.length))
  local rt, opts = openPage(case.length)
  local loaded = rt and rt.data ~= nil
  check("the page loaded its data", loaded)
  if loaded then
    for _, key in ipairs({ "cyclic_master_gain", "yaw_master_gain" }) do
      local field = rt.fields[key]
      local state = field and field.enabled
      check(string.format("%s is %s", key, case.enabled and "enabled" or "greyed out"),
            field ~= nil and state == case.enabled, "enabled=" .. tostring(state))
    end
  end
  if opts.cleanup then opts.cleanup() end
end

-- ── 3. the adjustment voice callouts ───────────────────────────────────

out("adjustment callouts")
local wavs = assert(loadfile("tasks/adjfunctions/wavs.lua"))()
for _, case in ipairs({ { id = 83, spec = "cyclic gain" }, { id = 84, spec = "yaw gain" } }) do
  check(string.format("adjustment %d is announced as \"%s\"", case.id, case.spec),
        wavs[case.id] == case.spec, tostring(wavs[case.id]))
  for word in tostring(wavs[case.id]):gmatch("[^%s]+") do
    local path = SUITE .. "/audio/en/default/adjfunctions/" .. word .. ".wav"
    local f = io.open(path, "rb")
    if f then f:close() end
    check(string.format("adjustment %d word \"%s\" has a recorded wav", case.id, word), f ~= nil, path)
  end
end

out(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
