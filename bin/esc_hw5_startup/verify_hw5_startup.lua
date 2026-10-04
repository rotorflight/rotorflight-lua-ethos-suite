-- Behaviour check for the Hobbywing Platinum V5 Startup Time conversion.
--
-- Run it:
--     lua5.3 bin/esc_hw5_startup/verify_hw5_startup.lua
--     lua5.3 bin/esc_hw5_startup/verify_hw5_startup.lua --self-test
--
-- This is a SEPARATE pull request from the OPTO layout fix (#2341) on purpose. It
-- moves the same question out of that one, because it is a different question:
--
--   * The OPTO defect is WHICH BYTE a field sits on. It affects OPTO models only,
--     and it is a wrong-value bug that the page cannot show you -- every row sits
--     one place out and looks entirely normal.
--   * This one is HOW A NUMBER IS COUNTED. It affects every HW5 model, OPTO or not,
--     and it is a range bug: the row declares 4..25 seconds and the decoder hands it
--     0..21.
--
-- The defect, in this file's own terms:
--
--   FIELD_META declares startup_time = {min = 4, max = 25, default = 11, suffix = "s"}
--   and decode() handed the page the RAW byte, which runs 0..21.
--
-- So an ESC set to its shortest start-up showed "0s" on a row that begins at 4, and
-- the page's own min/max said the value it was being given could not exist. The
-- contradiction is entirely inside this one file; no outside authority is needed to
-- establish that it exists. What an outside authority IS needed for is which side of
-- it was wrong -- and that is the EdgeTX codec, which is where this suite has always
-- taken the HW5 layouts from. It says so four times over:
--
--   1. its own fixture comment:  11, -- item 6: startup_time (raw 11 -> 15s)
--      (tasks/msp/api/esc_parameters_hw5.lua:203)
--   2. parse():                   out[fieldName] = rawVal + 4                     (:263-265)
--   3. buildWritePayload():       rawVal = math.max(0, math.min(21,
--                                 (tonumber(val) or 4) - 4))                       (:296-298)
--   4. the page widget:           min = 4, max = 25, step = 1, suffix = "s"
--      (app/pages/.../escmfg/hw5/page.lua:617), and its initial ui.config value
--      startup_time = 15 (:38) -- which is the fixture's raw 11 plus four.
--
-- The arithmetic is the cheapest of the five arguments and probably the strongest:
-- 4..25 is 22 values and 0..21 is 22 values. A range that is 22 long on the page and
-- 22 long on the wire is ONE range counted from two ends, not a page that guessed
-- wrong. That also explains the max: 25 - 4 + 1 = 22 = 21 - 0 + 1.
--
-- WHAT THIS FILE CHECKS, and why each one is here:
--
--   * the read direction is 0..21 -> 4..25, byte for byte, all 22 values. Gate.
--   * the write direction is the same 22 values in reverse. Gate, and through the
--     real page -- an identity decode that writes its own value back is lossless by
--     construction, so a codec that got the READ wrong and the write wrong in the
--     same way would pass every byte-level round trip. The two gates are not
--     redundant; they are the only pair that catches a codec which is consistently
--     wrong.
--   * the round trip is byte-exact, for all 22 values. NOT a gate: an identity
--     decode passes it too, so it cannot detect this bug. It is here because it is
--     what makes the offset safe -- if the two directions ever disagreed, this is
--     what would say so.
--   * the row's declared range and the decoded range agree, both ends. Gate, because
--     FIELD_META.min is 4 and the lowest byte the ESC can send is 0, so this fails
--     on the pre-fix codec and cannot fail on the fixed one for any other reason.
--   * the clamp is 0..21 and not 0..255. Gate. This one is here because the first
--     version of the fix clamped to 0..255, which EdgeTX does not: a caller outside
--     the page's range could write a raw byte the row says cannot exist.
--   * a raw byte ABOVE the field's range is written back as the ceiling rather than
--     as itself. Gate, and it is the honest one: that is a behaviour change, and it
--     is what EdgeTX does.
--   * every OTHER field is untouched by the table, and HW1132 / HW1128 gain no
--     Startup Time. NOT gates -- they pass on the pre-fix codec too, so they cannot
--     detect this defect. They catch the tempting WRONG fix: translating every
--     numeric field by four, or clamping every field to 0..21.
--
-- 6 of the 12 checks are gates and go red on the pre-fix codec; --self-test reports
-- exactly which. It splices the pre-fix decode()/encode() back into a copy of the
-- codec and requires all six to fail, and it verifies its own splice four ways
-- first, because a sabotage that breaks the module differently from the defect under
-- test proves nothing about the defect.
--
-- Two of the six were gates in the first version of this file and the self-test caught
-- them passing on the pre-fix code, which is why they are plain checks now: the
-- "every other field is untouched" case and the "HW1132 and HW1128 do not gain one"
-- case. Both were gates guarding the FIX rather than detecting the DEFECT, and
-- --self-test reported STAYS GREEN for both rather than letting them read as
-- verification.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local CODEC_SRC = SUITE .. "/lib/msp_esc_parameters_hw5.lua"

local SELF_TEST = arg[1] == "--self-test"

local MUST_GO_RED = {}

local checks, failures = 0, 0
local failedLabels = {}
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    failedLabels[label] = true
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

local function gateCheck(label, ok, detail)
  MUST_GO_RED[#MUST_GO_RED + 1] = label
  check(label, ok, detail)
end

-- ---------------------------------------------------------------------------
-- Ethos environment
-- ---------------------------------------------------------------------------

package.path = PREFIX .. "?.lua;" .. package.path

local realLoadfile = loadfile

local REPLACE_MATCH, REPLACE_FILE, replaceHits = nil, nil, 0

_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    if REPLACE_MATCH and REPLACE_FILE and path:match(REPLACE_MATCH) then
      replaceHits = replaceHits + 1
      return realLoadfile(REPLACE_FILE, ...)
    end
    return realLoadfile(PREFIX .. path, ...)
  end
  return realLoadfile(path, ...)
end

_G.package = package
_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.print = function() end
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }
_G.lcd = { getWindowSize = function() return 480 end, loadMask = function() return 0 end }

_G.LEFT = 1
_G.CENTERED = 2
_G.RIGHT = 3
_G.TIME_LEFT = 4
_G.TEXT_LEFT = 5
_G.FONT_XS = 6
_G.FONT_S = 7
_G.FONT_M = 8
_G.FONT_L = 9
_G.FONT_XL = 10
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07
_G.KEY_ENTER_BREAK = 0x08

-- ---------------------------------------------------------------------------
-- What the form, the bus and the chrome are allowed to do
-- ---------------------------------------------------------------------------

local obs = {}

local function resetObs()
  obs.lines = {}
  obs.fields = {}
  obs.fieldOrder = {}
  obs.expansionPanels = 0
  obs.reads = 0
  obs.writes = {}
  obs.staticTexts = {}
  obs.runtime = nil
end

local reply = nil
local replyFails = false

local function widgetStub(name, field)
  local w
  w = {
    name = name,
    enabled = nil,
    focus = function() end,
    enable = function(_, on) w.enabled = on end,
    value = function(_, v) return v end,
    setValue = function() end,
    setText = function() end,
    getValue = function() return 0 end,
    decimals = function() end,
    suffix = function() end,
    step = function() end,
    default = function() end,
    show = function() end,
    hide = function() end,
    close = function() end,
  }
  if field then field.widget = w end
  return w
end

local function dialogStub()
  local d
  d = { value = function() end, message = function() end, closeAllowed = function() end, close = function() end }
  return d
end

local function fieldFor(line)
  local label = obs.lines[line] or ("field#" .. tostring(line))
  local field = obs.fields[label]
  if not field then
    field = { label = label }
    obs.fields[label] = field
    obs.fieldOrder[#obs.fieldOrder + 1] = field
  end
  return field
end

_G.form = {
  addButton = function() return widgetStub("button") end,
  addTextButton = function() return widgetStub("textbutton") end,
  addStaticText = function(_, _, text) obs.staticTexts[#obs.staticTexts + 1] = text end,
  addNumberField = function(line, _, min, max, get, setWithDirty)
    local field = fieldFor(line)
    field.kind, field.min, field.max = "number", min, max
    field.get, field.set = get, setWithDirty
    return widgetStub("numberField", field)
  end,
  addChoiceField = function(line, _, choices, get, setWithDirty)
    local field = fieldFor(line)
    field.kind, field.choices = "choice", choices
    field.get, field.set = get, setWithDirty
    return widgetStub("choiceField", field)
  end,
  addExpansionPanel = function()
    obs.expansionPanels = obs.expansionPanels + 1
    return { open = function() end }
  end,
  addLine = function(label)
    obs.lines[#obs.lines + 1] = label
    return #obs.lines
  end,
  clear = function() end,
  height = function() return 320 end,
  width = function() return 480 end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local slots = {}
    for i = 1, n do slots[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 } end
    return slots
  end,
  openDialog = function() return dialogStub() end,
  openProgressDialog = function() return dialogStub() end,
}

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    if message.isWrite then
      obs.writes[#obs.writes + 1] = message
      if type(message.processReply) == "function" then message.processReply() end
      return
    end
    obs.reads = obs.reads + 1
    if type(message.processReply) ~= "function" then return end
    if replyFails then
      if message.errorHandler then message.errorHandler("simulated read failure") end
      return
    end
    message.processReply(nil, reply)
  end,
}

package.loaded["rfsuite.app.progress_dialog"] = {
  open = function() return dialogStub() end,
  SPEED = { DEFAULT = 1, SLOW = 2, VSLOW = 3 },
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
  reloadConfirmEnabled = function() return true end,
  developerModeEnabled = function() return false end,
  load = function() return { general = {}, developer = {} } end,
  save = function() end,
  DEFAULTS = { general = {}, developer = {} },
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function() return { command = 250, isWrite = true } end,
}
package.loaded["rfsuite.lib.msp_reboot"] = { reboot = function() end }

local requireModule = assert(realLoadfile(PREFIX .. "lib/require.lua"))()

-- ---------------------------------------------------------------------------
-- The runtime, reached through the real field_layout
-- ---------------------------------------------------------------------------
--
-- app/field_layout.lua is the REAL module, because a pilot edit is the call Ethos
-- makes on the setter it built and stubbing it would make the write-direction case
-- here vacuous. But it keeps no reference to the runtime it builds fields for, so
-- buildSingle() is WRAPPED rather than replaced: it records the runtime and then
-- calls through.
local fieldLayout = requireModule("app/field_layout.lua")
do
  local buildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, label, spec, parent)
    if not obs.runtime then obs.runtime = runtime end
    return buildSingle(runtime, label, spec, parent)
  end
end

-- ---------------------------------------------------------------------------
-- The codec, and the block it reads
-- ---------------------------------------------------------------------------

local CODEC_KEY = "rfsuite.lib.msp_esc_parameters_hw5"

local function loadCodec(file)
  package.loaded[CODEC_KEY] = nil
  return assert(realLoadfile(file or CODEC_SRC))()
end

-- The page is reloaded per runChecks(), and it has to be: esc_forward_hw5.lua binds
-- the codec into a module-level `local msp` at its line 5, so reloading only the
-- codec would leave the page still holding the first one.
local function loadPage()
  return assert(realLoadfile(PREFIX .. "app/pages/esc_forward_hw5.lua"))()
end

local codec

-- The block: two header bytes, then four descriptive strings of 16, 16, 16 and 15
-- bytes, then the sixteen parameter bytes at 66..81. Item N is byte 65 + N.
local HEADER_BYTES = 65
local PARAM_BYTES = 16
local BLOCK_BYTES = HEADER_BYTES + PARAM_BYTES

local STRING_FIELDS = {
  firmware = {at = 3, len = 16},
  hardware = {at = 19, len = 16},
  model_a = {at = 35, len = 16},   -- decoded as esc_type
  model_b = {at = 51, len = 15},   -- decoded as mode_name
}

local function itemByte(n)
  return HEADER_BYTES + n
end

-- Transcribed from the EdgeTX codec's layouts, which is the reference for them:
-- esc_parameters_hw5.lua:29-46 (DEFAULT), :72-88 (OPTO), and the HW1132 / HW1128
-- tables beside them. startup_time is item 6 in DEFAULT and item 5 in OPTO, and is
-- ABSENT from both HW1132 and HW1128 -- which is why there are two layouts named
-- here and four fields that must NOT move.
local LAYOUTS = {
  default = {
    flight_mode = 1, lipo_cell_count = 2, volt_cutoff_type = 3, cutoff_voltage = 4,
    bec_voltage = 5, startup_time = 6, gov_p_gain = 7, gov_i_gain = 8, auto_restart = 9,
    restart_time = 10, brake_type = 11, brake_force = 12, timing = 13, rotation = 14,
    active_freewheel = 15, startup_power = 16,
  },
  opto = {
    flight_mode = 1, lipo_cell_count = 2, volt_cutoff_type = 3, cutoff_voltage = 4,
    startup_time = 5, gov_p_gain = 6, gov_i_gain = 7, auto_restart = 8, restart_time = 9,
    brake_type = 10, brake_force = 11, timing = 12, rotation = 13, active_freewheel = 14,
    startup_power = 15,
  },
  hw1132 = {
    lipo_cell_count = 1, volt_cutoff_type = 2, cutoff_voltage = 3, bec_voltage = 4,
    response_time = 5, timing = 6, rotation = 7, active_freewheel = 8, startup_power = 9,
  },
  hw1128 = {
    lipo_cell_count = 1, volt_cutoff_type = 2, cutoff_voltage = 3,
    brake_type = 5, brake_force = 6, timing = 7, rotation = 8,
    active_freewheel = 9, startup_power = 10,
  },
}

-- The ranges, from FIELD_META, and the raw range they are counted from. These are
-- the two things the whole pull request is about, so they are written out here rather
-- than read from the codec -- a check that reads the codec's own table proves that
-- the codec agrees with itself.
local SHOWN_MIN, SHOWN_MAX = 4, 25
local RAW_MIN, RAW_MAX = 0, 21
local OFFSET = SHOWN_MIN - RAW_MIN

-- The fields that must come through untouched, with a value each that would change
-- if the table were applied too widely.
local UNAFFECTED = {
  timing = 24, gov_p_gain = 6, gov_i_gain = 5, auto_restart = 25, restart_time = 1,
  brake_force = 0, rotation = 0, active_freewheel = 0, startup_power = 2,
  flight_mode = 0, lipo_cell_count = 0, volt_cutoff_type = 0, cutoff_voltage = 3,
  bec_voltage = 0, brake_type = 0,
}

-- Counted, not `#UNAFFECTED`: that is the sequence-length operator and this is a
-- hash map, so it answers 0 for a table with fifteen entries in it. The first
-- version of this file printed "all 0 other numeric fields are read as the byte
-- says" directly above a check that had just walked fifteen of them -- a label that
-- contradicted the line under it, which is worse than no label.
local UNAFFECTED_NAMES = {}
for name in pairs(UNAFFECTED) do UNAFFECTED_NAMES[#UNAFFECTED_NAMES + 1] = name end
table.sort(UNAFFECTED_NAMES)
local UNAFFECTED_COUNT = #UNAFFECTED_NAMES

local FIXTURE = {}
local function fixture()
  if #FIXTURE == 0 then
    local message = codec.buildReadMessage(function() end, function() end)
    for i, v in ipairs(message.simulatorResponse) do FIXTURE[i] = v end
  end
  return FIXTURE
end

local function resetFixtureCache()
  FIXTURE = {}
end

local function blockWith(strings)
  local buf = {}
  for i = 1, #fixture() do buf[i] = fixture()[i] end
  for name, spec in pairs(strings or {}) do
    local field = STRING_FIELDS[name]
    for i = 0, field.len - 1 do buf[field.at + i] = 0 end
    for i = 1, math.min(#spec, field.len) do buf[field.at + i - 1] = spec:byte(i) end
  end
  return buf
end

local function decodeWith(buf)
  local data
  codec.buildReadMessage(function(d) data = d end, function() end).processReply(nil, buf)
  return data
end

local function encodeWith(data)
  local message = codec.buildWriteMessage(data, function() end, function() end)
  return message and message.payload or nil
end

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

local ROW_STARTUP = "mfg.hw5.startup_time"
local ROW_TIMING = "mfg.hw5.timing"

local function freshOpts()
  local opts = {}
  local installed = {}
  local function setter(name)
    return function(handler) installed[name] = handler end
  end
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() end
  opts.__installed = installed
  return opts
end

local function openPage(strings)
  resetObs()
  reply = blockWith(strings)
  replyFails = false

  local opts = freshOpts()
  page.open(opts)
  opts.__installed.setWakeupHandler()

  opts.__runtime = obs.runtime
  return obs.runtime, opts
end

local function rowField(key)
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].label:find(key, 1, true) then return obs.fieldOrder[i] end
  end
  return nil
end

local function edit(field, value)
  field.set(value)
end

local function editUnrelatedField()
  local field = rowField(ROW_TIMING)
  if not field then return false end
  local current = field.get()
  local next = current == field.max and field.min or current + 1
  if next == current then return false end
  edit(field, next)
  return true
end

local function pressSave(opts)
  local runtime = opts.__runtime
  if not runtime or not runtime.headerHandle then return nil end
  local writesBefore = #obs.writes
  runtime:confirmSave(runtime.headerHandle.focusSave)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  for i = writesBefore + 1, #obs.writes do
    if obs.writes[i].command == codec.WRITE_COMMAND then return obs.writes[i].payload end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------

local function checkReadDirection()
  out("")
  out(string.format("read: a raw byte of %d..%d is shown as %d..%d seconds", RAW_MIN, RAW_MAX, SHOWN_MIN, SHOWN_MAX))

  -- All 22 values, not a sample. The mapping is affine, so three points would
  -- prove the same thing mathematically -- but a check that samples is a check that
  -- can be satisfied by a mapping that is right at the sample points and wrong
  -- between them, and this file has 22 values to spend.
  local wrong = {}
  for raw = RAW_MIN, RAW_MAX do
    for _, layout in ipairs({ {name = "default", layout = LAYOUTS.default},
                              {name = "OPTO", layout = LAYOUTS.opto} }) do
      local buf = blockWith(layout.name == "OPTO" and {model_a = "Platinum OPTO"} or {})
      buf[itemByte(layout.layout.startup_time)] = raw
      local data = decodeWith(buf)
      local want = raw + OFFSET
      if data.startup_time ~= want then
        wrong[#wrong + 1] = string.format("%s raw %d shows %s, expected %d",
          layout.name, raw, tostring(data.startup_time), want)
      end
    end
  end
  gateCheck(string.format("every raw byte %d..%d reads as %d..%d, on both layouts that have the field",
    RAW_MIN, RAW_MAX, SHOWN_MIN, SHOWN_MAX),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)
end

local function checkWriteDirection()
  out("")
  out(string.format("write: a shown %d..%d goes back out as %d..%d", SHOWN_MIN, SHOWN_MAX, RAW_MIN, RAW_MAX))

  local wrong = {}
  for shown = SHOWN_MIN, SHOWN_MAX do
    local buf = blockWith({})
    local data = decodeWith(buf)
    data.startup_time = shown
    local payload = encodeWith(data)
    local at = itemByte(LAYOUTS.default.startup_time)
    if not payload then
      wrong[#wrong + 1] = "no payload for a shown " .. shown
    elseif payload[at] ~= shown - OFFSET then
      wrong[#wrong + 1] = string.format("shown %d wrote %s, expected %d",
        shown, tostring(payload[at]), shown - OFFSET)
    end
  end
  gateCheck(string.format("every shown value %d..%d is written back as %d..%d",
    SHOWN_MIN, SHOWN_MAX, RAW_MIN, RAW_MAX),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)

  -- Through the real page, because a codec-level check cannot see whether the row
  -- the pilot moves is the row the codec converts.
  --
  -- This is the gate that makes the read gate worth having. A codec that added four
  -- on the way in AND subtracted four on the way out is perfectly consistent, and
  -- it would pass every round trip in this file -- it just shows the wrong number.
  local runtime, opts = openPage({})
  local field = runtime and rowField(ROW_STARTUP)
  local label = string.format("moving the row on the page writes the byte %d below what the pilot chose", OFFSET)
  if not field then
    gateCheck(label, false, "the Startup Time row was never built")
  else
    local shown = field.get()
    edit(field, shown + 2)
    local payload = pressSave(opts)
    local want = (shown + 2) - OFFSET
    local got = payload and payload[itemByte(LAYOUTS.default.startup_time)]
    gateCheck(label, got == want,
      payload and string.format("byte is %s, expected %d for a shown %d",
        tostring(got), want, shown + 2) or "no write went out")
  end
end

local function checkDeclaredRangeAgrees()
  out("")
  out("the declared range and the decoded range must be the same range")

  local meta = codec.FIELD_META.startup_time
  local label = string.format("FIELD_META declares %d..%d and the lowest byte reads as %d",
    SHOWN_MIN, SHOWN_MAX, SHOWN_MIN)
  if type(meta) ~= "table" then
    gateCheck(label, false, "FIELD_META has no startup_time entry")
    return
  end
  local problems = {}
  if meta.min ~= SHOWN_MIN then
    problems[#problems + 1] = string.format("FIELD_META.min is %s, expected %d", tostring(meta.min), SHOWN_MIN)
  end
  if meta.max ~= SHOWN_MAX then
    problems[#problems + 1] = string.format("FIELD_META.max is %s, expected %d", tostring(meta.max), SHOWN_MAX)
  end
  local buf = blockWith({})
  buf[itemByte(LAYOUTS.default.startup_time)] = RAW_MIN
  local lowest = decodeWith(buf).startup_time
  if lowest ~= SHOWN_MIN then
    problems[#problems + 1] = string.format("raw %d reads as %s, not the declared minimum %d",
      RAW_MIN, tostring(lowest), SHOWN_MIN)
  end
  buf[itemByte(LAYOUTS.default.startup_time)] = RAW_MAX
  local highest = decodeWith(buf).startup_time
  if highest ~= SHOWN_MAX then
    problems[#problems + 1] = string.format("raw %d reads as %s, not the declared maximum %d",
      RAW_MAX, tostring(highest), SHOWN_MAX)
  end
  gateCheck(label, #problems == 0, #problems > 0 and table.concat(problems, "; ") or nil)

  -- And the widget the page actually built carries the same numbers, so the range
  -- a pilot can reach is the range the decoder produces.
  local runtime = openPage({})
  local field = runtime and rowField(ROW_STARTUP)
  check("the Startup Time widget on the page is built with the same range",
    field ~= nil and field.min == SHOWN_MIN and field.max == SHOWN_MAX,
    field and string.format("widget range is %s..%s, FIELD_META says %d..%d",
      tostring(field.min), tostring(field.max), SHOWN_MIN, SHOWN_MAX)
      or "the row was never built")
end

-- The clamp. EdgeTX clamps the raw value to 0..21 (esc_parameters_hw5.lua:296-298);
-- the first version of this fix clamped to 0..255, which is the range of a byte and
-- not the range of this field. The page's own min/max make it unreachable through the
-- UI, so nothing else in this file would notice it.
local function checkClampIsTheFieldsRangeNotTheBytesRange()
  out("")
  out("the clamp is the field's range, not the byte's")

  local wrong = {}
  local buf = blockWith({})
  local at = itemByte(LAYOUTS.default.startup_time)

  -- Below the row's minimum. With `% 256` this becomes a byte near 255 -- a 252,
  -- which is a start-up time no pilot asked for.
  local low = decodeWith(buf)
  low.startup_time = SHOWN_MIN - 1          -- 3, one below the row
  local lowPayload = encodeWith(low)
  if not lowPayload then
    wrong[#wrong + 1] = "no payload for a value below the row's minimum"
  elseif lowPayload[at] ~= RAW_MIN then
    wrong[#wrong + 1] = string.format("a shown %d wrote %s, expected the floor %d",
      SHOWN_MIN - 1, tostring(lowPayload[at]), RAW_MIN)
  end

  -- Above the row's maximum. With a 0..255 clamp this goes out as 30, a raw byte the
  -- row says cannot exist; EdgeTX's clamp makes it 21.
  local high = decodeWith(buf)
  high.startup_time = SHOWN_MAX + 5          -- 30, five above the row
  local highPayload = encodeWith(high)
  if not highPayload then
    wrong[#wrong + 1] = "no payload for a value above the row's maximum"
  elseif highPayload[at] ~= RAW_MAX then
    wrong[#wrong + 1] = string.format("a shown %d wrote %s, expected the ceiling %d",
      SHOWN_MAX + 5, tostring(highPayload[at]), RAW_MAX)
  end

  gateCheck(string.format("a value outside the row's range is clamped into %d..%d, not %d..255",
    RAW_MIN, RAW_MAX, RAW_MIN),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)
end

-- The tempting wrong fix: translate every numeric field, or clamp every field.
local function checkOtherFieldsUntouched()
  out("")
  out("every other field is passed through unchanged")

  local wrong = {}
  for name, value in pairs(UNAFFECTED) do
    for _, case in ipairs({
      {name = "default", layout = LAYOUTS.default, strings = {}},
      {name = "OPTO", layout = LAYOUTS.opto, strings = {model_a = "Platinum OPTO"}},
    }) do
      local at = case.layout[name]
      if at then
        local buf = blockWith(case.strings)
        buf[itemByte(at)] = value
        local data = decodeWith(buf)
        if data[name] ~= value then
          wrong[#wrong + 1] = string.format("%s on %s reads %s, expected %d",
            name, case.name, tostring(data[name]), value)
        end
      end
    end
  end
  -- NOT gates, and the self-test is what said so rather than the test passing quietly.
  -- Both below pass on the pre-fix codec, because pre-fix every other field WAS
  -- already passed through unchanged and HW1128/HW1132 already had no Startup Time
  -- byte. They cannot detect this bug. What they catch is the tempting WRONG fix --
  -- translating every numeric field by four, or clamping every field to 0..21 -- so
  -- they are kept as checks with the reason here, not as gates. Six gates detect the
  -- defect; these two guard the fix.
  check(string.format("all %d other numeric fields are read as the byte says, on both layouts",
    UNAFFECTED_COUNT),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)

  -- ...and the two layouts that do not HAVE the field must not grow one.
  local absent = {}
  for _, case in ipairs({
    {name = "HW1132", layout = LAYOUTS.hw1132, strings = {hardware = "HW1132_V100456NB"}},
    {name = "HW1128", layout = LAYOUTS.hw1128, strings = {hardware = "HW1128_V100456NB"}},
  }) do
    local data = decodeWith(blockWith(case.strings))
    if case.layout.startup_time ~= nil then
      absent[#absent + 1] = case.name .. " is transcribed as HAVING the field, which is wrong"
    elseif data.startup_time ~= nil then
      absent[#absent + 1] = case.name .. " offers a Startup Time it has no byte for"
    end
  end
  check("HW1132 and HW1128 have no Startup Time byte and do not gain one",
    #absent == 0, #absent > 0 and table.concat(absent, "; ") or nil)
end

-- Byte-exact, for all 22 values. NOT a gate -- an identity decode passes it too, and
-- it did before the fix. It is here because it is what makes the offset safe: if the
-- two directions ever drifted apart, this is what would say so.
local function checkRoundTrip()
  out("")
  out("round trip: every value survives a save byte for byte (not a gate -- it passed before too)")
  local at = itemByte(LAYOUTS.default.startup_time)
  local wrong = {}
  for raw = RAW_MIN, RAW_MAX do
    local buf = blockWith({})
    buf[at] = raw
    local payload = encodeWith(decodeWith(buf))
    if not payload then
      wrong[#wrong + 1] = string.format("raw %d: no payload", raw)
    elseif payload[at] ~= raw then
      wrong[#wrong + 1] = string.format("raw %d came back as %d, nothing was edited", raw, payload[at])
    end
  end
  check(string.format("all %d raw values come back as the same byte", RAW_MAX - RAW_MIN + 1),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)
end

-- Whole block, exhaustively, so the table cannot cost a byte anywhere else.
--
-- The Startup Time byte is EXCLUDED, and the exclusion is the interesting part. It is
-- not excluded to make the check pass: it is excluded because a field with a range
-- cannot round-trip every byte, and saying so is more useful than pretending
-- otherwise. Raw values above 21 are outside what the field can hold, and both this
-- codec and EdgeTX's clamp them to 21 on the way out
-- (esc_parameters_hw5.lua:296-298). That behaviour is pinned as a gate of its own
-- below, so "we clamp it exactly as EdgeTX does" stays a claim the repository carries
-- rather than a hole in a sweep.
--
-- This check is what found it: the first version swept all 81 positions and reported
-- 234 of 20736 values changed, first at byte 71 -- which is item 6, startup_time.
local STARTUP_BYTE_DEFAULT = itemByte(LAYOUTS.default.startup_time)

local function checkWholeBlockRoundTrip()
  out("")
  out("whole block: every byte except the Startup Time one survives a save (not a gate)")
  local base = fixture()
  local lost, firstLost, checked = 0, nil, 0
  for offset = 1, #base do
    if offset ~= STARTUP_BYTE_DEFAULT then
      checked = checked + 1
    for value = 0, 255 do
      local buf = blockWith({})
      buf[offset] = value
      local payload = encodeWith(decodeWith(buf))
      if type(payload) ~= "table" or #payload ~= BLOCK_BYTES then
        lost = lost + 1
        if not firstLost then
          firstLost = string.format("byte %d: %s for a %d byte block", offset,
            payload and #payload or "no payload", BLOCK_BYTES)
        end
      elseif payload[offset] ~= value then
        lost = lost + 1
        if not firstLost then
          firstLost = string.format("byte %d: value %d came back as %d, nothing was edited",
            offset, value, payload[offset])
        end
      end
    end
    end
  end
  check(string.format("all %d other byte positions survive all 256 of their values unchanged", checked),
    lost == 0,
    lost > 0 and string.format("%d of %d values came back changed; first: %s",
      lost, checked * 256, firstLost) or nil)
end

-- The clamp, seen from the other end: a byte the field cannot hold comes back as the
-- field's ceiling rather than as itself.
--
-- A gate, because pre-fix it came back as itself and this IS a behaviour change: if
-- an ESC ever sends a Startup Time byte above 21, a save now rewrites it to 21 where
-- it used to be passed through. That is EdgeTX's behaviour and it is the right
-- default, but it is a trade-off and the pull request body says so rather than only
-- claiming parity.
local function checkOutOfRangeByteIsClampedNotPassedThrough()
  out("")
  out("a byte outside the field's range is clamped to the ceiling, like EdgeTX does")
  local wrong = {}
  for _, raw in ipairs({ RAW_MAX + 1, 30, 100, 255 }) do
    local buf = blockWith({})
    buf[STARTUP_BYTE_DEFAULT] = raw
    local payload = encodeWith(decodeWith(buf))
    if not payload then
      wrong[#wrong + 1] = string.format("raw %d: no payload", raw)
    elseif payload[STARTUP_BYTE_DEFAULT] ~= RAW_MAX then
      wrong[#wrong + 1] = string.format("raw %d came back as %s, expected the ceiling %d",
        raw, tostring(payload[STARTUP_BYTE_DEFAULT]), RAW_MAX)
    end
  end
  gateCheck(string.format("a raw Startup Time byte above %d is written back as %d, not as itself",
    RAW_MAX, RAW_MAX),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)
end

local function checkSaveStillReachesTheEsc()
  out("")
  out("the write path is still live (not a gate)")
  local runtime, opts = openPage({hardware = "HW1106_V100456NB"})
  if not runtime or not editUnrelatedField() then
    check("Save reaches the ESC after moving an unrelated row", false,
      "the page did not load, or the Timing row was never built")
  else
    local payload = pressSave(opts)
    check("Save reaches the ESC after moving an unrelated row",
      payload ~= nil and #payload == BLOCK_BYTES,
      payload and string.format("payload is %d bytes, expected %d", #payload, BLOCK_BYTES)
        or "no write went out")
  end
end

local function runChecks()
  page = loadPage()
  checkReadDirection()
  checkWriteDirection()
  checkDeclaredRangeAgrees()
  checkClampIsTheFieldsRangeNotTheBytesRange()
  checkOtherFieldsUntouched()
  checkRoundTrip()
  checkWholeBlockRoundTrip()
  checkOutOfRangeByteIsClampedNotPassedThrough()
  checkSaveStillReachesTheEsc()
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("Hobbywing V5: the Startup Time byte is counted from the other end")
out(string.rep("=", 72))

codec = loadCodec()
runChecks()

local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the same cases against the pre-fix codec
-- ---------------------------------------------------------------------------

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end

local function writeTmp(text)
  local tmp = os.tmpname()
  local fh = assert(io.open(tmp, "wb"))
  fh:write(text)
  fh:close()
  return tmp
end

local function presplice(source, regionOpen, regionClose, replacement, what)
  local from = assert(source:find(regionOpen, 1, true), "sabotage: " .. what .. " start not found")
  local to = assert(source:find(regionClose, from, true), "sabotage: " .. what .. " end not found")
  return source:sub(1, from - 1) .. replacement .. source:sub(to)
end

local function newlineOf(source)
  return source:find("\r\n", 1, true) and "\r\n" or "\n"
end

-- The pre-fix codec directions, verbatim: no FIELD_OFFSETS, so decode() hands the page
-- the raw byte against a declared range of 4..25, and encode() writes it back with
-- `% 256`. Bounded by the FIELD_OFFSETS table above and the msp table below -- the
-- table stays, because once nothing reads it it is harmless, and cutting it out too
-- would be a second thing to get wrong.
--
-- Level-two long strings, not the plain form: a bare "]]" inside would close a plain
-- long string early and the file would fail to parse a long way from here.
local DIRECTIONS_SPLICE = [==[
local function decode(buf)
  buf.offset = 1
  local data = {
    esc_signature = mspcodec.readU8(buf),
    esc_command = mspcodec.readU8(buf),
  }
  data.firmware_version = readString(buf, 3, 16)
  data.hardware_version = readString(buf, 19, 16)
  data.esc_type = readString(buf, 35, 16)
  data.mode_name = readString(buf, 51, 15)
  local layout = itemLayoutFor(data)
  for name, itemIndex in pairs(layout) do
    data[name] = buf[65 + itemIndex] or 0
  end
  return data
end

local function encode(data)
  local payload = {}
  local source = data and data._raw or SIMULATOR_RESPONSE
  local limit = #source > 0 and #source or #SIMULATOR_RESPONSE
  for i = 1, limit do payload[i] = source[i] or SIMULATOR_RESPONSE[i] or 0 end
  local layout = itemLayoutFor(data)
  for name, itemIndex in pairs(layout) do
    if data and data[name] ~= nil then
      payload[65 + itemIndex] = math.floor(data[name] + 0.5) % 256
    end
  end
  return payload
end

]==]

local function preFix(source, nl)
  return presplice(source, "local FIELD_OFFSETS = {",
    "local msp = {", (DIRECTIONS_SPLICE:gsub("\n", nl)), "codec directions")
end

-- Four ways, before the spliced codec is allowed to stand in for the pre-fix one.
local function verifySplice(original, sabotaged)
  local problems = {}

  if sabotaged == original then problems[#problems + 1] = "the splice changed nothing" end

  local tmp = writeTmp(sabotaged)

  local readBack = readFile(tmp)
  if readBack ~= sabotaged then
    problems[#problems + 1] = string.format("does not read back (%d written, %d read)", #sabotaged, #readBack)
  end

  package.loaded[CODEC_KEY] = nil
  local ok, spliced = pcall(function() return assert(realLoadfile(tmp))() end)
  if not ok then
    problems[#problems + 1] = "does not load: " .. tostring(spliced):gsub(".*%.lua:%d+: ", "")
  else
    -- Its own signature, and it is a POSITIVE one rather than an absence: raw byte 0
    -- must come out as 0, which is the whole defect. An earlier version of this file
    -- checked the opposite -- that the offset was NOT applied -- and that check could
    -- no longer fail, because after the split from the OPTO fix the spliced codec and
    -- the real one agree about it by construction. A signature that cannot fail is not
    -- evidence.
    local fixtureBytes = spliced.buildReadMessage(function() end, function() end).simulatorResponse
    local buf = {}
    for i = 1, #fixtureBytes do buf[i] = fixtureBytes[i] end
    local at = 65 + 6                      -- item 6: startup_time in DEFAULT_ITEMS
    buf[at] = 0
    local data
    spliced.buildReadMessage(function(d) data = d end, function() end).processReply(nil, buf)
    if data == nil then
      problems[#problems + 1] = "decodes nothing, so this is not the pre-fix codec"
    elseif data.startup_time == nil then
      problems[#problems + 1] = "has no Startup Time row, so this is not the pre-fix codec"
    elseif data.startup_time ~= 0 then
      problems[#problems + 1] = string.format(
        "reads raw byte 0 as %s, so this is not the pre-fix codec", tostring(data.startup_time))
    end
  end

  os.remove(tmp)
  package.loaded[CODEC_KEY] = nil
  return #problems == 0, table.concat(problems, "; ")
end

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the Startup Time checks must go red on the pre-fix codec")
  out(string.rep("=", 72))

  local original = readFile(CODEC_SRC)
  local sabotaged = preFix(original, newlineOf(original))

  local spliceOk, spliceDetail = verifySplice(original, sabotaged)
  out(string.format("  %s  splice: %s", spliceOk and "ok   " or "FAIL ",
    spliceDetail ~= "" and spliceDetail
      or "different file, reads back, loads, and reads raw byte 0 as 0"))
  if not spliceOk then os.exit(1) end

  local tmp = writeTmp(sabotaged)
  REPLACE_MATCH, REPLACE_FILE = "msp_esc_parameters_hw5%.lua$", tmp

  -- Loaded DIRECTLY from the temp file, not through loadCodec(): that helper reads
  -- the checked-out path with realLoadfile, which the redirect does not touch -- so
  -- loading through it here would hand pass 2 the FIXED codec and make every gate
  -- pass for the wrong reason. Then dropped from package.loaded again, because that
  -- direct load left the spliced module there and requireModule() memoizes.
  codec = loadCodec(tmp)
  package.loaded[CODEC_KEY] = nil
  resetFixtureCache()

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = 0

  local pass1Gates = {}
  for i = 1, #MUST_GO_RED do pass1Gates[MUST_GO_RED[i]] = (pass1Gates[MUST_GO_RED[i]] or 0) + 1 end
  MUST_GO_RED = {}

  out("")
  out("pass 2: the same cases against the pre-fix codec")
  runChecks()

  local gateDrift = {}
  local pass2Gates = {}
  for i = 1, #MUST_GO_RED do pass2Gates[MUST_GO_RED[i]] = true end
  for label in pairs(pass1Gates) do
    if not pass2Gates[label] then gateDrift[#gateDrift + 1] = "only in pass 1: " .. label end
  end
  for label in pairs(pass2Gates) do
    if not pass1Gates[label] then gateDrift[#gateDrift + 1] = "only in pass 2: " .. label end
  end
  for label, n in pairs(pass1Gates) do
    if n > 1 then gateDrift[#gateDrift + 1] = string.format("registered %d times in pass 1: %s", n, label) end
  end

  codec = loadCodec()
  resetFixtureCache()
  REPLACE_MATCH, REPLACE_FILE = nil, nil
  os.remove(tmp)

  out("")
  out(string.format("  (spliced codec served %d time(s))", replaceHits))
  if replaceHits == 0 then
    out("  FAIL  the spliced codec never ran -- pass 2 proved nothing")
    os.exit(1)
  end

  out("")
  if #gateDrift > 0 then
    out("  FAIL  the two passes did not register the same gates:")
    for i = 1, #gateDrift do out("        " .. gateDrift[i]) end
    os.exit(1)
  end
  out(string.format("  both passes registered the same %d gates", #MUST_GO_RED))

  out("")
  out("self-test verdict:")
  local stayedGreen = {}
  for _, label in ipairs(MUST_GO_RED) do
    local red = failedLabels[label] == true
    out(string.format("  %s  %s", red and "goes red " or "STAYS GREEN", label))
    if not red then stayedGreen[#stayedGreen + 1] = label end
  end
  out("")
  if #stayedGreen > 0 then
    out(string.format("SELF-TEST FAILED -- %d of %d checks cannot detect the pre-fix behaviour",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d checks go red on the pre-fix codec", #MUST_GO_RED))
  out(string.format("pass 1 against the real tree: %d checks, %d failures", pass1Checks, pass1Failures))
end

-- The verdict below is pass 1's: without --self-test, pass 2 never ran, and with it
-- pass 2's red is the expected outcome rather than a failure here.
checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 72))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end