-- Behaviour check for the Scorpion block's serial number and version words (#2455).
--
-- Run it:
--     lua5.4 bin/esc_parameters_scorpion/verify_scorpion_serial.lua
--     lua5.4 bin/esc_parameters_scorpion/verify_scorpion_serial.lua --self-test
--
-- What the defect under test is:
--   lib/msp_esc_parameters_scorpion.lua carried bytes 57..62 as three anonymous
--   U16s named padding_1, padding_2 and padding_3, and read two byte offsets out of
--   the raw block by hand for its summary line:
--
--     return string.format("%s / FW %08X / v%d", model,
--       uintFromRaw(data, {55, 56, 57, 58}),
--       uintFromRaw(data, {61, 62}))
--
--   The sibling suite names those bytes, and the widths add up exactly -- 4 + 2 =
--   the 6 bytes the three U16s occupied:
--
--     rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/esc_parameters_scorpion.lua
--     ... {"motor_startup_sound","U16"}, {"serial_number","U32"},
--         {"firmware_version","U16"}, {"soft_start_time","U16"}, ...
--
--   So "FW %08X" was built from bytes 55-58, which that list calls
--   motor_startup_sound (55-56) and the LOW HALF of serial_number (57-58). It was
--   a number with nothing behind it, and the page has been showing it since the
--   codec was written. The version was already on the line as "v%d" from bytes
--   61-62, which that list calls firmware_version, so nothing that meant anything
--   goes away with it.
--
--   The reference prints the serial in decimal and prints nothing for a zero:
--
--     rotorflight-lua-edgetx-suite .../escmfg/scorp/init.lua
--     local sn = getUInt(buffer, {57, 58, 59, 60})
--     return sn ~= 0 and tostring(sn) or ""
--
--   That page has NO header compensation -- no mspHeaderBytes, unlike the YGE one
--   -- so its byte numbers and this suite's are the same numbers. The parity check
--   below is what makes that a statement about the whole field list instead of two
--   numbers that happen to agree.
--
-- What it drives, and why:
--   * The real app/pages/esc_forward_scorpion.lua through the real
--     app/pages/esc_forward_vendor.lua, so the line under test is the one the pilot
--     sees: esc_forward_vendor.lua renders mspModule.summaryFor(data) with
--     form.addLine, and asserting on the codec alone would leave open that the page
--     renders something else.
--   * The real app/field_layout.lua and app/page_runtime.lua, because the wire
--     check presses the pilot's own Save button.
--   * The real lib/msp_esc_parameters_scorpion.lua.
--
-- Which checks go RED without the fix:
--   4 of 14. --self-test proves that rather than asserting it: it restores the three
--   padding_ fields AND the old byte-offset summaryFor, and requires all four to fail.
--   It cuts both halves because either alone leaves the other able to hide the change
--   -- the old summaryFor alone would find no serial_number field to print, and the
--   new field names alone would decode a serial nobody displays.
--
--   Two checks that LOOKED like gates are deliberately not, and both earned that:
--     * the field-list parity check compares two transcriptions and never reads the
--       codec, so it stayed green while the codec's names were cut back to padding_;
--     * "two ESCs that differ only in serial do not render the same line" was already
--       true before the change, because the word labelled FW was built from bytes that
--       include the low half of the serial.
--   A gate that cannot go red is worse than no gate, so both are registered with
--   check() and say here why.
--
--   It restores rather than deleting, because deleting summaryFor would leave a
--   third state -- a page that renders no line at all -- in which the page-level
--   gates pass for the wrong reason.
--
--   It clears package.loaded before the sabotage load: the codec self-caches under
--   rfsuite.lib.msp_esc_parameters_scorpion, and pass 1 has already filled that key,
--   so loading the staged file returns the REAL module and a working cut looks
--   broken. This is the third harness in two days to fall into that, after the
--   XDFly bias harness and the YGE serial one.
--
--   And it verifies its own work before trusting anything: the staged file must read
--   back byte for byte, must still LOAD, and its summaryFor must produce the exact
--   pre-fix string -- asserted on an empty escinfo block so the expectation cannot
--   move when the fixture changes.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"

local SELF_TEST = arg[1] == "--self-test"

local CODEC_PATTERN = "msp_esc_parameters_scorpion%.lua$"
local CODEC_SOURCE = PREFIX .. "lib/msp_esc_parameters_scorpion.lua"

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

-- Reads a file as bytes. Defined HERE, above every use, because a local function
-- declared further down is not in scope for a closure defined up here: runChecks()
-- below would resolve the name as a global, find nil, and fail with "attempt to
-- call a nil value" on the first page-source check. The YGE harness gets away with
-- its copy sitting in the self-test section because nothing above uses it.
local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
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

local fieldLayout = requireModule("app/field_layout.lua")
do
  local buildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, label, spec, parent)
    if not obs.runtime then obs.runtime = runtime end
    return buildSingle(runtime, label, spec, parent)
  end
end

-- ---------------------------------------------------------------------------
-- The field list, and its parity with the sibling suite
-- ---------------------------------------------------------------------------

-- This suite's list, transcribed. escinfo_1..32 are generated by a loop in the
-- codec and written out here, so a change to the generated count fails loudly
-- instead of shifting every later offset silently.
local LOCAL_FIELDS = {
  { "esc_signature", "u8" }, { "esc_command", "u8" },
}
for i = 1, 32 do LOCAL_FIELDS[#LOCAL_FIELDS + 1] = { "escinfo_" .. i, "u8" } end
local LOCAL_TAIL = {
  { "esc_mode", "u16" }, { "bec_voltage", "u16" }, { "rotation", "u16" },
  { "telemetry_protocol", "u16" }, { "protection_delay", "u16" }, { "min_voltage", "u16" },
  { "max_temperature", "u16" }, { "max_current", "u16" }, { "cutoff_handling", "u16" },
  { "max_used", "u16" }, { "motor_startup_sound", "u16" },
  { "serial_number", "u32" }, { "firmware_version", "u16" },
  { "soft_start_time", "u16" }, { "runup_time", "u16" }, { "bailout", "u16" },
  { "gov_proportional", "u32" }, { "gov_integral", "u32" },
}
for i = 1, #LOCAL_TAIL do LOCAL_FIELDS[#LOCAL_FIELDS + 1] = LOCAL_TAIL[i] end

-- The sibling's, from
-- rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/esc_parameters_scorpion.lua,
-- transcribed and treated as the specification for the field NAMES. The three
-- padding_ names this change removed are absent from it, which is the point.
--
-- Only the fields this suite decodes are listed. The reference carries two more
-- after gov_integral -- see REFERENCE_ONLY_TAIL -- and counting them as mismatches
-- would make the parity check fail on a gap that is stated separately and on
-- purpose.
local REFERENCE_TAIL = {
  { "esc_mode", "u16" }, { "bec_voltage", "u16" }, { "rotation", "u16" },
  { "telemetry_protocol", "u16" }, { "protection_delay", "u16" }, { "min_voltage", "u16" },
  { "max_temperature", "u16" }, { "max_current", "u16" }, { "cutoff_handling", "u16" },
  { "max_used", "u16" }, { "motor_startup_sound", "u16" },
  { "serial_number", "u32" }, { "firmware_version", "u16" },
  { "soft_start_time", "u16" }, { "runup_time", "u16" }, { "bailout", "u16" },
  { "gov_proportional", "u32" }, { "gov_integral", "u32" },
}

-- Named rather than left out of the transcription: the reference decodes two more
-- U32s that this suite does not. The page builds no row for either -- its FIELDS
-- list ends at motor_startup_sound -- so there is nothing on screen to write and
-- nothing that can be lost. That is why this is a coverage gap and not a defect,
-- and the check below says so rather than leaving it to be assumed.
--
-- The first version of this file listed FOUR fields here and claimed the codec
-- decoded none of the governor words. Both halves were wrong: the transcription
-- stopped at bailout, and gov_proportional/gov_integral are decoded
-- (msp_esc_parameters_scorpion.lua:71-72) with rows on the page. A check written to
-- match what I believed was reading is not evidence about the code.
local REFERENCE_ONLY_TAIL = {
  { "stick_max", "u32" }, { "stick_zero", "u32" },
}

local function offsetsOf(fields, from)
  local WIDTH = { u8 = 1, u16 = 2, u32 = 4 }
  local offsets, cursor = {}, from or 1
  for i = 1, #fields do
    offsets[fields[i][1]] = { offset = cursor, width = WIDTH[fields[i][2]] }
    cursor = cursor + WIDTH[fields[i][2]]
  end
  return offsets, cursor - 1
end

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

local FIXTURE_SERIAL = nil
local FIXTURE_FIRMWARE = nil
local FIXTURE_MODEL = nil

local scorpionPage = nil

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

local function resetModules()
  package.loaded["rfsuite.app.pages.esc_forward_vendor"] = nil
  package.loaded["rfsuite.app.esc_error"] = nil
  package.loaded["rfsuite.app.close_key"] = nil
  package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = nil
  package.loaded["rfsuite.app.pages.esc_forward_scorpion"] = nil
  package.loaded["rfsuite.lib.msp_esc_parameters_scorpion"] = nil
end

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

local function readU16(buf, at)
  return (buf[at] or 0) + (buf[at + 1] or 0) * 256
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

-- Loaded through _G.loadfile, NOT realLoadfile: realLoadfile bypasses the redirect,
-- so the self-test's sabotaged codec would never be served.
local function openScorpion(fixture)
  resetObs()
  resetModules()
  scorpionPage = assert(_G.loadfile("app/pages/esc_forward_scorpion.lua"))()

  local codec = requireModule("lib/msp_esc_parameters_scorpion.lua")
  local f = copyOf(codec.buildReadMessage(function() end, function() end).simulatorResponse)
  local offsets = offsetsOf(LOCAL_FIELDS)
  if FIXTURE_SERIAL == nil then
    FIXTURE_SERIAL = readU32(f, offsets.serial_number.offset)
    FIXTURE_FIRMWARE = readU16(f, offsets.firmware_version.offset)
    -- The escinfo block is the model string; it stops at the first zero byte.
    FIXTURE_MODEL = ""
    for i = 3, 34 do
      local b = f[i] or 0
      if b == 0 then break end
      FIXTURE_MODEL = FIXTURE_MODEL .. string.char(b)
    end
  end
  if fixture then
    for i = 1, #fixture do f[i] = fixture[i] end
  end
  reply = f

  local opts = freshOpts()
  scorpionPage.open(opts)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  opts.__runtime = obs.runtime
  return obs.runtime, opts, codec, offsets
end

-- The summary line, found by the version part rather than by position: the page also
-- adds a loading line before the read, and form.clear() is a stub here.
local function summaryLine()
  for i = 1, #obs.lines do
    if obs.lines[i]:find("v", 1, true) and obs.lines[i]:find("/", 1, true) then
      return obs.lines[i]
    end
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
-- table.
--
-- The first NUMBER row, not the first row: this page's first entries are choice
-- fields (esc_mode, rotation, bec_voltage) inside an expansion panel, and picking
-- obs.fieldOrder[1] found a choice field and reported "no number row was built".
local function firstNumberLabel()
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].kind == "number" then return obs.fieldOrder[i].label end
  end
  return nil
end

local function editUnrelatedField()
  local label = firstNumberLabel()
  local field = label and rowField(label)
  if not field then return false end
  local next_ = field.get() + 1
  if field.max and next_ > field.max then next_ = field.min end
  if next_ == field.get() then return false end
  field.set(next_)
  return true
end

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

-- A serial deliberately unlike the fixture's, so "the summary shows a serial" and
-- "the summary shows THIS ESC's serial" stay two different assertions.
local OTHER_SERIAL = 987654321

local function runChecks()
  resetObs()
  resetModules()
  local codec = requireModule("lib/msp_esc_parameters_scorpion.lua")
  local baseFixture = codec.buildReadMessage(function() end, function() end).simulatorResponse
  local offsets = offsetsOf(LOCAL_FIELDS)

  out("")
  out("parity with the sibling suite's field list")
  -- The base is where esc_mode starts in THIS suite's list -- the first field of the
  -- tail in both. Passing motor_startup_sound's offset instead, which is what the
  -- first version did, places the reference twenty bytes late and makes every field
  -- look wrong.
  local refOffsets = offsetsOf(REFERENCE_TAIL, offsets.esc_mode.offset)

  do
    local wrong = {}
    for _, field in ipairs(REFERENCE_TAIL) do
      local mine, theirs = offsets[field[1]], refOffsets[field[1]]
      if not mine then
        wrong[#wrong + 1] = field[1] .. " is missing here"
      elseif mine.offset ~= theirs.offset or mine.width ~= theirs.width then
        wrong[#wrong + 1] = string.format("%s at %d/%dB here, %d/%dB there",
          field[1], mine.offset, mine.width, theirs.offset, theirs.width)
      end
    end
    -- NOT a gate, and the reason is the whole point of this file's first version
    -- failing: this check compares TWO TRANSCRIPTIONS and never looks at the codec,
    -- so it stayed green when the codec's field names were cut back to padding_1..3.
    -- The gate that ties the claim to the code is the fixture round-trip below.
    check("every field the reference names sits at the same byte with the same width (two transcriptions, not the codec)",
      #wrong == 0,
      #wrong > 0 and table.concat(wrong, "; ") or nil)
  end

  do
    -- The gate: the serial this suite DECODES has to be the u32 at the byte the
    -- reference puts it at. Read out of the shipped fixture and out of the page's own
    -- decoded table, so it fails if the codec's field names, widths or order are
    -- wrong -- and it fails when the field is renamed away, which the transcription
    -- check cannot do.
    local runtime = openScorpion()
    local data = runtime and runtime.data
    local want = readU32(baseFixture, refOffsets.serial_number.offset)
    gateCheck(string.format("the decoded serial is the u32 at byte %d, where the reference puts it",
        refOffsets.serial_number.offset),
      data ~= nil and tonumber(data.serial_number) == want,
      data == nil and "the page built no editor"
        or string.format("decoded serial_number is %s, the fixture's byte %d reads %d",
          tostring(data.serial_number), refOffsets.serial_number.offset, want))
  end

  do
    -- The gap after gov_integral, named. Both lists end at the same byte there, so
    -- stick_max and stick_zero are a difference in coverage and not a shift.
    local _, mineEnd = offsetsOf(LOCAL_TAIL, offsets.esc_mode.offset)
    local _, refEnd = offsetsOf(REFERENCE_ONLY_TAIL, mineEnd + 1)
    local undecoded = {}
    for _, field in ipairs(REFERENCE_ONLY_TAIL) do
      if offsets[field[1]] == nil then undecoded[#undecoded + 1] = field[1] end
    end
    -- The page is the reason this is a gap and not a defect: it builds no row for
    -- either field, so nothing can be written into them and nothing can be lost.
    local page = readFile(PREFIX .. "app/pages/esc_forward_scorpion.lua")
    local rowsForThem = 0
    for _, field in ipairs(REFERENCE_ONLY_TAIL) do
      if page:find('key = "' .. field[1] .. '"', 1, true) then rowsForThem = rowsForThem + 1 end
    end
    check("the two fields the reference decodes after gov_integral are named as a gap, and the page has no row for either",
      #undecoded == 2 and refEnd > mineEnd and rowsForThem == 0,
      string.format("this suite ends at byte %d, the reference at %d; undecoded here: %s; rows built for them: %d",
        mineEnd, refEnd, table.concat(undecoded, ", "), rowsForThem))
  end

  out("")
  out("the pilot's summary line")

  do
    local runtime, _, _, offs = openScorpion()
    local line = summaryLine()
    gateCheck("the summary line carries the ESC's serial number",
      line ~= nil and line:find("S/N " .. FIXTURE_SERIAL, 1, true) ~= nil,
      line and string.format("line reads %q, fixture serial is %d", line, FIXTURE_SERIAL)
        or "the page rendered no summary line")
  end

  do
    local f = copyOf(baseFixture)
    pokeU32(f, offsets.serial_number.offset, OTHER_SERIAL)
    openScorpion(f)
    local line = summaryLine()
    gateCheck("the serial shown is the one this ESC reported, not a fixed number",
      line ~= nil and line:find("S/N " .. OTHER_SERIAL, 1, true) ~= nil
        and line:find("S/N " .. FIXTURE_SERIAL, 1, true) == nil,
      line and string.format("line reads %q; staged %d, fixture carries %d",
        line, OTHER_SERIAL, FIXTURE_SERIAL) or "the page rendered no summary line")
  end

  do
    -- Two ESCs that differ only in the serial must not look alike.
    --
    -- NOT a gate for this codec, and the reason is worth reading: before the change
    -- the two lines already differed, because the word labelled FW was built from
    -- bytes 55-58 and bytes 57-58 are the low half of the serial. So "the two lines
    -- differ" was true before and after -- for the wrong reason before. Staging the
    -- serial and comparing lines therefore cannot detect this defect, and saying so
    -- is more useful than a gate that would go green either way.
    local fA = copyOf(baseFixture)
    pokeU32(fA, offsets.serial_number.offset, 111111111)
    openScorpion(fA)
    local lineA = summaryLine()
    local fB = copyOf(baseFixture)
    pokeU32(fB, offsets.serial_number.offset, 222222222)
    openScorpion(fB)
    local lineB = summaryLine()
    check("two ESCs that differ only in serial number do not render the same line",
      lineA ~= nil and lineB ~= nil and lineA ~= lineB,
      string.format("both lines read %q", tostring(lineA)))
  end

  do
    -- The word that used to be labelled FW is gone, and THAT is specific to this
    -- defect: the field list says bytes 55-58 are motor_startup_sound plus half a
    -- serial, so the label was wrong whatever the ESC reported.
    local runtime = openScorpion()
    local line = summaryLine()
    gateCheck("the line carries no word labelled FW any more",
      line ~= nil and line:find("FW", 1, true) == nil,
      line and string.format("line reads %q", line) or "the page rendered no summary line")
  end

  out("")
  out("unchanged: what was already on the line")

  do
    -- The version was already there as "v%d" from bytes 61-62; it must survive, and
    -- it must come from the named field now.
    local runtime = openScorpion()
    local line = summaryLine()
    check("the firmware version is still on the line",
      line ~= nil and line:find("v" .. FIXTURE_FIRMWARE, 1, true) ~= nil,
      line and string.format("line reads %q, fixture version is %d", line, FIXTURE_FIRMWARE)
        or "the page rendered no summary line")
  end

  do
    -- The model string comes from the escinfo block and was the first part before.
    local runtime = openScorpion()
    local line = summaryLine()
    check("the model string is still the first part",
      line ~= nil and line:sub(1, #FIXTURE_MODEL) == FIXTURE_MODEL,
      line and string.format("line reads %q, model is %q", line, FIXTURE_MODEL)
        or "the page rendered no summary line")
  end

  do
    -- A serial of 0 is left out. NOT a gate: the pre-fix codec passes this too,
    -- because it prints no serial at all. It is the invariant the omission keeps.
    local f = copyOf(baseFixture)
    pokeU32(f, offsets.serial_number.offset, 0)
    openScorpion(f)
    local line = summaryLine()
    check("a serial of 0 is left out instead of shown as \"S/N 0\"",
      line ~= nil and line:find("S/N", 1, true) == nil,
      line and string.format("line reads %q", line) or "the page rendered no summary line")
    check("and the line still carries the model and the version",
      line ~= nil and line:find(FIXTURE_MODEL, 1, true) ~= nil
        and line:find("v" .. FIXTURE_FIRMWARE, 1, true) ~= nil,
      line and string.format("line reads %q", line) or "the page rendered no summary line")
  end

  do
    local ok, got = pcall(codec.summaryFor, nil)
    check("summaryFor(nil) returns a string rather than raising",
      ok and type(got) == "string" and got:find("S/N", 1, true) == nil,
      ok and string.format("summaryFor(nil) returned %s", tostring(got)) or tostring(got))
  end

  out("")
  out("showing the serial does not make it writable")

  do
    -- The number is now on the pilot's screen, so a save that dropped it would be a
    -- new defect introduced by showing it. NOT a gate: this held before the change
    -- too, which is exactly why it is worth pinning.
    local f = copyOf(baseFixture)
    pokeU32(f, offsets.serial_number.offset, OTHER_SERIAL)
    local runtime, opts, _, offs = openScorpion(f)
    if not runtime or not editUnrelatedField() then
      check("a save leaves the ESC's own serial bytes on the wire", false,
        "the page did not load, or no number row was built")
    else
      local payload = pressSave(opts)
      check("a save leaves the ESC's own serial bytes on the wire",
        payload ~= nil and readU32(payload, offs.serial_number.offset) == OTHER_SERIAL,
        payload and string.format("wire serial is %d, the ESC reported %d",
          readU32(payload, offs.serial_number.offset), OTHER_SERIAL) or "no write went out")
    end
  end

  do
    -- And the same for the word that used to be labelled FW: it is now the serial's
    -- upper half, and a save must not zero it either.
    local f = copyOf(baseFixture)
    pokeU32(f, offsets.serial_number.offset, OTHER_SERIAL)
    local runtime, opts, _, offs = openScorpion(f)
    if not runtime or not editUnrelatedField() then
      check("the four serial bytes are written back whole", false, "no write went out")
    else
      local payload = pressSave(opts)
      local at = offs.serial_number.offset
      local intact = payload ~= nil
        and payload[at] == f[at] and payload[at + 1] == f[at + 1]
        and payload[at + 2] == f[at + 2] and payload[at + 3] == f[at + 3]
      check("the four serial bytes are written back whole", intact,
        payload and string.format("wire %d,%d,%d,%d against the ESC's %d,%d,%d,%d",
          payload[at], payload[at + 1], payload[at + 2], payload[at + 3],
          f[at], f[at + 1], f[at + 2], f[at + 3]) or "no write went out")
    end
  end

  out("")
  out("not driven here, and why:")
  out("  AM32, BLHeli_S, Bluejay   none of the three names a serial in the reference's field")
  out("                             list either, so there is nothing to show and nothing to")
  out("                             align. This is a statement, not an absence.")
  out("  FlyRotor                  the reference names esc_sn and this suite already decodes")
  out("                             it (bytes8) but does not display it. Left alone on")
  out("                             purpose: #2462 changes this same codec and is ahead in the")
  out("                             merge order.")
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("Scorpion: the serial number, and the word that was labelled FW (#2455)")
out(string.rep("=", 72))

runChecks()

local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the same cases against the pre-fix codec
-- ---------------------------------------------------------------------------

local function replace(src, open, close, replacement, what, nl)
  local at = src:find(open, 1, true)
  if not at then error("sabotage: could not find the start of " .. what, 0) end
  local last = src:find(close, at, true)
  if not last then error("sabotage: could not find the end of " .. what, 0) end
  return (src:sub(1, at - 1) .. replacement .. nl .. src:sub(last + #close))
end

-- The pre-fix state, in both halves. The three padding_ fields go back, and so does
-- the byte-offset summaryFor -- which needs uintFromRaw back, because that is what
-- it called.
--
-- Both are [==[ ... ]==] and not [[ ... ]] because the text contains "positions[i]]",
-- and a plain long string ends at the first "]]" -- which is inside the very helper
-- being restored. The first version used [[ ]] and the file did not parse.
--
-- PREFIX_SUMMARY ends with uintFromRaw's own "end", so the replacement must not add
-- another one; see prefixCodec.
local PREFIX_TAIL = [==[  {"motor_startup_sound", "u16"},
  {"padding_1", "u16"},
  {"padding_2", "u16"},
  {"padding_3", "u16"},
  {"soft_start_time", "u16"},]==]

-- ORDER MATTERS IN HERE. uintFromRaw comes first and summaryFor second, because that
-- is the order the pre-fix file had (the helper at its line 150, summaryFor at 159)
-- and because a Lua local is lexically scoped: a summaryFor defined above the helper
-- resolves the name as a GLOBAL and dies with "attempt to call a nil value". Which is
-- what the first version did -- it read "uintFromRaw first" as the natural order --
-- and the staged file then failed at the sabotage check rather than at the parse.
local PREFIX_SUMMARY = [==[local function uintFromRaw(data, positions)
  local raw = data and data._raw or {}
  local value = 0
  for i = 1, #positions do
    value = value + (raw[positions[i]] or 0) * (256 ^ (i - 1))
  end
  return value
end

function msp.summaryFor(data)
  local model = textFromInfo(data)
  if model == "" then model = msp.TITLE end
  return string.format("%s / FW %08X / v%d",
    model,
    uintFromRaw(data, {55, 56, 57, 58}),
    uintFromRaw(data, {61, 62}))
end]==]

local function prefixCodec(src, nl)
  -- (1) the field names. Both anchors stay INSIDE a line: an anchor with a "\n" in
  -- it matches nothing on a CRLF checkout, and core.autocrlf=true with no
  -- .gitattributes means the checkout IS CRLF on Windows. The first version did that
  -- and the self-test reported "could not find the start of the tail field names",
  -- which is a message about the anchor and not about the feature.
  local out = replace(src,
    '{"motor_startup_sound", "u16"},',
    '{"soft_start_time", "u16"},',
    PREFIX_TAIL, "the tail field names", nl)
  -- (2) summaryFor, anchored on its own opening line and on the first line that is
  -- exactly "end" -- the two indented "end"s inside it are preceded by spaces and do
  -- not match nl .. "end".
  --
  -- No "end" is appended to the replacement here, unlike the YGE harness: this
  -- PREFIX_SUMMARY already ends with uintFromRaw's own "end", so appending one closes
  -- a function that was never opened. The staged file then does not load, which is
  -- what the "must still LOAD" step exists to catch.
  out = replace(out,
    "function msp.summaryFor(data)",
    nl .. "end",
    PREFIX_SUMMARY, "summaryFor()", nl)
  -- (3) the helper summaryFor used to call. Left defined and unused on purpose, the
  -- same trade the sibling harness makes with specBound(): cutting it would widen the
  -- slice into whatever follows it, and an unused local cannot change behaviour.
  return out
end

local function stageSabotage(pattern, source, build)
  local nl = source:find("\r\n", 1, true) and "\r\n" or "\n"
  local sabotaged = build(source, nl)
  if sabotaged == source then error("sabotage: nothing was cut from " .. pattern, 0) end

  local path = os.tmpname() .. "_scorpion_prefix.lua"
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
  -- masquerade as the pre-fix module.
  do
    package.loaded["rfsuite.lib.msp_esc_parameters_scorpion"] = nil
    local pre = assert(realLoadfile(file))()
    local problems = {}
    local summary = tostring(pre.summaryFor({ escinfo_1 = 0, firmware_version = 7 }))
    if summary:find("S/N", 1, true) then
      problems[#problems + 1] = "the serial is still in the summary: " .. summary
    end
    -- The exact pre-fix rendering, so "no serial" cannot be satisfied by a label that
    -- merely differs from the real one. escinfo_1 = 0 makes the model fall back to the
    -- title, which keeps the expectation independent of the fixture.
    --
    -- The version reads v0, not the firmware_version this table carries, and that is
    -- the point: the pre-fix summaryFor read it out of _raw by byte offset, so a table
    -- without _raw has nothing to read and renders a zero. The version only ever came
    -- out right because the page always passed a decoded table.
    if summary ~= string.format("%s / FW %08X / v0", "Scorpion", 0) then
      problems[#problems + 1] = "the pre-fix summary is not what the pre-fix codec produced: " .. summary
    end
    if pre.summaryFor == nil then
      problems[#problems + 1] = "summaryFor is gone entirely -- that is a third state, not the pre-fix one"
    end
    if #problems > 0 then
      for i = 1, #problems do out("  FAIL  sabotage check: " .. problems[i]) end
      os.exit(1)
    end
    out("  the sabotaged codec is the pre-fix shape: FW word back, no serial in the summary")
  end

  REPLACE = { [CODEC_PATTERN] = file }

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = {}

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

checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 72))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
