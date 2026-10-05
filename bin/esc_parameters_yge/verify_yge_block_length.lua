-- Behaviour check for the YGE block length (#2458).
--
-- Run it:
--     lua5.4 bin/esc_parameters_yge/verify_yge_block_length.lua
--     lua5.4 bin/esc_parameters_yge/verify_yge_block_length.lua --self-test
--
-- What the defect under test is:
--   The block is not a fixed size. The flight controller derives its length from the
--   count the ESC itself reports -- rotorflight-firmware src/main/io/esc_sensor.c:
--   ygeParamCount = ygeParams[0], paramPayloadLength = ygeParamCount * 2,
--   escGetParamFullBufferLength() = PARAM_HEADER_SIZE + paramPayloadLength with
--   PARAM_HEADER_SIZE = 2, and OPENYGE_PARAM_CACHE_SIZE_MAX = 64 -- so the real range
--   is 1..64 parameters.
--
--   The codec described 30 fixed fields, 58 bytes, which is 2 + 28 * 2: correct for an
--   ESC reporting 28 and for no other. Its own fixture said 32 and stopped at 58.
--   Measured on the shipped fixture, bytes 3..4 read 32, and 2 + 32 * 2 = 66 -- the
--   length the sibling suite's fixture carries for the same ESC.
--
--   On the write side this is not a truncation but a stale read, which is why the fix
--   refuses rather than pads. msp.c's only length check on MSP_SET_ESC_PARAMETERS is
--   `if (len == 0)`, sbufReadData's memcpy has no bounds check, and the destination
--   paramUpdBuffer is a static array that nothing clears per message -- so a short
--   payload has the firmware copy the overflow out of the PREVIOUS contents of that
--   buffer and escCommitParameters() then write those bytes to the ESC.
--
-- What it drives, and why:
--   * The real lib/msp_esc_parameters_yge.lua for decode(), encode() and the fixture.
--   * The real app/pages/esc_forward_yge.lua through app/pages/esc_forward_vendor.lua
--     and the real app/page_runtime.lua, for the refusal: a nil message is only a
--     REFUSED write if page_runtime treats it that way, and that is the whole point of
--     the change, so the Save button is pressed and the log line read.
--   * The real app/field_layout.lua, because the row the harness moves to make a save
--     reachable goes through the same accessors every field uses.
--
-- Which checks go RED without the fix:
--   8 of 12. --self-test proves that: it restores the fixed-length decode() and
--   encode(), the unconditional buildWriteMessage and the 58-byte fixture, and
--   requires all eight to fail.
--
--   The one that looks like a gate and is not: "a buffer built for 20 parameters
--   carries 20 in bytes 3..4" checks THIS FILE's own blockOf() helper, so it is green
--   in both passes by construction. It is what makes the length matrix meaningful,
--   and it is registered with check() so the verdict below does not claim it.
--
--   The cut is anchored on the function headers and on a line that is exactly "end"
--   FOLLOWED BY A BLANK LINE -- decode() and encode() each contain an inner block
--   whose "end" also sits in column 0, and a plain end anchor matches that one first
--   and leaves the function unterminated. The staged file must read back byte for
--   byte, must still LOAD, and must produce the pre-fix payload length of 58, or a
--   cut that did nothing reports itself as a working sabotage.
--
--   package.loaded is cleared before the sabotage load: the codec self-caches, and
--   pass 1 has filled that key, so the staged file otherwise hands back the REAL
--   module and a working cut looks broken. Same trap as the two harnesses before it.
--   The replacement text is [==[ ]==], never [[ ]], because the surrounding helpers
--   contain "]]".
--
--   And one measurement trap worth naming: the first version of the length matrix
--   built its buffer by appending to a copy of the shipped fixture, so every case
--   still carried the fixture's own count of 32 in bytes 3..4 and every "different N"
--   was a lie. The count is now poked into the buffer explicitly, and one check
--   asserts that the buffer really says what the case claims.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"

local SELF_TEST = arg[1] == "--self-test"

local CODEC_PATTERN = "msp_esc_parameters_yge%.lua$"
local CODEC_SOURCE = PREFIX .. "lib/msp_esc_parameters_yge.lua"

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
  obs.refused = {}
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
-- Buffers of a stated length
-- ---------------------------------------------------------------------------

local PARAM_HEADER_BYTES = 2
local MAX_PARAM_COUNT = 64
local FIXED_BLOCK_BYTES = 58   -- what WIRE_FIELDS covers, header included
-- The count at which the block is long enough to carry every named field: 58 bytes is
-- 2 + 28 * 2, so 28 parameters is exactly the one count the pre-fix codec was right
-- about and the smallest that can be written without inventing anything.
local FIXED_PARAM_COUNT = (FIXED_BLOCK_BYTES - PARAM_HEADER_BYTES) / 2

local function pokeU16(buf, at, value)
  buf[at] = value % 256
  buf[at + 1] = math.floor(value / 256) % 256
end

local function u16At(buf, at)
  return (buf[at] or 0) + (buf[at + 1] or 0) * 256
end

local function copyOf(t)
  local c = {}
  for i = 1, #t do c[i] = t[i] end
  return c
end

-- A block of exactly 2 + 2*count bytes, carrying that count in bytes 3..4.
--
-- The first version built these by copying the shipped fixture and appending to it,
-- so every case still carried the fixture's own 32 and every "different N" was a
-- lie that passed. Hence the explicit poke, and the case below that asserts the
-- buffer really says what it claims.
local function blockOf(count, template)
  local length = PARAM_HEADER_BYTES + count * 2
  local buf = {}
  for i = 1, length do buf[i] = template[i] or 0 end
  pokeU16(buf, 3, count)
  return buf, length
end

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

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

local function resetModules()
  package.loaded["rfsuite.app.pages.esc_forward_vendor"] = nil
  package.loaded["rfsuite.app.esc_error"] = nil
  package.loaded["rfsuite.app.close_key"] = nil
  package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = nil
  package.loaded["rfsuite.app.pages.esc_forward_yge"] = nil
  package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil
end

local function rowField(key)
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].label:find(key, 1, true) then return obs.fieldOrder[i] end
  end
  return nil
end

-- One open of the real YGE page, answered with `fixture`.
--
-- Loaded through _G.loadfile, NOT realLoadfile: realLoadfile bypasses the redirect,
-- so the self-test's sabotaged codec would never be served.
local function openYge(fixture)
  resetObs()
  resetModules()
  ygePage = assert(_G.loadfile("app/pages/esc_forward_yge.lua"))()

  local codec = requireModule("lib/msp_esc_parameters_yge.lua")
  reply = fixture

  local opts = freshOpts()
  ygePage.open(opts)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  opts.__runtime = obs.runtime
  return obs.runtime, opts, codec
end

local ROW_GOV_P = "mfg.yge.gov_p"

-- Moves a row the length cases do not care about, so Save is reachable the way it
-- is for a pilot: canSave() requires dirty, and refreshDirty() compares the whole
-- table.
--
-- The range checks are nil-guarded because a block for a small parameter count does
-- not carry every row, and a field spec with no bounds is what a field the block did
-- not describe looks like from here.
local function editUnrelatedField()
  local field = rowField(ROW_GOV_P)
  if not field then return false end
  local current = field.get()
  if type(current) ~= "number" then return false end
  local next_ = current + 1
  if field.max and next_ > field.max then next_ = field.min or current end
  if next_ == current then return false end
  field.set(next_)
  return true
end

-- The pilot's Save button. Returns the MSP 218 payload, or nil plus the reason the
-- runtime logged -- which is the case this whole change is about.
local function pressSave(opts)
  local runtime = opts.__runtime
  if not runtime or not runtime.headerHandle then return nil, "no runtime" end
  local before = #obs.writes
  runtime:confirmSave(runtime.headerHandle.focusSave)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
  for i = before + 1, #obs.writes do
    local w = obs.writes[i]
    if w.command == 218 then return w.payload, nil end
  end
  return nil, runtime.pendingSaveError or "no write went out"
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------

-- A message that lists all 64 counts is a message nobody reads. Four, and a count.
local function summarise(list, limit)
  local n = #list
  local head = {}
  for i = 1, math.min(n, limit or 4) do head[#head + 1] = list[i] end
  return string.format("%d of them: %s%s", n, table.concat(head, "; "), n > (limit or 4) and ", ..." or "")
end

local function runChecks()
  resetObs()
  resetModules()
  local codec = requireModule("lib/msp_esc_parameters_yge.lua")
  local fixture = codec.buildReadMessage(function() end, function() end).simulatorResponse

  out("")
  out("the fixture describes the ESC it stands for")
  do
    -- The length is derived, not asserted: 2 + 2 * (bytes 3..4).
    local count = u16At(fixture, 3)
    local expected = PARAM_HEADER_BYTES + count * 2
    gateCheck(string.format("the shipped fixture is 2 + 2 * its own count (%d parameters, %d bytes)",
        count, expected),
      #fixture == expected,
      string.format("fixture is %d bytes, its count %d asks for %d", #fixture, count, expected))
  end

  do
    -- The count really is where it is claimed to be. Without this the matrix below
    -- could be asserting against buffers that all say 32.
    --
    -- NOT a gate, and the reason is the whole point: this checks THIS FILE's own
    -- blockOf() helper, not the codec, so it is green in both passes by construction.
    -- It is here because it is what makes the matrix meaningful, and it says so.
    local buf = blockOf(20, fixture)
    check("a buffer built for 20 parameters carries 20 in bytes 3..4 (this file's own helper)",
      u16At(buf, 3) == 20 and #buf == 42,
      string.format("bytes 3..4 read %d, buffer is %d bytes", u16At(buf, 3), #buf))
  end

  out("")
  out("the length follows the count, over the whole range the firmware allows")

  do
    -- 1 .. OPENYGE_PARAM_CACHE_SIZE_MAX. Every count, not a sample: "the ones that
    -- matter" is the kind of list that rots, and this one is a loop.
    local wrong = {}
    for count = 1, MAX_PARAM_COUNT do
      local buf = blockOf(count, fixture)
      local runtime = openYge(buf)
      local data = runtime and runtime.data
      local wantLength = PARAM_HEADER_BYTES + count * 2
      if not data then
        wrong[#wrong + 1] = string.format("N=%d built no editor", count)
      elseif tonumber(data.param_count) ~= count then
        wrong[#wrong + 1] = string.format("N=%d read back as %s", count, tostring(data.param_count))
      elseif tonumber(data.expected_length) ~= wantLength then
        wrong[#wrong + 1] = string.format("N=%d expected_length %s, not %d",
          count, tostring(data.expected_length), wantLength)
      end
    end
    gateCheck(string.format("all %d parameter counts decode to their own block length", MAX_PARAM_COUNT),
      #wrong == 0,
      #wrong > 0 and summarise(wrong) or nil)
  end

  do
    -- The write side over the whole range, at the CODEC, because the length rule is
    -- the codec's and the page cannot exercise it at every count: a block for a small
    -- count does not carry the row the harness would move, so there is nothing for a
    -- pilot to change and nothing to make dirty. The rule the matrix asserts:
    --
    --   N >= 28  the block carries every field this codec names, so the payload is
    --            written and is exactly 2 + 2N bytes.
    --   N <  28  the block ends inside the field list, so at least one named field
    --            was never read. Writing it would mean inventing it, so the write is
    --            REFUSED and the reason names the field. This is the misalignment
    --            case #2458 describes, and padding it to 58 would be the defect.
    local wrong, refused = {}, {}
    for count = 1, MAX_PARAM_COUNT do
      local buf = blockOf(count, fixture)
      local data
      local reader = codec.buildReadMessage(function(d) data = d end, function() end)
      reader.processReply(nil, copyOf(buf))
      local writer, reason
      if data then
        writer, reason = codec.buildWriteMessage(data, function() end, function() end)
      else
        reason = "decode() returned nothing"
      end
      local payload = writer and writer.payload or nil
      local wantLength = PARAM_HEADER_BYTES + count * 2
      if count >= FIXED_PARAM_COUNT then
        if not payload then
          wrong[#wrong + 1] = string.format("N=%d refused (%s)", count, tostring(reason))
        elseif #payload ~= wantLength then
          wrong[#wrong + 1] = string.format("N=%d wrote %d bytes, not %d", count, #payload, wantLength)
        end
      else
        if payload then
          wrong[#wrong + 1] = string.format("N=%d wrote %d bytes for a block too short to read them from",
            count, #payload)
        else
          refused[#refused + 1] = string.format("%d:%s", count, tostring(reason))
        end
      end
    end
    gateCheck(string.format("every count from 28 to %d writes exactly 2 + 2 * count bytes", MAX_PARAM_COUNT),
      #wrong == 0,
      #wrong > 0 and summarise(wrong) or nil)
    gateCheck(string.format("every count below %d is refused, naming the field it never read", FIXED_PARAM_COUNT),
      #refused == FIXED_PARAM_COUNT - 1,
      string.format("%d of %d refused%s", #refused, FIXED_PARAM_COUNT - 1,
        #refused > 0 and (": " .. table.concat(refused, ", ", 1, math.min(3, #refused))) or ""))
  end

  do
    -- And the same length through the pilot's own Save button, at the counts whose
    -- block carries rows. This is the half that proves the plumbing: page_runtime
    -- hands the decoded table to buildWriteMessage, and the payload that comes out
    -- has to be the count's length and not the field count's.
    local wrong = {}
    for _, count in ipairs({ 28, 32, 40, MAX_PARAM_COUNT }) do
      local buf = blockOf(count, fixture)
      local runtime, opts = openYge(buf)
      if not runtime or not editUnrelatedField() then
        wrong[#wrong + 1] = string.format("N=%d never became saveable", count)
      else
        local payload, reason = pressSave(opts)
        local wantLength = PARAM_HEADER_BYTES + count * 2
        if not payload then
          wrong[#wrong + 1] = string.format("N=%d refused: %s", count, tostring(reason))
        elseif #payload ~= wantLength then
          wrong[#wrong + 1] = string.format("N=%d wrote %d bytes, not %d", count, #payload, wantLength)
        end
      end
    end
    gateCheck("the pilot's Save writes the count's length, not the field count's",
      #wrong == 0,
      #wrong > 0 and summarise(wrong) or nil)
  end

  do
    -- The tail the pilot never sees goes back byte for byte. Filled with zeros it
    -- would be four parameters the pilot did not choose, written to the ESC.
    local tailValues = { 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 }
    local buf = blockOf(32, fixture)
    local at = FIXED_BLOCK_BYTES + 1
    for i = 1, #tailValues do buf[at + i - 1] = tailValues[i] end
    local runtime, opts = openYge(buf)
    if not runtime or not editUnrelatedField() then
      gateCheck("the unknown tail comes back byte for byte", false, "the page never became saveable")
    else
      local payload = pressSave(opts)
      local same = payload ~= nil
      for i = 1, #tailValues do
        same = same and payload[at + i - 1] == tailValues[i]
      end
      gateCheck("the unknown tail comes back byte for byte", same,
        -- tostring, not %d: against the pre-fix codec the payload is 58 bytes and
        -- payload[59] is nil, which string.format rejects outright. The message has
        -- to survive the case it is reporting.
        payload and string.format("wire tail %s,%s,%s,%s against the ESC's %d,%d,%d,%d",
          tostring(payload[at]), tostring(payload[at + 1]),
          tostring(payload[at + 2]), tostring(payload[at + 3]),
          tailValues[1], tailValues[2], tailValues[3], tailValues[4]) or "no write went out")
    end
  end

  out("")
  out("a block that cannot be written is refused, not padded")

  do
    -- A count of 0 and a count past the firmware's own cache ceiling. Padding either
    -- to 58 would send a length the ESC did not ask for, which is the defect.
    local refused, accepted = {}, {}
    for _, count in ipairs({ 0, MAX_PARAM_COUNT + 1, 255 }) do
      local buf = blockOf(count, fixture)
      local runtime, opts = openYge(buf)
      if runtime and editUnrelatedField() then
        local payload, reason = pressSave(opts)
        if payload then
          accepted[#accepted + 1] = string.format("%d -> %d bytes", count, #payload)
        else
          refused[#refused + 1] = string.format("%d (%s)", count, tostring(reason))
        end
      end
    end
    gateCheck(string.format("a count of 0, and one past the firmware's ceiling of %d, are refused", MAX_PARAM_COUNT),
      #accepted == 0,
      #accepted > 0 and ("wrote anyway: " .. summarise(accepted)) or nil)
  end

  do
    -- A block that arrives short of what its own count demands: the tail was never
    -- read, so there is nothing to write back and nothing may be invented.
    local buf = blockOf(32, fixture)
    for i = #buf, FIXED_BLOCK_BYTES + 3, -1 do buf[i] = nil end
    local runtime, opts = openYge(buf)
    if not runtime or not editUnrelatedField() then
      gateCheck("a block short of its own count is refused rather than zero-padded", false,
        "the page never became saveable")
    else
      local payload, reason = pressSave(opts)
      gateCheck("a block short of its own count is refused rather than zero-padded",
        payload == nil,
        payload and string.format("wrote %d bytes anyway", #payload)
          or ("refused, reason: " .. tostring(reason)))
    end
  end

  out("")
  out("unchanged: what the fix must not disturb")

  do
    -- The fields this codec names still decode to the values the fixture carries --
    -- esc_type 848 and the serial 43550 are the two the sibling harnesses pin.
    local runtime = openYge(copyOf(fixture))
    local data = runtime and runtime.data
    check("the named fields still decode (esc_type 848, serial 43550, firmware 1.03555)",
      data ~= nil and tonumber(data.esc_type) == 848
        and tonumber(data.serial_number) == 43550
        and tonumber(data.firmware_version) == 103555,
      data and string.format("esc_type %s, serial %s, firmware %s",
        tostring(data.esc_type), tostring(data.serial_number), tostring(data.firmware_version))
        or "the page built no editor")
  end

  do
    -- The timing translation and its raw twin, which two other harnesses pin.
    local runtime = openYge(copyOf(fixture))
    local data = runtime and runtime.data
    check("the timing row keeps its raw twin, which the untouched-row rule needs",
      data ~= nil and data.timing_raw ~= nil and data.lv_bec_voltage_raw ~= nil,
      "one of the raw twins is missing")
  end

  do
    -- A block that carries every field and asks for no tail at all: N = 28 is the one
    -- count the pre-fix codec was right about, and it must still work unchanged.
    local buf = blockOf(28, fixture)
    local runtime, opts = openYge(buf)
    if not runtime or not editUnrelatedField() then
      check("the one count the old fixed layout was right about still writes 58 bytes", false,
        "the page never became saveable")
    else
      local payload = pressSave(opts)
      check("the one count the old fixed layout was right about still writes 58 bytes",
        payload ~= nil and #payload == 58,
        payload and string.format("wrote %d bytes", #payload) or "no write went out")
    end
  end

  out("")
  out("not driven here, and why:")
  out("  the count a real YGE ESC reports   no YGE hardware here, and every number in")
  out("                                     this file comes from the fixture. What an ESC")
  out("                                     does with a misaligned block is unchecked too.")
  out("  msp.c's missing length check       firmware side, one line, and not this")
  out("                                     repository. See #2458's third point.")
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("YGE: the block length follows the count the ESC reports (#2458)")
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

local function replace(src, open, close, replacement, what, nl)
  local at = src:find(open, 1, true)
  if not at then error("sabotage: could not find the start of " .. what, 0) end
  local last = src:find(close, at, true)
  if not last then error("sabotage: could not find the end of " .. what, 0) end
  return (src:sub(1, at - 1) .. replacement .. nl .. src:sub(last + #close))
end

-- The pre-fix decode() and encode(), verbatim, and nothing else. The helpers above
-- them (paramCountOf, blockLengthFor, countIsPlausible and the three constants) are
-- left defined and unused on purpose: an unused local cannot change behaviour, and
-- cutting them would widen the slice into whatever follows.
local PREFIX_DECODE = [==[local function decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2])
  end
  data.timing_raw = data.timing
  data.lv_bec_voltage_raw = data.lv_bec_voltage
  data.timing = motorTimingToUi(data.timing)
  return data
end]==]

local PREFIX_ENCODE = [==[local function encode(data)
  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    local value = data and data[field[1]] or 0
    if field[1] == "timing" then
      value = motorTimingFromUi(value, data and data.timing_raw)
    end
    writeValue(payload, field[2], value)
  end
  return payload
end]==]

local PREFIX_BUILD_WRITE = [==[function msp.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = encode(data),
    isWrite = true,
    processReply = function() if onWritten then onWritten() end end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end]==]

local function prefixCodec(src, nl)
  -- The close anchor is a line that is exactly "end" FOLLOWED BY A BLANK LINE, not
  -- just "end". All three functions here contain an inner block whose "end" also
  -- sits in column 0 -- decode()'s and encode()'s `for` loops do -- so a plain
  -- nl .. "end" matches the LOOP and leaves the function unterminated. The staged
  -- file then does not load, which is what the "must still LOAD" step caught; the
  -- anchor now skips those because an inner end is followed by code, not by a blank
  -- line.
  --
  -- Each replacement ends with its own "end" and is followed by one nl, because
  -- replace() consumes the close token -- blank line included -- and does not
  -- re-emit it.
  --
  -- (1) decode()
  local out = replace(src, "local function decode(buf)", nl .. "end" .. nl .. nl,
    PREFIX_DECODE, "decode()", nl)
  -- (2) encode()
  out = replace(out, "local function encode(data)", nl .. "end" .. nl .. nl,
    PREFIX_ENCODE, "encode()", nl)
  -- (3) buildWriteMessage's refusal, so pass 2 has the pre-fix behaviour on the write
  -- side too: it returned a message unconditionally, and a cut that left the refusal
  -- in would make the write-side gates pass for the wrong reason.
  out = replace(out,
    "function msp.buildWriteMessage(data, onWritten, onError)",
    nl .. "end" .. nl .. nl,
    PREFIX_BUILD_WRITE, "buildWriteMessage()", nl)
  -- (4) the fixture back to 58 bytes, which is what makes the length matrix lie in
  -- pass 2 rather than merely fail.
  --
  -- The "}" goes back into the replacement. The close anchor is nl .. "}", and
  -- replace() consumes the close token without re-emitting it -- so a close anchor
  -- that IS a piece of syntax has to be put back by the replacement, or the staged
  -- file loses SIMULATOR_RESPONSE's closing brace and does not load. That is the
  -- third time today this exact shape bit: the "end" in the Scorpion harness and the
  -- "end" in the YGE serial harness were both consumed the same way, and both were
  -- caught by the staged file failing to load rather than by reading the diff.
  out = replace(out,
    "  2, 19, -- current_limit",
    nl .. "}",
    "  2, 19 -- current_limit" .. nl .. "}", "the fixture's tail", nl)
  return out
end

local function stageSabotage(pattern, source, build)
  local nl = source:find("\r\n", 1, true) and "\r\n" or "\n"
  local sabotaged = build(source, nl)
  if sabotaged == source then error("sabotage: nothing was cut from " .. pattern, 0) end

  local path = os.tmpname() .. "_yge_len_prefix.lua"
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
  out("self-test: the gate checks must go red against the fixed-length codec")
  out(string.rep("=", 72))

  local ok, file = pcall(stageSabotage, CODEC_PATTERN, readFile(CODEC_SOURCE), prefixCodec)
  if not ok then
    out("  FAIL  " .. tostring(file))
    os.exit(1)
  end
  out(string.format("  %-32s cut and verified (%d bytes)", CODEC_PATTERN, readFile(file):len()))

  -- The pre-fix shape, verified three ways: the fixture is 58 bytes again, the
  -- payload is 58 bytes whatever the count says, and decode() reports no length at
  -- all. Any one of them alone could be satisfied by a partial cut.
  do
    package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil
    local pre = assert(realLoadfile(file))()
    local problems = {}
    local fixture = pre.buildReadMessage(function() end, function() end).simulatorResponse
    if #fixture ~= 58 then
      problems[#problems + 1] = "the fixture is " .. #fixture .. " bytes, not the pre-fix 58"
    end
    local buf = { unpack and {} or {} }
    for i = 1, 32 do buf[i] = fixture[i] or 0 end
    pokeU16(buf, 3, 32)
    local data = nil
    local msg = pre.buildReadMessage(function(d) data = d end, function() end)
    msg.processReply(nil, buf)
    if type(data) ~= "table" then
      problems[#problems + 1] = "decode() returned nothing for a 34-byte buffer"
    elseif data.expected_length ~= nil then
      problems[#problems + 1] = "the pre-fix decode reports an expected_length: " .. tostring(data.expected_length)
    end
    if data and data.param_count ~= nil then
      problems[#problems + 1] = "the pre-fix decode reports a param_count: " .. tostring(data.param_count)
    end
    local payload = nil
    if data then
      local w = pre.buildWriteMessage(data, function() end, function() end)
      if w then payload = w.payload end
    end
    if payload and #payload ~= 58 then
      problems[#problems + 1] = "the pre-fix payload is " .. #payload .. " bytes, not 58"
    end
    if #problems > 0 then
      for i = 1, #problems do out("  FAIL  sabotage check: " .. problems[i]) end
      os.exit(1)
    end
    out("  the sabotaged codec is the pre-fix shape: 58-byte fixture, 58-byte payload, no length reported")
  end

  REPLACE = { [CODEC_PATTERN] = file }

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = {}

  local pass1Gates = {}
  for i = 1, #MUST_GO_RED do pass1Gates[MUST_GO_RED[i]] = (pass1Gates[MUST_GO_RED[i]] or 0) + 1 end
  MUST_GO_RED = {}

  out("")
  out("pass 2: the same cases against the fixed-length codec")
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
    out(string.format("SELF-TEST FAILED -- %d of %d gate checks cannot detect the fixed-length codec",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d gate checks go red against the fixed-length codec",
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
