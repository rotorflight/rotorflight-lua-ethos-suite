-- Behaviour check for the YGE forward-programming codec (#2336).
--
-- Run it:
--     lua5.3 bin/esc_parameters_yge/verify_esc_parameters_yge.lua
--     lua5.3 bin/esc_parameters_yge/verify_esc_parameters_yge.lua --self-test
--
-- What the defect under test is:
--   lib/msp_esc_parameters_yge.lua draws its Motor Timing row from a ten-entry
--   list of UI positions (msp_esc_parameters_yge.lua:19, `TIMING`) and used to
--   hand that position to the wire unchanged in BOTH directions: decode()
--   stored the ESC's own word as the field value and encode() wrote the field
--   value back as the word. The ESC does not number its timing the way the page
--   does:
--
--     UI 0 "Auto Norm"  UI 1 "Auto Eff"  UI 2 "Auto Power"  UI 3 "Auto Extr"
--     UI 4 "0 deg"  UI 5 "6 deg"  UI 6 "12 deg"  UI 7 "18 deg"  UI 8 "24 deg"  UI 9 "30 deg"
--
--     wire 16..19 = the four automatic modes     wire 1..6 = the six fixed angles
--     wire 0      = a second spelling of automatic mode 1
--     wire 7..15 and >19 = values the ESC does not define
--
--   So every word the ESC actually sends lands on the wrong row, and every row
--   the pilot picks lands on the wrong word. Measured on the pre-fix codec: an
--   ESC reporting wire 17 ("Auto Efficient") displayed "Auto Norm" (index 0),
--   and a pilot selecting "0 deg" wrote wire 17 -- a fixed advance angle
--   commanded as an automatic mode. Neither error is visible from the page,
--   because the value shown is a position in the page's own list rather than
--   the ESC's word.
--
--   The translation is the one the EdgeTX suite already carries, at
--   rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/esc_parameters_yge.lua:39-68
--   (MOTOR_TIMING_TO_UI / MOTOR_TIMING_FROM_UI, plus motor_timing_from_ui()'s
--   round-trip rule). It was not copied blind: `timing_raw` rides along in the
--   EdgeTX parsed table, and it can ride along here too, because the whole
--   decoded table is what app/page_runtime.lua:726 hands to buildWriteMessage().
--
-- The other half of the issue does NOT reproduce here, and the file says so:
--   The issue also asks the flags byte to preserve vendor-reserved bits 4..7.
--   That is a real defect in the EdgeTX page, which keeps FOUR SEPARATE booleans
--   and packs them into a fresh byte (edgetx .../yge/page.lua:113-131,
--   unpackFlags/packFlags) -- there the read byte has to be threaded in
--   explicitly or the reserved bits are lost on a save that changed none of
--   them. This suite has no such step. The page keeps the ESC's byte itself and
--   edits single bits in place through app/field_layout.lua, whose bitSet()
--   (field_layout.lua:268-272) reads the current value, adds or subtracts one
--   bit's mask and writes the whole byte back, so every bit the page does not
--   touch keeps the value the read gave it.
--
--   The flags cases below pin that through the real page and the real
--   field_layout, so the answer is a fact the suite carries rather than a claim
--   in a comment. They are deliberately NOT gate checks: they pass on the
--   pre-fix codec too, and a gate check that cannot go red is worse than none.
--
-- What it drives, and why:
--   * The real app/pages/esc_forward_yge.lua, the real
--     app/pages/esc_forward_vendor.lua and the real
--     lib/msp_esc_parameters_yge.lua, entered through the page's own open().
--     Which codec the page hands the shared editor is half of what makes a
--     timing translation correct.
--   * The real app/field_layout.lua. Its bit accessors are what the flags cases
--     turn on, so a stub would make those cases vacuous -- and the codec cases
--     run through the same widgets, so one form stub serves both halves.
--   * The real app/page_runtime.lua, for the reason bin/esc_signature's is real:
--     what reaches the ESC on a save is only a fact if a save is actually
--     attempted, and with a stubbed runtime nothing ever presses Save.
--   * Only form, the bus and the chrome-only modules are stubbed. The bus
--     answers reads with the codec's OWN simulatorResponse -- the same fixture
--     tasks/msp/queue.lua replays on the Ethos simulator -- decoded by the
--     production decode(), and records the payload of every write.
--
-- Which checks go RED on the pre-fix codec:
--   21 of them, and they are the ones that can only pass WITH a translation:
--   the six fixed-angle decode cases, three of the four automatic-mode decode
--   cases, "every row is reachable", "the ESC's own word is kept", the nine
--   write-direction cases, and the moved-away-and-back case.
--   --self-test proves that rather than asserting it: it re-runs this whole file
--   against a copy of the codec with the pre-fix TIMING table, no translation
--   block and the pre-fix decode()/encode() put back, and requires every one of
--   those twenty-one to fail.
--
--   The other sixteen pass in both passes by construction, and each group says
--   why where it is written:
--     * wire 0 and wire 16 both mean the first automatic mode, which is row 0,
--       so the pre-fix codec happens to agree on those two words;
--     * the untouched-row, deliberate-reselect and round-trip cases pin that a
--       row the pilot did not touch is written back with the ESC's OWN word and
--       one he did is written with the canonical word. "Write back what you read"
--       is what the pre-fix codec already does, so no round-trip case can be a
--       gate -- they are here to catch a translation bolted on without the
--       round-trip rule, which is the mistake this change could most easily make;
--     * the flags cases and the load-gate cases pin behaviour that was already
--       correct and that this change deliberately leaves alone.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local CODEC_SRC = SUITE .. "/lib/msp_esc_parameters_yge.lua"

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
-- temp file to serve instead. A redirect that never fires would leave the
-- second pass a disguise of the first, so the hit count is reported and
-- required.
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

-- The read fixture this case staged, and whether it fails. Copied per case in
-- openPage(), so a case that pokes a byte cannot be seen by the next one.
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
-- This page gives every row its own line (esc_forward_vendor.lua:221 calls
-- buildSingle, which is one addLine per field), and no two of its choice rows
-- share one, which is what makes the label a usable key.
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
    -- Covers the bit rows too: field_layout sends a spec with `choices` down
    -- the choice path whatever `bit` says (field_layout.lua:430-432).
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
-- app/field_layout.lua is the REAL module here, because its bit accessors are
-- what the flags cases turn on. But it keeps no reference to the runtime it
-- builds fields for, and something has to hand the harness that runtime or
-- there is no Save to press. So buildSingle() is WRAPPED rather than replaced:
-- it records the runtime and then calls through, so the bitGet/bitSet/setBit
-- arithmetic every case below depends on is the production one.
--
-- (bin/esc_signature stubs field_layout instead and gets obs.runtime out of the
-- stub. That would make these flags cases vacuous, which is why it is not done
-- here.)
local fieldLayout = requireModule("app/field_layout.lua")
do
  local buildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, label, spec, parent)
    if not obs.runtime then obs.runtime = runtime end
    return buildSingle(runtime, label, spec, parent)
  end
end

-- ---------------------------------------------------------------------------
-- The codec, and the page that holds it
-- ---------------------------------------------------------------------------

-- realLoadfile, deliberately, not the redirect above: the redirect prepends the
-- suite prefix to anything ending in .lua, which is right for requireModule()'s
-- bare "lib/..." paths and wrong for this absolute-ish one.
local function loadCodec(file)
  package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil
  return assert(realLoadfile(file))()
end

local codec = loadCodec(CODEC_SRC)

-- The page is reloaded per runChecks(), and it has to be: esc_forward_yge.lua
-- binds the codec into a module-level `local msp` at :5, so reloading only the
-- codec would leave the page still holding the first one and pass 2 would be a
-- rerun of pass 1 wearing a different label. The page carries no self-cache
-- guard, so a plain reload really does re-run its body.
local function loadPage()
  return assert(realLoadfile(PREFIX .. "app/pages/esc_forward_yge.lua"))()
end

-- ---------------------------------------------------------------------------
-- Byte offsets of the fields under test
-- ---------------------------------------------------------------------------

-- A verbatim transcription of the shipped WIRE_FIELDS, because the shipped
-- codec keeps that table local to decode()/encode() and does not export it. Two
-- things keep this honest rather than a second source of truth:
--   * the fixture-length check below asserts the table predicts the shipped
--     simulatorResponse's length, so a field added, removed or retyped upstream
--     fails loudly instead of quietly making every case test the wrong byte;
--   * the byte-poke helper below re-reads the staged value out of the reply
--     that actually reached decode(), so a case cannot assert against a byte it
--     failed to set.
local function wireLayout()
  local LAYOUT = {
    { "esc_signature", "u8" }, { "esc_command", "u8" }, { "esc_model", "u8" },
    { "esc_version", "u8" }, { "governor", "u16" }, { "lv_bec_voltage", "u16" },
    { "timing", "u16" }, { "acceleration", "u16" }, { "gov_p", "u16" },
    { "gov_i", "u16" }, { "throttle_response", "u16" }, { "auto_restart_time", "u16" },
    { "cell_cutoff", "u16" }, { "active_freewheel", "u16" }, { "esc_type", "u16" },
    { "firmware_version", "u32" }, { "serial_number", "u32" }, { "unknown_1", "u16" },
    { "stick_zero_us", "u16" }, { "stick_range_us", "u16" }, { "unknown_2", "u16" },
    { "motor_pole_pairs", "u16" }, { "pinion_teeth", "u16" }, { "main_teeth", "u16" },
    { "min_start_power", "u16" }, { "max_start_power", "u16" }, { "unknown_3", "u16" },
    { "flags", "u8" }, { "unknown_4", "u8" }, { "current_limit", "u16" },
  }
  local WIDTH = { u8 = 1, u16 = 2, u32 = 4 }
  local offsets, cursor = {}, 1
  for i = 1, #LAYOUT do
    offsets[LAYOUT[i][1]] = { offset = cursor, wireType = LAYOUT[i][2], width = WIDTH[LAYOUT[i][2]] }
    cursor = cursor + WIDTH[LAYOUT[i][2]]
  end
  return offsets, cursor - 1
end

local OFFSETS, LAYOUT_BYTES = wireLayout()

local function readU16(buf, at)
  return (buf[at] or 0) + (buf[at + 1] or 0) * 256
end

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

local TIMING_LABELS = {
  [0] = "Auto Norm", [1] = "Auto Eff", [2] = "Auto Power", [3] = "Auto Extr",
  [4] = "0 deg", [5] = "6 deg", [6] = "12 deg", [7] = "18 deg", [8] = "24 deg",
  [9] = "30 deg",
}

-- The ESC's own numbering, transcribed from the EdgeTX codec's header comment
-- (rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/esc_parameters_yge.lua:39-44).
local WIRE_AUTO = { [16] = 0, [17] = 1, [18] = 2, [19] = 3 }
local WIRE_ANGLE = { [1] = 4, [2] = 5, [3] = 6, [4] = 7, [5] = 8, [6] = 9 }

-- What the ESC has to receive for each row the pilot can pick. Row 0 is absent
-- on purpose: it is the one row whose canonical word is 0, and a pilot can only
-- reach it deliberately from some other word -- picking the row the ESC already
-- stands on is not an edit, so it is a different case below.
local EXPECTED_WIRE = {
  [1] = 17, [2] = 18, [3] = 19,
  [4] = 1, [5] = 2, [6] = 3, [7] = 4, [8] = 5, [9] = 6,
}

-- Which i18n key ends which row. The page's labels are unresolved @i18n(...)@
-- tags at this point -- they are substituted at build time by
-- .vscode/scripts/resolve_i18n_tags.py, not at Lua runtime -- so the key IS
-- the label here, and it is a stable one to match on.
local ROW_TIMING = "mfg.yge.timing"
local ROW_DIRECTION = "mfg.yge.direction"
local ROW_F3C = "mfg.yge.f3c_auto"
local ROW_GOV_P = "mfg.yge.gov_p"

local ygePage = loadPage()

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

local function copyOf(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end

-- One open of the real page, answered with `fixture`. Returns the runtime the
-- page built -- reached through field_layout.buildSingle(), which receives it
-- as its first argument (esc_forward_vendor.lua:221) -- and the opts.
--
-- One wakeup tick is enough, and the reason matters: esc_forward_vendor passes
-- the finished read in as `initialData`, so PageRuntime:loadInitial()
-- (page_runtime.lua:1262-1282) takes its short-circuit branch and sets
-- self.loaded = true without issuing a second read. The editor is built during
-- that same tick, by the page's own handler at esc_forward_vendor.lua:257.
local function openPage(fixture)
  resetObs()
  reply = fixture and copyOf(fixture) or nil
  replyFails = false

  local opts = freshOpts()
  ygePage.open(opts)
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
-- dirty state too. Every "untouched field" case below therefore edits an
-- unrelated row, which is both reachable and the harder test: the untouched
-- fields have to ride along on their own.
local UNRELATED_ROW = ROW_GOV_P
-- The wire field that row edits, for the byte-level check further down.
local UNRELATED_ROW_FIELD = "gov_p"

local function editUnrelatedField()
  local field = rowField(UNRELATED_ROW)
  if not field then return false end
  local current = field.get()
  local next = current + 1
  if next > field.max then next = field.min end
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

local FIXTURE = codec.buildReadMessage(function() end, function() end).simulatorResponse

local function staged(opts, name, value)
  local field = OFFSETS[name]
  local buf = copyOf(opts and opts or FIXTURE)
  if field.wireType == "u16" then
    buf[field.offset] = value % 256
    buf[field.offset + 1] = math.floor(value / 256) % 256
    return buf, readU16(buf, field.offset) == value
  end
  buf[field.offset] = value
  return buf, buf[field.offset] == value
end

local function runChecks()
  ygePage = loadPage()

  -- -------------------------------------------------------------------------
  -- The layout this file assumes is the layout the shipped codec uses
  -- -------------------------------------------------------------------------
  out("")
  out("layout")
  check("the shipped fixture is the length this file's layout predicts",
    #FIXTURE == LAYOUT_BYTES,
    string.format("fixture is %d bytes, layout predicts %d -- WIRE_FIELDS changed, update the table above",
      #FIXTURE, LAYOUT_BYTES))

  -- -------------------------------------------------------------------------
  -- The read direction, straight off the wire
  -- -------------------------------------------------------------------------
  out("")
  out("read: an ESC's timing word must land on the row that word means")

  local function decodeCase(wireWord, uiIndex, gate)
    local f, stagedOk = staged(nil, "timing", wireWord)
    local label = string.format("wire %d decodes to row %d (%s), not row %d",
      wireWord, uiIndex, TIMING_LABELS[uiIndex], wireWord)
    local emit = gate and gateCheck or check
    if not stagedOk then
      emit(label, false, "the fixture byte was not the value this case staged")
      return
    end
    local runtime = openPage(f)
    local data = runtime and runtime.data
    local ok = data ~= nil and data.timing == uiIndex
    emit(label, ok,
      data and string.format("row shows %s", tostring(data.timing)) or "no runtime was built")
  end

  -- The four automatic modes. Only the fixed-angle half is a gate: the
  -- automatic half happens to coincide with the UI index for the first word in
  -- each pair, so one of the four would pass on the pre-fix codec and putting
  -- all four in MUST_GO_RED would be a claim the sabotage cannot back.
  decodeCase(16, 0, false)
  decodeCase(17, 1, true)
  decodeCase(18, 2, true)
  decodeCase(19, 3, true)

  for wireWord, uiIndex in pairs(WIRE_ANGLE) do
    decodeCase(wireWord, uiIndex, true)
  end

  -- 0 is a second spelling of the first automatic mode, not a fixed 0-degree --
  -- which is also why it is a non-gate: the pre-fix codec happens to agree.
  decodeCase(0, 0, false)

  -- An undefined word must not index outside the choice list, or Ethos is handed
  -- a position with no row behind it.
  do
    local f = staged(nil, "timing", 7)
    local runtime = openPage(f)
    local idx = runtime and runtime.data and runtime.data.timing
    check("wire 7 (undefined by the ESC) decodes to a row that exists",
      idx ~= nil and idx >= 0 and idx <= 9,
      string.format("got %s, outside 0..9", tostring(idx)))
  end

  -- Every row the page offers must be reachable from a word the ESC defines,
  -- and no row may be spelled by a word the ESC does not define.
  do
    local WORD_FOR_ROW = {}
    for w, idx in pairs(WIRE_AUTO) do WORD_FOR_ROW[idx] = w end
    for w, idx in pairs(WIRE_ANGLE) do WORD_FOR_ROW[idx] = w end
    WORD_FOR_ROW[0] = 16  -- the first automatic mode has two spellings; take 16

    local reachable = {}
    for row = 0, 9 do reachable[row] = false end
    for row = 0, 9 do
      local f = staged(nil, "timing", WORD_FOR_ROW[row])
      local runtime = openPage(f)
      if runtime and runtime.data then reachable[runtime.data.timing] = true end
    end
    local missing = {}
    for row = 0, 9 do
      if not reachable[row] then missing[#missing + 1] = row end
    end
    gateCheck("every one of the ten Motor Timing rows is reachable from a word the ESC defines",
      #missing == 0,
      #missing > 0 and string.format("unreachable rows: %s", table.concat(missing, ", ")) or nil)
  end

  -- The ESC's own word has to survive into the write, or an untouched row cannot
  -- be written back unchanged.
  do
    local f = staged(nil, "timing", 19)
    local runtime = openPage(f)
    local data = runtime and runtime.data
    gateCheck("the ESC's own timing word is kept alongside the row it decoded to",
      data ~= nil and data.timing_raw == 19,
      data and string.format("timing_raw is %s, expected 19", tostring(data.timing_raw)) or "no runtime was built")
  end

  -- -------------------------------------------------------------------------
  -- The write direction, through the pilot's own row
  -- -------------------------------------------------------------------------
  out("")
  out("write: the row the pilot picks must reach the ESC as the word that row means")

  for uiIndex = 1, 9 do
    local want = EXPECTED_WIRE[uiIndex]
    local label = string.format("row %d (%s) reaches the wire as %d", uiIndex, TIMING_LABELS[uiIndex], want)
    -- Start from an automatic word, so "the pilot picked something else" is
    -- true by construction and an unchanged save cannot pass by accident.
    local f = staged(nil, "timing", 16)
    local runtime, opts = openPage(f)
    local field = rowField(ROW_TIMING)
    if not runtime or not field then
      gateCheck(label, false, runtime and "the Motor Timing row was never built" or "no runtime was built")
    else
      edit(field, uiIndex)
      local payload = pressSave(opts)
      local got = payload and readU16(payload, OFFSETS.timing.offset)
      gateCheck(label, got == want,
        payload and string.format("wire got %s, expected %d", tostring(got), want) or "no write went out")
    end
  end

  -- The round-trip rule, on the codec's own surface rather than through the
  -- page. It cannot be reached through the page and that is not an accident: an
  -- undefined word decodes to the first automatic mode, so a pilot editing that
  -- row to 0 and back leaves the table identical to the one the read produced,
  -- refreshDirty() finds nothing changed, canSave() stays false, and no write
  -- goes out at all. Before the fix the same edit was reachable and wrote the
  -- undefined word; after it, the UI simply cannot express that edit.
  --
  -- So the rule is pinned where it lives. Two halves, and they are not the same
  -- claim: a row still standing on the ESC's own word writes THAT word back, and
  -- a row that no longer stands on it gets the canonical word for the row rather
  -- than the word it happened to be read from.
  local function encodeDirect(values)
    local message = codec.buildWriteMessage(values, function() end, function() end)
    if not message or type(message.payload) ~= "table" then return nil end
    return readU16(message.payload, OFFSETS.timing.offset)
  end

  do
    -- 19 is "Auto Extr" and row 3 is what it decodes to, so this is a row the
    -- pilot did not touch.
    local got = encodeDirect({ timing = 3, timing_raw = 19 })
    gateCheck("a row still standing on the ESC's own word is written back as that word",
      got == 19,
      string.format("wire got %s, expected 19", tostring(got)))
  end

  do
    -- Same row, but the word it was read from is one the ESC does not define,
    -- and the pilot has moved off it and back -- so it must be canonicalised.
    -- Not a gate: writing 0 for row 0 is what the pre-fix codec did too, since
    -- it wrote the row straight through. It is here to catch the opposite
    -- mistake, a round-trip rule that keeps the raw word unconditionally.
    local got = encodeDirect({ timing = 0, timing_raw = 11 })
    check("a row the pilot moved off and back is written as the row's canonical word, not the word it was read from",
      got == 0,
      string.format("wire got %s, expected 0", tostring(got)))
  end

  -- An untouched row writes the ESC's own word back, so a save that changed
  -- something else changes nothing in this field.
  --
  -- Not gates, and deliberately so: "write back the word you were given" is
  -- exactly what the pre-fix codec does, so these pass in both passes. They are
  -- here as the healthy-path half of the fix -- the case that fails if the
  -- translation is bolted on without the round-trip rule and starts canonicalising
  -- an untouched row's word -- and a gate claim they cannot back is not made.
  for _, word in ipairs({ 19, 0, 3 }) do
    local f = staged(nil, "timing", word)
    local runtime, opts = openPage(f)
    local label = string.format("an untouched row standing on wire %d writes %d back", word, word)
    if not runtime or not editUnrelatedField() then
      check(label, false, runtime and "the unrelated row was never built" or "no runtime was built")
    else
      local payload = pressSave(opts)
      local got = payload and readU16(payload, OFFSETS.timing.offset)
      check(label, got == word,
        payload and string.format("wire got %s, expected %d", tostring(got), word) or "no write went out")
    end
  end

  -- Moved off the ESC's word and back: the write has to follow the row, not the
  -- word the row started on.
  do
    local f = staged(nil, "timing", 18)
    local runtime, opts = openPage(f)
    local field = rowField(ROW_TIMING)
    if not runtime or not field then
      gateCheck("a row moved off the ESC's word and back writes the row's own word",
        false, "the Motor Timing row was never built")
    else
      edit(field, 2)
      edit(field, 9)
      local payload = pressSave(opts)
      local got = payload and readU16(payload, OFFSETS.timing.offset)
      gateCheck("a row moved off the ESC's word and back writes the row's own word",
        got == 6,
        payload and string.format("wire got %s, expected 6 (30 deg)", tostring(got)) or "no write went out")
    end
  end

  -- -------------------------------------------------------------------------
  -- The flags byte -- the issue's other half, which does NOT reproduce
  -- -------------------------------------------------------------------------
  out("")
  out("flags: vendor-reserved bits must survive a save (not reproduced by this defect)")

  -- The scenario the EdgeTX page lost them in: a save that changed some other
  -- field. Here the untouched byte has to ride along on its own.
  do
    local f = staged(nil, "flags", 0xF0)
    local runtime, opts = openPage(f)
    if not runtime or not editUnrelatedField() then
      check("a save that changed another field keeps vendor bits 4..7 (0xF0)",
        false, "the unrelated row was never built")
    else
      local payload = pressSave(opts)
      local got = payload and payload[OFFSETS.flags.offset]
      check("a save that changed another field keeps vendor bits 4..7 (0xF0)",
        got == 0xF0,
        payload and string.format("wire got 0x%02X", got or 0) or "no write went out")
    end
  end

  -- ...and a save that changed the flags byte itself.
  --
  -- Each case starts from a byte where the bit being toggled IS set, so the
  -- toggle is a real change: a pilot "edit" that sets a bit the ESC already has
  -- leaves the page clean, canSave() stays false, and no write goes out at all --
  -- which is the harness's problem to notice, not a result.
  for _, case in ipairs({
    { row = ROW_DIRECTION, start = 0xF1, to = 0, want = 0xF0, bit = "bit 0" },
    { row = ROW_F3C, start = 0xF2, to = 0, want = 0xF0, bit = "bit 1" },
  }) do
    local f = staged(nil, "flags", case.start)
    local runtime, opts = openPage(f)
    local field = rowField(case.row)
    local label = string.format("a pilot toggle of %s keeps vendor bits 4..7", case.bit)
    if not runtime or not field then
      check(label, false, "the row was never built")
    else
      edit(field, case.to)
      local payload = pressSave(opts)
      local got = payload and payload[OFFSETS.flags.offset]
      check(label, got == case.want,
        payload and string.format("wire got 0x%02X, expected 0x%02X", got or 0, case.want) or "no write went out")
    end
  end

  -- Bits 2 and 3 have no row on this page at all -- the closest thing here to a
  -- bit the suite does not manage, and so the case that says most about the
  -- reserved-bit claim.
  do
    local f = staged(nil, "flags", 0xFC)
    local runtime, opts = openPage(f)
    if not runtime or not rowField(ROW_DIRECTION) or not editUnrelatedField() then
      check("bits 2 and 3, which this page has no row for, survive a save",
        false, "a row was never built")
    else
      local payload = pressSave(opts)
      local got = payload and payload[OFFSETS.flags.offset]
      check("bits 2 and 3, which this page has no row for, survive a save",
        got == 0xFC,
        payload and string.format("wire got 0x%02X, expected 0xFC", got or 0) or "no write went out")
    end
  end

  -- The row must read the bit the ESC set, not a position in the page's list.
  do
    local f = staged(nil, "flags", 0x02)
    local runtime = openPage(f)
    local field = rowField(ROW_F3C)
    check("the F3C Auto row shows the bit the ESC set",
      field ~= nil and field.get() == 1,
      field and string.format("row shows %s", tostring(field.get())) or "the row was never built")
  end

  -- -------------------------------------------------------------------------
  -- The payload itself, and the load gate
  -- -------------------------------------------------------------------------
  out("")
  out("payload and load gate")

  -- The strongest single statement about both halves: with a timing word that
  -- is not the canonical 0 and a flags byte with reserved bits set, a save that
  -- touched exactly one unrelated row must leave every other byte identical to
  -- the reply the ESC sent.
  --
  -- Not a gate: a decode/encode round trip is the identity on BOTH codecs --
  -- that is the property being protected here, not the missing translation --
  -- so requiring this one to go red would be requiring the harness to fail on
  -- correct behaviour. It is also the only case that looks at every field at
  -- once rather than at the two under test, which is what it is for.
  do
    local f, stagedTiming = staged(nil, "timing", 17)
    f = staged(f, "flags", 0xF5)
    if not stagedTiming then
      check("a save that changed one row leaves every other byte as the ESC sent it",
        false, "the fixture byte was not the value this case staged")
    else
      local runtime, opts = openPage(f)
      if not runtime or not editUnrelatedField() then
        check("a save that changed one row leaves every other byte as the ESC sent it",
          false, "the unrelated row was never built")
      else
        local payload = pressSave(opts)
        local diffs = {}
        if not payload then
          diffs[#diffs + 1] = "no write went out"
        else
          if #payload ~= #f then
            diffs[#diffs + 1] = string.format("payload is %d bytes, the reply was %d", #payload, #f)
          else
            for i = 1, #f do
              if payload[i] ~= f[i] then
                diffs[#diffs + 1] = string.format("byte %d: reply 0x%02X, write 0x%02X", i, f[i], payload[i])
              end
            end
          end
        end
        -- Exactly one diff is expected and it is the row the case edited: the
        -- point is that nothing ELSE moved.
        local unrelatedAt = OFFSETS[UNRELATED_ROW_FIELD]
        local diffAt = {}
        for _, d in ipairs(diffs) do diffAt[#diffAt + 1] = tonumber(d:match("byte (%d+)")) end
        local onlyEditedRow = #diffs == 1 and diffAt[1] ~= nil
          and unrelatedAt ~= nil
          and diffAt[1] >= unrelatedAt.offset and diffAt[1] < unrelatedAt.offset + unrelatedAt.width
        check("a save that changed one row leaves every other byte as the ESC sent it",
          onlyEditedRow,
          #diffs == 0 and "nothing changed at all, so the case proved nothing"
            or table.concat(diffs, "; "))
      end
    end
  end

  -- No completed read, no write: the whole parameter block is written at once,
  -- so a save built from a page that never read would pack every field the page
  -- does not carry as zero.
  do
    resetObs()
    replyFails = true
    local opts = freshOpts()
    ygePage.open(opts)
    opts.__installed.setWakeupHandler()
    replyFails = false

    local wrote = false
    for i = 1, #obs.writes do
      if obs.writes[i].command == codec.WRITE_COMMAND then wrote = true end
    end
    check("a read that fails leaves no runtime and puts no parameter block on the bus",
      (obs.runtime == nil) and not wrote,
      string.format("runtime built: %s, %d write(s)", tostring(obs.runtime ~= nil), #obs.writes))
  end

  -- And the other half of that: after a completed read, Save does reach the ESC.
  do
    local f = copyOf(FIXTURE)
    local runtime, opts = openPage(f)
    if not runtime or not editUnrelatedField() then
      check("Save reaches the ESC after a completed read and a pilot edit",
        false, "the page did not load, or the unrelated row was never built")
    else
      local payload = pressSave(opts)
      check("Save reaches the ESC after a completed read and a pilot edit",
        payload ~= nil and #payload == LAYOUT_BYTES,
        payload and string.format("payload is %d bytes, expected %d", #payload, LAYOUT_BYTES)
          or "no write went out")
    end
  end
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("YGE forward-programming codec: timing words and the flags byte (#2336)")
out(string.rep("=", 72))

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

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the timing checks must go red without the translation")
  out(string.rep("=", 72))

  local source = readFile(CODEC_SRC)
  -- core.autocrlf=true and no .gitattributes, so the checkout is CRLF. Detect
  -- rather than assume; a mismatch would make the plain finds below miss.
  local nl = source:find("\r\n", 1, true) and "\r\n" or "\n"

  -- Four substitutions, and each replaces one piece of the fixed codec with the
  -- piece that was there before. The translation block is removed along with
  -- them, so this really is the pre-fix codec rather than the fixed one plus
  -- dead tables. Every anchor is a plain find on a string unique in the file.
  local sabotaged = source

  -- (1) the TIMING table
  local tOpen = assert(sabotaged:find('local TIMING = {{"Auto Norm", 0}', 1, true), "sabotage: TIMING not found")
  local tClose = assert(sabotaged:find('{"30 deg", 9}}', tOpen, true), "sabotage: the end of TIMING not found")
  tClose = tClose + #'{"30 deg", 9}}'
  sabotaged = sabotaged:sub(1, tOpen - 1)
    .. 'local TIMING = {{"Auto Norm", 0}, {"Auto Eff", 1}, {"Auto Power", 2}, {"Auto Extr", 3},\r\n'
    .. '  {"0 deg", 4}, {"6 deg", 5}, {"12 deg", 6}, {"18 deg", 7}, {"24 deg", 8}, {"30 deg", 9}}'
    .. sabotaged:sub(tClose)

  -- (2) the two mapping tables. Bounded by the line AFTER them rather than by
  -- the end of motorTimingFromUi(): the two live either side of FREEWHEEL and
  -- ESC_TYPE, and an earlier version of this self-test cut from the first table
  -- to the end of the last function -- which took FREEWHEEL with it, so the
  -- Active Freewheel row lost its choice list and field_layout.lua:439 asserted
  -- on the missing min/max. A sabotage that breaks the module differently from
  -- the defect under test proves nothing about the defect.
  local t2Open = assert(sabotaged:find("local MOTOR_TIMING_TO_UI", 1, true), "sabotage: MOTOR_TIMING_TO_UI not found")
  local t2End = assert(sabotaged:find("local FREEWHEEL", t2Open, true), "sabotage: FREEWHEEL not found after the mapping tables")
  sabotaged = sabotaged:sub(1, t2Open - 1) .. sabotaged:sub(t2End)

  -- (3) both translation functions and the comment block above them. They are
  -- adjacent, so one slice takes all of it -- the comment goes too, or the
  -- sabotaged file is left claiming it translates something it no longer does.
  local cStart = assert(sabotaged:find("-- Both halves of the same mapping", 1, true),
    "sabotage: the translation block's comment not found")
  local fTail = "  return MOTOR_TIMING_FROM_UI[value] or 0" .. nl .. "end"
  local fEnd = assert(sabotaged:find(fTail, cStart, true), "sabotage: the end of motorTimingFromUi not found")
  sabotaged = sabotaged:sub(1, cStart - 1) .. sabotaged:sub(fEnd + #fTail + 1)

  -- (4) decode()'s two lines
  local dKeep = "  data.timing_raw = data.timing" .. nl
    .. "  data.timing = motorTimingToUi(data.timing)" .. nl
    .. "  return data"
  local dAt = assert(sabotaged:find(dKeep, 1, true), "sabotage: decode()'s timing split not found")
  sabotaged = sabotaged:sub(1, dAt - 1) .. "  return data" .. sabotaged:sub(dAt + #dKeep)

  -- (5) encode()'s branch
  local eBranch = "    local value = data and data[field[1]] or 0" .. nl
    .. '    if field[1] == "timing" then' .. nl
    .. "      value = motorTimingFromUi(value, data and data.timing_raw)" .. nl
    .. "    end" .. nl
  local eAt = assert(sabotaged:find(eBranch, 1, true), "sabotage: encode()'s timing branch not found")
  sabotaged = sabotaged:sub(1, eAt - 1)
    .. "    local value = data and data[field[1]] or 0" .. nl
    .. sabotaged:sub(eAt + #eBranch)

  local tmp = os.tmpname()
  local fh = assert(io.open(tmp, "wb"))
  fh:write(sabotaged)
  fh:close()

  -- Read it straight back. A temp file that kept stale contents would make the
  -- whole self-test vacuous.
  local readBack = readFile(tmp)
  if readBack ~= sabotaged then
    out(string.format("  FAIL  the sabotage file does not read back (%d written, %d read)",
      #sabotaged, #readBack))
    os.exit(1)
  end
  out(string.format("  sabotage file: %d bytes, verified by read-back (newline %s)",
    #readBack, nl == "\r\n" and "CRLF" or "LF"))

  -- The page binds the codec into a module-level local at its line 5, so the
  -- page has to be reloaded too -- runChecks() does that on entry, and the
  -- redirect below is what makes the page's requireModule() land on the temp
  -- file instead of the checked-out one.
  REPLACE_MATCH = "msp_esc_parameters_yge%.lua$"
  REPLACE_FILE = tmp

  -- Loaded directly first, so the codec-level cases (encodeDirect) work on the
  -- sabotaged module whatever requireModule() does.
  local savedCodec = codec
  codec = loadCodec(tmp)

  -- And then dropped again, because loadCodec left the sabotaged module in
  -- package.loaded and requireModule() memoizes: the page would then find it
  -- there and never call loadfile() at all. That is not a cosmetic difference --
  -- it is the difference between the redirect being exercised and the whole
  -- self-test being a rerun of pass 1, which is exactly what the hit count below
  -- exists to rule out.
  package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = 0

  -- MUST_GO_RED is reset too, and the pass-1 list is kept to compare against.
  -- Left accumulating, it would list every gate twice and the verdict would
  -- read "all 44" for 22 distinct checks -- and a duplicate is exactly what
  -- would hide a case that only registers itself on one of the two trees.
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

  codec = savedCodec
  package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil
  os.remove(tmp)
  REPLACE_MATCH, REPLACE_FILE = nil, nil

  out("")
  out(string.format("  (sabotaged codec served %d time(s))", replaceHits))
  if replaceHits == 0 then
    out("  FAIL  the sabotaged codec never ran -- pass 2 proved nothing")
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
    out(string.format("SELF-TEST FAILED -- %d of %d timing checks cannot detect the missing translation",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d timing checks go red without the translation",
    #MUST_GO_RED))
  out(string.format("pass 1 against the real tree: %d checks, %d failures",
    pass1Checks, pass1Failures))
end

-- The verdict below is pass 1's: without --self-test, pass 2 never ran, and
-- with it pass 2's red is the expected outcome rather than a failure here.
checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 72))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
