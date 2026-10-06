-- Behaviour check for the Bluejay and AM32 forward-programming codecs (#2339).
--
-- Run it:
--     lua5.3 bin/esc_raw_bytes/verify_esc_raw_bytes.lua
--     lua5.3 bin/esc_raw_bytes/verify_esc_raw_bytes.lua --self-test
--
-- What the defect under test is:
--   Both codecs laid the write payload out from the parsed fields alone —
--   lib/msp_esc_parameters_bluejay.lua's encode() and
--   lib/msp_esc_parameters_am32.lua's encode() walked WIRE_FIELDS and wrote one
--   byte per entry from `data[name]`. decode() already kept the ESC's own bytes
--   in `data._raw` for Bluejay (and only for Bluejay); nothing read them.
--
--   That is not a display bug, because the flight controller is a pass-through
--   that hands the ESC exactly what this suite sends:
--     * rotorflight-firmware src/main/msp/msp.c:3397-3409, MSP_SET_ESC_PARAMETERS,
--       does `sbufReadData(src, escGetParamUpdBuffer(), len)` and then
--       `escCommitParameters()`. It copies the reply's bytes over the update
--       buffer and commits that; it merges nothing.
--     * len is escGetParamBufferLength() (esc_sensor.c:4553-4570): a two-byte
--       header plus BLHELI_S_MSP_NUM_EEPROM_BYTES (0x40) for the 0xC1 signature
--       Bluejay shares with BLHeli_S, and AM32_NUM_EEPROM_BYTES (0x30) for
--       0xC2. So Bluejay is 66 bytes and AM32 is 50, which is what both
--       simulatorResponse fixtures carry.
--     * the ESC parameter bytes BEYOND that window are the firmware's own
--       business (fourwayIfFetchData caches the whole block, esc_sensor.c:765-819);
--       these first 0x40 are the Lua suite's and nobody else's.
--
--   So every byte encode() did not reproduce byte-for-byte is a byte the ESC is
--   told changed. Measured on the pre-fix codecs, poking one byte at a time over
--   all 256 values and re-encoding without editing anything:
--
--     Bluejay byte  7  startup_power_min   130 of 256 values came back different
--              byte 10  startup_power_max   181 of 256
--              byte 13  pwm_frequency        1 of 256   (0 came back 192)
--              byte 46  threshold_48to24    155 of 256
--              byte 47  threshold_96to48    188 of 256
--     AM32    byte 26  timing_advance      248 of 256   (11 came back 10, 42 -> 34)
--
--   Two separate causes, and the fix has to answer both:
--     * the four Bluejay rows above plus six AM32 rows store a byte that is not
--       the number the page shows, so the shown number cannot say which byte it
--       came from; and
--     * AM32's timing advance is numbered differently by two firmware
--       generations (0..3 and 10..42 in steps of 8) and both spellings occur, so
--       the position alone does not say which of them the ESC used.
--   The pre-fix Bluejay encoder also clamped threshold_96to48 down to
--   threshold_48to24 on EVERY save, so an ESC reporting the pair the other way
--   round was corrected whether or not the pilot touched either row.
--
-- What the fix is, and what this pins:
--   encode() starts from a copy of the ESC's own bytes and writes one field
--   only when the pilot moved it off the byte that value came from. Everything
--   else is the ESC's own byte back. It is the rule the EdgeTX suite already
--   applies to its five transformed Bluejay fields (esc_parameters_bluejay.lua's
--   TRANSFORMS / buildWritePayload) and to the AM32 timing byte
--   (encodeTimingAdvance), extended from those fields to the whole block.
--
--   The exhaustive check below is the one that matters and it is not a sample:
--   for EVERY byte position and EVERY one of its 256 values, a decode/encode
--   round trip with nothing edited must return the block unchanged. That is
--   16896 Bluejay pairs and 12800 AM32 ones, and on the pre-fix codecs it fails
--   at exactly the six positions above.
--
-- What it drives, and why:
--   * the real app/pages/esc_forward_bluejay.lua and esc_forward_am32.lua, the
--     real app/pages/esc_forward_vendor.lua, the real app/page_runtime.lua and
--     the real codecs, entered through each page's own open(). Which codec a
--     page hands the shared editor is half of what makes the write correct.
--   * the real app/field_layout.lua, because a pilot edit is exactly the call
--     Ethos makes on the setter the widget was built with.
--   * Only form, the bus and the chrome-only modules are stubbed. The bus
--     answers reads with the codec's OWN simulatorResponse -- the same fixture
--     tasks/msp/queue.lua replays on the Ethos simulator -- decoded by the
--     production decode(), and records the payload of every write.
--
-- Which checks go RED on the pre-fix codecs -- fourteen of them, and the list is
-- exactly what pass 2 reports:
--   * both exhaustive round-trip checks (2);
--   * the five staged Bluejay bytes (5) -- startup_power_min 1, startup_power_max
--     0, pwm_frequency 0, threshold_48to24 1, threshold_96to48 2, every one of
--     which the pre-fix encoder rewrote;
--   * the untouched out-of-order threshold pair (1), which the pre-fix encoder
--     clamped on every save;
--   * the staged AM32 timing bytes 11 and 42 (2). Bytes 26 and 3 are in the same
--     loop but are NOT gates: both survive the pre-fix round trip, because 26 and
--     34 are exactly what the pre-fix encoder wrote for those two positions, so
--     requiring them to go red would be requiring the harness to fail on correct
--     behaviour;
--   * the four refusals (4).
--
-- Deliberately NOT gates, each for a stated reason at the case:
--   * the eight timing-decode cases -- the read direction is unchanged by this
--     fix, so none of them can go red;
--   * the three AM32 timing write-direction cases and the Motor KV one -- they
--     confirm the fix did not turn "preserve" into "ignore", and the pre-fix
--     encoder produced the same bytes;
--   * the Bluejay u16 vendor word and the two threshold-clamp-still-applies cases --
--     both passed before the fix too.
--
-- --self-test proves the list rather than asserting it: it splices the pre-fix
-- clamp/readValue/writeValue/decode/encode and the pre-fix buildWriteMessage back
-- into copies of both codecs and requires every one of those fourteen to fail. It
-- also verifies each splice four ways before using it, because a sabotage that
-- breaks the module differently from the defect under test proves nothing about
-- the defect.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local BLUEJAY_SRC = SUITE .. "/lib/msp_esc_parameters_bluejay.lua"
local AM32_SRC = SUITE .. "/lib/msp_esc_parameters_am32.lua"

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
-- Both pages give every row its own line (esc_forward_vendor.lua's buildEditor
-- calls buildSingle, one addLine per field), and no two of their rows share one,
-- which is what makes the label a usable key.
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

-- app/pages/esc_forward_4way.lua only decides WHICH ESC to address: it reads the
-- motor count, offers a selector and then hands off to the page's own
-- openEditor(). Bluejay and AM32 both go through it, and it waits on os.clock()
-- between the pre-switch write, the switch write and the read -- about six seconds
-- of wall clock per open on real hardware, which is why
-- bin/esc_signature/verify_esc_signature.lua stubs it too (its comment says the
-- same thing). Stubbing it here keeps the real openEditor(), the real shared
-- editor, the real runtime and the real codec in the seat; what it drops is the
-- choice of ESC number, which is not what #2339 is about.
--
-- The stub captures the config so the harness can call the page's own
-- openEditor() itself -- going through the real closure rather than a copy of it,
-- so "which codec does this page hand the editor" is still the question the page
-- answers.
local capturedFourWay = nil
package.loaded["rfsuite.app.pages.esc_forward_4way"] = {
  open = function(_, config) capturedFourWay = config end,
}

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
-- The two codecs and the two pages that hold them
-- ---------------------------------------------------------------------------

local CODEC_SOURCES = {
  bluejay = BLUEJAY_SRC,
  am32 = AM32_SRC,
}
local CODEC_KEYS = {
  bluejay = "rfsuite.lib.msp_esc_parameters_bluejay",
  am32 = "rfsuite.lib.msp_esc_parameters_am32",
}
local PAGE_FILES = {
  bluejay = "app/pages/esc_forward_bluejay.lua",
  am32 = "app/pages/esc_forward_am32.lua",
}

-- The loaded codecs and pages, filled in before pass 1 and again before pass 2.
-- Declared here rather than down with the cases, because pressSave() and
-- roundTripSurvives() below both read them.
local CODECS = {}
local pages = {}

-- realLoadfile, deliberately, not the redirect above: the redirect prepends the
-- suite prefix to anything ending in .lua, which is right for requireModule()'s
-- bare "lib/..." paths and wrong for this absolute-ish one.
local function loadCodec(which)
  package.loaded[CODEC_KEYS[which]] = nil
  return assert(realLoadfile(CODEC_SOURCES[which]))()
end

-- The page is reloaded per runChecks(), and it has to be: both ESC pages bind
-- their codec into a module-level `local msp` at their line 6, so reloading only
-- the codec would leave the page still holding the first one and pass 2 would be
-- a rerun of pass 1 wearing a different label. Neither page carries a self-cache
-- guard, so a plain reload really does re-run its body.
local function loadPage(which)
  return assert(realLoadfile(PREFIX .. PAGE_FILES[which]))()
end

-- ---------------------------------------------------------------------------
-- The wire layouts
-- ---------------------------------------------------------------------------
--
-- A verbatim transcription of each shipped WIRE_FIELDS, because each codec keeps
-- that table local to decode()/encode() and does not export it. Three things
-- keep this honest rather than a second source of truth:
--   * the fixture-length check in each codec's section asserts the table predicts
--     the shipped simulatorResponse's length, so a field added, removed or
--     retyped upstream fails loudly instead of quietly making every case test
--     the wrong byte;
--   * the byte-poke helper re-reads the staged value out of the reply that
--     actually reached decode(), so a case cannot assert against a byte it
--     failed to set; and
--   * every offset a case asserts on is asked for BY NAME below, and checkLayout
--     compares the transcribed offset with the one the case uses, so a table that
--     drifted shows up as a reported mismatch rather than a silently wrong byte.
local LAYOUTS = {
  bluejay = {
    { "esc_signature", "u8" }, { "esc_command", "u8" }, { "main_revision", "u8" },
    { "sub_revision", "u8" }, { "layout_revision", "u8" }, { "reserved_03", "u8" },
    { "startup_power_min", "u8" }, { "startup_beep", "u8" }, { "dithering", "u8" },
    { "startup_power_max", "u8" }, { "reserved_08", "u8" }, { "rpm_power_slope", "u8" },
    { "pwm_frequency", "u8" }, { "motor_direction", "u8" }, { "reserved_0c", "u8" },
    { "mode_raw", "u16" }, { "reserved_0f", "u8" }, { "braking_strength", "u8" },
    { "reserved_11", "u8" }, { "reserved_12", "u8" }, { "reserved_13", "u8" },
    { "reserved_14", "u8" }, { "commutation_timing", "u8" }, { "reserved_16", "u8" },
    { "reserved_17", "u8" }, { "reserved_18", "u8" }, { "reserved_19", "u8" },
    { "reserved_1a", "u8" }, { "beep_strength", "u8" }, { "beacon_strength", "u8" },
    { "beacon_delay", "u8" }, { "reserved_1e", "u8" }, { "demag_compensation", "u8" },
    { "reserved_20", "u8" }, { "reserved_21", "u8" }, { "reserved_22", "u8" },
    { "temperature_protection", "u8" }, { "low_rpm_power_protection", "u8" },
    { "reserved_25", "u8" }, { "reserved_26", "u8" }, { "brake_on_stop", "u8" },
    { "reserved_28", "u8" }, { "power_rating", "u8" }, { "force_edt_arm", "u8" },
    { "threshold_48to24", "u8" }, { "threshold_96to48", "u8" },
  },
  am32 = {
    { "esc_signature", "u8" }, { "esc_command", "u8" }, { "reserved_0", "u8" },
    { "eeprom_version", "u8" }, { "reserved_1", "u8" }, { "version_major", "u8" },
    { "version_minor", "u8" }, { "max_ramp", "u8" }, { "minimum_duty_cycle", "u8" },
    { "disable_stick_calibration", "u8" }, { "absolute_voltage_cutoff", "u8" },
    { "current_p", "u8" }, { "current_i", "u8" }, { "current_d", "u8" },
    { "active_brake_power", "u8" }, { "reserved_eeprom_3_0", "u8" },
    { "reserved_eeprom_3_1", "u8" }, { "reserved_eeprom_3_2", "u8" },
    { "reserved_eeprom_3_3", "u8" }, { "motor_direction", "u8" },
    { "bidirectional_mode", "u8" }, { "sinusoidal_startup", "u8" },
    { "complementary_pwm", "u8" }, { "variable_pwm_frequency", "u8" },
    { "stuck_rotor_protection", "u8" }, { "timing_advance", "u8" },
    { "pwm_frequency", "u8" }, { "startup_power", "u8" }, { "motor_kv", "u8" },
    { "motor_poles", "u8" }, { "brake_on_stop", "u8" }, { "stall_protection", "u8" },
    { "beep_volume", "u8" }, { "interval_telemetry", "u8" },
    { "servo_low_threshold", "u8" }, { "servo_high_threshold", "u8" },
    { "servo_neutral", "u8" }, { "servo_dead_band", "u8" },
    { "low_voltage_cutoff", "u8" }, { "low_voltage_threshold", "u8" },
    { "rc_car_reversing", "u8" }, { "use_hall_sensors", "u8" },
    { "sine_mode_range", "u8" }, { "brake_strength", "u8" },
    { "running_brake_level", "u8" }, { "temperature_limit", "u8" },
    { "current_limit", "u8" }, { "sine_mode_power", "u8" }, { "esc_protocol", "u8" },
    { "auto_advance", "u8" },
  },
}

local WIDTH = { u8 = 1, u16 = 2 }

-- Bluejay's shipped layout appends reserved_2d..reserved_3f in a loop rather than
-- as 19 literals, and this transcription mirrors that loop rather than spelling
-- the nineteen out -- a hand-typed tail is a place for a transcription to be one
-- byte short, and the fixture-length check in checkLayout() is what says whether
-- it is. The names are generated, not looked up, because no case asserts on
-- them: they exist to make the block come out 66 bytes long.
local RESERVED_TAIL = {bluejay = {0x2d, 0x3f}}

local function wireLayout(which)
  local layout = LAYOUTS[which]
  local offsets, cursor = {}, 1
  for i = 1, #layout do
    offsets[layout[i][1]] = { offset = cursor, width = WIDTH[layout[i][2]] }
    cursor = cursor + WIDTH[layout[i][2]]
  end
  local tail = RESERVED_TAIL[which]
  if tail then
    for at = tail[1], tail[2] do
      offsets[string.format("reserved_%02x", at)] = { offset = cursor, width = 1 }
      cursor = cursor + 1
    end
  end
  return offsets, cursor - 1
end

-- Two values per codec, so a table constructor cannot silently drop the byte
-- count: `OFFSETS[k] = wireLayout(k)` would keep only the first return value.
local OFFSETS, LAYOUT_BYTES = {}, {}
for _, which in ipairs({ "bluejay", "am32" }) do
  OFFSETS[which], LAYOUT_BYTES[which] = wireLayout(which)
end

-- The offsets every case below asserts on, named so a typo is a reported
-- mismatch from checkLayout() rather than a silently wrong byte.
local AT = {
  bluejay = {
    startup_power_min = 7, startup_power_max = 10, pwm_frequency = 13,
    motor_direction = 14, mode_raw = 16, commutation_timing = 24,
    beacon_strength = 31, threshold_48to24 = 46, threshold_96to48 = 47,
  },
  am32 = {
    timing_advance = 26, motor_kv = 29,
  },
}

-- Compares the transcription above against the shipped layout. Returns the
-- predicted byte count as well, so each codec's section can assert the fixture
-- length against it.
local function checkLayout(which, fixtureBytes)
  local offsets = OFFSETS[which]
  local bytes = LAYOUT_BYTES[which]
  local bad = {}
  for name, at in pairs(AT[which]) do
    local field = offsets[name]
    if not field then
      bad[#bad + 1] = name .. " is not in the transcribed layout"
    elseif field.offset ~= at then
      bad[#bad + 1] = string.format("%s is at %d in the transcribed layout, the cases use %d",
        name, field.offset, at)
    end
  end
  if bytes ~= fixtureBytes then
    bad[#bad + 1] = string.format("the layout predicts %d bytes, the fixture carries %d",
      bytes, fixtureBytes)
  end
  return #bad == 0, table.concat(bad, "; ")
end

local function copyOf(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end

local function readU16(buf, at)
  return (buf[at] or 0) + (buf[at + 1] or 0) * 256
end

-- Only ever used on a payload whose length the case has already checked, so an
-- index past the end cannot happen -- but a bare payload[i] reads as nil and
-- prints "nil" in a failure line, which is a worse report than a 0.
local function readByte(payload, at)
  return payload[at] or 0
end

-- ---------------------------------------------------------------------------
-- Driving a page
-- ---------------------------------------------------------------------------

-- Which i18n key ends which row. Both pages' labels are unresolved @i18n(...)@
-- tags at this point -- they are substituted at build time by
-- .vscode/scripts/resolve_i18n_tags.py, not at Lua runtime -- so the key IS the
-- label here, and it is a stable one to match on.
local ROWS = {
  bluejay = {
    unrelated = "mfg.blheli_s.beaconstrength",
    direction = "mfg.blheli_s.motordirection",
    pwm = "mfg.bluejay.pwmfrequency",
    threshold_low = "mfg.bluejay.threshold48to24",
    threshold_high = "mfg.bluejay.threshold96to48",
  },
  am32 = {
    unrelated = "mfg.am32.beepvolume",
    motorKv = "mfg.am32.motorkv",
    timing = "mfg.am32.timing",
  },
}

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

-- Drives the page to its editor: open(opts), then the handoff the 4-way page
-- would perform once it had settled on an ESC. Split out because the load-gate
-- case below has to run the same two steps with a failing read behind them.
local function drivePageOpen(which, opts)
  capturedFourWay = nil
  pages[which].open(opts)
  local editor = capturedFourWay and capturedFourWay.openEditor
  if editor then editor(opts, {label = "ESC 1", target = 0}) end
end

-- One open of the real page, answered with `fixture`. Returns the runtime the
-- page built -- reached through field_layout.buildSingle(), which receives it
-- as its first argument -- and the opts.
--
-- One wakeup tick is enough: esc_forward_vendor passes the finished read in as
-- `initialData`, so PageRuntime:loadInitial() takes its short-circuit branch and
-- sets self.loaded = true without a second read. The editor is built during that
-- same tick, by the page's own wakeup handler.
local function openPage(which, fixture)
  resetObs()
  reply = fixture and copyOf(fixture) or nil
  replyFails = false

  local opts = freshOpts()
  -- pressSave() has to recognise this page's write command, and the opts table is
  -- the only thing it is handed, so the page that opened it tags the opts with
  -- its own name. A case cannot then be handed the wrong page's runtime.
  opts.__which = which
  drivePageOpen(which, opts)
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
-- bytes have to ride along on their own.
--
-- Both chosen rows are plain bytes, and both are built at the fixture's layout
-- revision (Bluejay 209 in its own fixture), so the row exists in every case.
local function editUnrelatedField(which)
  local field = rowField(ROWS[which].unrelated)
  if not field then return false end
  local current = field.get()
  local next = current + 1
  if field.max and next > field.max then next = field.min end
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
  local command = CODECS[opts.__which].WRITE_COMMAND
  for i = writesBefore + 1, #obs.writes do
    if obs.writes[i].command == command then return obs.writes[i].payload end
  end
  return nil
end

-- Stage `value` into the fixture at the byte the named field occupies, and
-- report whether the byte really is that value afterwards -- so a case cannot
-- assert against a byte it failed to set.
local function poke(which, fixture, name, value)
  local field = OFFSETS[which][name]
  if not field then return nil, false, name .. " is not in the transcribed layout" end
  local buf = copyOf(fixture)
  if field.width == 2 then
    buf[field.offset] = value % 256
    buf[field.offset + 1] = math.floor(value / 256) % 256
    return buf, readU16(buf, field.offset) == value
  end
  buf[field.offset] = value
  return buf, buf[field.offset] == value
end

-- The exhaustive check: every byte position, every one of its 256 values, no
-- edit at all. This is the whole defect in one loop -- on the pre-fix codecs it
-- fails at exactly the positions named in this file's header.
local function roundTripSurvives(which, fixture)
  local lost, firstLost = 0, nil
  for offset = 1, #fixture do
    for value = 0, 255 do
      local buf = copyOf(fixture)
      buf[offset] = value
      local out = CODECS[which]._encode(CODECS[which]._decode(buf))
      if type(out) ~= "table" or #out ~= #buf then
        lost = lost + 1
        if not firstLost then
          firstLost = string.format("byte %d: the codec wrote %s bytes for a %d byte block",
            offset, out and #out or "no", #buf)
        end
      elseif out[offset] ~= value then
        lost = lost + 1
        if not firstLost then
          firstLost = string.format("byte %d: value %d came back as %d, nothing was edited",
            offset, value, out[offset])
        end
      end
    end
  end
  return lost, firstLost
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------

-- A failed read must leave neither a runtime nor a block on the bus, and this is
-- stated once per codec rather than inlined, because it is the same claim about
-- two pages and a difference between them would be worth seeing.
local function checkLoadGate(which)
  resetObs()
  replyFails = true
  local opts = freshOpts()
  drivePageOpen(which, opts)
  opts.__installed.setWakeupHandler()
  replyFails = false

  local wrote = false
  for i = 1, #obs.writes do
    if obs.writes[i].command == CODECS[which].WRITE_COMMAND then wrote = true end
  end
  check("a read that fails leaves no runtime and puts no parameter block on the bus",
    (obs.runtime == nil) and not wrote,
    string.format("runtime built: %s, %d write(s)", tostring(obs.runtime ~= nil), #obs.writes))
end

-- Save has to reach the ESC at all, or every "nothing else moved" case above
-- would be satisfied by a codec that never writes.
local function checkSaveReachesEsc(which, expectedBytes)
  local runtime, opts = openPage(which, copyOf(CODECS[which]._simulatorResponse))
  if not runtime or not editUnrelatedField(which) then
    check("Save reaches the ESC after a completed read and a pilot edit", false,
      "the page did not load, or the unrelated row was never built")
  else
    local payload = pressSave(opts)
    check("Save reaches the ESC after a completed read and a pilot edit",
      payload ~= nil and #payload == expectedBytes,
      payload and string.format("payload is %d bytes, expected %d", #payload, expectedBytes)
        or "no write went out")
  end
end

-- A write with no ESC bytes behind it is a refused write. Asserting on the codec
-- alone would pass while page_runtime published the zeros, so the claim is split:
-- the codec must decline, and it must say what was missing.
--
-- The codec name is IN the label: these run once per codec, and two identically
-- worded gates would collide in MUST_GO_RED -- the self-test counts duplicates
-- and reports them, because a duplicate is what would hide a case that only
-- registers itself on one of the two trees.
local function checkRefusal(which)
  local message, reason = CODECS[which].buildWriteMessage({}, function() end, function() end)
  gateCheck(string.format("[%s] a table with no ESC bytes is a refused write, not a payload of zeros", which),
    message == nil,
    message and string.format("built a %d-byte payload instead", #message.payload or 0) or nil)
  gateCheck(string.format("[%s] the refusal says what was missing", which),
    reason == "_raw",
    "reason was " .. tostring(reason))
end

local function runBluejayChecks()
  local which = "bluejay"
  local fixture = CODECS[which]._simulatorResponse
  out("")
  out(string.rep("-", 72))
  out("Bluejay: 66 bytes on the wire, 21 rows on the page")
  out(string.rep("-", 72))

  local layoutOk, layoutDetail = checkLayout(which, #fixture)
  check("the transcribed layout is the layout the shipped codec uses", layoutOk, layoutDetail)
  check("the fixture is the 66 bytes escGetParamBufferLength() returns for a 0xC1 ESC",
    #fixture == 66,
    string.format("the fixture carries %d bytes; 2 header + BLHELI_S_MSP_NUM_EEPROM_BYTES (0x40) = 66",
      #fixture))

  out("")
  out("every byte survives a save that changed something else")
  local lost, firstLost = roundTripSurvives(which, fixture)
  gateCheck(string.format(
    "all %d Bluejay byte positions survive all 256 of their values unchanged",
    #fixture), lost == 0,
    lost > 0 and string.format("%d of %d values came back changed; first: %s",
      lost, #fixture * 256, firstLost) or nil)

  -- The same statement through the real page, so it is a fact about the suite and
  -- not only about a private function. Byte values are staged on purpose: every
  -- value in the shipped fixture happens to survive, so a case built on the
  -- fixture alone would pass on the pre-fix codec and prove nothing.
  out("")
  out("staged bytes, through the real page and the real Save button")
  for _, case in ipairs({
    { name = "startup_power_min", value = 1, was = "0" },
    { name = "startup_power_max", value = 0, was = "1" },
    { name = "pwm_frequency", value = 0, was = "192" },
    { name = "threshold_48to24", value = 1, was = "0" },
    { name = "threshold_96to48", value = 2, was = "3" },
  }) do
    local at = AT[which][case.name]
    local label = string.format(
      "a %s byte of %d survives a save that changed the beacon strength (pre-fix it was written %s)",
      case.name, case.value, case.was)
    local f, stagedOk = poke(which, fixture, case.name, case.value)
    local runtime, opts = openPage(which, f)
    if not stagedOk then
      gateCheck(label, false, "the fixture byte was not the value this case staged")
    elseif not runtime then
      gateCheck(label, false, "no runtime was built")
    elseif not editUnrelatedField(which) then
      gateCheck(label, false, "the Beacon Strength row was never built")
    else
      local payload = pressSave(opts)
      local got = payload and readByte(payload, at)
      gateCheck(label, got == case.value,
        payload and string.format("byte %d went out as %d, the ESC sent %d",
          at, got, case.value) or "no write went out")
    end
  end

  -- The vendor word at bytes 16..17: a u16 this page has no row for, kept as a
  -- number and written back as a number. It survived before the fix too, so it is
  -- deliberately NOT a gate -- it is here to catch a fix that starts the payload
  -- from something narrower than the ESC's whole block.
  do
    local label = "the vendor word at bytes 16..17 survives a save that changed the beacon strength"
    local f, stagedOk = poke(which, fixture, "mode_raw", 0xBEEF)
    local runtime, opts = openPage(which, f)
    if not stagedOk then
      check(label, false, "the byte was not staged")
    elseif not runtime or not editUnrelatedField(which) then
      check(label, false, "the page did not load, or the row was never built")
    else
      local payload = pressSave(opts)
      local got = payload and readU16(payload, AT[which].mode_raw)
      check(label, got == 0xBEEF,
        payload and string.format("wire got 0x%04X, expected 0xBEEF", got or 0) or "no write went out")
    end
  end

  out("")
  out("the two PWM-frequency thresholds are one decision wearing two rows")
  -- Untouched and out of order: the pre-fix encoder clamped 96->48 down to
  -- 48->24 on every save, so an ESC reporting the pair the other way round was
  -- corrected whether or not the pilot looked at either row.
  do
    local label = "an untouched threshold pair the other way round is left alone"
    local f = copyOf(fixture)
    f[AT[which].threshold_48to24] = 85
    f[AT[which].threshold_96to48] = 170
    local runtime, opts = openPage(which, f)
    if not runtime or not editUnrelatedField(which) then
      gateCheck(label, false, "the page did not load, or the row was never built")
    else
      local payload = pressSave(opts)
      local lo = payload and readByte(payload, AT[which].threshold_48to24)
      local hi = payload and readByte(payload, AT[which].threshold_96to48)
      gateCheck(label, lo == 85 and hi == 170,
        payload and string.format("wrote 48->24 %d and 96->48 %d, the ESC sent 85 and 170",
          lo, hi) or "no write went out")
    end
  end

  -- ...and the clamp still applies when the pilot moves one of the two. Not a
  -- gate: the pre-fix encoder clamped unconditionally, so it does this too. It is
  -- here to catch the opposite mistake -- a fix that drops the rule instead of
  -- scoping it to a moved row.
  do
    local label = "moving the 48->24 threshold below the 96->48 one still pulls the other down"
    local runtime, opts = openPage(which, copyOf(fixture))
    local field = runtime and rowField(ROWS[which].threshold_low)
    if not field then
      check(label, false, "the 48->24 threshold row was never built")
    else
      -- The fixture is 170/85, i.e. 67 % and 33 %. Setting the low one to 10 %
      -- leaves 33 % above it, which is the state the rule forbids.
      edit(field, 10)
      local payload = pressSave(opts)
      local lo = payload and readByte(payload, AT[which].threshold_48to24)
      local hi = payload and readByte(payload, AT[which].threshold_96to48)
      check(label, lo == hi,
        payload and string.format("wrote 48->24 %d and 96->48 %d; they must match", lo, hi)
          or "no write went out")
    end
  end

  do
    local label = "moving the 96->48 threshold above the 48->24 one is clamped to the ceiling"
    local runtime, opts = openPage(which, copyOf(fixture))
    local field = runtime and rowField(ROWS[which].threshold_high)
    if not field then
      check(label, false, "the 96->48 threshold row was never built")
    else
      -- The fixture is 170/85, i.e. 67 % and 33 %. Setting the high one to 90 %
      -- leaves it above the untouched 67 % ceiling, which is the state the rule
      -- forbids.
      edit(field, 90)
      local payload = pressSave(opts)
      local lo = payload and readByte(payload, AT[which].threshold_48to24)
      local hi = payload and readByte(payload, AT[which].threshold_96to48)
      local decoded = payload and CODECS[which]._decode(payload)
      local loShown = decoded and decoded.threshold_48to24
      local hiShown = decoded and decoded.threshold_96to48
      check(label, hi == 171 and hiShown ~= nil and hiShown == loShown,
        payload and string.format("wrote 48->24 %d (shown %s) and 96->48 %d (shown %s); 96->48 must clamp to 48->24 ceiling",
          lo, tostring(loShown), hi, tostring(hiShown))
          or "no write went out")
    end
  end

  out("")
  out("an edit still reaches the wire")
  do
    local label = "moving Motor Direction writes byte 14"
    local runtime, opts = openPage(which, copyOf(fixture))
    local field = runtime and rowField(ROWS[which].direction)
    if not field then
      check(label, false, "the Motor Direction row was never built")
    else
      edit(field, 2)
      local payload = pressSave(opts)
      local got = payload and readByte(payload, AT[which].motor_direction)
      check(label, got == 2,
        payload and string.format("byte 14 is %d, expected 2", got) or "no write went out")
    end
  end

  -- An edit of a row whose shown number is not the byte behind it still has to be
  -- encoded, not written back: the fix must not turn "preserve" into "ignore".
  do
    local label = "selecting Dynamic PWM Frequency writes 192, the byte that means it"
    local runtime, opts = openPage(which, copyOf(fixture))
    local field = runtime and rowField(ROWS[which].pwm)
    if not field then
      check(label, false, "the PWM Frequency row was never built")
    else
      edit(field, 0)
      local payload = pressSave(opts)
      local got = payload and readByte(payload, AT[which].pwm_frequency)
      check(label, got == 192,
        payload and string.format("byte 13 is %d, expected 192", got) or "no write went out")
    end
  end

  out("")
  out("payload, refusal and load gate")
  checkSaveReachesEsc(which, 66)
  checkRefusal(which)
  checkLoadGate(which)
end

local function runAm32Checks()
  local which = "am32"
  local fixture = CODECS[which]._simulatorResponse
  out("")
  out(string.rep("-", 72))
  out("AM32: 50 bytes on the wire, 31 rows on the page")
  out(string.rep("-", 72))

  local layoutOk, layoutDetail = checkLayout(which, #fixture)
  check("the transcribed layout is the layout the shipped codec uses", layoutOk, layoutDetail)
  check("the fixture is the 50 bytes escGetParamBufferLength() returns for a 0xC2 ESC",
    #fixture == 50,
    string.format("the fixture carries %d bytes; 2 header + AM32_NUM_EEPROM_BYTES (0x30) = 50",
      #fixture))

  out("")
  out("every byte survives a save that changed something else")
  local lost, firstLost = roundTripSurvives(which, fixture)
  gateCheck(string.format(
    "all %d AM32 byte positions survive all 256 of their values unchanged",
    #fixture), lost == 0,
    lost > 0 and string.format("%d of %d values came back changed; first: %s",
      lost, #fixture * 256, firstLost) or nil)

  -- The timing-advance byte is the one the issue names, and the READ direction
  -- is not what this fix changes: decode() decodes the same eight wires to the
  -- same positions as before. So none of these is a gate -- they all pass on the
  -- pre-fix codec, and a gate check that cannot go red is worse than no check.
  -- They are here to catch the mistake this change could most easily make, which
  -- is the opposite one: a fix that "normalises" the numbering on the way in and
  -- quietly re-maps what the pilot sees.
  out("")
  out("the two firmware generations' numbering of the timing advance (read direction, unchanged)")
  for _, case in ipairs({
    { wire = 0, row = 0, note = "legacy, the first position" },
    { wire = 2, row = 2, note = "legacy, the third position" },
    { wire = 10, row = 0, note = "10..42, the first position" },
    { wire = 11, row = 0, note = "10..42, a value the older numbering has no position for" },
    { wire = 26, row = 2, note = "10..42, the third position" },
    { wire = 34, row = 3, note = "10..42, the fourth position" },
    { wire = 42, row = 3, note = "10..42, above the last position of the older numbering" },
    { wire = 5, row = 3, note = "legacy, clamped into range" },
  }) do
    local label = string.format("timing advance %d decodes to position %d (%s)",
      case.wire, case.row, case.note)
    local f, stagedOk = poke(which, fixture, "timing_advance", case.wire)
    local runtime = openPage(which, f)
    local got = runtime and runtime.data and runtime.data.timing_advance
    if not stagedOk then
      gateCheck(label, false, "the fixture byte was not the value this case staged")
    else
      check(label, got == case.row,
        got and string.format("the row shows %s", tostring(got)) or "no runtime was built")
    end
  end

  -- Two of these four are gates and two are not, and the difference is a fact
  -- about the pre-fix encoder rather than about how interesting the case is: 11
  -- and 42 are wire words the pre-fix encoder could not reproduce (it wrote 10
  -- and 34), while 26 and 3 happen to be exactly what it wrote for those two
  -- positions. Marking all four as gates would make the self-test demand that
  -- two of them go red, and they cannot.
  out("")
  out("staged timing bytes, through the real page and the real Save button")
  for _, case in ipairs({
    { wire = 11, was = "10", gate = true },
    { wire = 42, was = "34", gate = true },
    { wire = 26, was = "26", gate = false },
    { wire = 3, was = "3", gate = false },
  }) do
    local label = string.format(
      "a timing advance of %d survives a save that changed the beep volume (pre-fix it was written %s)",
      case.wire, case.was)
    local emit = case.gate and gateCheck or check
    local f, stagedOk = poke(which, fixture, "timing_advance", case.wire)
    local runtime, opts = openPage(which, f)
    if not stagedOk then
      gateCheck(label, false, "the fixture byte was not the value this case staged")
    elseif not runtime then
      gateCheck(label, false, "no runtime was built")
    elseif not editUnrelatedField(which) then
      gateCheck(label, false, "the Beep Volume row was never built")
    else
      local payload = pressSave(opts)
      local got = payload and readByte(payload, AT[which].timing_advance)
      emit(label, got == case.wire,
        payload and string.format("byte 26 went out as %d, the ESC sent %d",
          got, case.wire) or "no write went out")
    end
  end

  -- Moving the timing row must still be encoded, in the generation the ESC uses
  -- -- not written back, and not forced into the other one.
  --
  -- None of these is a gate: the pre-fix encoder produced the same three bytes,
  -- because it did encode a row the pilot moved. They are the healthy-path half
  -- of the fix -- the case that fails if "preserve" is ever implemented as
  -- "ignore" -- and a gate claim they cannot back is not made.
  out("")
  out("an edit still reaches the wire, in the ESC's own numbering")
  for _, case in ipairs({
    { wire = 11, row = 2, want = 26, note = "an ESC on the 10..42 numbering" },
    { wire = 26, row = 3, want = 34, note = "an ESC on the 10..42 numbering" },
    { wire = 2, row = 1, want = 1, note = "an ESC on the 0..3 numbering" },
  }) do
    local label = string.format("moving the timing advance to position %d writes %d (%s)",
      case.row, case.want, case.note)
    local f, stagedOk = poke(which, fixture, "timing_advance", case.wire)
    local runtime, opts = openPage(which, f)
    local field = stagedOk and runtime and rowField(ROWS[which].timing) or nil
    if not field then
      check(label, false, stagedOk and "the Timing Advance row was never built" or "the byte was not staged")
    else
      edit(field, case.row)
      local payload = pressSave(opts)
      local got = payload and readByte(payload, AT[which].timing_advance)
      check(label, got == case.want,
        payload and string.format("byte 26 is %d, expected %d", got, case.want) or "no write went out")
    end
  end

  -- A row whose shown number is not the byte behind it, on AM32's side.
  do
    local label = "moving Motor KV from 500 to 900 writes the byte that means 900"
    local f, stagedOk = poke(which, fixture, "motor_kv", 12)
    local runtime, opts = openPage(which, f)
    local field = stagedOk and runtime and rowField(ROWS[which].motorKv) or nil
    if not field then
      check(label, false, stagedOk and "the Motor KV row was never built" or "the byte was not staged")
    else
      edit(field, 900)
      local payload = pressSave(opts)
      -- 900 KV is byte 22, and byte 22 reads back as 900.
      local got = payload and readByte(payload, AT[which].motor_kv)
      check(label, got == 22,
        payload and string.format("byte 29 is %d, expected 22", got) or "no write went out")
    end
  end

  out("")
  out("payload, refusal and load gate")
  checkSaveReachesEsc(which, 50)
  checkRefusal(which)
  checkLoadGate(which)
end

local function runChecks()
  pages.bluejay = loadPage("bluejay")
  pages.am32 = loadPage("am32")
  runBluejayChecks()
  runAm32Checks()
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("ESC forward programming: unedited bytes survive a save (#2339)")
out(string.rep("=", 72))

CODECS.bluejay = loadCodec("bluejay")
CODECS.am32 = loadCodec("am32")

runChecks()

local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the same cases against the pre-fix codecs
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

-- Level-two long strings, not the plain form, because the spliced code contains
-- `data[field[1]]` and a bare "]]" in there closes a plain long string early --
-- which parses as a syntax error a long way from the cause.
local BLUEJAY_PREFIX = [==[
local function clamp(value, min, max)
  value = math.floor((value or 0) + 0.5)
  if value < min then return min end
  if value > max then return max end
  return value
end

local function readValue(buf, wireType)
  if wireType == "u16" then return mspcodec.readU16(buf) or 0 end
  local raw = mspcodec.readU8(buf) or 0
  if wireType == "startup_power_min" then return clamp(raw * 1000 / 2047 + 1000, 1000, 1125) end
  if wireType == "startup_power_max" then return clamp(raw * 1000 / 250 + 1000, 1004, 1300) end
  if wireType == "pwm_frequency" and raw == 192 then return 0 end
  if wireType == "threshold" then return clamp(raw * 100 / 255, 0, 100) end
  return raw
end

local function writeValue(payload, wireType, value)
  if wireType == "u16" then
    mspcodec.writeU16(payload, value or 0)
    return
  end
  local raw = value or 0
  if wireType == "startup_power_min" then raw = clamp(((value or 1000) - 1000) * 2047 / 1000, 0, 255) end
  if wireType == "startup_power_max" then raw = clamp(((value or 1004) - 1000) * 250 / 1000, 0, 255) end
  if wireType == "pwm_frequency" and tonumber(value) == 0 then raw = 192 end
  if wireType == "threshold" then raw = clamp((value or 0) * 255 / 100, 0, 255) end
  mspcodec.writeU8(payload, raw)
end

local function decode(buf)
  buf.offset = 1
  local data = {_raw = {}}
  for i = 1, #buf do data._raw[i] = buf[i] end
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2])
  end
  return data
end

local function encode(data)
  local payload = {}
  local original96 = data and data.threshold_96to48
  if data and data.threshold_48to24 and data.threshold_96to48 and data.threshold_96to48 > data.threshold_48to24 then
    data.threshold_96to48 = data.threshold_48to24
  end
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    writeValue(payload, field[2], data and data[field[1]])
  end
  if data then data.threshold_96to48 = original96 end
  return payload
end

]==]

local AM32_PREFIX = [==[
local function clamp(value, min, max)
  value = math.floor((value or 0) + 0.5)
  if value < min then return min end
  if value > max then return max end
  return value
end

local function decodeTiming(raw, data)
  data._timing_advance_encoding = "legacy"
  if raw >= 10 and raw <= 42 then
    data._timing_advance_encoding = "new"
    return clamp((raw - 10) / 8, 0, 3)
  end
  return clamp(raw, 0, 3)
end

local function encodeTiming(value, data)
  local normalized = clamp(value, 0, 3)
  if data and data._timing_advance_encoding == "new" then
    return 10 + normalized * 8
  end
  return normalized
end

local function readValue(buf, wireType, data)
  local raw = mspcodec.readU8(buf) or 0
  if wireType == "timing" then return decodeTiming(raw, data) end
  if wireType == "motor_kv" then return raw * 40 + 20 end
  if wireType == "servo_low" then return raw * 2 + 750 end
  if wireType == "servo_high" then return raw * 2 + 1750 end
  if wireType == "servo_neutral" then return raw + 1374 end
  if wireType == "low_voltage" then return raw + 250 end
  if wireType == "current_limit" then return raw * 2 end
  return raw
end

local function writeValue(payload, wireType, value, data)
  local raw = value
  if wireType == "timing" then raw = encodeTiming(value, data) end
  if wireType == "motor_kv" then raw = clamp(((value or 20) - 20) / 40, 0, 255) end
  if wireType == "servo_low" then raw = clamp(((value or 750) - 750) / 2, 0, 255) end
  if wireType == "servo_high" then raw = clamp(((value or 1750) - 1750) / 2, 0, 255) end
  if wireType == "servo_neutral" then raw = clamp((value or 1374) - 1374, 0, 255) end
  if wireType == "low_voltage" then raw = clamp((value or 250) - 250, 0, 255) end
  if wireType == "current_limit" then raw = clamp((value or 0) / 2, 0, 255) end
  mspcodec.writeU8(payload, raw or 0)
end

local function decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2], data)
  end
  return data
end

local function encode(data)
  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    writeValue(payload, field[2], data and data[field[1]], data)
  end
  return payload
end

]==]

-- The pre-fix buildWriteMessage, which built a message with no payload rather
-- than refusing. The refusal is part of the fix, so it goes back with the rest.
local WRITE_MESSAGE_PREFIX = [==[
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

local function bluejayPreFix(source, nl)
  -- (1) everything from clamp() to layout(): the whole normalize/encoded/raw
  -- block and both codec directions, replaced by the pre-fix ones. clamp() itself
  -- is re-declared in the replacement, so the region starts there and ends where
  -- the next unrelated function begins.
  source = presplice(source, "local function clamp(value, min, max)", "local function layout(data)",
    (BLUEJAY_PREFIX:gsub("\n", nl)), "Bluejay codec directions")
  -- (2) buildWriteMessage(), bounded by the next statement after it.
  source = presplice(source, "function msp.buildWriteMessage(data, onWritten, onError)",
    "msp._decode = decode", (WRITE_MESSAGE_PREFIX:gsub("\n", nl)), "Bluejay buildWriteMessage")
  return source
end

local function am32PreFix(source, nl)
  -- (1) everything from clamp() to the msp table: the whole normalize/encoded
  -- block and both codec directions, replaced by the pre-fix ones.
  source = presplice(source, "local function clamp(value, min, max)", "local msp = {",
    (AM32_PREFIX:gsub("\n", nl)), "AM32 codec directions")
  -- (2) buildWriteMessage()
  source = presplice(source, "function msp.buildWriteMessage(data, onWritten, onError)",
    "msp._decode = decode", (WRITE_MESSAGE_PREFIX:gsub("\n", nl)), "AM32 buildWriteMessage")
  return source
end

-- Four ways, before a spliced codec is allowed to stand in for the pre-fix one.
-- Each of these has caught a self-test that was quietly proving nothing.
--
-- The fourth is the one that matters and it is per codec, because "is this the
-- pre-fix codec?" has a different answer for each:
--   * Bluejay's pre-fix decode() ALSO kept `_raw`, so the buffer's presence says
--     nothing. What it did instead is clamp threshold_96to48 onto
--     threshold_48to24 on every save -- so a block whose pair is the other way
--     round comes back rewritten, and byte 47 reads 84 where a codec that leaves
--     an untouched row alone leaves 170. (The first attempt at this check asked
--     whether byte 7 moved, which proved nothing: 0 is a legal minimum-startup-
--     power byte and normalizes straight back to 0.)
--   * AM32's pre-fix decode() kept no buffer at all, so its absence is the
--     signature.
local function verifySplice(which, original, sabotaged, expectedBytes, discriminate)
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

  -- 3. it loads
  package.loaded[CODEC_KEYS[which]] = nil
  local ok, codec = pcall(function() return assert(realLoadfile(tmp))() end)
  if not ok then
    problems[#problems + 1] = "does not load: " .. tostring(codec):gsub(".*%.lua:%d+: ", "")
  else
    -- 4. it is the pre-fix codec, and not a module that broke some other way
    local recognised, why = discriminate(codec, expectedBytes)
    if not recognised then problems[#problems + 1] = why end
  end

  os.remove(tmp)
  package.loaded[CODEC_KEYS[which]] = nil
  return #problems == 0, table.concat(problems, "; ")
end

local function allZeroBlock(bytes, signature)
  local buf = {}
  for i = 1, bytes do buf[i] = 0 end
  buf[1] = signature
  return buf
end

-- Bluejay: the out-of-order threshold pair. Byte 46 reads as 33 % and byte 47 as
-- 67 %, so the pre-fix clamp pulls byte 47 down onto byte 46 and writes 84.
local function looksPreFixBluejay(codec, bytes)
  local buf = allZeroBlock(bytes, 193)
  buf[46] = 85
  buf[47] = 170
  local out = codec._encode(codec._decode(buf))
  if type(out) ~= "table" then
    return false, "encode() returned " .. tostring(out) .. " for a full table"
  end
  if #out ~= bytes then
    return false, string.format("writes %d bytes for a %d byte block, expected %d",
      #out, bytes, bytes)
  end
  if out[47] == 170 then
    return false, "leaves an out-of-order threshold pair alone, so this is not the pre-fix codec"
  end
  if out[47] ~= 84 then
    return false, string.format("writes byte 47 as %d, the pre-fix codec writes 84 there",
      out[47])
  end
  return true
end

-- AM32: the pre-fix decode() kept no raw buffer, and that absence is the point.
local function looksPreFixAm32(codec, bytes)
  local data = codec._decode(allZeroBlock(bytes, 194))
  if type(data) ~= "table" then
    return false, "decode() returned " .. tostring(data) .. " for a full block"
  end
  if data._raw ~= nil then
    return false, "decode() kept a raw buffer, so this is not the pre-fix codec"
  end
  local out = codec._encode(data)
  if type(out) ~= "table" then
    return false, "encode() returned " .. tostring(out) .. " for a decoded block"
  end
  if #out ~= bytes then
    return false, string.format("writes %d bytes for a %d byte block, expected %d",
      #out, bytes, bytes)
  end
  return true
end

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the byte-preservation checks must go red on the pre-fix codecs")
  out(string.rep("=", 72))

  local originalBluejay = readFile(BLUEJAY_SRC)
  local originalAm32 = readFile(AM32_SRC)

  local sabotagedBluejay = bluejayPreFix(originalBluejay, newlineOf(originalBluejay))
  local sabotagedAm32 = am32PreFix(originalAm32, newlineOf(originalAm32))

  -- Each splice is proved to be the pre-fix codec before it is allowed to stand
  -- in for one -- different file, reads back from disk, loads, and carries that
  -- codec's own pre-fix signature (see looksPreFixBluejay / looksPreFixAm32).
  local bluejaySpliceOk, bluejaySpliceDetail =
    verifySplice("bluejay", originalBluejay, sabotagedBluejay, 66, looksPreFixBluejay)
  out(string.format("  %s  Bluejay splice: %s", bluejaySpliceOk and "ok   " or "FAIL ",
    bluejaySpliceDetail ~= "" and bluejaySpliceDetail
      or "different file, reads back, loads, 66 bytes, and clamps the threshold pair"))
  if not bluejaySpliceOk then os.exit(1) end

  local am32SpliceOk, am32SpliceDetail =
    verifySplice("am32", originalAm32, sabotagedAm32, 50, looksPreFixAm32)
  out(string.format("  %s  AM32 splice: %s", am32SpliceOk and "ok   " or "FAIL ",
    am32SpliceDetail ~= "" and am32SpliceDetail
      or "different file, reads back, loads, 50 bytes, and keeps no raw buffer"))
  if not am32SpliceOk then os.exit(1) end

  -- The page binds its codec into a module-level local, so both pages have to be
  -- reloaded -- runChecks() does that on entry, and the redirects below are what
  -- make each page's requireModule() land on a temp file instead of the
  -- checked-out one. One temp file per codec, because the redirect a single
  -- loadfile() stands in for has to be told which codec it is replacing.
  local redirects = {
    { match = "msp_esc_parameters_bluejay%.lua$", file = writeTmp(sabotagedBluejay) },
    { match = "msp_esc_parameters_am32%.lua$", file = writeTmp(sabotagedAm32) },
  }
  local originalLoadfile = _G.loadfile
  _G.loadfile = function(path, ...)
    if type(path) == "string" and path:match("%.lua$") then
      for i = 1, #redirects do
        if path:match(redirects[i].match) then
          redirects[i].hits = (redirects[i].hits or 0) + 1
          return realLoadfile(redirects[i].file, ...)
        end
      end
      return realLoadfile(PREFIX .. path, ...)
    end
    return realLoadfile(path, ...)
  end
  REPLACE_MATCH, REPLACE_FILE = nil, nil

  -- Loaded DIRECTLY from the temp files, not through loadCodec(): that helper
  -- reads the checked-out path with realLoadfile, which the redirect below does
  -- not touch -- so loading through it here would have handed pass 2 the FIXED
  -- codec and made the exhaustive checks and the refusals pass for the wrong
  -- reason. That is not a hypothetical: it is what the first version of this
  -- self-test did, and nine of the seventeen gates stayed green because of it.
  --
  -- And then dropped from package.loaded again, because that direct load left the
  -- sabotaged module there and requireModule() memoizes -- the page would then
  -- find it and never call loadfile() at all, so the redirect would never be
  -- exercised and the page-level cases would be a rerun of pass 1.
  local function loadCodecFrom(file)
    package.loaded[CODEC_KEYS.bluejay] = nil
    return assert(realLoadfile(file))()
  end
  CODECS.bluejay = loadCodecFrom(redirects[1].file)
  CODECS.am32 = loadCodecFrom(redirects[2].file)
  package.loaded[CODEC_KEYS.bluejay] = nil
  package.loaded[CODEC_KEYS.am32] = nil

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = 0

  -- MUST_GO_RED is reset too, and the pass-1 list is kept to compare against.
  -- Left accumulating, it would list every gate twice and the verdict would read
  -- "all 30" for 15 distinct checks -- and a duplicate is exactly what would hide
  -- a case that only registers itself on one of the two trees.
  local pass1Gates = {}
  for i = 1, #MUST_GO_RED do pass1Gates[MUST_GO_RED[i]] = (pass1Gates[MUST_GO_RED[i]] or 0) + 1 end
  MUST_GO_RED = {}

  out("")
  out("pass 2: the same cases against the pre-fix codecs")
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

  CODECS.bluejay = loadCodec("bluejay")
  CODECS.am32 = loadCodec("am32")
  _G.loadfile = originalLoadfile
  for i = 1, #redirects do os.remove(redirects[i].file) end

  out("")
  local totalHits, served = 0, {}
  for i = 1, #redirects do
    totalHits = totalHits + (redirects[i].hits or 0)
    served[#served + 1] = string.format("%s %d", redirects[i].match, redirects[i].hits or 0)
  end
  out(string.format("  (sabotaged codecs served %d time(s): %s)", totalHits, table.concat(served, ", ")))
  if totalHits == 0 then
    out("  FAIL  the sabotaged codecs never ran -- pass 2 proved nothing")
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
      "SELF-TEST FAILED -- %d of %d byte-preservation checks cannot detect the missing raw buffer",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format(
    "SELF-TEST PASSED -- all %d byte-preservation checks go red without the raw buffer",
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