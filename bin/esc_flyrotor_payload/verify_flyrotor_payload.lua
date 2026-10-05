-- Behaviour check for the FlyRotor forward-programming codec (#2340).
--
-- Run it:
--     lua5.3 bin/esc_flyrotor_payload/verify_flyrotor_payload.lua
--     lua5.3 bin/esc_flyrotor_payload/verify_flyrotor_payload.lua --self-test
--
-- What the issue asks for, and what this file finds:
--   #2340 says the FlyRotor payload spec is truncated, that reading further pages
--   fails on a length mismatch, that a save truncates or corrupts the trailing
--   parameters, and asks for three things: extend the spec to 56 bytes, make the
--   base and ADV/OTHER sub-page offsets match it, and validate buffer lengths
--   before writing.
--
--   Two of the three are already true, and this file measures that rather than
--   asserting it. The block is 56 bytes and it has been:
--
--     * rotorflight-firmware src/main/sensors/esc_sensor.c:1931-1932 holds the
--       page table the length comes from --
--       `static uint16_t flyParamPages[] = { 0x0016, 0x160C, 0x220A, 0x2C0A }`,
--       hi-byte = offset, lo-byte = length. flyCalcParamBufferLength()
--       (:2130-2136) sums the low bytes, 22 + 12 + 10 + 10 = 54, and
--       escGetParamFullBufferLength() (:4540-4551) adds PARAM_HEADER_SIZE = 2.
--       So MSP_ESC_PARAMETERS carries 56 bytes for a FlyRotor -- which is what
--       the codec's own WIRE_FIELDS already summed to and what its shipped
--       simulatorResponse already carried.
--     * WIRE_FIELDS lands on all four page boundaries exactly, field for field:
--       8 fields over INFO's 22 bytes, 12 over BASIC's 12, 8 over ADV's 10, 7
--       over OTHER's 10. Nothing is unmapped and nothing straddles a boundary.
--       The "layout" section below walks that and would fail loudly if a field
--       were added, removed or retyped.
--     * a decode/encode round trip with nothing edited changes 0 of 14 336 byte
--       values -- every position against all 256 of its values. It is lossless.
--
--   What is NOT true is the third thing, and it is the one that costs the ESC
--   something. lib/mspcodec.lua is deliberately bounds-safe -- a byte past the
--   end reads as 0, not nil -- and its own header says a decoder that cannot
--   tolerate a missing field must check the length itself. This codec did not, so
--   a truncated reply decoded into a table whose tail was zeros, the editor
--   opened on it, and a save wrote those zeros out:
--
--     decode(40 bytes) -> encode wrote 56 bytes, 26 of them zero
--     decode( 3 bytes) -> encode wrote 56 bytes, 55 of them zero
--     decode( 0 bytes) -> encode wrote 56 bytes, ALL of them zero
--
--   The signature gate does not catch it, because esc_signature is byte 1 and a
--   40-byte reply still carries it. And flyParamCommit() (esc_sensor.c:1964-1987)
--   writes every page whose bytes DIFFER from the FC's cached block, so the pages
--   that got zeroed are written: ADV lost soft_start, auto_restart_time,
--   restart_acc, gov_p, gov_i, active_freewheel, drive_freq and motor_erpm_max,
--   and OTHER lost throttle_protocol, telemetry_protocol, led_color_index,
--   led_color_rgb, motor_temp_sensor, motor_temp and battery_capacity. That is the
--   "soft-start acceleration or current limiter settings" the issue describes, and
--   it needed a truncated read rather than a shorter spec to happen.
--
--   The fix is the guard the issue's third point asks for: decode() refuses a
--   block shorter than the layout and reports it as a failed read, so no editor
--   is built; encode() refuses a table that is not a decoded one rather than
--   zeroing the fields it is missing, and buildWriteMessage() declines to build
--   a message at all, which app/page_runtime.lua already treats as a REFUSED
--   write and reports (its writeSource(), the same branch
--   lib/msp_governor_profile.lua's refusal uses).
--
-- What it drives, and why:
--   * the real app/pages/esc_forward_flyrotor.lua, the real
--     app/pages/esc_forward_vendor.lua, the real app/page_runtime.lua and the
--     real codec, entered through the page's own open(). FlyRotor goes straight
--     to the shared editor -- it has no 4-way target selector -- so unlike the
--     Bluejay and AM32 harnesses nothing here has to be stubbed to get past a
--     page that is not under test.
--   * the real app/field_layout.lua, because a pilot edit is exactly the call
--     Ethos makes on the setter the widget was built with.
--   * Only form, the bus and the chrome-only modules are stubbed. The bus answers
--     reads with the codec's OWN simulatorResponse -- the fixture
--     tasks/msp/queue.lua replays on the Ethos simulator -- decoded by the
--     production decode(), and records the payload of every write.
--
-- Which checks go RED on the pre-fix codec -- eight of them, and pass 2 reports
-- exactly which: the 55-byte boundary, the four-page truncation walk, the reason
-- string, the read's error path against its data path, the page-level "no editor,
-- nothing on the bus", the decline-instead-of-raise case, the exhaustive
-- missing-one-field walk, and the reason naming the field.
-- --self-test proves that rather than asserting it: it splices the pre-fix byte
-- helpers, the pre-fix decode()/encode() and the pre-fix buildReadMessage()/
-- buildWriteMessage() back into a copy of the codec and requires every one of the
-- eight to fail. It also verifies the splice four ways before using it, because a
-- sabotage that breaks the module differently from the defect under test proves
-- nothing about the defect.
--
-- Everything in the "layout" and "round trip" sections is deliberately NOT a
-- gate, and the section headers say so where they are written. Those are the
-- issue's first two points, and they were already satisfied before this change --
-- measured above. They are here so the claim stays a fact the repository carries
-- rather than a sentence in a comment, and so the next person to touch WIRE_FIELDS
-- finds out. One check in the first group is not a gate either, and for the
-- opposite reason: "a block of exactly 56 bytes is accepted" has to hold both
-- before and after, so requiring it to go red would be requiring the harness to
-- fail on correct behaviour. A gate check that cannot go red is worse than no
-- check.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local CODEC_SRC = SUITE .. "/lib/msp_esc_parameters_flyrotor.lua"

local SELF_TEST = arg[1] == "--self-test"

-- The names of every check the sabotage has to turn red. Collected as they run
-- so the self-test cannot drift away from the checks as they are written.
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

-- Registers a check whose passing is only meaningful if it can fail.
local function gateCheck(label, ok, detail)
  MUST_GO_RED[#MUST_GO_RED + 1] = label
  check(label, ok, detail)
end

-- ---------------------------------------------------------------------------
-- Ethos environment
-- ---------------------------------------------------------------------------

package.path = PREFIX .. "?.lua;" .. package.path

local realLoadfile = loadfile

-- Set by the self-test: the codec path suffix the redirect replaces, and the
-- temp file to serve instead. A redirect that never fires would leave the second
-- pass a disguise of the first, so the hit count is reported and required.
local REPLACE_MATCH, REPLACE_FILE, replaceHits = nil, nil, 0

-- requireModule() calls loadfile() with a path carrying no directory part; on
-- the radio the working directory is src/rfsuite.
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

-- Everything this run observed, cleared before each drive so one case cannot
-- see another's editor.
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

-- The read fixture this case staged, how long it is, and whether it fails.
-- Copied per case in openPage(), so a case that pokes a byte cannot be seen by
-- the next one.
local reply = nil
local replyFails = false

-- A widget that remembers the accessors field_layout handed it, because a pilot
-- edit is exactly "call the setter the widget was built with".
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

-- field_layout.buildField() hands form.addChoiceField/addNumberField no label,
-- only the line it was added to -- so the field is keyed by that line's label.
-- This page gives every row its own line (esc_forward_vendor.lua's buildEditor
-- calls buildSingle, one addLine per field) and no two rows share one, which is
-- what makes the label a usable key.
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
-- Off, so confirmSave() routes straight into performSave() instead of stopping
-- at a confirmation modal. Without it the write path is not reachable at all.
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
-- app/field_layout.lua is the REAL module, because a pilot edit is the call
-- Ethos makes on the setter it built and stubbing it would make every
-- write-direction case here vacuous. But it keeps no reference to the runtime it
-- builds fields for, and something has to hand this harness that runtime or
-- there is no Save to press. So buildSingle() is WRAPPED rather than replaced:
-- it records the runtime and then calls through.
local fieldLayout = requireModule("app/field_layout.lua")
do
  local buildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, label, spec, parent)
    if not obs.runtime then obs.runtime = runtime end
    return buildSingle(runtime, label, spec, parent)
  end
end

-- ---------------------------------------------------------------------------
-- The firmware's page table, and the codec's layout against it
-- ---------------------------------------------------------------------------

-- rotorflight-firmware src/main/sensors/esc_sensor.c:1931-1932, verbatim:
--   // param pages - hi-byte=offset, low-byte=length
--   static uint16_t flyParamPages[] = { 0x0016, 0x160C, 0x220A, 0x2C0A };
-- and PARAM_HEADER_SIZE at :107. Nothing here is a transcription of anybody's
-- idea of the layout -- it is the flight controller's own table, which is where
-- the block length comes from.
local FLY_PARAM_PAGES = {
  {name = "INFO", word = 0x0016},
  {name = "BASIC", word = 0x160C},
  {name = "ADV", word = 0x220A},
  {name = "OTHER", word = 0x2C0A},
}
local PARAM_HEADER_SIZE = 2

local PAGES = {}
local FIRMWARE_PAYLOAD_BYTES = 0
for i, p in ipairs(FLY_PARAM_PAGES) do
  PAGES[i] = {
    name = p.name,
    offset = p.word >> 8,
    len = p.word % 256,
  }
  FIRMWARE_PAYLOAD_BYTES = FIRMWARE_PAYLOAD_BYTES + PAGES[i].len
end
local FIRMWARE_BLOCK_BYTES = PARAM_HEADER_SIZE + FIRMWARE_PAYLOAD_BYTES

-- A verbatim transcription of the shipped WIRE_FIELDS, because the codec keeps
-- that table local to decode()/encode() and does not export it. Two things keep
-- this honest rather than a second source of truth: every case below asserts
-- against the codec's OWN BLOCK_BYTES (which the codec sums from its own table),
-- and the page-coverage walk fails loudly with the field names if the two ever
-- stop agreeing.
local LAYOUT = {
  { "esc_signature", "u8" }, { "esc_command", "u8" }, { "esc_type", "u8" },
  { "esc_model", "u16be" }, { "esc_sn", "bytes8" }, { "esc_iap", "bytes3" },
  { "esc_fw", "bytes3" }, { "esc_hardware", "u8" }, { "throttle_min", "u16be" },
  { "throttle_max", "u16be" }, { "esc_mode", "u8" }, { "cell_count", "u8" },
  { "low_voltage_protection", "u8" }, { "temperature_protection", "u8" },
  { "bec_voltage", "u8" }, { "electrical_angle", "u8" }, { "motor_direction", "u8" },
  { "starting_torque", "u8" }, { "response_speed", "u8" }, { "buzzer_volume", "u8" },
  { "current_gain", "current_gain" }, { "fan_control", "u8" }, { "soft_start", "u8" },
  { "auto_restart_time", "u8" }, { "restart_acc", "u8" }, { "gov_p", "u8" },
  { "gov_i", "u8" }, { "active_freewheel", "u8" }, { "drive_freq", "u8" },
  { "motor_erpm_max", "u24be" }, { "throttle_protocol", "u8" },
  { "telemetry_protocol", "u8" }, { "led_color_index", "u8" },
  { "led_color_rgb", "bytes3" }, { "motor_temp_sensor", "u8" }, { "motor_temp", "u8" },
  { "battery_capacity", "u16be" },
}

local WIDTH = {
  u8 = 1, u16be = 2, u24be = 3, current_gain = 1, bytes3 = 3, bytes8 = 8,
}

-- 1-based MSP byte positions, so esc_signature is byte 1 and the first payload
-- byte -- esc_type -- is byte 3, PARAM_HEADER_SIZE + 1.
local function walkLayout()
  local offsets, cursor = {}, 1
  for i = 1, #LAYOUT do
    local name, wireType = LAYOUT[i][1], LAYOUT[i][2]
    local width = WIDTH[wireType]
    if not width then
      error("the transcribed layout has no width for wire type " .. tostring(wireType))
    end
    offsets[name] = {
      msp = cursor,
      width = width,
      -- 0-based offset inside the 54-byte ESC payload
      payload = cursor - 1 - PARAM_HEADER_SIZE,
    }
    cursor = cursor + width
  end
  return offsets, cursor - 1
end

local OFFSETS, LAYOUT_BYTES = walkLayout()

local function copyOf(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end

-- The first `bytes` entries of a block, which is what a truncated reply looks
-- like. Separate from copyOf on purpose: copyOf(t, 0, n) reads as though the
-- extra arguments did something, and the first version of the boundary case below
-- passed a full block where it meant to pass a short one -- and then reported the
-- guard as broken.
local function truncate(t, bytes)
  local out = {}
  for i = 1, math.min(bytes, #t) do out[i] = t[i] end
  return out
end

-- ---------------------------------------------------------------------------
-- The codec and the page that holds it
-- ---------------------------------------------------------------------------

local CODEC_KEY = "rfsuite.lib.msp_esc_parameters_flyrotor"

-- realLoadfile, deliberately, not the redirect above: the redirect prepends the
-- suite prefix to anything ending in .lua, which is right for requireModule()'s
-- bare "lib/..." paths and wrong for this absolute-ish one.
local function loadCodec(file)
  package.loaded[CODEC_KEY] = nil
  return assert(realLoadfile(file or CODEC_SRC))()
end

-- The page is reloaded per runChecks(), and it has to be: esc_forward_flyrotor.lua
-- binds the codec into a module-level `local msp` at its line 5, so reloading only
-- the codec would leave the page still holding the first one and pass 2 would be a
-- rerun of pass 1 wearing a different label. The page carries no self-cache guard,
-- so a plain reload really does re-run its body.
local function loadPage()
  return assert(realLoadfile(PREFIX .. "app/pages/esc_forward_flyrotor.lua"))()
end

local codec

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

-- Which i18n key ends which row. The page's labels are unresolved @i18n(...)@
-- tags at this point -- they are substituted at build time by
-- .vscode/scripts/resolve_i18n_tags.py, not at Lua runtime -- so the key IS the
-- label here, and it is a stable one to match on.
local ROW_GOV_P = "mfg.flrtr.gov_p"
-- Spelled from the page's own key, which carries an underscore:
-- `@i18n(app.modules.esc_tools.mfg.flrtr.buzzer_volume)@`. The first version of this
-- file guessed "buzzervolume" instead, and the two cases that depend on it failed
-- with "the row was never built" -- which is the right way for that mistake to
-- surface, since the row really was not built.
local ROW_UNRELATED = "mfg.flrtr.buzzer_volume"

local page

local function freshOpts()
  local opts = {}
  local installed = {}
  local function setter(name)
    return function(handler) installed[name] = handler end
  end
  -- Stored in a side table, not back onto opts: writing the handler under the
  -- setter's own name would replace the setter with the handler, and the wakeup
  -- would then call itself.
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() end
  opts.__installed = installed
  return opts
end

-- One open of the real page, answered with `fixture` (or with a copy of its first
-- `bytes` entries). Returns the runtime the page built -- reached through
-- field_layout.buildSingle(), which receives it as its first argument -- and the
-- opts.
--
-- One wakeup tick is enough: esc_forward_vendor passes the finished read in as
-- `initialData`, so PageRuntime:loadInitial() takes its short-circuit branch and
-- sets self.loaded = true without a second read. The editor is built during that
-- same tick, by the page's own wakeup handler.
local function openPage(fixture, bytes)
  resetObs()
  local staged = nil
  if fixture then
    staged = {}
    for i = 1, bytes or #fixture do staged[i] = fixture[i] end
  end
  reply = staged
  replyFails = false

  local opts = freshOpts()
  page.open(opts)
  opts.__installed.setWakeupHandler()

  local runtime = obs.runtime
  opts.__runtime = runtime
  return runtime, opts
end

local function rowField(key)
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].label:find(key, 1, true) then return obs.fieldOrder[i] end
  end
  return nil
end

-- A pilot edit: exactly the call Ethos makes on the widget's setter.
local function edit(field, value)
  field.set(value)
end

-- Moves a row the cases do not care about, so Save becomes reachable the way it
-- is for a real pilot -- by changing something. A page on which nothing was
-- touched cannot be saved at all: canSave() requires self.dirty, and
-- refreshDirty() compares the whole table, so changing a row back undoes the
-- dirty state too. Every "nothing else moved" case therefore edits an unrelated
-- row, which is both reachable and the harder test.
local function editUnrelatedField()
  local field = rowField(ROW_UNRELATED)
  if not field then return false end
  local current = field.get()
  local next = current == field.max and field.min or current + 1
  if next == current then return false end
  edit(field, next)
  return true
end

-- The pilot's Save button, through the header the runtime built. Returns the
-- MSP 218 payload that went onto the bus, or nil.
local function pressSave(opts)
  local runtime = opts.__runtime
  if not runtime or not runtime.headerHandle then return nil end
  local writesBefore = #obs.writes
  runtime:confirmSave(runtime.headerHandle.focusSave)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  -- Ascending from writesBefore + 1: a descending loop from #obs.writes down to
  -- writesBefore runs once with i == 0 when nothing was written at all, and
  -- obs.writes[0] is nil.
  for i = writesBefore + 1, #obs.writes do
    if obs.writes[i].command == codec.WRITE_COMMAND then return obs.writes[i].payload end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------

-- A read that is one byte short, and one of exactly the right length: the two
-- sides of the boundary, and the boundary is the whole claim.
local function checkShortReadRefused()
  local fixture = codec._simulatorResponse

  -- The other side of the boundary, and deliberately NOT a gate: a block of
  -- exactly the right length has to be accepted both before and after the fix, so
  -- requiring this one to go red would be requiring the harness to fail on correct
  -- behaviour. It is here because a guard written as `<=` instead of `<` passes
  -- every "is it refused" case in this file and only this one catches it.
  check(string.format("a block of exactly %d bytes is accepted",
    FIRMWARE_BLOCK_BYTES), codec._decode(copyOf(fixture)) ~= nil)

  local oneShort = FIRMWARE_BLOCK_BYTES - 1
  gateCheck(string.format("a block of %d bytes, one short, is refused", oneShort),
    codec._decode(truncate(fixture, oneShort)) == nil)

  -- One length from inside each firmware page, so the guard is shown to cover the
  -- whole block rather than just its first bytes -- a check that only ever poked
  -- byte 40 would pass a guard that stopped at byte 41.
  local slipped = {}
  for _, p in ipairs(PAGES) do
    -- the last byte of this page, which is also the last byte the page owns
    local at = p.offset + p.len - 1 + PARAM_HEADER_SIZE
    if codec._decode(truncate(fixture, at)) ~= nil then
      slipped[#slipped + 1] = string.format("%s truncated at payload byte %d (%d bytes)",
        p.name, p.offset + p.len - 1, at)
    end
  end
  gateCheck("a block truncated inside each of the four firmware pages is refused",
    #slipped == 0, #slipped > 0 and table.concat(slipped, "; ") or nil)

  local data, reason = codec._decode(truncate(fixture, 40))
  gateCheck("the refusal says how short the block was",
    data == nil and type(reason) == "string" and reason:find("40", 1, true) ~= nil
      and reason:find(tostring(FIRMWARE_BLOCK_BYTES), 1, true) ~= nil,
    "reason was " .. tostring(reason))

  -- The refusal has to arrive where the page can act on it. Asserting on decode()
  -- alone would pass while processReply handed the page a table anyway -- which is
  -- exactly what the pre-fix code did, and what would make an editor open on a
  -- zeroed tail. So this drives the real message builder and watches which of its
  -- two callbacks fires.
  --
  -- pcall because the pre-fix path RAISES in writeBytes on some of these, and a
  -- harness that lets that escape takes the whole file down and proves nothing
  -- about anything else.
  local gotData, gotError
  local okRead = pcall(function()
    local message = codec.buildReadMessage(
      function(d) gotData = d or gotData end,
      function(r) gotError = r or gotError end)
    message.processReply(nil, truncate(fixture, 40))
  end)
  gateCheck("a short block reaches the read's error path and not its data path",
    okRead and gotData == nil and gotError ~= nil,
    not okRead and "processReply raised"
      or (gotData ~= nil and "processReply handed the page a table anyway" or nil))
end

-- The same refusal seen through the real page: a short read must not build an
-- editor, because an editor built on a zeroed tail is how zeros reach the ESC.
local function checkShortReadBuildsNoEditor()
  local fixture = codec._simulatorResponse
  local runtime = openPage(fixture, FIRMWARE_BLOCK_BYTES - 16)

  local wrote = false
  for i = 1, #obs.writes do
    if obs.writes[i].command == codec.WRITE_COMMAND then wrote = true end
  end
  gateCheck("a short read builds no editor and puts no parameter block on the bus",
    (obs.runtime == nil) and not wrote,
    string.format("runtime built: %s, %d write(s)",
      tostring(obs.runtime ~= nil), #obs.writes))
end

-- The write half. The pre-fix encoder turned a missing field into a zero, and for
-- this block a zero is a legal value the firmware accepts and commits. Measured on
-- the pre-fix codec, a table missing exactly one field: **33 of the 37 produced a
-- payload with that field zeroed**, and the other **four RAISED** -- esc_sn,
-- esc_iap, esc_fw and led_color_rgb, the byte-array fields -- because writeValue()
-- turned the missing value into 0 first and 0 is truthy in Lua, so `bytes or {}`
-- kept the number and writeBytes() indexed it. Both are failures, and the check
-- counts them apart rather than folding them together.
local function checkIncompleteWriteRefused()
  -- Returns the message on success, and nil plus a reason on either a refusal or a
  -- raise -- and `raised` says which, because a raise is NOT a refusal and a check
  -- that cannot tell them apart passes on the pre-fix codec for the wrong reason:
  -- `buildWriteMessage(nil)` crashed there, and a helper that maps "crashed" onto
  -- "declined" reports green. That is what the first version did, and two of the
  -- eight gates stayed green because of it. pcall because the pre-fix path raises
  -- on four of the 37, and a harness that lets that escape takes the whole file
  -- down and proves nothing about anything else.
  -- Three values, because pcall passes through everything the function returned and
  -- buildWriteMessage() answers a refusal with (nil, reason): capturing only the
  -- first would throw the reason away, and the gate that checks the reason names
  -- the field would then see nil and fail on the FIXED codec. That is what the
  -- first version did -- it reported "refused, reason nil" against correct code.
  local function tryWrite(data)
    local ok, message, reason = pcall(codec.buildWriteMessage, data, function() end, function() end)
    if not ok then return nil, tostring(message), true end
    return message, reason, false
  end

  local noTable, noTableReason, noTableRaised = tryWrite(nil)
  gateCheck("a write with no table at all is declined rather than raised",
    noTable == nil and not noTableRaised,
    noTable and string.format("built a %d-byte payload instead", #noTable.payload or 0)
      or (noTableRaised and "it raised: " .. tostring(noTableReason):gsub("^.-: ", "")
        or ("reason was " .. tostring(noTableReason))))

  -- Every field, missing on its own. Exhaustive rather than sampled: the failure
  -- mode is per-field, and a check of three fields would pass with the other
  -- thirty-four broken.
  local decoded = codec._decode(copyOf(codec._simulatorResponse))
  local accepted, raised = {}, {}
  for name in pairs(decoded) do
    local partial = {}
    for other, value in pairs(decoded) do
      if other ~= name then partial[other] = value end
    end
    local message, err, didRaise = tryWrite(partial)
    if didRaise then
      raised[#raised + 1] = name
    elseif message ~= nil then
      accepted[#accepted + 1] = name
    end
  end
  gateCheck("every field, missing on its own, is a refused write",
    #accepted == 0 and #raised == 0,
    #accepted > 0 and string.format("%d field(s) still produced a payload: %s",
      #accepted, table.concat(accepted, ", "))
      or (#raised > 0 and string.format("%d field(s) raised instead of refusing: %s",
        #raised, table.concat(raised, ", ")) or nil))

  local named, reason, namedRaised = tryWrite({esc_type = 0})
  gateCheck("the refusal names the field it could not write",
    named == nil and not namedRaised and reason ~= nil and reason ~= "<not a table>",
    (named and string.format("built a %d-byte payload", #named.payload or 0) or "refused")
      .. ", reason " .. tostring(reason))
end

-- Everything below is the issue's first two points. None of it is a gate: all of
-- it was already true before this change, measured, and the reason it is here is
-- that a claim nobody checks stops being true quietly.
local function checkLayout()
  out("")
  out("layout: the block is the firmware's block (already true, now pinned)")

  check(string.format("the firmware's four pages sum to %d payload bytes",
    FIRMWARE_PAYLOAD_BYTES), FIRMWARE_PAYLOAD_BYTES == 54,
    string.format("22 + 12 + 10 + 10 = %d, expected 54", FIRMWARE_PAYLOAD_BYTES))
  check(string.format("with the %d-byte header that is the %d-byte block MSP carries",
    PARAM_HEADER_SIZE, FIRMWARE_BLOCK_BYTES), FIRMWARE_BLOCK_BYTES == 56,
    string.format("got %d", FIRMWARE_BLOCK_BYTES))

  -- The codec's OWN number, summed by the codec from its own table.
  check(string.format("the codec says the block is %d bytes too", codec.BLOCK_BYTES),
    codec.BLOCK_BYTES == FIRMWARE_BLOCK_BYTES,
    string.format("codec.BLOCK_BYTES is %s, the firmware's table says %d",
      tostring(codec.BLOCK_BYTES), FIRMWARE_BLOCK_BYTES))
  check("the transcribed layout above is the length the codec computes",
    LAYOUT_BYTES == codec.BLOCK_BYTES,
    string.format("transcription %d, codec %d -- WIRE_FIELDS changed, update the table above",
      LAYOUT_BYTES, codec.BLOCK_BYTES))
  check("the shipped simulator fixture is the block, byte for byte",
    #codec._simulatorResponse == FIRMWARE_BLOCK_BYTES,
    string.format("the fixture carries %d bytes, the block is %d",
      #codec._simulatorResponse, FIRMWARE_BLOCK_BYTES))

  -- The page-coverage walk. This is the issue's second point stated as a fact:
  -- every byte of every firmware page belongs to exactly one field, and no field
  -- straddles a page boundary.
  out("")
  out("layout: every firmware page byte belongs to exactly one field")
  for _, p in ipairs(PAGES) do
    local inPage, straddling = {}, {}
    -- Which page bytes does any field claim? Claimed counts a byte twice, which is
    -- as wrong as leaving it unclaimed -- two fields over one byte means one of
    -- them is written from the wrong offset.
    local claimed, twice = {}, {}
    for name, f in pairs(OFFSETS) do
      local first, lastInPayload = f.payload, f.payload + f.width - 1
      if first < p.offset + p.len and lastInPayload >= p.offset then
        inPage[#inPage + 1] = name
        if first < p.offset or lastInPayload > p.offset + p.len - 1 then
          straddling[#straddling + 1] = name
        end
        for b = math.max(first, p.offset), math.min(lastInPayload, p.offset + p.len - 1) do
          claimed[b] = (claimed[b] or 0) + 1
          if claimed[b] == 2 then twice[#twice + 1] = b end
        end
      end
    end
    table.sort(inPage)

    local uncovered, overclaimed = {}, {}
    for b = p.offset, p.offset + p.len - 1 do
      if not claimed[b] then uncovered[#uncovered + 1] = b end
    end
    table.sort(twice)

    local problems = {}
    if #uncovered > 0 then
      problems[#problems + 1] = string.format("unmapped byte(s) %s", table.concat(uncovered, ", "))
    end
    if #twice > 0 then
      problems[#problems + 1] = string.format("claimed twice: payload byte %s", table.concat(twice, ", "))
    end
    if #straddling > 0 then
      problems[#problems + 1] = string.format("straddles the boundary: %s", table.concat(straddling, ", "))
    end

    check(string.format("%-5s payload %2d..%2d: %2d bytes, %2d fields, none unmapped or shared",
      p.name, p.offset, p.offset + p.len - 1, p.len, #inPage),
      #problems == 0, #problems > 0 and table.concat(problems, "; ") or nil)
  end

  -- And the two header bytes are where PARAM_HEADER_SIG and PARAM_HEADER_VER say
  -- they are, which is why esc_signature and esc_command are the first two.
  check("the first two bytes are the MSP header the firmware fills in",
    OFFSETS.esc_signature.msp == 1 and OFFSETS.esc_command.msp == 2
      and OFFSETS.esc_type.payload == 0,
    string.format("esc_signature at msp %d, esc_command at msp %d, esc_type at payload %d",
      OFFSETS.esc_signature.msp, OFFSETS.esc_command.msp, OFFSETS.esc_type.payload))
end

-- Every byte position against every one of its 256 values, decode/encode with
-- nothing edited. Not a gate -- it was already lossless -- and the point of it is
-- that a field added to WIRE_FIELDS later with a lossy transform fails here.
local function checkRoundTrip()
  out("")
  out("round trip: every byte survives a save that changed something else")
  local fixture = codec._simulatorResponse
  local lost, firstLost = 0, nil
  for offset = 1, #fixture do
    for value = 0, 255 do
      local buf = copyOf(fixture)
      buf[offset] = value
      local data = codec._decode(buf)
      local out2 = data and codec._encode(data)
      if type(out2) ~= "table" or #out2 ~= #buf then
        lost = lost + 1
        if not firstLost then
          firstLost = string.format("byte %d: encode produced %s for a %d byte block",
            offset, out2 and #out2 or "nothing", #buf)
        end
      elseif out2[offset] ~= value then
        lost = lost + 1
        if not firstLost then
          firstLost = string.format("byte %d: value %d came back as %d, nothing was edited",
            offset, value, out2[offset])
        end
      end
    end
  end
  check(string.format("all %d byte positions survive all 256 of their values unchanged",
    #fixture), lost == 0,
    lost > 0 and string.format("%d of %d values came back changed; first: %s",
      lost, #fixture * 256, firstLost) or nil)

  -- current_gain is the one field that is not the identity: it is stored biased
  -- by 20 so that -20..20 fits a signed byte. Both ends of the declared range,
  -- because the bias is what makes the ends the interesting ones, and one byte
  -- outside it -- 0xEB reads as -21 signed, so -41 once the bias is taken off --
  -- which is a value the page cannot offer and the codec must still carry
  -- unchanged rather than clamp.
  local field = OFFSETS.current_gain
  for _, case in ipairs({
    { wire = 0, shown = -20, note = "the bottom of the declared range" },
    { wire = 20, shown = 0, note = "the middle" },
    { wire = 40, shown = 20, note = "the top of the declared range" },
    { wire = 235, shown = -41, note = "outside it, and still carried unchanged" },
  }) do
    local buf = copyOf(fixture)
    buf[field.msp] = case.wire
    local data = codec._decode(buf)
    local label = string.format("a Current Gain byte of %d reads as %s (%s)",
      case.wire, tostring(case.shown), case.note)
    if data == nil then
      check(label, false, "refused")
    elseif data.current_gain ~= case.shown then
      check(label, false, string.format("the row shows %s", tostring(data.current_gain)))
    else
      -- ...and the value goes back as the byte it came from, bias included.
      local out2 = codec._encode(data)
      check(label, out2[field.msp] == case.wire,
        string.format("byte %d came back as %s", field.msp, tostring(out2[field.msp])))
    end
  end
end

-- The write direction, through the real page: a refusal must not have turned into
-- "nothing is ever written".
local function checkEditReachesWire()
  out("")
  out("write: the row the pilot moves still reaches the ESC")
  local fixture = codec._simulatorResponse

  do
    local runtime, opts = openPage(fixture)
    local row = runtime and rowField(ROW_GOV_P)
    local label = "moving Gov P writes its byte"
    if not row then
      check(label, false, "the Gov P row was never built")
    else
      edit(row, 60)
      local payload = pressSave(opts)
      local got = payload and payload[OFFSETS.gov_p.msp]
      check(label, got == 60,
        payload and string.format("byte %d is %s, expected 60",
          OFFSETS.gov_p.msp, tostring(got)) or "no write went out")
    end
  end

  do
    local runtime, opts = openPage(fixture)
    local label = "Save reaches the ESC after a completed read and a pilot edit"
    if not runtime or not editUnrelatedField() then
      check(label, false, "the page did not load, or the Buzzer Volume row was never built")
    else
      local payload = pressSave(opts)
      check(label, payload ~= nil and #payload == FIRMWARE_BLOCK_BYTES,
        payload and string.format("payload is %d bytes, expected %d",
          #payload, FIRMWARE_BLOCK_BYTES) or "no write went out")
    end
  end

  -- ...and a save that changed one row leaves every other byte as the ESC sent it,
  -- which is the same statement #2339 made for Bluejay and AM32 and which this
  -- codec gets for free: it has one lossless field and thirty-six identities.
  do
    local runtime, opts = openPage(fixture)
    local label = "a save that moved one row leaves every other byte as the ESC sent it"
    if not runtime or not editUnrelatedField() then
      check(label, false, "the page did not load, or the Buzzer Volume row was never built")
    else
      local payload = pressSave(opts)
      if not payload then
        check(label, false, "no write went out")
      elseif #payload ~= #fixture then
        check(label, false, string.format("payload is %d bytes, the reply was %d",
          #payload, #fixture))
      else
        local diffs = {}
        for i = 1, #fixture do
          if payload[i] ~= fixture[i] then
            diffs[#diffs + 1] = string.format("byte %d", i)
          end
        end
        local editedAt = OFFSETS.buzzer_volume.msp
        check(label, #diffs == 1 and tonumber(diffs[1]:match("(%d+)")) == editedAt,
          table.concat(diffs, ", "))
      end
    end
  end
end

local function runChecks()
  page = loadPage()

  out("")
  out("a short read must not become a table of zeros")
  checkShortReadRefused()
  checkShortReadBuildsNoEditor()

  out("")
  out("a write without a whole table must be refused, not zeroed")
  checkIncompleteWriteRefused()

  checkLayout()
  checkRoundTrip()
  checkEditReachesWire()
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("FlyRotor forward programming: the 56-byte block and the length guard (#2340)")
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

-- Replaces ONE contiguous region, so a mistake in one splice cannot take an
-- unrelated table with it -- the trap bin/esc_parameters_yge's self-test
-- documents, where a cut from the first mapping table to the end of the last
-- function took a third table with it and the resulting failure had nothing to do
-- with the defect under test.
local function presplice(source, regionOpen, regionClose, replacement, what)
  local from = assert(source:find(regionOpen, 1, true), "sabotage: " .. what .. " start not found")
  local to = assert(source:find(regionClose, from, true), "sabotage: " .. what .. " end not found")
  return source:sub(1, from - 1) .. replacement .. source:sub(to)
end

-- core.autocrlf=true and no .gitattributes, so the checkout is CRLF. Detect
-- rather than assume; a mismatch would make the plain finds below miss.
local function newlineOf(source)
  return source:find("\r\n", 1, true) and "\r\n" or "\n"
end

-- The pre-fix byte-level helpers, verbatim: readBytes/writeBytes without the type
-- guard, and the readValue/writeValue if-chain that WIRE replaced. What is NOT in
-- here is WIRE and BLOCK_BYTES -- the width table and the number summed from it.
-- They are not the fix, and splicing them out would leave the spliced module with
-- no BLOCK_BYTES at all, so the whole "layout" section below would blow up on a
-- nil in pass 2 and the self-test would abort before its verdict instead of
-- reporting red. The first version of this self-test cut from readBytes() to
-- version() and did exactly that.
--
-- Level-two long strings, not the plain form, because the spliced code contains
-- `data[field[1]]` and a bare "]]" in there would close a plain long string
-- early -- which parses as a syntax error a long way from the cause.
local HELPERS_SPLICE = [==[
local function readBytes(buf, count)
  local bytes = {}
  for i = 1, count do
    bytes[i] = mspcodec.readU8(buf) or 0
  end
  return bytes
end

local function writeBytes(payload, bytes, count)
  bytes = bytes or {}
  for i = 1, count do
    mspcodec.writeU8(payload, bytes[i] or 0)
  end
end

local function readValue(buf, wireType)
  if wireType == "u8" then return mspcodec.readU8(buf) end
  if wireType == "u16be" then
    local high = mspcodec.readU8(buf) or 0
    local low = mspcodec.readU8(buf) or 0
    return high * 256 + low
  end
  if wireType == "u24be" then
    local high = mspcodec.readU8(buf) or 0
    local mid = mspcodec.readU8(buf) or 0
    local low = mspcodec.readU8(buf) or 0
    return high * 65536 + mid * 256 + low
  end
  if wireType == "current_gain" then return (mspcodec.readS8(buf) or 0) - 20 end
  if wireType == "bytes3" then return readBytes(buf, 3) end
  return readBytes(buf, 8)
end

local function writeValue(payload, wireType, value)
  value = value or 0
  if wireType == "u8" then
    mspcodec.writeU8(payload, value)
  elseif wireType == "u16be" then
    mspcodec.writeU8(payload, math.floor(value / 256) % 256)
    mspcodec.writeU8(payload, value % 256)
  elseif wireType == "u24be" then
    mspcodec.writeU8(payload, math.floor(value / 65536) % 256)
    mspcodec.writeU8(payload, math.floor(value / 256) % 256)
    mspcodec.writeU8(payload, value % 256)
  elseif wireType == "current_gain" then
    mspcodec.writeS8(payload, value + 20)
  elseif wireType == "bytes3" then
    writeBytes(payload, value, 3)
  else
    writeBytes(payload, value, 8)
  end
end

]==]

-- The pre-fix codec directions. No length check in decode(), and encode() writing
-- `data and data[field[1]] or nil`, which is where both the zeros and the raises
-- came from.
local DIRECTIONS_SPLICE = [==[
local function decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2])
  end
  return data
end

local function encode(data)
  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    writeValue(payload, field[2], data and data[field[1]] or nil)
  end
  return payload
end

]==]

-- The pre-fix message builders. decode() returned a table unconditionally and
-- buildWriteMessage() built a message with whatever encode() produced, so both
-- guards this change adds are gone.
local BUILDERS_SPLICE = [==[
function msp.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf) onData(decode(buf)) end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = encode(data),
    isWrite = true,
    processReply = function() if onWritten then onWritten() end end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

]==]

local function preFix(source, nl)
  -- (1) the byte-level helpers, from readBytes() to the big-endian pair -- which
  --     WIRE and BLOCK_BYTES sit behind and must survive.
  source = presplice(source, "local function readBytes(buf, count)",
    "local function readBigEndian(buf, count)", (HELPERS_SPLICE:gsub("\n", nl)),
    "byte-level helpers")
  -- (2) decode() and encode().
  source = presplice(source, "local function decode(buf)",
    "local function version(bytes)", (DIRECTIONS_SPLICE:gsub("\n", nl)),
    "codec directions")
  -- (3) the two message builders. Bounded by the export block that follows them,
  --     so the exports this harness needs survive -- they are not the fix either.
  source = presplice(source, "function msp.buildReadMessage(onData, onError)",
    "msp.BLOCK_BYTES = BLOCK_BYTES", (BUILDERS_SPLICE:gsub("\n", nl)),
    "message builders")
  return source
end

-- Four ways, before the spliced codec is allowed to stand in for the pre-fix one.
-- Each of these has caught a self-test that was quietly proving nothing.
local function verifySplice(original, sabotaged)
  local problems = {}

  -- 1. it is a different file
  if sabotaged == original then problems[#problems + 1] = "the splice changed nothing" end

  local tmp = writeTmp(sabotaged)

  -- 2. it reads back from disk exactly as written. A temp file that kept stale
  --    contents would make the whole self-test vacuous.
  local readBack = readFile(tmp)
  if readBack ~= sabotaged then
    problems[#problems + 1] = string.format("does not read back (%d written, %d read)",
      #sabotaged, #readBack)
  end

  -- 3. it loads, still writes 56 bytes for a whole block, and
  -- 4. it carries the pre-fix signature: a short block decodes to a TABLE, and a
  --    table missing esc_sn does not return a message.
  package.loaded[CODEC_KEY] = nil
  local ok, spliced = pcall(function() return assert(realLoadfile(tmp))() end)
  if not ok then
    problems[#problems + 1] = "does not load: " .. tostring(spliced):gsub(".*%.lua:%d+: ", "")
  else
    local whole = {}
    for i = 1, 56 do whole[i] = 0 end
    whole[1] = 115
    local data = spliced._decode(whole)
    if data == nil then
      problems[#problems + 1] = "refuses a short block, so this is not the pre-fix codec"
    end
    local short = {}
    for i = 1, 40 do short[i] = whole[i] end
    if spliced._decode(short) == nil then
      problems[#problems + 1] = "refuses a 40-byte block, so this is not the pre-fix codec"
    end
    local partial = data
    if type(partial) == "table" then
      partial.esc_sn = nil
      local built = pcall(spliced.buildWriteMessage, partial, function() end, function() end)
      if built and select(2, pcall(spliced.buildWriteMessage, partial, function() end, function() end)) ~= nil then
        problems[#problems + 1] = "still refuses an incomplete table, so this is not the pre-fix codec"
      end
    end
  end

  os.remove(tmp)
  package.loaded[CODEC_KEY] = nil
  return #problems == 0, table.concat(problems, "; ")
end

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the length-guard checks must go red on the pre-fix codec")
  out(string.rep("=", 72))

  local original = readFile(CODEC_SRC)
  local sabotaged = preFix(original, newlineOf(original))

  local spliceOk, spliceDetail = verifySplice(original, sabotaged)
  out(string.format("  %s  splice: %s", spliceOk and "ok   " or "FAIL ",
    spliceDetail ~= "" and spliceDetail
      or "different file, reads back, loads, 56 bytes, and decodes a short block"))
  if not spliceOk then os.exit(1) end

  -- The page binds its codec into a module-level local, so it has to be reloaded
  -- too -- runChecks() does that on entry, and the redirect below is what makes
  -- the page's requireModule() land on the temp file instead of the checked-out
  -- one.
  local tmp = writeTmp(sabotaged)
  REPLACE_MATCH, REPLACE_FILE = "msp_esc_parameters_flyrotor%.lua$", tmp

  -- Loaded DIRECTLY from the temp file, not through loadCodec(): that helper
  -- reads the checked-out path with realLoadfile, which the redirect does not
  -- touch -- so loading through it here would have handed pass 2 the FIXED codec
  -- and made the guard checks pass for the wrong reason. That is not a
  -- hypothetical: it is what the first version of
  -- bin/esc_raw_bytes/verify_esc_raw_bytes.lua did, and nine of its seventeen
  -- gates stayed green because of it.
  --
  -- And then dropped from package.loaded again, because that direct load left the
  -- spliced module there and requireModule() memoizes -- the page would then find
  -- it and never call loadfile() at all, so the redirect would never be exercised
  -- and the page-level cases would be a rerun of pass 1.
  codec = loadCodec(tmp)
  package.loaded[CODEC_KEY] = nil

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = 0

  -- MUST_GO_RED is reset too, and the pass-1 list is kept to compare against.
  -- Left accumulating, it would list every gate twice and the verdict would read
  -- "all 8" for 4 distinct checks -- and a duplicate is exactly what would hide a
  -- case that only registers itself on one of the two trees.
  local pass1Gates = {}
  for i = 1, #MUST_GO_RED do pass1Gates[MUST_GO_RED[i]] = (pass1Gates[MUST_GO_RED[i]] or 0) + 1 end
  MUST_GO_RED = {}

  out("")
  out("pass 2: the same cases against the pre-fix codec")
  runChecks()

  -- Both passes have to have registered the same set of gates, or a case is
  -- running on one tree and not the other and the self-test is comparing two
  -- different files.
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
    out(string.format(
      "SELF-TEST FAILED -- %d of %d length-guard checks cannot detect the missing guard",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format(
    "SELF-TEST PASSED -- all %d length-guard checks go red without the guard",
    #MUST_GO_RED))
  out(string.format("pass 1 against the real tree: %d checks, %d failures",
    pass1Checks, pass1Failures))
end

-- The verdict below is pass 1's: without --self-test, pass 2 never ran, and with
-- it pass 2's red is the expected outcome rather than a failure here.
checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 72))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end