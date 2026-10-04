-- Behaviour check for the Hobbywing Platinum V5 forward-programming codec (#2341).
--
-- Run it:
--     lua5.3 bin/esc_hw5_opto/verify_hw5_opto.lua
--     lua5.3 bin/esc_hw5_opto/verify_hw5_opto.lua --self-test
--
-- What the issue asks for, and what this file finds:
--
--   Claim 1 -- an OPTO ESC shows a BEC Voltage row and every field after it is
--   read one byte too high. CONFIRMED, and the row is not the cause:
--
--     The layout was chosen by a PROFILE KEY. profileKey() returned
--     `<hardware_version>_PL_OPTO` for any OPTO model, and PROFILES carried
--     exactly one such entry, HW1104_V100456NB_PL_OPTO. Every OTHER OPTO model
--     missed the lookup, fell through to PROFILES.default, and got DEFAULT_ITEMS
--     -- bec_voltage at item 5 and active_freewheel at 15, where OPTO_ITEMS has
--     no bec_voltage and puts active_freewheel at 14. So the fields from item 5
--     up were read and written one byte off.
--
--     Measured on the pre-fix codec, an OPTO HW1106 over the codec's own
--     simulator fixture (bytes 66..81 = 0 0 0 3 0 11 6 5 25 1 0 0 24 0 0 2):
--
--       field              pre-fix shows   the byte says
--       bec_voltage        0              (no such byte -- it is not there)
--       startup_time       11             4
--       gov_p_gain         6              11
--       gov_i_gain         5              6
--       auto_restart       25             5
--       restart_time       1              25
--       brake_type         0              1
--       timing             24             0
--       rotation           0              24
--       startup_power      2              0
--
--     That is 9 of the 15 fields on the OPTO layout reading the wrong byte. Six
--     coincide: four of them sit BEFORE the missing BEC byte, so they were never
--     shifted, and two -- brake_force and active_freewheel -- happen to carry equal
--     bytes on either side of the boundary in this fixture. The count was measured
--     rather than tallied by hand, because the first version of this comment said
--     "six of seven" from a partial probe and was wrong in the pilot's favour.
--
--     A second, independent miss: OPTO was looked for in ONE of the two model
--     strings. The block carries the model twice -- bytes 35..50 as esc_type and
--     bytes 51..65 as mode_name, the same name spelled with spaces -- plus the
--     firmware version in bytes 3..18, and which of the three a given ESC puts
--     "OPTO" in is not something this file can know. The EdgeTX codec
--     concatenates both model strings for exactly that reason
--     (esc_parameters_hw5.lua:119, :251).
--
--   Claim 2 -- the Active Freewheel boolean is inverted. NOT REPRODUCIBLE, and
--   the issue does not say which way round is right:
--
--     this repo   lib/msp_esc_parameters_hw5.lua:21  {{"Enabled", 0}, {"Disabled", 1}}
--     EdgeTX      app/pages/.../escmfg/hw5/page.lua:687-690
--                 { value = 0, label = "Enabled" }, { value = 1, label = "Disabled" }
--
--     Identical. And the codec cannot invert it: decode() reads the byte and
--     encode() writes it straight back (checked below, both directions, on all
--     three layouts), so there is no place in this file where the sense could be
--     lost. The flight controller is no help either -- it treats the whole HW5
--     block as opaque and only ever memcmps it (esc_sensor.c:2387-2393, the 48
--     devinfo and 31 parameter payload bytes), so it never interprets a field.
--     The issue itself writes "0 = Enabled vs 1 = Disabled, **or vice versa
--     depending on firmware version**", which is a question rather than a
--     specification.
--
--     So there is nothing here to invert, and nothing to change. The parity check
--     exists so the answer stays a fact the repository carries: if either suite's
--     mapping moves, this goes red. It is NOT a gate, because it passes on the
--     pre-fix codec too.
--
-- What the fix is:
--   * The VARIANT chooses the LAYOUT and the VERSION chooses the CHOICE LISTS.
--     profileFor() looks the version up as before and then, for an OPTO model,
--     returns that profile's tables with OPTO_ITEMS. An explicit
--     `<version>_PL_OPTO` entry still wins where one exists, because its tables
--     may differ -- HW1104's do not, but that is a fact about HW1104.
--   * isOpto() searches all three descriptive strings.
--   * The merged profile is built once per version rather than per call, because
--     isFieldAvailable() reaches profileFor() once per field per page build.
--
-- And one thing the issue does NOT mention, found while measuring: FIELD_META
-- declares startup_time as min 4, max 25, default 11 -- and decode() hands the page
-- the RAW byte, which runs 0..21, so the row's own range is violated by its own
-- decoder. That is a real defect and it is NOT fixed here: it lives in decode() and
-- encode() rather than in the layout, it affects every HW5 model whether OPTO or
-- not, and EdgeTX settles it by adding 4 on the way in and taking it off again on
-- the way out (esc_parameters_hw5.lua:263-265, :296-298). It has its own pull
-- request and its own harness, so this one stays about the layout.
--
-- Which checks go RED on the pre-fix codec -- twelve, and --self-test reports
-- exactly which: eight of the nine OPTO layout cases, the BEC row, the OPTO byte
-- alignment, the OPTO write alignment, and the page building no BEC row.
--
-- One case is deliberately NOT in that list, and it started out as a gate:
-- OPTO hardware HW1104, because PROFILES carried HW1104_V100456NB_PL_OPTO and so
-- that model already came out right. It is checked anyway -- it is the fix's own
-- regression guard on the one model that used to work -- and it is marked in place
-- with the reason, so a later reader does not have to rediscover it from the
-- self-test output.
--
-- --self-test proves the list rather than asserting it: it splices the pre-fix
-- profile selection back into a copy of the codec and requires every one of them to
-- fail. It also verifies the splice four ways before using it, because a sabotage
-- that breaks the module differently from the defect under test proves nothing
-- about the defect.
--
-- The round trip, the Active Freewheel parity and the "models that were already
-- right" checks are deliberately NOT gates -- they pass on the pre-fix codec too,
-- and a gate check that cannot go red is worse than no check.

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

-- Set by the self-test: the codec path suffix the redirect replaces, and the temp
-- file to serve instead. A redirect that never fires would leave the second pass a
-- disguise of the first, so the hit count is reported and required.
local REPLACE_MATCH, REPLACE_FILE, replaceHits = nil, nil, 0

-- requireModule() calls loadfile() with a path carrying no directory part; on the
-- radio the working directory is src/rfsuite.
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
-- makes on the setter it built and stubbing it would make the write-direction cases
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

-- realLoadfile, deliberately, not the redirect above: the redirect prepends the
-- suite prefix to anything ending in .lua, which is right for requireModule()'s bare
-- "lib/..." paths and wrong for this absolute-ish one.
local function loadCodec(file)
  package.loaded[CODEC_KEY] = nil
  return assert(realLoadfile(file or CODEC_SRC))()
end

-- The page is reloaded per runChecks(), and it has to be: esc_forward_hw5.lua binds
-- the codec into a module-level `local msp` at its line 5, so reloading only the
-- codec would leave the page still holding the first one and pass 2 would be a rerun
-- of pass 1 wearing a different label. The page carries no self-cache guard.
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

-- The item layouts, transcribed.
--
-- NOT taken from the shipped tables: choosing the layout is the thing under test,
-- so a transcription of the shipped tables would only restate the bug. These come
-- from the EdgeTX codec's DEFAULT_LAYOUT (esc_parameters_hw5.lua:29-46) and
-- OPTO_LAYOUT (:72-88), which agree with this codec's own DEFAULT_ITEMS and
-- OPTO_ITEMS on every index -- and the checks below confirm the codec AGREES with
-- them, so the transcription cannot drift away silently.
local DEFAULT_LAYOUT = {
  flight_mode = 1, lipo_cell_count = 2, volt_cutoff_type = 3, cutoff_voltage = 4,
  bec_voltage = 5, startup_time = 6, gov_p_gain = 7, gov_i_gain = 8, auto_restart = 9,
  restart_time = 10, brake_type = 11, brake_force = 12, timing = 13, rotation = 14,
  active_freewheel = 15, startup_power = 16,
}
local OPTO_LAYOUT = {
  flight_mode = 1, lipo_cell_count = 2, volt_cutoff_type = 3, cutoff_voltage = 4,
  startup_time = 5, gov_p_gain = 6, gov_i_gain = 7, auto_restart = 8, restart_time = 9,
  brake_type = 10, brake_force = 11, timing = 12, rotation = 13, active_freewheel = 14,
  startup_power = 15,
}
local HW1132_LAYOUT = {
  lipo_cell_count = 1, volt_cutoff_type = 2, cutoff_voltage = 3, bec_voltage = 4,
  response_time = 5, timing = 6, rotation = 7, active_freewheel = 8, startup_power = 9,
}
local HW1128_LAYOUT = {
  lipo_cell_count = 1, volt_cutoff_type = 2, cutoff_voltage = 3,
  brake_type = 5, brake_force = 6, timing = 7, rotation = 8,
  active_freewheel = 9, startup_power = 10,
}

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

-- A block with the descriptive strings replaced. Every case goes through here, so a
-- case cannot assert against a byte it failed to set.
--
-- A string longer than its field is TRUNCATED, not silently padded -- which is a
-- property of the fixture and not of the codec. The first version of this file used
-- "Platinum V5 OPTO" (15 characters) against model_b and reported a layout
-- mismatch that was really a field width; the string is now inside the field.
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

-- Which layout did the codec actually use? Asked of the codec, by what it exposes
-- -- isFieldAvailable() and the values it decoded -- rather than by a transcription
-- of its tables, because the selection is the thing under test.
--
-- A field's item index is recovered by moving one parameter byte at a time and
-- watching which row's value moves. That needs no knowledge of any layout at all,
-- which is the point: a wrong layout shows up as a wrong index rather than as a
-- disagreement between two copies of the same table.
local function layoutInUse(buf)
  local base = decodeWith(buf)
  local used = {}
  for offset = HEADER_BYTES + 1, BLOCK_BYTES do
    local poked = {}
    for i = 1, #buf do poked[i] = buf[i] end
    poked[offset] = (poked[offset] + 1) % 256
    local after = decodeWith(poked)
    for _, name in ipairs(codec.EDIT_FIELDS) do
      if after[name] ~= nil and base[name] ~= nil and after[name] ~= base[name] then
        used[name] = used[name] or (offset - HEADER_BYTES)
      end
    end
  end
  return base, used
end

local function layoutMatches(layout, expected)
  local wrong = {}
  for name, index in pairs(expected) do
    if layout[name] ~= index then
      wrong[#wrong + 1] = string.format("%s is at item %s, expected %d",
        name, tostring(layout[name]), index)
    end
  end
  for name, index in pairs(layout) do
    if expected[name] == nil then
      wrong[#wrong + 1] = string.format(
        "%s is at item %s and has no row in the layout this case expects", name, tostring(index))
    end
  end
  table.sort(wrong)
  return #wrong == 0, table.concat(wrong, "; ")
end

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

-- Which i18n key ends which row. The page's labels are unresolved @i18n(...)@ tags
-- at this point -- substituted at build time by
-- .vscode/scripts/resolve_i18n_tags.py, not at Lua runtime -- so the key IS the
-- label here.
local ROW_BEC = "mfg.hw5.bec_voltage"
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

-- A pilot edit: exactly the call Ethos makes on the widget's setter.
local function edit(field, value)
  field.set(value)
end

-- Moves a row the cases do not care about, so Save becomes reachable the way it is
-- for a real pilot. canSave() requires dirty, and refreshDirty() compares the whole
-- table, so an untouched page cannot be saved at all.
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

-- Every OPTO model the suite could meet, across all three places the string can
-- appear. One check for the whole set, reporting which combinations slipped -- a
-- gate per combination would be the same claim with nine labels.
local OPTO_CASES = {
  { what = "OPTO in the first model string", strings = {model_a = "Platinum_V5 OPTO"} },
  { what = "OPTO in the second model string", strings = {model_b = "Platinum OPTO"} },
  { what = "OPTO in the firmware string", strings = {firmware = "V1.0.2 OPTO"} },
  { what = "OPTO, hardware HW1104", strings = {hardware = "HW1104_V100456NB", model_a = "Platinum OPTO"} },
  { what = "OPTO, hardware HW1106", strings = {hardware = "HW1106_V100456NB", model_a = "Platinum OPTO"} },
  { what = "OPTO, hardware HW1121", strings = {hardware = "HW1121_V100456NB", model_a = "Platinum OPTO"} },
  { what = "OPTO, hardware HW1128", strings = {hardware = "HW1128_V100456NB", model_a = "Platinum OPTO"} },
  { what = "OPTO, hardware HW1132", strings = {hardware = "HW1132_V100456NB", model_a = "Platinum OPTO"} },
  { what = "OPTO, a hardware version with no profile at all",
    strings = {hardware = "HW9999_V000000NB", model_a = "Platinum OPTO"} },
}

local function checkOptoLayout()
  out("")
  out("OPTO: an ESC with no BEC has no BEC byte, so every later field moves up one")
  -- Hardware HW1104 is deliberately NOT a gate, and the self-test says so out loud:
  -- PROFILES carried HW1104_V100456NB_PL_OPTO, so HW1104 was the ONE OPTO model
  -- that came out right before the fix. It is a regression case -- the fix must not
  -- break the model that worked -- and a gate that cannot go red is not a gate.
  for _, case in ipairs(OPTO_CASES) do
    local buf = blockWith(case.strings)
    local data, used = layoutInUse(buf)
    local label = string.format("%s uses the OPTO layout, with no BEC Voltage row", case.what)
    if data.active_freewheel == nil then
      check(label, false, "nothing decoded at all")
    else
      local ok, detail = layoutMatches(used, OPTO_LAYOUT)
      if not ok then
        detail = detail .. "; bec_voltage available: "
          .. tostring(codec.isFieldAvailable(data, "bec_voltage"))
      end
      if case.what:find("HW1104", 1, true) then check(label, ok, detail) else gateCheck(label, ok, detail) end
    end
  end

  -- The issue's own phrasing, on its own. Split out from the layout walk because
  -- it fails for a different reason: the row is built from isFieldAvailable(), not
  -- from the offsets.
  local slipped = {}
  for _, case in ipairs(OPTO_CASES) do
    local data = decodeWith(blockWith(case.strings))
    if codec.isFieldAvailable(data, "bec_voltage") then
      slipped[#slipped + 1] = case.what
    end
  end
  gateCheck("no OPTO model is offered a BEC Voltage row",
    #slipped == 0,
    #slipped > 0 and ("offered one for: " .. table.concat(slipped, "; ")) or nil)

  -- ...and a model that HAS a BEC must still get one. NOT a gate: it passes before
  -- the fix too, and it is here so the fix cannot be "hide the row everywhere".
  local withBec = decodeWith(blockWith({model_a = "Platinum_V5"}))
  check("a model that HAS a BEC is still offered the BEC Voltage row",
    codec.isFieldAvailable(withBec, "bec_voltage"),
    "isFieldAvailable said no")
end

-- The consequence, on the bytes. This is the one the issue describes: not a wrong
-- row, but every field after it read and written one byte off.
local function checkOptoByteAlignment()
  out("")
  out("OPTO: every field reads the byte its own item names")

  -- The codec's own fixture on an OPTO HW1106 -- the model that fell through
  -- before. Bytes 66..81 are 0 0 0 3 0 11 6 5 25 1 0 0 24 0 0 2, and under the
  -- OPTO layout those are startup_time 11, gov_p_gain 6, gov_i_gain 5,
  -- auto_restart 25, restart_time 1, brake_type 0, brake_force 0, timing 24,
  -- rotation 0, active_freewheel 0, startup_power 2.
  local buf = blockWith({hardware = "HW1106_V100456NB", model_a = "Platinum OPTO"})
  local data = decodeWith(buf)

  local wrong = {}
  -- Every field is compared against its own byte. The Startup Time row is NOT
  -- special here: this change is about which byte a field sits on, and the byte a
  -- field shows is the subject of a separate pull request.
  local function expect(name)
    local at = itemByte(OPTO_LAYOUT[name])
    if data[name] ~= buf[at] then
      wrong[#wrong + 1] = string.format("%s reads %s, byte %d says %s",
        name, tostring(data[name]), at, tostring(buf[at]))
    end
  end
  for _, name in ipairs({ "startup_time", "gov_p_gain", "gov_i_gain", "auto_restart",
                          "restart_time", "brake_type", "brake_force", "timing",
                          "rotation", "active_freewheel", "startup_power" }) do
    expect(name)
  end
  gateCheck("on an OPTO HW1106 every field reads the byte the OPTO layout names it",
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)

  -- ...and a save writes those bytes back, not the ones a BEC model would use.
  local edited = decodeWith(buf)
  local timingAt = itemByte(OPTO_LAYOUT.timing)
  edited.timing = (buf[timingAt] + 1) % 256
  local payload = encodeWith(edited)
  local writeWrong = {}
  if not payload then
    writeWrong[#writeWrong + 1] = "no write payload"
  else
    for name, index in pairs(OPTO_LAYOUT) do
      local at = itemByte(index)
      if edited[name] == buf[at] and payload[at] ~= buf[at] then
        writeWrong[#writeWrong + 1] = string.format("%s moved byte %d to %s",
          name, at, tostring(payload[at]))
      end
    end
    if payload[timingAt] ~= edited.timing then
      writeWrong[#writeWrong + 1] = "the Timing the pilot moved did not reach its byte"
    end
  end
  gateCheck("a save on an OPTO ESC writes each field back to its own byte",
    #writeWrong == 0, #writeWrong > 0 and table.concat(writeWrong, "; ") or nil)

  -- Through the real page, so the claim is about the suite and not about a private
  -- function: an OPTO ESC must build no BEC row, and the other rows must exist.
  do
    local runtime = openPage({hardware = "HW1106_V100456NB", model_a = "Platinum OPTO"})
    local label = "the page builds no BEC Voltage row on an OPTO ESC"
    if not runtime then
      gateCheck(label, false, "no runtime was built")
    elseif rowField(ROW_BEC) then
      gateCheck(label, false, "a BEC Voltage row was built")
    else
      local missing = {}
      for _, key in ipairs({ "startup_time", "gov_p_gain", "auto_restart",
                              "active_freewheel", "startup_power" }) do
        if not rowField("mfg.hw5." .. key) then missing[#missing + 1] = key end
      end
      gateCheck(label, #missing == 0,
        #missing > 0 and ("also missing: " .. table.concat(missing, ", ")) or nil)
    end
  end
end

-- The round trip, exhaustively: every byte against all 256 of its values. NOT a
-- gate -- it was lossless before and after -- and here so that a layout change
-- cannot quietly cost a byte.
local function checkRoundTrip()
  out("")
  out("round trip: every byte survives a save that changed something else")
  local base = fixture()
  local lost, firstLost = 0, nil
  for offset = 1, #base do
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
  check(string.format("all %d byte positions survive all 256 of their values unchanged",
    #base), lost == 0,
    lost > 0 and string.format("%d of %d values came back changed; first: %s",
      lost, #base * 256, firstLost) or nil)
end

-- Issue claim 2, recorded as a fact rather than a comment.
local function checkActiveFreewheelMapping()
  out("")
  out("Active Freewheel: the mapping, and why nothing here is inverted")

  local mapping = {}
  for _, choice in ipairs(codec.FIELD_META.active_freewheel.choices or {}) do
    mapping[choice[2]] = choice[1]
  end
  check("this suite maps 0 to Enabled and 1 to Disabled",
    mapping[0] == "Enabled" and mapping[1] == "Disabled",
    string.format("0 -> %s, 1 -> %s", tostring(mapping[0]), tostring(mapping[1])))

  -- ...and the EdgeTX page, transcribed. That is the reference #2341 names, and
  -- it says the same thing (app/pages/.../escmfg/hw5/page.lua:687-690).
  local EDGETX_PAGE = {[0] = "Enabled", [1] = "Disabled"}
  local mismatch = {}
  for value = 0, 1 do
    if mapping[value] ~= EDGETX_PAGE[value] then
      mismatch[#mismatch + 1] = string.format("%d: here %s, EdgeTX %s",
        value, tostring(mapping[value]), tostring(EDGETX_PAGE[value]))
    end
  end
  check("the two suites agree on Active Freewheel, so there is no inversion to fix",
    #mismatch == 0, #mismatch > 0 and table.concat(mismatch, "; ") or nil)

  -- And the codec cannot invert it: the byte goes in and comes out.
  local wrong = {}
  for _, raw in ipairs({ 0, 1 }) do
    local buf = blockWith({})
    buf[itemByte(DEFAULT_LAYOUT.active_freewheel)] = raw
    local data = decodeWith(buf)
    local payload = encodeWith(data)
    local at = itemByte(DEFAULT_LAYOUT.active_freewheel)
    if data.active_freewheel ~= raw then
      wrong[#wrong + 1] = string.format("byte %d decoded as %s", raw, tostring(data.active_freewheel))
    elseif not payload or payload[at] ~= raw then
      wrong[#wrong + 1] = string.format("byte %d was written back as %s", raw,
        payload and tostring(payload[at]) or "no payload")
    end
  end
  check("the Active Freewheel byte is passed through the codec unchanged",
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)

  -- The other two layouts put it elsewhere, and each must still pass its own byte
  -- through -- an OPTO ESC has it at item 14, not 15.
  for _, case in ipairs({
    { what = "OPTO", index = OPTO_LAYOUT.active_freewheel, strings = {model_a = "Platinum OPTO"} },
    { what = "HW1132", index = HW1132_LAYOUT.active_freewheel, strings = {hardware = "HW1132_V100456NB"} },
    { what = "HW1128", index = HW1128_LAYOUT.active_freewheel, strings = {hardware = "HW1128_V100456NB"} },
  }) do
    for _, raw in ipairs({ 0, 1 }) do
      local buf = blockWith(case.strings)
      local at = itemByte(case.index)
      buf[at] = raw
      local data = decodeWith(buf)
      local payload = encodeWith(data)
      check(string.format("the %s layout passes Active Freewheel through item %d with byte %d unchanged",
        case.what, case.index, raw),
        data.active_freewheel == raw and payload ~= nil and payload[at] == raw,
        string.format("byte %d -> %s -> %s", raw, tostring(data.active_freewheel),
          payload and tostring(payload[at]) or "no payload"))
    end
  end
end

-- The layouts that have nothing to do with OPTO must come out unchanged. NOT
-- gates: they pass before the fix too.
local function checkOtherLayoutsUnchanged()
  out("")
  out("the models that were already right are still right (not gates -- they pass before too)")
  for _, case in ipairs({
    { what = "a model with a BEC", strings = {}, layout = DEFAULT_LAYOUT },
    { what = "hardware HW1106", strings = {hardware = "HW1106_V100456NB"}, layout = DEFAULT_LAYOUT },
    { what = "hardware HW1121", strings = {hardware = "HW1121_V100456NB"}, layout = DEFAULT_LAYOUT },
    { what = "hardware HW1132", strings = {hardware = "HW1132_V100456NB"}, layout = HW1132_LAYOUT },
    { what = "hardware HW1128", strings = {hardware = "HW1128_V100456NB"}, layout = HW1128_LAYOUT },
  }) do
    local _, used = layoutInUse(blockWith(case.strings))
    local ok, detail = layoutMatches(used, case.layout)
    check(string.format("%s keeps its own layout", case.what), ok, detail)
  end

  -- HW1104 carries an explicit _PL_OPTO profile, and its CHOICE LISTS must still
  -- win on an OPTO HW1104 -- the fix replaces the LAYOUT, not the tables.
  --
  -- Asked as a comparison rather than as a transcribed list: an earlier version of
  -- this check asserted "#choices == 5, first Auto, last 14S" and failed against a
  -- codec that was right, because TABLES.lipo_even_6_to_14 has six options. The
  -- claim that matters is which list wins, and both answers to that are available
  -- from the codec itself -- the OPTO HW1104 against the same model without OPTO,
  -- and against a model that does fall through to the default tables.
  local function listOf(data, key)
    local out2 = {}
    for _, choice in ipairs(codec.choicesFor(data, key) or {}) do
      out2[#out2 + 1] = tostring(choice[1]) .. "=" .. tostring(choice[2])
    end
    return table.concat(out2, ", ")
  end

  local optoHw1104 = decodeWith(blockWith({hardware = "HW1104_V100456NB", model_a = "Platinum OPTO"}))
  local plainHw1104 = decodeWith(blockWith({hardware = "HW1104_V100456NB"}))
  local defaultModel = decodeWith(blockWith({hardware = "HW1106_V100456NB"}))

  local key = "lipo_cell_count"
  local optoList, plainList, defaultList =
    listOf(optoHw1104, key), listOf(plainHw1104, key), listOf(defaultModel, key)
  check("an OPTO HW1104 keeps its own choice lists, not the default ones",
    optoList == plainList and optoList ~= defaultList,
    string.format("OPTO HW1104 offers [%s], HW1104 without OPTO offers [%s], a default model [%s]",
      optoList, plainList, defaultList))

  -- And a save on a model with a BEC still reaches the ESC, so the write path is
  -- still live after the refusal-aware encode().
  local runtime, opts = openPage({hardware = "HW1106_V100456NB"})
  if not runtime or not editUnrelatedField() then
    check("Save reaches the ESC on a model with a BEC", false,
      "the page did not load, or the Timing row was never built")
  else
    local payload = pressSave(opts)
    check("Save reaches the ESC on a model with a BEC",
      payload ~= nil and #payload == BLOCK_BYTES,
      payload and string.format("payload is %d bytes, expected %d", #payload, BLOCK_BYTES)
        or "no write went out")
  end
end

local function runChecks()
  page = loadPage()
  checkOptoLayout()
  checkOptoByteAlignment()
  checkRoundTrip()
  checkActiveFreewheelMapping()
  checkOtherLayoutsUnchanged()
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("Hobbywing V5 forward programming: the OPTO layout (#2341)")
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

-- The pre-fix profile selection, verbatim: the variant was part of the PROFILE KEY,
-- and PROFILES carried exactly one `<version>_PL_OPTO` entry, so every other OPTO
-- model missed the lookup and fell through to PROFILES.default.
--
-- Level-two long strings, not the plain form: a bare "]]" inside would close a plain
-- long string early and the file would fail to parse a long way from here.
local PROFILE_SPLICE = [==[
local function profileKey(data)
  local version = trim(data and data.hardware_version) ~= "" and trim(data.hardware_version) or "default"
  local model = trim(data and data.esc_type)
  local firmware = trim(data and data.firmware_version)
  local versionUpper = version:upper()

  if version ~= "default" and (hasToken(model, "OPTO") or hasToken(firmware, "OPTO")) then
    return version .. "_PL_OPTO"
  end
  if not PROFILES[version] then
    if versionUpper:find("HW1132", 1, true) then
      return "HW1132_V100456NB"
    elseif versionUpper:find("HW1128", 1, true) then
      return "HW1128_V100456NB"
    elseif versionUpper:find("HW1121", 1, true) then
      return "HW1121_V100456NB"
    end
  end
  return version
end

local function profileFor(data)
  return PROFILES[profileKey(data)] or PROFILES.default
end

local function itemLayoutFor(data)
  return (profileFor(data).items) or DEFAULT_ITEMS
end

]==]


-- One splice, because this change is one splice. The pre-fix codec is the current
-- one with the profile selection put back; decode() and encode() are byte-identical
-- to the pre-fix versions here, because the Startup Time offset that used to sit in
-- them moved to its own pull request. There is nothing else to cut out, and a second
-- cut would be a second thing to get wrong.
local function preFix(source, nl)
  return presplice(source, "local function isOpto(data)",
    "local function decode(buf)", (PROFILE_SPLICE:gsub("\n", nl)), "profile selection")
end

-- Four ways, before the spliced codec is allowed to stand in for the pre-fix one.
local function verifySplice(original, sabotaged)
  local problems = {}

  if sabotaged == original then problems[#problems + 1] = "the splice changed nothing" end

  local tmp = writeTmp(sabotaged)

  local readBack = readFile(tmp)
  if readBack ~= sabotaged then
    problems[#problems + 1] = string.format("does not read back (%d written, %d read)",
      #sabotaged, #readBack)
  end

  package.loaded[CODEC_KEY] = nil
  local ok, spliced = pcall(function() return assert(realLoadfile(tmp))() end)
  if not ok then
    problems[#problems + 1] = "does not load: " .. tostring(spliced):gsub(".*%.lua:%d+: ", "")
  else
    -- Its own signature, and it is a positive one rather than an absence: an OPTO
    -- HW1106 gets DEFAULT_ITEMS, so bec_voltage is available AND active_freewheel
    -- sits at item 15. Checking that it HIDES the BEC row is enough on its own, but
    -- a splice that broke the profile lookup some other way could satisfy that half
    -- while decoding nothing usable, so the second half pins the layout directly.
    --
    -- It used to have a third condition here -- "and it does not apply the Startup
    -- Time offset" -- which went away with the offset. That condition could no
    -- longer distinguish anything: after the split, decode() and encode() are
    -- byte-identical to the pre-fix versions, so the spliced codec and the real one
    -- agree about it by construction. A signature that cannot fail is not evidence.
    local fixtureBytes = spliced.buildReadMessage(function() end, function() end).simulatorResponse
    local buf = {}
    for i = 1, #fixtureBytes do buf[i] = fixtureBytes[i] end
    local hardware = "HW1106_V100456NB"
    for i = 1, #hardware do buf[19 + i - 1] = hardware:byte(i) end
    local model = "Platinum OPTO"
    for i = 1, #model do buf[35 + i - 1] = model:byte(i) end
    local data
    spliced.buildReadMessage(function(d) data = d end, function() end).processReply(nil, buf)
    if data == nil then
      problems[#problems + 1] = "decodes nothing, so this is not the pre-fix codec"
    elseif not spliced.isFieldAvailable(data, "bec_voltage") then
      problems[#problems + 1] = "hides the BEC row on an OPTO HW1106, so this is not the pre-fix codec"
    elseif data.active_freewheel == nil or buf[65 + 15] == nil then
      problems[#problems + 1] = "places Active Freewheel somewhere the DEFAULT layout does not, so this is not the pre-fix codec"
    elseif data.active_freewheel ~= buf[65 + 15] then
      problems[#problems + 1] = string.format(
        "reads Active Freewheel as %s where DEFAULT item 15 says %s, so this is not the pre-fix codec",
        tostring(data.active_freewheel), tostring(buf[65 + 15]))
    end
  end

  os.remove(tmp)
  package.loaded[CODEC_KEY] = nil
  return #problems == 0, table.concat(problems, "; ")
end

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the OPTO checks must go red on the pre-fix codec")
  out(string.rep("=", 72))

  local original = readFile(CODEC_SRC)
  local sabotaged = preFix(original, newlineOf(original))

  local spliceOk, spliceDetail = verifySplice(original, sabotaged)
  out(string.format("  %s  splice: %s", spliceOk and "ok   " or "FAIL ",
    spliceDetail ~= "" and spliceDetail
      or "different file, reads back, loads, and still offers a BEC row on an OPTO HW1106"))
  if not spliceOk then os.exit(1) end

  local tmp = writeTmp(sabotaged)
  REPLACE_MATCH, REPLACE_FILE = "msp_esc_parameters_hw5%.lua$", tmp

  -- Loaded DIRECTLY from the temp file, not through loadCodec(): that helper reads
  -- the checked-out path with realLoadfile, which the redirect does not touch -- so
  -- loading through it here would hand pass 2 the FIXED codec and make every gate
  -- pass for the wrong reason. Then dropped from package.loaded again, because that
  -- direct load left the spliced module there and requireModule() memoizes: the page
  -- would find it and never call loadfile(), and the page-level case would be a
  -- rerun of pass 1.
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
    out(string.format(
      "SELF-TEST FAILED -- %d of %d checks cannot detect the pre-fix behaviour",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d checks go red on the pre-fix codec", #MUST_GO_RED))
  out(string.format("pass 1 against the real tree: %d checks, %d failures",
    pass1Checks, pass1Failures))
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
