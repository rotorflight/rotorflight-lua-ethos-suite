-- Behaviour check for the Scorpion block's length (#2457).
--
-- Run it:
--     lua5.4 bin/esc_parameters_scorpion/verify_scorpion_block_length.lua
--     lua5.4 bin/esc_parameters_scorpion/verify_scorpion_block_length.lua --self-test
--
-- What the defect under test is:
--   lib/msp_esc_parameters_scorpion.lua described 76 bytes where the flight
--   controller's block for a Scorpion is 84. The last eight are two U32 words the
--   sibling suite names stick_max and stick_zero; this codec stopped at gov_integral.
--
--   That is not cosmetic on the write path. msp.c's MSP_SET_ESC_PARAMETERS is an
--   opaque move of escGetParamBufferLength() bytes:
--
--       const uint8_t len = escGetParamBufferLength();
--       if (len == 0) return MSP_RESULT_ERROR;
--       sbufReadData(src, escGetParamUpdBuffer(), len);
--       if (!escCommitParameters()) return MSP_RESULT_ERROR;
--
--   The only length check is `len == 0`. sbufReadData is an unchecked memcpy
--   (streambuf.c) and the destination paramUpdBuffer is a persistent static array
--   that nothing clears per message -- escGetParamUpdBuffer() re-fills it from
--   paramBuffer only in the BLHeli_S case. So a 76-byte payload leaves the firmware
--   copying eight bytes from past the end of the received frame into escCommitParameters
--   and on to the ESC. The last two words are stored from whatever those bytes were.
--
--   Where 84 comes from (rotorflight-firmware src/main/sensors/esc_sensor.c, and the
--   Scorpion is ESC_SIG_TRIB = 0x53, served by tribSensorInit, not the 4-way path):
--
--       static uint16_t tribParamAddrLen[] =
--           { 0x0020, 0x1008, 0x230E, 0x8204, 0x8502, 0x1406, 0x1808, 0x3408 };
--       tribCalcParamBufferLength() sums (x & 0xFF)         -> 32+8+14+4+2+6+8+8 = 82
--       #define PARAM_HEADER_SIZE 2
--       escGetParamBufferLength() = PARAM_HEADER_SIZE + it  -> 2 + 82 = 84
--
--   The TRIB path sets paramPayloadLength = tribCalcParamBufferLength() when the
--   ESC's UNC/status handshake completes (tribDecodeReadStatusResp), so the length is
--   a constant 84 for this vendor and not a count the ESC varies.
--
-- What it drives, and why:
--   * The codec directly, for the round-trip length and the field layout.
--   * The real app/pages/esc_forward_scorpion.lua through the real
--     app/pages/esc_forward_vendor.lua, app/field_layout.lua and app/page_runtime.lua,
--     because the wire check presses the pilot's own Save button and reads the MSP 218
--     payload -- asserting on the codec alone would leave open that the page truncates.
--
-- Which checks go RED without the fix:
--   6 of 12. --self-test proves that rather than asserting it: it cuts the two stick
--   fields out of REST_FIELDS and the eight fixture bytes back out, then requires all
--   six to fail. It cuts both the field list and the fixture because either alone
--   leaves the other able to hide the change -- a field list without fixture bytes
--   fails to load/short, and fixture bytes with no fields were never decoded.
--
--   Checks that LOOK like gates and deliberately are not:
--     * "the transcribed trib table sums to 84" is a constant in this file -- it cannot
--       go red whatever the codec does, so it documents the firmware number rather than
--       gating on it;
--     * the two-transcription offset parity check compares the field lists here and
--       never reads the codec (the same reason the serial harness names it).
--   A gate that cannot go red is worse than no gate, so both are registered with
--   check() and say here why.
--
--   It clears package.loaded before the sabotage load: the codec self-caches under
--   rfsuite.lib.msp_esc_parameters_scorpion, so without that the staged file is never
--   served and a working cut looks broken.

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

-- Defined HERE, above every use: a local declared further down is not in scope for a
-- closure defined up here, and runChecks() reads files.
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
-- The two field lists, and the firmware's own length
-- ---------------------------------------------------------------------------

local function offsetsOf(fields, from)
  local WIDTH = { u8 = 1, u16 = 2, u32 = 4 }
  local offsets, cursor = {}, from or 1
  for i = 1, #fields do
    offsets[fields[i][1]] = { offset = cursor, width = WIDTH[fields[i][2]] }
    cursor = cursor + WIDTH[fields[i][2]]
  end
  return offsets, cursor - 1
end

local function readLE(buf, at, width)
  local v, mul = 0, 1
  for i = 0, width - 1 do
    v = v + (buf[at + i] or 0) * mul
    mul = mul * 256
  end
  return v
end

-- This suite's list, transcribed. escinfo_1..32 are generated by a loop in the codec
-- and written out here, so a change to the generated count fails loudly instead of
-- shifting every later offset silently.
local LOCAL_TAIL = {
  { "esc_mode", "u16" }, { "bec_voltage", "u16" }, { "rotation", "u16" },
  { "telemetry_protocol", "u16" }, { "protection_delay", "u16" }, { "min_voltage", "u16" },
  { "max_temperature", "u16" }, { "max_current", "u16" }, { "cutoff_handling", "u16" },
  { "max_used", "u16" }, { "motor_startup_sound", "u16" },
  { "serial_number", "u32" }, { "firmware_version", "u16" },
  { "soft_start_time", "u16" }, { "runup_time", "u16" }, { "bailout", "u16" },
  { "gov_proportional", "u32" }, { "gov_integral", "u32" },
  { "stick_max", "u32" }, { "stick_zero", "u32" },
}

-- The sibling's, from
-- rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/esc_parameters_scorpion.lua
-- (FIELD_SPEC). It is the specification for the layout AND for the fixture below.
local EDGETX_TAIL = {
  { "esc_mode", "u16" }, { "bec_voltage", "u16" }, { "rotation", "u16" },
  { "telemetry_protocol", "u16" }, { "protection_delay", "u16" }, { "min_voltage", "u16" },
  { "max_temperature", "u16" }, { "max_current", "u16" }, { "cutoff_handling", "u16" },
  { "max_used", "u16" }, { "motor_startup_sound", "u16" },
  { "serial_number", "u32" }, { "firmware_version", "u16" },
  { "soft_start_time", "u16" }, { "runup_time", "u16" }, { "bailout", "u16" },
  { "gov_proportional", "u32" }, { "gov_integral", "u32" },
  { "stick_max", "u32" }, { "stick_zero", "u32" },
}

local function fullList(tail)
  local fields = { { "esc_signature", "u8" }, { "esc_command", "u8" } }
  for i = 1, 32 do fields[#fields + 1] = { "escinfo_" .. i, "u8" } end
  for i = 1, #tail do fields[#fields + 1] = tail[i] end
  return fields
end

local LOCAL_FIELDS = fullList(LOCAL_TAIL)
local EDGETX_FIELDS = fullList(EDGETX_TAIL)

-- The sibling's SIM_RESPONSE, verbatim. This suite's shipped fixture must equal it
-- byte for byte -- that is the "layout-compatible with EdgeTX" acceptance in #2457
-- stated as something the repository checks rather than a sentence in a comment.
local EDGETX_SIM_RESPONSE = {
  83, 128,
  84, 114, 105, 98, 117, 110, 117, 115, 32, 69, 83, 67, 45, 54, 83, 45,
  56, 48, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0,
  3, 0, -- esc_mode
  3, 0, -- bec_voltage
  1, 0, -- rotation
  3, 0, -- telemetry_protocol
  136, 19, -- protection_delay
  22, 3, -- min_voltage
  16, 39, -- max_temperature
  64, 31, -- max_current
  136, 19, -- cutoff_handling
  0, 0, -- max_used
  1, 0, -- motor_startup_sound
  7, 2, -- serial_number bytes 1-2
  0, 6, -- serial_number bytes 3-4
  63, 0, -- firmware_version
  160, 15, -- soft_start_time
  64, 31, -- runup_time
  208, 7, -- bailout
  100, 0, 0, 0, -- gov_proportional
  200, 0, 0, 0, -- gov_integral
  1, 0, 0, 0, -- stick_max
  200, 250, 0, 0, -- stick_zero
}

-- The flight controller's own length for a Scorpion block, transcribed. The table
-- below is the whole of it: tribCalcParamBufferLength() sums the low bytes and
-- escGetParamBufferLength() adds the two header bytes.
local TRIB_PARAM_ADDR_LEN = { 0x0020, 0x1008, 0x230E, 0x8204, 0x8502, 0x1406, 0x1808, 0x3408 }
local PARAM_HEADER_SIZE = 2
local function firmwareBlockLength()
  local sum = 0
  for i = 1, #TRIB_PARAM_ADDR_LEN do sum = sum + (TRIB_PARAM_ADDR_LEN[i] % 256) end
  return PARAM_HEADER_SIZE + sum
end

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

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

local function pokeU32(buf, at, value)
  buf[at] = value % 256
  buf[at + 1] = math.floor(value / 256) % 256
  buf[at + 2] = math.floor(value / 65536) % 256
  buf[at + 3] = math.floor(value / 16777216) % 256
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
  if fixture then
    for i = 1, #fixture do f[i] = fixture[i] end
  end
  reply = f

  local opts = freshOpts()
  scorpionPage.open(opts)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  opts.__runtime = obs.runtime
  return obs.runtime, opts, codec
end

local function rowField(key)
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].label:find(key, 1, true) then return obs.fieldOrder[i] end
  end
  return nil
end

-- The first NUMBER row, not the first row: this page's first entries are choice
-- fields (esc_mode, rotation, bec_voltage) inside an expansion panel.
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

-- The codec's own round trip, with no page involved: decode the fixture through the
-- read message's reply callback, then encode it back through the write message.
local function codecPayload(codec, fixture)
  local decoded
  local read = codec.buildReadMessage(function(d) decoded = d end, function() end)
  read.processReply(nil, fixture)
  if not decoded then return nil end
  local write = codec.buildWriteMessage(decoded, function() end, function() end)
  return write and write.payload or nil
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------

local function runChecks()
  resetObs()
  resetModules()
  local codec = requireModule("lib/msp_esc_parameters_scorpion.lua")
  local baseFixture = codec.buildReadMessage(function() end, function() end).simulatorResponse
  local localOffsets = offsetsOf(LOCAL_FIELDS)
  local edgetxOffsets, edgetxEnd = offsetsOf(EDGETX_FIELDS)

  out("")
  out("the block is the length the flight controller asks for")

  -- A constant in this file: it cannot go red, so it documents the firmware number
  -- rather than gating on it.
  check("the transcribed trib table sums to 84 (PARAM_HEADER_SIZE + 82)",
    firmwareBlockLength() == 84,
    string.format("firmware length is %d", firmwareBlockLength()))
  check("the sibling suite's field list covers those 84 bytes",
    edgetxEnd == 84,
    string.format("the EdgeTX transcription ends at byte %d", edgetxEnd))

  do
    local payload = codecPayload(codec, baseFixture)
    gateCheck("the codec round-trips the fixture to 84 bytes",
      payload ~= nil and #payload == 84,
      payload and string.format("the codec wrote %d bytes", #payload) or "the codec built no payload")
  end

  do
    -- The write the pilot's Save actually puts on the bus. Asserting on the codec alone
    -- would leave open that the page truncates the payload on the way out.
    local runtime, opts = openScorpion()
    if not runtime or not editUnrelatedField() then
      gateCheck("the page's Save writes 84 bytes on MSP 218", false,
        "the page did not load, or no number row was built")
    else
      local payload = pressSave(opts)
      gateCheck("the page's Save writes 84 bytes on MSP 218",
        payload ~= nil and #payload == 84,
        payload and string.format("the wire payload is %d bytes", #payload) or "no write went out")
    end
  end

  do
    -- The shipped fixture must equal the sibling's byte for byte, over every one of
    -- the 84 bytes and in length. This is #2457's acceptance in one assertion.
    local n = math.max(#baseFixture, #EDGETX_SIM_RESPONSE)
    local firstDiff = nil
    for i = 1, n do
      if (baseFixture[i] or 0) ~= (EDGETX_SIM_RESPONSE[i] or 0) then
        firstDiff = i
        break
      end
    end
    gateCheck("the shipped fixture equals the sibling suite's, byte for byte over all 84",
      firstDiff == nil and #baseFixture == #EDGETX_SIM_RESPONSE,
      string.format("fixture is %d bytes against %d, first difference at byte %s",
        #baseFixture, #EDGETX_SIM_RESPONSE, firstDiff and tostring(firstDiff) or "none"))
  end

  out("")
  out("parity with the sibling suite's field list")

  do
    local wrong = {}
    for _, field in ipairs(EDGETX_TAIL) do
      local mine, theirs = localOffsets[field[1]], edgetxOffsets[field[1]]
      if not mine then
        wrong[#wrong + 1] = field[1] .. " is missing here"
      elseif mine.offset ~= theirs.offset or mine.width ~= theirs.width then
        wrong[#wrong + 1] = string.format("%s at %d/%dB here, %d/%dB there",
          field[1], mine.offset, mine.width, theirs.offset, theirs.width)
      end
    end
    -- NOT a gate: it compares two transcriptions and never reads the codec, so it would
    -- stay green while the codec's field list was cut back. The gate that ties the
    -- layout to the code is the decode parity below.
    check("every field the sibling names sits at the same byte with the same width (two transcriptions, not the codec)",
      #wrong == 0,
      #wrong > 0 and table.concat(wrong, "; ") or nil)
  end

  do
    -- The gate: what the codec DECODES from the fixture must equal what the sibling's
    -- fixture carries at the sibling's offsets, field for field. It fails if a field is
    -- missing, renamed, at the wrong offset or the wrong width -- and it fails on the
    -- two fields #2457 appended, which is what ties the length change to the codec.
    local data
    local read = codec.buildReadMessage(function(d) data = d end, function() end)
    read.processReply(nil, baseFixture)
    local wrong = {}
    if data == nil then
      wrong[#wrong + 1] = "the codec decoded nothing"
    else
      for _, field in ipairs(EDGETX_FIELDS) do
        local off = edgetxOffsets[field[1]]
        local want = readLE(EDGETX_SIM_RESPONSE, off.offset, off.width)
        local got = tonumber(data[field[1]])
        if got ~= want then
          wrong[#wrong + 1] = string.format("%s decoded %s, the reference byte %d holds %d",
            field[1], tostring(data[field[1]]), off.offset, want)
        end
      end
    end
    gateCheck("the codec decodes every field to the value at the sibling's byte",
      #wrong == 0,
      #wrong > 0 and (table.concat(wrong, "; ")) or nil)
  end

  out("")
  out("the eight appended bytes are the ESC's own, and survive a save")

  do
    local data
    local read = codec.buildReadMessage(function(d) data = d end, function() end)
    read.processReply(nil, baseFixture)
    local atMax = edgetxOffsets.stick_max.offset
    local atZero = edgetxOffsets.stick_zero.offset
    gateCheck("stick_max and stick_zero decode from bytes 77..84",
      data ~= nil
        and tonumber(data.stick_max) == readLE(EDGETX_SIM_RESPONSE, atMax, 4)
        and tonumber(data.stick_zero) == readLE(EDGETX_SIM_RESPONSE, atZero, 4),
      data == nil and "the codec decoded nothing"
        or string.format("decoded %s/%s against %d/%d at bytes %d/%d",
          tostring(data.stick_max), tostring(data.stick_zero),
          readLE(EDGETX_SIM_RESPONSE, atMax, 4), readLE(EDGETX_SIM_RESPONSE, atZero, 4),
          atMax, atZero))
  end

  do
    -- The page has no row for either word, so the only thing that can happen to them is
    -- that they are carried through. Poke them and require the save to write the ESC's
    -- own bytes back at 77..84 rather than zeroing them.
    local f = copyOf(baseFixture)
    pokeU32(f, edgetxOffsets.stick_max.offset, 123456789)
    pokeU32(f, edgetxOffsets.stick_zero.offset, 424242)
    local runtime, opts = openScorpion(f)
    if not runtime or not editUnrelatedField() then
      gateCheck("a save writes the ESC's own stick words back at bytes 77..84", false,
        "the page did not load, or no number row was built")
    else
      local payload = pressSave(opts)
      local atMax = edgetxOffsets.stick_max.offset
      local atZero = edgetxOffsets.stick_zero.offset
      local intact = payload ~= nil
        and readLE(payload, atMax, 4) == readLE(f, atMax, 4)
        and readLE(payload, atZero, 4) == readLE(f, atZero, 4)
      gateCheck("a save writes the ESC's own stick words back at bytes 77..84", intact,
        payload and string.format("wire %d/%d against the ESC's %d/%d",
          readLE(payload, atMax, 4), readLE(payload, atZero, 4),
          readLE(f, atMax, 4), readLE(f, atZero, 4)) or "no write went out")
    end
  end

  do
    -- The page is the reason these are carried and not edited: it builds no row for
    -- either, so nothing can be written into them and nothing can be lost. If a row is
    -- ever added, this says so rather than letting the length change look complete.
    local page = readFile(PREFIX .. "app/pages/esc_forward_scorpion.lua")
    local rowsForThem = 0
    for _, name in ipairs({ "stick_max", "stick_zero" }) do
      if page:find('key = "' .. name .. '"', 1, true) then rowsForThem = rowsForThem + 1 end
    end
    check("the page builds no row for stick_max or stick_zero",
      rowsForThem == 0,
      string.format("%d row(s) built for them", rowsForThem))
  end

  out("")
  out("unchanged: the fields around the appended bytes")

  do
    check("serial_number still starts at byte 57 and firmware_version at byte 61",
      localOffsets.serial_number.offset == 57 and localOffsets.firmware_version.offset == 61,
      string.format("serial at %d, firmware at %d",
        localOffsets.serial_number.offset, localOffsets.firmware_version.offset))
    check("the model string still starts at byte 3",
      localOffsets.escinfo_1.offset == 3,
      string.format("escinfo_1 at %d", localOffsets.escinfo_1.offset))
  end

  out("")
  out("not driven here, and why:")
  out("  the ESC's own stick words   no row shows them, so what they MEAN is not a")
  out("                              question this page answers; only that all 84 bytes")
  out("                              are carried and written back. What a real ESC does")
  out("                              with a misaligned block is unchecked -- no hardware")
  out("                              in reach -- and is stated as a claim, not a result.")
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("Scorpion: the block is the length the flight controller asks for (#2457)")
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

-- The pre-fix state, in both halves: REST_FIELDS ends at gov_integral, and the fixture
-- ends there too. Anchors stay INSIDE a single line -- an anchor with a "\n" in it
-- matches nothing on a CRLF checkout, and core.autocrlf=true with no .gitattributes
-- means the checkout IS CRLF on Windows.
local function prefixCodec(src, nl)
  local out = replace(src,
    '  {"gov_integral", "u32"},',
    '{"stick_zero", "u32"},',
    '  {"gov_integral", "u32"},', "the stick field list", nl)
  out = replace(out,
    '  200, 0, 0, 0, -- gov_integral',
    '200, 250, 0, 0',
    '  200, 0, 0, 0 -- gov_integral', "the appended fixture bytes", nl)
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
  out("self-test: the gate checks must go red without the eight appended bytes")
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
    local fixture = pre.buildReadMessage(function() end, function() end).simulatorResponse
    if #fixture ~= 76 then
      problems[#problems + 1] = string.format("the pre-fix fixture is %d bytes, not 76", #fixture)
    end
    local decoded
    pre.buildReadMessage(function(d) decoded = d end, function() end).processReply(nil, fixture)
    if decoded and (decoded.stick_max ~= nil or decoded.stick_zero ~= nil) then
      problems[#problems + 1] = "the stick words are still decoded"
    end
    if #problems > 0 then
      for i = 1, #problems do out("  FAIL  sabotage check: " .. problems[i]) end
      os.exit(1)
    end
    out("  the sabotaged codec is the pre-fix shape: 76-byte fixture, no stick words")
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
    out(string.format("SELF-TEST FAILED -- %d of %d gate checks cannot detect the missing eight bytes",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d gate checks go red without the eight appended bytes",
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
