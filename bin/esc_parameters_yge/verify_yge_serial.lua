-- Behaviour check for the YGE serial number in the summary line (#2455).
--
-- Run it:
--     lua5.4 bin/esc_parameters_yge/verify_yge_serial.lua
--     lua5.4 bin/esc_parameters_yge/verify_yge_serial.lua --self-test
--
-- What the defect under test is:
--   lib/msp_esc_parameters_yge.lua decodes the ESC's own serial number --
--   WIRE_FIELDS carries {"serial_number", "u32"} and the block is 58 bytes, so the
--   word is on the wire and in the table the page holds -- and summaryFor()
--   printed two parts: the model label and the firmware version. A pilot with four
--   YGE ESCs had no way to tell them apart on the screen. The EdgeTX suite shows
--   it as the `S/N:` part of its subheader
--   (rotorflight-lua-edgetx-suite src/rfsuite/ui/controls.lua:335-356).
--
-- Two decisions in here are settled by the sibling suite rather than argued, and the
-- harness pins the behaviour instead of restating the reasoning:
--
--   * A serial of 0 is left out rather than printed. "S/N 0" reads like data and
--     identifies nothing. .../escmfg/yge/init.lua's getEscVersion() does the same:
--     `return sn ~= 0 and tostring(sn) or ""`.
--   * Decimal, not hexadecimal. Same line: `tostring(sn)`.
--
-- The offset looked wrong on first reading and is not: the sibling reads the serial
-- from {29, 30, 31, 32} because that page carries `local mspHeaderBytes = 2`
-- (yge/init.lua:8) and its getUInt adds it to every index. 29 + 2 = 31, which is
-- where serial_number starts in this suite's WIRE_FIELDS -- verified here by the
-- layout check against the shipped 58-byte fixture.
--
-- What it drives, and why:
--   * The real app/pages/esc_forward_yge.lua through the real
--     app/pages/esc_forward_vendor.lua, so the line under test is the one the
--     pilot sees: esc_forward_vendor.lua renders mspModule.summaryFor(data) with
--     form.addLine, and asserting on the codec alone would leave open the
--     possibility that the page renders something else.
--   * The real app/field_layout.lua and app/page_runtime.lua, because the wire
--     check presses the pilot's own Save button -- page_runtime is what decides
--     which table reaches buildWriteMessage, and that is the question the last
--     gate asks.
--   * The real lib/msp_esc_parameters_yge.lua.
--
-- Which checks go RED without the fix:
--   3 of 12, and the self-test is what established that number rather than a guess.
--
--   The first version of this file registered six and reported "4 of 6 gate checks
--   cannot detect the missing serial number". All four were the same mistake: they
--   assert something the PRE-FIX codec satisfies too, because a codec that shows no
--   serial at all also shows no "S/N 0", raises nothing on a nil, and already wrote
--   the ESC's own serial bytes back unchanged. They are invariants, not gates, and
--   they are registered with check() so the verdict below says so out loud.
--
--   The gate that earns the feature its keep is the third one: two ESCs with
--   different serial numbers must not render the same line. That is the pilot's
--   actual complaint in #2455, it is red before the fix because both lines are
--   identical, and no amount of "the summary contains a number" phrasing can
--   substitute for it.
--
--   It restores the pre-fix summaryFor rather than deleting it, because deleting the
--   function would leave a codec with no summaryFor at all -- a third state, not the
--   pre-fix one, and the page renders nothing on it, which would make the page-level
--   gates pass for the wrong reason. The sibling harness lost a gate the same way
--   once.
--
--   It serves the sabotaged module through _G.loadfile and counts the hits: the
--   sibling's first version loaded the page with realLoadfile, which BYPASSES the
--   redirect, so pass 2 tested the real page against a sabotaged codec and one gate
--   stayed green for the wrong reason. The counter at the end of the self-test is
--   what catches that here.
--
--   And it verifies its own work before trusting anything: the staged file must read
--   back byte for byte, must still LOAD, and its summaryFor must produce the exact
--   pre-fix string -- asserted on an id this suite does not know, so the expectation
--   cannot drift when the model table gains an entry. Two of those three steps earned
--   themselves on the first run: the cut consumed the `end` it was anchored on and
--   produced a file that did not load, and the staged codec was then shadowed by the
--   module's own self-cache guard, which made a working cut look broken.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"

local SELF_TEST = arg[1] == "--self-test"

-- The one module this change touches.
local CODEC_PATTERN = "msp_esc_parameters_yge%.lua$"
local CODEC_SOURCE = PREFIX .. "lib/msp_esc_parameters_yge.lua"

-- The names MUST_GO_RED, collected as they run so the self-test cannot drift away
-- from the checks as they are written.
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

-- Set by the self-test: pattern -> temp file to serve instead, and a count of how
-- often each fired. A redirect that never fires would leave the second pass a
-- disguise of the first, so the counts are reported and required.
local REPLACE, replaceHits = nil, {}

_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    if REPLACE then
      for pattern, file in pairs(REPLACE) do
        if path:match(pattern) then
          replaceHits[pattern] = (replaceHits[pattern] or 0) + 1
          return realLoadfile(file, ...)
        end
      end
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
  obs.reads = 0
  obs.writes = {}
  obs.runtime = nil
end

local reply = nil

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
  return { value = function() end, message = function() end, closeAllowed = function() end, close = function() end }
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
  addStaticText = function() end,
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
  addExpansionPanel = function() return { open = function() end } end,
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

-- The real field_layout, wrapped rather than replaced: the wire check goes through
-- the same accessors every field uses, so a stub would make that half vacuous. The
-- wrapper only records the runtime the page built, which nothing else holds a
-- reference to.
local fieldLayout = requireModule("app/field_layout.lua")
do
  local buildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, label, spec, parent)
    if not obs.runtime then obs.runtime = runtime end
    return buildSingle(runtime, label, spec, parent)
  end
end

-- ---------------------------------------------------------------------------
-- The wire layout, derived rather than hard-coded
-- ---------------------------------------------------------------------------

-- Same reasoning as the sibling harness: the layout is re-derived here and then
-- checked against the shipped fixture, so a field added or removed upstream fails
-- loudly instead of making every case assert against the wrong byte.
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
    offsets[LAYOUT[i][1]] = { offset = cursor, width = WIDTH[LAYOUT[i][2]] }
    cursor = cursor + WIDTH[LAYOUT[i][2]]
  end
  return offsets, cursor - 1
end

local OFFSETS, LAYOUT_BYTES = wireLayout()

local function pokeU16(buf, at, value)
  buf[at] = value % 256
  buf[at + 1] = math.floor(value / 256) % 256
end

local function pokeU32(buf, at, value)
  buf[at] = value % 256
  buf[at + 1] = math.floor(value / 256) % 256
  buf[at + 2] = math.floor(value / 65536) % 256
  buf[at + 3] = math.floor(value / 16777216) % 256
end

local function readU32(buf, at)
  return (buf[at] or 0) + (buf[at + 1] or 0) * 256
    + (buf[at + 2] or 0) * 65536 + (buf[at + 3] or 0) * 16777216
end

local function copyOf(t)
  local c = {}
  for i = 1, #t do c[i] = t[i] end
  return c
end

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

-- The serial the shipped fixture carries, and the firmware version it carries, both
-- read out of the fixture at run time rather than written here, so this file
-- cannot disagree with the codec about what the fixture says. The firmware one was
-- a hard-coded "1.31148" in the first version, taken from a probe that had been
-- GIVEN firmware_version = 131148 rather than one that read the fixture -- the
-- bytes are 131, 148, 1, 0 = 103555, so the line reads 1.03555. Two regression
-- pins caught it on the first run, which is what they are for.
local FIXTURE_SERIAL = nil
local FIXTURE_FIRMWARE = nil

-- The rendering of that firmware version, the way the codec formats it.
local function firmwareText()
  return string.format("%.5f", (FIXTURE_FIRMWARE or 0) / 100000)
end

local ygePage = nil

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

-- Drops the page-owned modules so the next open re-runs their bodies and picks up
-- whatever the loadfile redirect is currently serving. The codec is in the list
-- because esc_forward_yge.lua binds it into a module-level local at its line 5, so
-- a reused page module would keep the previous open's codec.
local function resetModules()
  package.loaded["rfsuite.app.pages.esc_forward_vendor"] = nil
  package.loaded["rfsuite.app.esc_error"] = nil
  package.loaded["rfsuite.app.close_key"] = nil
  package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = nil
  package.loaded["rfsuite.app.pages.esc_forward_yge"] = nil
  package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil
end

-- One open of the real YGE page, answered with `fixture` (or with the codec's own
-- fixture when none is given).
--
-- Loaded through _G.loadfile, NOT realLoadfile: realLoadfile bypasses the
-- redirect, so the self-test's sabotaged codec would never be served and pass 2
-- would quietly test the real page against a sabotaged codec.
local function openYge(fixture)
  resetObs()
  resetModules()
  ygePage = assert(_G.loadfile("app/pages/esc_forward_yge.lua"))()

  local codec = requireModule("lib/msp_esc_parameters_yge.lua")
  local f = copyOf(codec.buildReadMessage(function() end, function() end).simulatorResponse)
  if FIXTURE_SERIAL == nil then
    FIXTURE_SERIAL = readU32(f, OFFSETS.serial_number.offset)
    FIXTURE_FIRMWARE = readU32(f, OFFSETS.firmware_version.offset)
  end
  if fixture then
    for i = 1, #fixture do f[i] = fixture[i] end
  end
  reply = f

  local opts = freshOpts()
  ygePage.open(opts)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  opts.__runtime = obs.runtime
  return obs.runtime, opts, codec
end

-- The line the pilot reads. The page also adds a loading line before the read, so
-- the summary is picked out by the model label the codec puts in front of it
-- rather than by position.
local function summaryLine(modelName)
  for i = 1, #obs.lines do
    if obs.lines[i]:find(modelName, 1, true) then return obs.lines[i] end
  end
  return nil
end

local function rowField(key)
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].label:find(key, 1, true) then return obs.fieldOrder[i] end
  end
  return nil
end

-- Moves a row the serial cases do not care about, so Save is reachable the way it
-- is for a pilot: canSave() requires dirty, and refreshDirty() compares the whole
-- table, so a page nobody touched cannot be saved at all.
local ROW_GOV_P = "mfg.yge.gov_p"

local function editUnrelatedField()
  local field = rowField(ROW_GOV_P)
  if not field then return false end
  local next_ = field.get() + 1
  if next_ > field.max then next_ = field.min end
  if next_ == field.get() then return false end
  field.set(next_)
  return true
end

-- The pilot's Save button. Returns the MSP 218 payload that went onto the bus.
local function pressSave(opts)
  local runtime = opts.__runtime
  if not runtime or not runtime.headerHandle then return nil end
  local before = #obs.writes
  runtime:confirmSave(runtime.headerHandle.focusSave)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  for i = before + 1, #obs.writes do
    local w = obs.writes[i]
    if w.command == 218 then return w.payload end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------

local MODEL = 848        -- YGE 35 LVT BEC, in the codec's table
local MODEL_NAME = "YGE 35 LVT BEC"
local UNKNOWN_MODEL = 31337

-- A serial deliberately unlike the fixture's, so "the summary shows a serial" and
-- "the summary shows THIS ESC's serial" are two different assertions. Without it
-- the first gate would also pass on a hard-coded number.
local OTHER_SERIAL = 123456789

local function runChecks()
  resetObs()
  resetModules()
  local codec = requireModule("lib/msp_esc_parameters_yge.lua")
  local baseFixture = codec.buildReadMessage(function() end, function() end).simulatorResponse

  out("")
  out("layout")
  check("the named fields cover the first 58 bytes of the fixture",
    LAYOUT_BYTES == 58 and #baseFixture >= LAYOUT_BYTES,
    string.format("fixture is %d bytes, the named fields cover %d -- expected 58 named bytes",
      #baseFixture, LAYOUT_BYTES))
  check("the fixture's length is what its own parameter count asks for",
    #baseFixture == 2 + 2 * ((baseFixture[3] or 0) + (baseFixture[4] or 0) * 256),
    string.format("fixture is %d bytes, bytes 3..4 ask for %d",
      #baseFixture, 2 + 2 * ((baseFixture[3] or 0) + (baseFixture[4] or 0) * 256)))

  -- -------------------------------------------------------------------------
  -- The serial on the screen
  -- -------------------------------------------------------------------------
  out("")
  out("the pilot's summary line")

  do
    local runtime = openYge()
    local line = summaryLine(MODEL_NAME)
    gateCheck("the summary line the page renders carries the ESC's serial number",
      line ~= nil and line:find("S/N " .. FIXTURE_SERIAL, 1, true) ~= nil,
      line and string.format("line reads %q, fixture serial is %d", line, FIXTURE_SERIAL)
        or "the page rendered no line naming " .. MODEL_NAME)
  end

  do
    local f = copyOf(baseFixture)
    pokeU32(f, OFFSETS.serial_number.offset, OTHER_SERIAL)
    local runtime = openYge(f)
    local line = summaryLine(MODEL_NAME)
    gateCheck("the serial shown is the one this ESC reported, not a fixed number",
      line ~= nil and line:find("S/N " .. OTHER_SERIAL, 1, true) ~= nil
        and line:find("S/N " .. FIXTURE_SERIAL, 1, true) == nil,
      line and string.format("line reads %q; staged %d, fixture carries %d",
        line, OTHER_SERIAL, FIXTURE_SERIAL) or "the page rendered no line naming " .. MODEL_NAME)
  end

  do
    -- The pilot's actual complaint, stated as the thing the screen must do: two ESCs
    -- that differ only in their serial number must not look alike on the page.
    --
    -- Red before the fix, because both lines are then the same two parts. This is
    -- the check that cannot be satisfied by a hard-coded number in the codec, and
    -- it is why "the summary contains a serial" is not the gate on its own.
    local fA = copyOf(baseFixture)
    pokeU32(fA, OFFSETS.serial_number.offset, 111111111)
    openYge(fA)
    local lineA = summaryLine(MODEL_NAME)
    local fB = copyOf(baseFixture)
    pokeU32(fB, OFFSETS.serial_number.offset, 222222222)
    openYge(fB)
    local lineB = summaryLine(MODEL_NAME)
    gateCheck("two ESCs that differ only in serial number do not render the same line",
      lineA ~= nil and lineB ~= nil and lineA ~= lineB,
      string.format("both lines read %q", tostring(lineA)))
  end

  do
    -- A serial of 0 reads back as 0 on an ESC that does not fill the field. It is
    -- left out rather than printed, because "S/N 0" reads like data and
    -- identifies nothing.
    --
    -- NOT a gate: the pre-fix codec passes this too, because it prints no serial at
    -- all. It is the invariant the omission has to keep, and registering it as a
    -- gate is what made the first version of this file claim four gates it did not
    -- have.
    local f = copyOf(baseFixture)
    pokeU32(f, OFFSETS.serial_number.offset, 0)
    local runtime = openYge(f)
    local line = summaryLine(MODEL_NAME)
    check("a serial of 0 is left out instead of shown as \"S/N 0\"",
      line ~= nil and line:find("S/N", 1, true) == nil,
      line and string.format("line reads %q", line) or "the page rendered no line naming " .. MODEL_NAME)
    check("and the line still names the model and the firmware",
      line ~= nil and line:find(MODEL_NAME, 1, true) ~= nil
        and line:find(firmwareText(), 1, true) ~= nil,
      line and string.format("line reads %q, expected %q somewhere in it", line, firmwareText())
        or "the page rendered no line naming " .. MODEL_NAME)
  end

  do
    -- No serial_number key at all: not the same as 0, and the case that keeps
    -- string.format away from a nil. NOT a gate, for the same reason as above.
    local got = codec.summaryFor({ esc_type = UNKNOWN_MODEL, firmware_version = 0 })
    check("a data table with no serial_number yields no S/N part and no nil in the text",
      type(got) == "string" and got:find("S/N", 1, true) == nil and got:find("nil", 1, true) == nil,
      string.format("summaryFor returned %s", tostring(got)))
  end

  do
    local ok, got = pcall(codec.summaryFor, nil)
    check("summaryFor(nil) returns a string rather than raising",
      ok and type(got) == "string" and got:find("S/N", 1, true) == nil,
      ok and string.format("summaryFor(nil) returned %s", tostring(got)) or tostring(got))
  end

  -- -------------------------------------------------------------------------
  -- The serial on the wire
  -- -------------------------------------------------------------------------
  out("")
  out("showing the serial does not make it writable")

  do
    -- The point of this one: the number is now on the pilot's screen, so a save
    -- that dropped it would be a new defect introduced by showing it. encode()
    -- writes every WIRE_FIELD from the table page_runtime hands it
    -- (page_runtime.lua:726 passes the decoded table whole), so the ESC's own
    -- bytes have to come back out unchanged.
    --
    -- NOT a gate: this held before the change too, which is exactly why it is worth
    -- pinning -- it is the property that must survive adding the number to the
    -- screen, and a gate would only claim it had detected the fix.
    local f = copyOf(baseFixture)
    pokeU32(f, OFFSETS.serial_number.offset, OTHER_SERIAL)
    local runtime, opts = openYge(f)
    if not runtime or not editUnrelatedField() then
      check("a save leaves the ESC's own serial bytes on the wire", false,
        "the page did not load, or the unrelated row was never built")
    else
      local payload = pressSave(opts)
      local at = OFFSETS.serial_number.offset
      check("a save leaves the ESC's own serial bytes on the wire",
        payload ~= nil and readU32(payload, at) == OTHER_SERIAL,
        payload and string.format("wire serial is %d, the ESC reported %d",
          readU32(payload, at), OTHER_SERIAL) or "no write went out")
    end
  end

  -- -------------------------------------------------------------------------
  -- What this change must not disturb
  -- -------------------------------------------------------------------------
  out("")
  out("unchanged: the parts that were already there")

  do
    -- The two parts this change did not touch, asserted on an id the suite does not
    -- know so the expectation cannot move when the model table gains an entry.
    -- Also the exact pre-fix string, which is what the self-test's sabotage check
    -- requires -- so a change to the format fails here first.
    local got = codec.summaryFor({ esc_type = UNKNOWN_MODEL, firmware_version = 0, serial_number = FIXTURE_SERIAL })
    check("the line still begins \"<model> / <firmware>\" with the serial appended last",
      got == string.format("YGE ESC (%d) / 0.00000 / S/N %d", UNKNOWN_MODEL, FIXTURE_SERIAL),
      string.format("summary reads %q", tostring(got)))
  end

  do
    -- A cross-harness contract, not a style preference: the sibling 12 V BEC
    -- harness reads the model name out of this line with label:match("^(.-)%s*/%s"),
    -- so anything inserted BEFORE the first separator breaks it.
    local runtime, _, c = openYge()
    local label = c.summaryFor(runtime.data)
    local nameOnly = label:match("^(.-)%s*/%s")
    check("the model name is still everything before the first separator",
      nameOnly == MODEL_NAME,
      string.format("summary reads %q, name part is %q", label, tostring(nameOnly)))
  end

  do
    -- The firmware part must still be the same five-decimal rendering, on whatever
    -- the fixture carries.
    local line = (function()
      local runtime = openYge()
      return summaryLine(MODEL_NAME)
    end)()
    check("the firmware version still renders as %.5f",
      line ~= nil and line:find(firmwareText(), 1, true) ~= nil,
      line and string.format("line reads %q, expected %q in it", line, firmwareText())
        or "the page rendered no line naming " .. MODEL_NAME)
  end

  out("")
  out("not driven here, and why:")
  out("  AM32, BLHeli_S, Bluejay   none of the three decodes a serial number, so there is")
  out("                             nothing to show; the issue says the same. Whether one is")
  out("                             readable over MSP 217 at all is unchecked.")
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("YGE serial number in the summary line (#2455)")
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

-- Replaces one span. `nl` is detected rather than assumed -- core.autocrlf=true and
-- no .gitattributes, so the checkout is CRLF on Windows and a hard-coded "\n" would
-- miss the anchor and fail with a message about the anchor rather than about the
-- feature.
local function replace(src, open, close, replacement, what, nl)
  local at = src:find(open, 1, true)
  if not at then error("sabotage: could not find the start of " .. what, 0) end
  local last = src:find(close, at, true)
  if not last then error("sabotage: could not find the end of " .. what, 0) end
  return (src:sub(1, at - 1) .. replacement .. nl .. src:sub(last + #close)), what
end

-- The pre-fix summaryFor, verbatim. Only this function is restored: serialLabel()
-- is left defined and unused on purpose, the same way the sibling harness left
-- specBound() behind -- an unused local cannot change behaviour, and cutting it
-- would widen the slice into whatever follows it.
--
-- Note the "end" appended after it below. `replace` cuts from the start of the
-- span to the END of the close token and does not re-emit that token, so a close
-- anchor that IS a keyword has to be put back by the replacement. Without it the
-- staged file is missing an `end` -- which is what happened on the first run, and
-- the "must still LOAD" step is what caught it.
local PREFIX_SUMMARY = [[function msp.summaryFor(data)
  return string.format("%s / %.5f",
    typeLabel(data and data.esc_type),
    (tonumber(data and data.firmware_version) or 0) / 100000)]]

local PREFIX_SUMMARY_END = "end"

local function prefixCodec(src, nl)
  local out, what = replace(src,
    "function msp.summaryFor(data)",
    nl .. "end",
    PREFIX_SUMMARY .. nl .. PREFIX_SUMMARY_END,
    "summaryFor()", nl)
  return out, what
end

-- Reads the file back and requires it to load. A cut that broke the module has to
-- fail HERE, with a message that says so -- not three layers down as an assert
-- about a missing serial.
local function stageSabotage(pattern, source, build)
  local nl = source:find("\r\n", 1, true) and "\r\n" or "\n"
  local sabotaged = build(source, nl)
  if sabotaged == source then error("sabotage: nothing was cut from " .. pattern, 0) end

  local path = os.tmpname() .. "_yge_serial_prefix.lua"
  local fh = assert(io.open(path, "wb"))
  fh:write(sabotaged)
  fh:close()

  local readBack = readFile(path)
  if readBack ~= sabotaged then
    error(string.format("sabotage: %s does not read back (%d written, %d read)",
      pattern, #sabotaged, #readBack), 0)
  end
  if not realLoadfile(path) then
    error(string.format("sabotage: %s no longer loads -- the cut took something with it", pattern), 0)
  end
  return path
end

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the gate checks must go red without the serial number")
  out(string.rep("=", 72))

  local ok, file = pcall(stageSabotage, CODEC_PATTERN, readFile(CODEC_SOURCE), prefixCodec)
  if not ok then
    out("  FAIL  " .. tostring(file))
    os.exit(1)
  end
  out(string.format("  %-32s cut and verified (%d bytes)", CODEC_PATTERN, readFile(file):len()))

  -- The feature must actually be GONE, so a cut that removed the wrong thing cannot
  -- masquerade as the pre-fix module. Tested on an id this suite does not know, and
  -- against the exact pre-fix string.
  --
  -- package.loaded is cleared FIRST, and that is not tidiness. The codec opens with
  -- a self-cache guard (`if package.loaded["rfsuite.lib.msp_esc_parameters_yge"]
  -- then return package.loaded[...] end`, lines 3-5), and pass 1 already populated
  -- that key. Loading the staged file under any other key therefore returns the REAL
  -- module untouched, the summary still carries the serial, and the sabotage check
  -- reports a working cut as a broken one. The same thing happened to the XDFly
  -- bias harness on 2026-10-04, where it was read as "the sabotage failed" instead.
  do
    package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil
    local pre = assert(realLoadfile(file))()
    local problems = {}
    local summary = tostring(pre.summaryFor({ esc_type = 31337, firmware_version = 0, serial_number = 43550 }))
    if summary:find("S/N", 1, true) then
      problems[#problems + 1] = "the serial is still in the summary: " .. summary
    end
    if summary ~= "YGE ESC (31337) / 0.00000" then
      problems[#problems + 1] = "the pre-fix summary is not what the pre-fix codec produced: " .. summary
    end
    if type(pre.summaryFor) ~= "function" then
      problems[#problems + 1] = "summaryFor is gone entirely -- that is a third state, not the pre-fix one"
    end
    if #problems > 0 then
      for i = 1, #problems do out("  FAIL  sabotage check: " .. problems[i]) end
      os.exit(1)
    end
    out("  the sabotaged codec is the pre-fix shape: summaryFor returns \"YGE ESC (31337) / 0.00000\"")
  end

  REPLACE = { [CODEC_PATTERN] = file }

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = {}

  -- MUST_GO_RED is reset too, and the pass-1 list kept to compare against. Left
  -- accumulating it would list every gate twice, and a duplicate is exactly what
  -- would hide a case that registers on one tree and not the other.
  local pass1Gates = {}
  for i = 1, #MUST_GO_RED do pass1Gates[MUST_GO_RED[i]] = (pass1Gates[MUST_GO_RED[i]] or 0) + 1 end
  MUST_GO_RED = {}

  out("")
  out("pass 2: the same cases against the codec with the fix cut out")
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

  REPLACE = nil

  out("")
  local fired = 0
  for pattern, n in pairs(replaceHits) do
    fired = fired + n
    out(string.format("  %-32s served %d time(s)", pattern, n))
  end
  if fired == 0 then
    out("  FAIL  no sabotaged module was ever served -- pass 2 proved nothing")
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
    out(string.format("SELF-TEST FAILED -- %d of %d gate checks cannot detect the missing serial number",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d gate checks go red without the serial number",
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
