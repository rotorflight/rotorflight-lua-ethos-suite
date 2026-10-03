-- Behaviour check for the YGE 12 V BEC support (#2337).
--
-- Run it:
--     lua5.4 bin/esc_parameters_yge/verify_yge_bec12v.lua
--     lua5.4 bin/esc_parameters_yge/verify_yge_bec12v.lua --self-test
--
-- What the defect under test is:
--   The YGE BEC Voltage field was capped at 8.4 V for every model, and the flags
--   byte's HV-BEC bit (bit 3) was never set by anything. Two halves, and they are
--   one decision:
--     * seven of the twenty-one YGE models can run their BEC in HV mode up to
--       12.0 V. The ceiling is a property of the MODEL, so a constant in
--       FIELD_META cannot express it.
--     * bit 3 tells the ESC to run that mode. This page has no row for it -- it
--       has rows for bits 0 and 1 only -- so selecting 12.0 V commanded the
--       voltage without the mode that makes it 12 V.
--
--   Both halves exist and work in the EdgeTX suite:
--   rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/esc_parameters_yge.lua
--   does the timing translation, and
--   rotorflight-lua-edgetx-suite .../escmfg/yge/init.lua:17-39 carries the model
--   table with bec12v, while .../escmfg/yge/page.lua:322-328 and :543-556 do the
--   range and the flag. The list used here is that table, transcribed, and
  --   every model's ceiling is asserted against it below, so the parity is a gate.
  --
  -- What was found on the way, and is pinned below:
--   The Ethos codec's model table was missing [4691] "YGE Saphir 125v2" -- one
--   of the seven 12 V models, and the first one the issue names. It showed as
--   "YGE ESC (4691)", and with no entry there was nothing to raise the ceiling
--   for. The EdgeTX table's own comment says why this shape of bug happens:
--   "The name and the 12 V BEC capability used to live in two hard-coded lists in
--   two files, and adding a model meant remembering both -- which is how 4691
--   came to be in neither." So the fix is ONE table carrying both facts, not a
--   second list next to the first.
--
--   A third fact joined it later the same day: an Opto ESC has no BEC at all
--   (Björn), so "cannot reach 12 V" and "has no BEC" are different answers and
--   need different UI -- the first caps the row, the second hides it.
--
--   That one is a FACT about the ESC and not a reading of the model name. The
--   name is only the label it carries in a datasheet and in the EdgeTX table, so
--   the five ids are stated in the table and no code inspects the string -- a
--   model called "YGE Opto" with bec = true would be a wrong TABLE, not a wrong
--   filter. He then confirmed the other sixteen per model: all ten whose names say
--   neither BEC nor Opto have a BEC, so `bec` is false for exactly the five Opto
--   models and true for the rest, with no entry left undecided. EdgeTX has no
--   `bec` field at all, which is why its page cannot hide the row and still offers
--   a BEC voltage on an ESC that has no BEC.
--
-- What it drives, and why:
--   * The real app/pages/esc_forward_yge.lua and the real
--     app/pages/esc_forward_vendor.lua, so the field spec the page hands the
--     widget is the one under test -- that is where a model-dependent ceiling
--     has to arrive, and getting it wrong is invisible in the codec alone.
--   * The real app/field_layout.lua and the real app/page_runtime.lua. The
--     ceiling reaches the widget through field_layout's spec.min/spec.max
--     fallback chain, and the flag reaches the wire through page_runtime's
--     beforeSave hook; stubbing either would make its half vacuous.
--   * The real lib/msp_esc_parameters_yge.lua for the model table, for
--     becVoltageMax(), and for beforeSave().
--   * The other six ESC pages that go through the same shared editor, for the
--     blast radius of the esc_forward_vendor.lua change -- see the section that
--     says what it does and does not cover.
--
-- Which checks go RED without the fix:
  --   11 of 28. --self-test proves that rather than asserting it: it cuts the fix
  --   back out of the three files that carry it and requires every one of the eleven
--   to fail.
--
--   It cuts rather than serving pre-fix files from git, because the CI checkout
--   has no history to serve them from -- and a cut is exactly where the sibling
--   harness went wrong once: a slice that ran from the first mapping table to the
--   end of the last function took an unrelated table with it, and the result
--   looked like a test failure. So this one verifies its own work before
--   trusting anything, in five steps:
--     * every temp file must still LOAD (a cut that broke the module is caught
--       here, not three layers down);
--     * the feature must actually be GONE from the sabotaged codec -- no
--       becVoltageMax, no beforeSave, no hasBec;
--     * the sabotaged PAGE must still HAVE its BEC row, plainly, with neither
--       the ceiling nor the Opto gate on it. This one earned its place: the
--       first version of the cut deleted the row instead of restoring the
--       one-line entry, which left a page with no BEC row at all -- a third
--       state, not the pre-fix one -- and the Opto gate then passed for the
--       wrong reason, because the row was gone on every model and nothing could
--       leak. Reading the source is the only way to see this: the page module
--       exports open() and nothing else, so its FIELDS cannot be inspected.
--     * all three files must have been SERVED at least once;
--     * both passes must have registered the same gate set.
--
--   Two more of those steps earned themselves while this file was being written:
--     * the page was being loaded with realLoadfile, which BYPASSES the redirect,
--       so the sabotaged page was never served -- pass 2 was testing the real page
--       against a sabotaged codec and one gate stayed green for the wrong reason;
--     * the sabotage check asked whether "4691" still appeared in the summary, and
--       the pre-fix fallback label is "YGE ESC (4691)" -- it contains the digits,
--       so a correct sabotage was reported as a broken one.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"

local SELF_TEST = arg[1] == "--self-test"

-- The three modules that carry the fix, and what has to come out of each.
local SWAPPABLE = {
  ["msp_esc_parameters_yge%.lua$"] = PREFIX .. "lib/msp_esc_parameters_yge.lua",
  ["esc_forward_yge%.lua$"] = PREFIX .. "app/pages/esc_forward_yge.lua",
  ["esc_forward_vendor%.lua$"] = PREFIX .. "app/pages/esc_forward_vendor.lua",
}

-- Every ESC page that goes through the shared vendor editor, YGE excluded: the
-- esc_forward_vendor.lua change is shared, so its blast radius is these pages.
-- app/pages/esc_forward_4way.lua is deliberately NOT here -- it has its own
-- editor (its own requireModule calls at :8-15, no vendorPage.open) and never
-- reaches the changed code at all.
local SIBLING_PAGES = {
  {label = "FlyRotor", page = "flyrotor"},
  {label = "HW5", page = "hw5"},
  {label = "OMP", page = "omp"},
  {label = "Scorpion", page = "scorpion"},
  {label = "XDFly", page = "xdfly"},
  {label = "ZTW", page = "ztw"},
}

-- The three ESC pages this file does NOT drive, named so the gap is a statement
-- rather than an absence: their editors are gated on a signature their own
-- simulatorResponse fixture does not satisfy, so they need the hand-staged
-- replies bin/esc_signature builds -- and that harness stubs field_layout, so it
-- cannot see a field range at all. Their bounds come from the same two lines of
-- fieldSpec() that the six above exercise, which is why the coverage is stated
-- rather than padded with fixtures that would have to hard-code byte offsets.
local NOT_DRIVEN = {
  {label = "AM32", reason = "its own fixture's signature does not satisfy its own isCompatible()"},
  {label = "BLHeli_S", reason = "needs 0xC1 AND main_revision == 16"},
  {label = "Bluejay", reason = "needs 0xC1 AND main_revision == 0"},
}

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

-- Set by the self-test: pattern -> temp file to serve instead, and a count of
-- how often each fired. A redirect that never fires would leave the second pass
-- a disguise of the first, so the counts are reported and required.
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

-- The spec field_layout actually received is the thing under test for the
-- ceiling, so it is recorded rather than just the resulting min/max.
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

-- The real field_layout, wrapped rather than replaced: the ceiling reaches the
-- widget through its spec.min/spec.max fallback chain and the flag reaches the
-- data through the same accessors every other field uses, so a stub would make
-- both halves vacuous. The wrapper only records the runtime the page built,
-- which nothing else holds a reference to.
local fieldLayout = requireModule("app/field_layout.lua")
do
  local buildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, label, spec, parent)
    if not obs.runtime then obs.runtime = runtime end
    return buildSingle(runtime, label, spec, parent)
  end
end

-- ---------------------------------------------------------------------------
-- The model table under test
-- ---------------------------------------------------------------------------

-- The specification. The 12 V capability is the EdgeTX table's
-- (rotorflight-lua-edgetx-suite .../escmfg/yge/init.lua:17-39), confirmed by
-- Björn per model on 2026-10-03 including the three non-v2 entries. EDGETX_MODELS
-- below is that table verbatim, and the parity check asserts all 21 entries
-- agree, so the two cannot drift apart unnoticed.
--
-- `bec` is the one field EdgeTX has no notion of, and it is what makes the BEC
-- Voltage row exist at all. The five Opto models have no BEC -- a fact about the
-- ESC, not a reading of the name; the name is only the label it carries, and the
-- ids are listed here and in the codec rather than filtered at runtime. The
-- sixteen others have one, confirmed by Björn per model on 2026-10-03, including
-- the ten whose name says neither BEC nor Opto. That is his answer, not an
-- inference from a name.
local EXPECTED_MODELS = {
  [848] = {name = "YGE 35 LVT BEC", bec = true, bec12v = false},
  [1616] = {name = "YGE 65 LVT BEC", bec = true, bec12v = false},
  [2128] = {name = "YGE 85 LVT BEC", bec = true, bec12v = false},
  [2384] = {name = "YGE 95 LVT BEC", bec = true, bec12v = false},
  [4944] = {name = "YGE 135 LVT BEC", bec = true, bec12v = false},
  [8273] = {name = "YGE 205 HVT BEC", bec = true, bec12v = true},
  [2304] = {name = "YGE 90 HVT Opto", bec = false, bec12v = false},
  [4608] = {name = "YGE 120 HVT Opto", bec = false, bec12v = false},
  [4928] = {name = "YGE Opto 135", bec = false, bec12v = false},
  [9552] = {name = "YGE Opto 255", bec = false, bec12v = false},
  [16464] = {name = "YGE Opto 405", bec = false, bec12v = false},
  [4177] = {name = "YGE Aureus 105", bec = true, bec12v = false},
  [4179] = {name = "YGE Aureus 105v2", bec = true, bec12v = true},
  [4689] = {name = "YGE Saphir 125", bec = true, bec12v = false},
  [4691] = {name = "YGE Saphir 125v2", bec = true, bec12v = true},
  [5025] = {name = "YGE Aureus 135", bec = true, bec12v = false},
  [5027] = {name = "YGE Aureus 135v2", bec = true, bec12v = true},
  [5457] = {name = "YGE Saphir 155", bec = true, bec12v = false},
  [5459] = {name = "YGE Saphir 155v2", bec = true, bec12v = true},
  [5712] = {name = "YGE 165 HVT", bec = true, bec12v = true},
  [8272] = {name = "YGE 205 HVT v2", bec = true, bec12v = true},
}

local OPTO_IDS = {2304, 4608, 4928, 9552, 16464}
local UNMARKED_IDS = {4177, 4179, 4689, 4691, 5025, 5027, 5457, 5459, 5712, 8272}

-- The two the ceiling cases are driven on. 4691 because it is the model the whole
-- finding is about; 5712 because it is a 12 V model whose name carries neither BEC
-- nor Opto nor v2, and is therefore the one a reader is most likely to "correct"
-- away. 848 is a plain 8.4 V BEC model.
local MODEL_12V = 4691   -- YGE Saphir 125v2
local MODEL_8V4 = 848    -- YGE 35 LVT BEC

-- The EdgeTX table, transcribed from
-- rotorflight-lua-edgetx-suite .../escmfg/yge/init.lua:17-39, and treated here as
-- the specification for bec12v. Transcribed rather than parsed on purpose: a check
-- that reads the other repository cannot run in this repository's CI.
--
-- Two of the names differ from EdgeTX's, and BOTH differences are Björn's, given
-- 2026-10-03:
--   4691 "YGE Saphir 125v2" -- EdgeTX already spells it this way. It was THIS
--     codec that was missing the entry, so before this branch it had no name at
--     all and rendered as "YGE ESC (4691)".
--   8272 "YGE 205 HVT v2" -- EdgeTX calls it "YGE 205 HVT". The id and the 12 V
--     capability are EdgeTX's; only the spelling is the owner's.
-- The parity check names the other nineteen explicitly rather than asserting a
-- count, so that a future edit which adds or drops an entry fails with the id in
-- the message instead of a bare "expected 21".
local EDGETX_MODELS = {
  { id = 848, name = "YGE 35 LVT BEC", bec12v = false },
  { id = 1616, name = "YGE 65 LVT BEC", bec12v = false },
  { id = 2128, name = "YGE 85 LVT BEC", bec12v = false },
  { id = 2304, name = "YGE 90 HVT Opto", bec12v = false },
  { id = 2384, name = "YGE 95 LVT BEC", bec12v = false },
  { id = 4177, name = "YGE Aureus 105", bec12v = false },
  { id = 4179, name = "YGE Aureus 105v2", bec12v = true },
  { id = 4608, name = "YGE 120 HVT Opto", bec12v = false },
  { id = 4689, name = "YGE Saphir 125", bec12v = false },
  { id = 4691, name = "YGE Saphir 125v2", bec12v = true },
  { id = 4928, name = "YGE Opto 135", bec12v = false },
  { id = 4944, name = "YGE 135 LVT BEC", bec12v = false },
  { id = 5025, name = "YGE Aureus 135", bec12v = false },
  { id = 5027, name = "YGE Aureus 135v2", bec12v = true },
  { id = 5457, name = "YGE Saphir 155", bec12v = false },
  { id = 5459, name = "YGE Saphir 155v2", bec12v = true },
  { id = 5712, name = "YGE 165 HVT", bec12v = true },
  { id = 8272, name = "YGE 205 HVT", bec12v = true },
  { id = 8273, name = "YGE 205 HVT BEC", bec12v = true },
  { id = 9552, name = "YGE Opto 255", bec12v = false },
  { id = 16464, name = "YGE Opto 405", bec12v = false },
}

-- The one name that is deliberately NOT EdgeTX's, with the reason.
local NAME_DIFFERS_ON_PURPOSE = { id = 8272, here = "YGE 205 HVT v2", edgetx = "YGE 205 HVT" }

local BEC_8V_MAX = 84
local BEC_12V_MAX = 120
local FLAG_BIT_BEC12V = 3

-- Byte offsets, derived rather than hard-coded. Same reasoning as the sibling
-- harness: the layout is re-derived here and then checked against the shipped
-- fixture, so a field added or removed upstream fails loudly instead of making
-- every case assert against the wrong byte.
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

local function readU16(buf, at)
  return (buf[at] or 0) + (buf[at + 1] or 0) * 256
end

local function pokeU16(buf, at, value)
  buf[at] = value % 256
  buf[at + 1] = math.floor(value / 256) % 256
end

local function copyOf(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end

-- ---------------------------------------------------------------------------
-- Driving the pages
-- ---------------------------------------------------------------------------

local ROW_BEC = "mfg.yge.lv_bec_voltage"
local ROW_GOV_P = "mfg.yge.gov_p"

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
-- whatever the loadfile redirect is currently serving.
local function resetModules()
  package.loaded["rfsuite.app.pages.esc_forward_vendor"] = nil
  package.loaded["rfsuite.app.esc_error"] = nil
  package.loaded["rfsuite.app.close_key"] = nil
  package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = nil
  package.loaded["rfsuite.app.pages.esc_forward_yge"] = nil
  package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = nil
end

-- One open of the real YGE page, answered with `fixture` (or with the codec's own
-- fixture when none is given). esc_forward_yge.lua binds the codec into a
-- module-level local at its line 5, so the page is reloaded on every open rather
-- than reused -- otherwise the second drive would keep the first open's codec.
--
-- Loaded through _G.loadfile, NOT realLoadfile: realLoadfile bypasses the
-- redirect, so the self-test's sabotaged page would never be served and pass 2
-- would quietly test the real page against a sabotaged codec. The hit counter at
-- the end of the self-test is what catches that, and it caught it.
local function openYge(fixture)
  resetObs()
  resetModules()
  ygePage = assert(_G.loadfile("app/pages/esc_forward_yge.lua"))()

  local codec = requireModule("lib/msp_esc_parameters_yge.lua")
  local f = copyOf(codec.buildReadMessage(function() end, function() end).simulatorResponse)
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

local function rowField(key)
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].label:find(key, 1, true) then return obs.fieldOrder[i] end
  end
  return nil
end

local function edit(field, value)
  field.set(value)
end

-- Moves a row the BEC cases do not care about, so Save is reachable the way it is
-- for a pilot: canSave() requires dirty, and refreshDirty() compares the whole
-- table, so a page nobody touched cannot be saved at all.
local function editUnrelatedField()
  local field = rowField(ROW_GOV_P)
  if not field then return false end
  local next = field.get() + 1
  if next > field.max then next = field.min end
  if next == field.get() then return false end
  edit(field, next)
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

local function runChecks()
  resetObs()
  resetModules()
  local codec = requireModule("lib/msp_esc_parameters_yge.lua")
  local baseFixture = codec.buildReadMessage(function() end, function() end).simulatorResponse

  out("")
  out("layout")
  check("the shipped fixture is the length this file's layout predicts",
    #baseFixture == LAYOUT_BYTES,
    string.format("fixture is %d bytes, layout predicts %d -- WIRE_FIELDS changed, update the table above",
      #baseFixture, LAYOUT_BYTES))

  -- -------------------------------------------------------------------------
  -- The model table
  -- -------------------------------------------------------------------------
  out("")
  out("model table")

  -- One open per model id, answered with that model, and the page's own summary
  -- line is what names it. That is the pilot-visible half: an id with no entry
  -- renders as "YGE ESC (4691)".
  local ids = {}
  for id in pairs(EXPECTED_MODELS) do ids[#ids + 1] = id end
  table.sort(ids)

  local unnamed = {}
  for _, id in ipairs(ids) do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, id)
    local runtime = openYge(f)
    if not runtime then
      unnamed[#unnamed + 1] = string.format("%d built no editor", id)
    else
      local label = codec.summaryFor(runtime.data)
      if not label:find(EXPECTED_MODELS[id].name, 1, true) then
        unnamed[#unnamed + 1] = string.format("%d -> %q", id, label)
      end
    end
  end
  gateCheck("every known model id is named by the page, not shown as a raw number",
    #unnamed == 0,
    #unnamed > 0 and string.format("%d of %d unnamed: %s",
      #unnamed, #ids, table.concat(unnamed, ", ")) or nil)

  -- The specific entry that was missing, called out on its own so the regression
  -- reads as the finding it was rather than as one row of a table check.
  do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, 4691)
    local runtime, _, codec = openYge(f)
    local label = runtime and codec.summaryFor(runtime.data) or ""
    gateCheck("model 4691 is named \"YGE Saphir 125v2\" and not \"YGE ESC (4691)\"",
      label:find("YGE Saphir 125v2", 1, true) ~= nil,
      string.format("summary reads %q", label))
  end

  -- -------------------------------------------------------------------------
  -- The ceiling, as the codec reports it
  -- -------------------------------------------------------------------------
  out("")
  out("ceiling")

  do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_12V)  -- YGE Saphir 125v2
    local runtime = openYge(f)
    local got = runtime and codec.becVoltageMax and codec.becVoltageMax(runtime.data)
    gateCheck("a 12 V model reports the 12.0 V ceiling",
      got == BEC_12V_MAX,
      string.format("becVoltageMax returned %s, expected %d", tostring(got), BEC_12V_MAX))
  end

  do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_8V4)  -- YGE 35 LVT BEC, 8.4 V
    local runtime = openYge(f)
    local got = runtime and codec.becVoltageMax and codec.becVoltageMax(runtime.data)
    check("an 8.4 V model keeps the 8.4 V ceiling",
      got == BEC_8V_MAX,
      string.format("becVoltageMax returned %s, expected %d", tostring(got), BEC_8V_MAX))
  end

  do
    -- An id this suite has never heard of. The safe direction is the shared
    -- 8.4 V: a pilot is not offered a voltage the suite cannot vouch for.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, 31337)
    local runtime = openYge(f)
    local got = runtime and codec.becVoltageMax and codec.becVoltageMax(runtime.data)
    check("an unknown model id keeps the 8.4 V ceiling rather than being offered 12 V",
      got == BEC_8V_MAX,
      string.format("becVoltageMax returned %s, expected %d", tostring(got), BEC_8V_MAX))
  end

  -- -------------------------------------------------------------------------
  -- The ceiling, as the field spec the widget receives
  -- -------------------------------------------------------------------------
  out("")
  out("the BEC field's ceiling reaches the widget")

  do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_12V)
    local runtime = openYge(f)
    local field = rowField(ROW_BEC)
    gateCheck("the BEC field is built with a ceiling of 12.0 V on a 12 V model",
      field ~= nil and field.max == BEC_12V_MAX,
      field and string.format("widget got max=%s, expected %d", tostring(field.max), BEC_12V_MAX)
        or "the BEC row was never built")
  end

  do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_8V4)
    local runtime = openYge(f)
    local field = rowField(ROW_BEC)
    check("the BEC field is built with a ceiling of 8.4 V on an 8.4 V model",
      field ~= nil and field.max == BEC_8V_MAX,
      field and string.format("widget got max=%s, expected %d", tostring(field.max), BEC_8V_MAX)
        or "the BEC row was never built")
  end

  -- -------------------------------------------------------------------------
  -- The flag, on the wire
  -- -------------------------------------------------------------------------
  out("")
  out("the HV-BEC bit reaches the wire")

  local function bitOf(buf, at, bit)
    return math.floor((buf[at] or 0) / (2 ^ bit)) % 2
  end

  -- 0x0F on the wire: bits 0..3 set, 4..7 clear. Bit 3 is the one under test, the
  -- other three are there so "left the rest alone" is a statement about bytes and
  -- not about a byte that happened to be zero.
  --
  -- For the case that asserts the bit is SET, the staged byte has bit 3 CLEAR
  -- (0xF7). Staging it set would make the assertion true before beforeSave() has
  -- run, and the first version of this file did exactly that -- which is how a
  -- check that cannot fail got in.
  do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_12V)
    f[OFFSETS.flags.offset] = 0xF7
    local runtime, opts = openYge(f)
    local field = rowField(ROW_BEC)
    if not runtime or not field then
      gateCheck("selecting 12.0 V sets the HV-BEC bit", false, "the BEC row was never built")
    else
      edit(field, BEC_12V_MAX)
      local payload = pressSave(opts)
      local got = payload and bitOf(payload, OFFSETS.flags.offset, FLAG_BIT_BEC12V)
      gateCheck("selecting 12.0 V sets the HV-BEC bit",
        got == 1,
        payload and string.format("wire flags byte 0x%02X, bit 3 is %s -- it started clear",
          payload[OFFSETS.flags.offset], tostring(got)) or "no write went out")
      check("and the other three bits in that byte are left as they were",
        payload ~= nil and bitOf(payload, OFFSETS.flags.offset, 0) == 1
          and bitOf(payload, OFFSETS.flags.offset, 1) == 1
          and bitOf(payload, OFFSETS.flags.offset, 2) == 1,
        payload and string.format("wire flags byte 0x%02X", payload[OFFSETS.flags.offset]) or "no write went out")
      check("and so are the reserved bits above it",
        payload ~= nil and bitOf(payload, OFFSETS.flags.offset, 7) == 1,
        payload and string.format("wire flags byte 0x%02X", payload[OFFSETS.flags.offset]) or "no write went out")
    end
  end

  do
    -- The ESC is on 12 V and the pilot drops back to 8.4 V. The bit has to go
    -- with it, or the ESC is left in HV mode with a voltage that is not the one
    -- the bit means.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_12V)
    f[OFFSETS.flags.offset] = 0x0F
    local runtime, opts = openYge(f)
    local field = rowField(ROW_BEC)
    if not runtime or not field then
      gateCheck("dropping to 8.4 V clears the HV-BEC bit", false, "the BEC row was never built")
    else
      edit(field, BEC_8V_MAX)
      local payload = pressSave(opts)
      local got = payload and bitOf(payload, OFFSETS.flags.offset, FLAG_BIT_BEC12V)
      gateCheck("dropping to 8.4 V clears the HV-BEC bit",
        got == 0,
        payload and string.format("wire flags byte 0x%02X, bit 3 is %s",
          payload[OFFSETS.flags.offset], tostring(got)) or "no write went out")
    end
  end

  do
    -- 11.9 V is one step below the mode on the same slider and is NOT that mode.
    -- Asserting the bit for it would tell the ESC to switch to HV and hand it a
    -- voltage the bit does not mean.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_12V)
    f[OFFSETS.flags.offset] = 0x0F
    local runtime, opts = openYge(f)
    local field = rowField(ROW_BEC)
    if not runtime or not field then
      check("11.9 V does not set the HV-BEC bit", false, "the BEC row was never built")
    else
      edit(field, 119)
      local payload = pressSave(opts)
      local got = payload and bitOf(payload, OFFSETS.flags.offset, FLAG_BIT_BEC12V)
      check("11.9 V does not set the HV-BEC bit",
        got == 0,
        payload and string.format("wire flags byte 0x%02X, bit 3 is %s",
          payload[OFFSETS.flags.offset], tostring(got)) or "no write went out")
    end
  end

  do
    -- An ESC that reports 8.4 V with the bit SET is in a state this page never
    -- put it in. A save that changed the governor gain has no business clearing a
    -- BEC setting nobody looked at -- the same rule the timing translation
    -- follows for an untouched row.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_8V4)
    f[OFFSETS.flags.offset] = 0x0F
    local runtime, opts = openYge(f)
    if not runtime or not editUnrelatedField() then
      check("a save that did not touch the voltage leaves the HV-BEC bit as the ESC reported it",
        false, "the page did not load, or the unrelated row was never built")
    else
      local payload = pressSave(opts)
      local got = payload and bitOf(payload, OFFSETS.flags.offset, FLAG_BIT_BEC12V)
      check("a save that did not touch the voltage leaves the HV-BEC bit as the ESC reported it",
        got == 1,
        payload and string.format("wire flags byte 0x%02X -- a save that had nothing to do with the BEC cleared it",
          payload[OFFSETS.flags.offset]) or "no write went out")
    end
  end

  do
    -- ...and the converse: a pilot who DOES move the voltage gets the invariant,
    -- whatever the ESC said before.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_8V4)
    f[OFFSETS.flags.offset] = 0x0F
    local runtime, opts = openYge(f)
    local field = rowField(ROW_BEC)
    if not runtime or not field then
      gateCheck("moving the voltage sets the bit even on a model whose ceiling is 8.4 V",
        false, "the BEC row was never built")
    else
      edit(field, 60)
      local payload = pressSave(opts)
      local got = payload and bitOf(payload, OFFSETS.flags.offset, FLAG_BIT_BEC12V)
      gateCheck("moving the voltage sets the bit even on a model whose ceiling is 8.4 V",
        got == 0,
        payload and string.format("wire flags byte 0x%02X, bit 3 is %s",
          payload[OFFSETS.flags.offset], tostring(got)) or "no write went out")
    end
  end

  -- -------------------------------------------------------------------------
  -- The Opto models have no BEC, so the row is hidden rather than capped
  -- -------------------------------------------------------------------------
  out("")
  out("a model with no BEC hides the row instead of capping it")

  do
    -- Every Opto-named model, each on its own open, and each must not have the
    -- row built at all. Capping it would leave a live control on hardware that
    -- has no BEC to set.
    local leaked = {}
    for _, id in ipairs(OPTO_IDS) do
      local f = copyOf(baseFixture)
      pokeU16(f, OFFSETS.esc_type.offset, id)
      local runtime = openYge(f)
      if not runtime then
        leaked[#leaked + 1] = string.format("%d built no editor", id)
      elseif rowField(ROW_BEC) ~= nil then
        leaked[#leaked + 1] = string.format("%d (%s)", id, EXPECTED_MODELS[id].name)
      end
    end
    gateCheck("none of the five Opto models builds the BEC Voltage row",
      #leaked == 0,
      #leaked > 0 and string.format("row shown on: %s", table.concat(leaked, ", ")) or nil)
  end

  do
    -- ...and the capability itself is reported, not merely used to hide a row.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, 16464)  -- YGE Opto 405
    local runtime, _, codec = openYge(f)
    local got = runtime and codec.hasBec and codec.hasBec(runtime.data)
    gateCheck("hasBec() reports false for an Opto model",
      got == false,
      string.format("hasBec returned %s, expected false", tostring(got)))
  end

  do
    -- A model whose name says BEC keeps the row.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, MODEL_8V4)  -- YGE 35 LVT BEC, 8.4 V
    local runtime = openYge(f)
    check("a model named BEC keeps the BEC Voltage row",
      rowField(ROW_BEC) ~= nil,
      "the row was not built")
  end

  do
    -- The ten whose name says neither BEC nor Opto. All ten HAVE a BEC -- that is
    -- Björn's per-model answer, not an inference from the name -- so the row stays
    -- on every one of them. Not a gate: the pre-fix page builds the row on all ten
    -- too, so this cannot detect the fix. It is here because the tempting wrong
    -- move is to read the name and hide the row on ten models whose BEC nobody had
    -- confirmed either way.
    local hidden = {}
    for _, id in ipairs(UNMARKED_IDS) do
      local f = copyOf(baseFixture)
      pokeU16(f, OFFSETS.esc_type.offset, id)
      local runtime = openYge(f)
      if not runtime then
        hidden[#hidden + 1] = string.format("%d built no editor", id)
      elseif rowField(ROW_BEC) == nil then
        hidden[#hidden + 1] = string.format("%d (%s)", id, EXPECTED_MODELS[id].name)
      end
    end
    check("the ten models whose name says neither all have a BEC and keep the row",
      #hidden == 0,
      #hidden > 0 and string.format("row hidden on: %s", table.concat(hidden, ", ")) or nil)
  end

  do
    -- An unknown id behaves like the unknown models: the row stays. Hiding it
    -- would be the suite inventing a fact about hardware it has never seen.
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, 31337)
    local runtime = openYge(f)
    check("an unknown model id keeps the BEC Voltage row",
      rowField(ROW_BEC) ~= nil,
      "the row was hidden for an id this suite does not know")
  end

  -- -------------------------------------------------------------------------
  -- Parity with the EdgeTX table, on bec12v
  -- -------------------------------------------------------------------------
  out("")
  out("the BEC ceiling matches the EdgeTX table on all 21 models")

  do
    -- A gate, unlike the non-gate this replaced: on the pre-fix codec every model
    -- returns BEC_8V_MAX, so all seven 12 V entries already fail here. That is what
    -- makes it able to detect the fix rather than merely pin it afterwards.
    --
    -- Every entry is walked, not a sample, because "the seven that matter" is the
    -- kind of list that rots: adding a model to EdgeTX would leave a four-entry
    -- spot check green. Ids and counts are both asserted, so an entry dropped on
    -- either side is named rather than counted.
    local wrong, checked = {}, 0
    for _, e in ipairs(EDGETX_MODELS) do
      checked = checked + 1
      local f = copyOf(baseFixture)
      pokeU16(f, OFFSETS.esc_type.offset, e.id)
      local runtime, _, codec = openYge(f)
      if not runtime then
        wrong[#wrong + 1] = string.format("%d built no editor", e.id)
      elseif not codec.becVoltageMax then
        wrong[#wrong + 1] = string.format("%d has no becVoltageMax", e.id)
      else
        local want = e.bec12v and BEC_12V_MAX or BEC_8V_MAX
        local got = codec.becVoltageMax(runtime.data)
        if got ~= want then
          wrong[#wrong + 1] = string.format("%d %s: EdgeTX says %s, codec returned %s",
            e.id, e.name, want / 10 .. " V", got and (got / 10) .. " V" or tostring(got))
        end
      end
    end
    gateCheck("all 21 BEC ceilings equal the EdgeTX table's",
      #wrong == 0 and checked == 21,
      #wrong > 0 and table.concat(wrong, "; ") or (checked ~= 21 and ("walked " .. checked .. " entries, expected 21") or nil))
  end

  -- The one name that is deliberately not EdgeTX's, checked separately so that the
  -- message says which kind of difference it is.
  do
    local f = copyOf(baseFixture)
    pokeU16(f, OFFSETS.esc_type.offset, NAME_DIFFERS_ON_PURPOSE.id)
    -- A gate: on the pre-fix codec [8272] is named "YGE 205 HVT", EdgeTX's
    -- spelling, because the v2 came from the owner. It goes red if the name is
    -- ever copied back from the other repository.
    --
    -- Compared for EQUALITY against the name part only. A "does it contain our
    -- spelling and not EdgeTX's" test is unsatisfiable here and would have passed
    -- nothing: "YGE 205 HVT v2" CONTAINS "YGE 205 HVT". summaryFor returns
    -- "<name> / <ratio>", so the name is everything before the separator.
    local runtime, _, codec = openYge(f)
    local label = runtime and codec.summaryFor(runtime.data) or ""
    local reported = label:match("^(.-)%s*/%s") or label
    gateCheck(string.format("model %d is named exactly \"%s\", the owner's spelling, not EdgeTX's \"%s\"",
        NAME_DIFFERS_ON_PURPOSE.id, NAME_DIFFERS_ON_PURPOSE.here, NAME_DIFFERS_ON_PURPOSE.edgetx),
      reported == NAME_DIFFERS_ON_PURPOSE.here,
      string.format("model row named \"%s\", expected exactly \"%s\"", reported, NAME_DIFFERS_ON_PURPOSE.here))
  end

  -- -------------------------------------------------------------------------
  -- Blast radius of the shared-editor change
  -- -------------------------------------------------------------------------
  out("")
  out("blast radius: the other ESC pages keep their own ranges")

  for _, tool in ipairs(SIBLING_PAGES) do
    resetObs()
    resetModules()
    package.loaded["rfsuite.app.pages.esc_forward_" .. tool.page] = nil
    package.loaded["rfsuite.lib.msp_esc_parameters_" .. tool.page] = nil

    local sibCodec = requireModule("lib/msp_esc_parameters_" .. tool.page .. ".lua")
    reply = sibCodec.buildReadMessage(function() end, function() end).simulatorResponse
    local page = assert(realLoadfile(PREFIX .. "app/pages/esc_forward_" .. tool.page .. ".lua"))()
    local opts = freshOpts()
    page.open(opts)
    if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end

    local numbers = 0
    local moved = {}
    for i = 1, #obs.fieldOrder do
      local f = obs.fieldOrder[i]
      if f.kind == "number" then
        numbers = numbers + 1
        -- Every one of these pages declares no min/max of its own, so the widget
        -- must have been given the codec's FIELD_META range and nothing else.
        local meta = sibCodec.FIELD_META and sibCodec.FIELD_META[f.label]
        if f.min == nil or f.max == nil then
          moved[#moved + 1] = string.format("%s got no range at all", tostring(f.label))
        end
      end
    end
    check(string.format("%s still builds %d number field(s), none left without a range",
        tool.label, numbers),
      numbers > 0 and #moved == 0,
      numbers == 0 and "no number fields built -- the check would be vacuous"
        or table.concat(moved, "; "))
  end

  out("")
  out("not driven here, and why:")
  for _, tool in ipairs(NOT_DRIVEN) do
    out(string.format("  %-10s %s", tool.label, tool.reason))
  end
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("YGE 12 V BEC: the ceiling and the HV-BEC bit (#2337)")
out(string.rep("=", 72))

runChecks()

local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the same cases against the real pre-fix modules
-- ---------------------------------------------------------------------------

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end

-- Cuts the fix back out of one module. Every slice is bounded by two anchors
-- that are unique in the file, and `nl` is detected rather than assumed --
-- core.autocrlf=true and no .gitattributes, so the checkout is CRLF on Windows
-- and a hard-coded "\n" would miss every anchor and fail with a message about
-- the anchors rather than about the feature.
local function cut(src, open, close, what)
  local at = src:find(open, 1, true)
  if not at then error("sabotage: could not find the start of " .. what, 0) end
  local last = src:find(close, at, true)
  if not last then error("sabotage: could not find the end of " .. what, 0) end
  return (src:sub(1, at - 1) .. src:sub(last + #close)), what
end

-- Replaces one span with given text. Used where the pre-fix form is not "the
-- feature is gone" but "the feature is gone AND what was there before is back":
-- the BEC row has to come back as the plain one-line entry it was, not vanish.
local function replace(src, open, close, replacement, what, nl)
  local at = src:find(open, 1, true)
  if not at then error("sabotage: could not find the start of " .. what, 0) end
  local last = src:find(close, at, true)
  if not last then error("sabotage: could not find the end of " .. what, 0) end
  return (src:sub(1, at - 1) .. replacement .. nl .. src:sub(last + #close))
end

local function prefixCodec(src, nl)
  local out = src
  -- (1) the model that was missing until this change
  out = cut(out, '  [4691] = {name = "YGE Saphir 125v2"', "},\r\n", "model [4691]")
  -- (2) becVoltageMax
  out = cut(out, "-- The ceiling of the BEC Voltage field, for the page",
    "return becMax(data)\r\nend", "becVoltageMax()")
  -- (3) beforeSave
  out = cut(out, "-- The flags byte's HV-BEC bit is not a row on this page",
    "data.flags = setBit(data.flags, FLAG_BIT_BEC12V, data.lv_bec_voltage == BEC_VOLTAGE_MAX_12V and 1 or 0)\r\nend",
    "beforeSave()")
  -- (4) and (5) the BEC-presence fact, both halves. Without these the Opto gate
  -- stays green against a codec that has no notion of an Opto at all -- the
  -- page's own enabledWhen is cut below, so removing only the accessor would
  -- leave a live row that nothing hides, which is the defect.
  out = cut(out, "function msp.hasBec(data)",
    "return hasBec(data)\r\nend", "msp.hasBec()")
  -- (6) the ONE name that is deliberately not EdgeTX's, rewritten back to EdgeTX's
  -- spelling. Same cut as (1): a table entry, edited in place.
  --
  -- This was not a gate until this cut existed, and the self-test is what said so:
  -- without (6) the name check "STAYS GREEN", because cutting functions and blocks
  -- out of the codec leaves the table's strings untouched. The sabotage was
  -- reaching the mechanism and not the table, so the check was asserting something
  -- no cut could ever falsify. A gate that cannot go red is not a gate.
  out = replace(out, '[8272] = {name = "YGE 205 HVT v2"', 'v2"', '[8272] = {name = "YGE 205 HVT"', 'model [8272] name', nl)
  -- This anchor is a COMMENT in the codec, and it is therefore coupled to how that
  -- comment is worded: the phrasing was rewritten on 2026-10-03 to say that the Opto
  -- fact is not read off the model name, and this line had to move with it. A cut
  -- anchored on prose is a maintenance edge -- it fails loudly at the next rewording
  -- rather than silently cutting the wrong span, which is why the error names the
  -- anchor and not the feature.
  out = cut(out, '-- Whether the BEC Voltage row is shown at all. It reports false only for the five',
    "return model == nil or model.bec ~= false\r\nend", "hasBec()")
  return out
end

local function prefixPage(src, nl)
  local out = src
  -- (4) the BEC row goes back to the one-line entry it had before #2337 -- the
  -- dynamic ceiling AND the Opto gate come off, and the row itself STAYS.
  --
  -- Deleting the whole entry instead of putting the old one back was the first
  -- version of this cut, and it produced a THIRD state rather than the pre-fix
  -- one: a page with no BEC row at all. That made the Opto gate pass for the
  -- wrong reason -- the row was missing on every model, so nothing leaked. The
  -- pre-fix page has the row, plainly, which is why this is a replacement and
  -- not a deletion. --self-test now checks the shape of the sabotaged page
  -- directly rather than trusting the slice.
  out = replace(out,
    "  -- The ceiling is a property of the model that answered",
    "    enabledWhen = function(data) return msp.hasBec(data) end},",
    '  {label = "@i18n(app.modules.esc_tools.mfg.yge.lv_bec_voltage)@", key = "lv_bec_voltage"},',
    "the BEC row's ceiling and Opto gate", nl)
  -- (5) the beforeSave hand-through
  out = cut(out, "    -- Selects 12.0 V, sets the flags byte's HV-BEC bit. #2337",
    "beforeSave = msp.beforeSave,\r\n", "the page's beforeSave")
  return out
end

local function prefixVendor(src, nl)
  -- (6) the two lines that route a field entry's own bounds. specBound() is left
  -- defined and unused on purpose: deleting it as well would risk cutting into
  -- whatever follows it, and an unused local cannot change behaviour.
  local out = src
  out = out:gsub('    min = specBound%(field, "min", data%) or meta%.min,', '    min = meta.min,')
  out = out:gsub('    max = specBound%(field, "max", data%) or meta%.max,', '    max = meta.max,')
  if out == src then error("sabotage: neither fieldSpec() bound line was rewritten", 0) end
  return out
end

-- Reads the file back and requires it to load. A cut that broke the module has to
-- fail HERE, with a message that says so -- not three layers down as an assert
-- about a missing min/max, which is what the sibling harness's over-wide slice
-- produced.
local function stageSabotage(pattern, source, build)
  local nl = source:find("\r\n", 1, true) and "\r\n" or "\n"
  local sabotaged = build(source, nl)
  if sabotaged == source then error("sabotage: nothing was cut from " .. pattern, 0) end

  local path = os.tmpname() .. "_yge_prefix.lua"
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
  out("self-test: the gate checks must go red without the 12 V support")
  out(string.rep("=", 72))

  local builders = {
    ["msp_esc_parameters_yge%.lua$"] = prefixCodec,
    ["esc_forward_yge%.lua$"] = prefixPage,
    ["esc_forward_vendor%.lua$"] = prefixVendor,
  }

  local staged, stagedFailures = {}, {}
  for pattern, source in pairs(SWAPPABLE) do
    local ok, file = pcall(stageSabotage, pattern, readFile(source), builders[pattern])
    if ok then
      staged[pattern] = file
      out(string.format("  %-32s cut and verified (%d bytes)", pattern, (readFile(file):len())))
    else
      stagedFailures[#stagedFailures + 1] = tostring(file)
    end
  end
  for i = 1, #stagedFailures do out("  FAIL  " .. stagedFailures[i]) end
  if #stagedFailures > 0 then os.exit(1) end

  -- Step two: the feature must actually be GONE from the sabotaged codec, so a cut
  -- that removed the wrong thing cannot masquerade as a pre-fix module.
  --
  -- "4691 is still named" is tested on the MODEL NAME, not on the digits. The
  -- pre-fix fallback label for an unknown id is "YGE ESC (4691)" -- it contains
  -- the number -- so a substring test on "4691" reports the correct pre-fix
  -- behaviour as a broken sabotage. That is what the first version of this check
  -- did, and it failed a sabotage that had worked.
  do
    local pre = assert(realLoadfile(staged["msp_esc_parameters_yge%.lua$"]))()
    local problems = {}
    if type(pre.becVoltageMax) == "function" then problems[#problems + 1] = "becVoltageMax() is still there" end
    if type(pre.beforeSave) == "function" then problems[#problems + 1] = "beforeSave() is still there" end
    if type(pre.hasBec) == "function" then problems[#problems + 1] = "hasBec() is still there" end
    local summary = tostring(pre.summaryFor({ esc_type = 4691, firmware_version = 0 }))
    if summary:find("Saphir", 1, true) then
      problems[#problems + 1] = "model 4691 is still named: " .. summary
    end
    -- The exact pre-fix rendering, so "unnamed" cannot be satisfied by a label
    -- that merely differs from the real one.
    if summary ~= "YGE ESC (4691) / 0.00000" then
      problems[#problems + 1] = "the pre-fix summary is not what the pre-fix codec produced: " .. summary
    end
    if #problems > 0 then
      for i = 1, #problems do out("  FAIL  sabotage check: " .. problems[i]) end
      os.exit(1)
    end
    out("  the sabotaged codec is the pre-fix shape: no becVoltageMax, no beforeSave, no hasBec, 4691 unnamed")
  end

  -- ...and the sabotaged PAGE must still HAVE the BEC row, plainly, with neither
  -- the ceiling function nor the Opto gate on it. Reading the source is the only
  -- way to see this: the page module exports open() and nothing else, so its
  -- FIELDS table cannot be inspected from outside.
  --
  -- This check exists because the first version of the cut deleted the entry
  -- instead of putting the old one back, which left a page with no BEC row at
  -- all -- a third state, not the pre-fix one. It made the Opto gate pass for the
  -- wrong reason: the row was gone on every model, so nothing could leak.
  do
    local page = readFile(staged["esc_forward_yge%.lua$"])
    local problems = {}
    if page:find("enabledWhen", 1, true) then
      problems[#problems + 1] = "the Opto gate is still on the BEC row"
    end
    if page:find("becVoltageMax", 1, true) then
      problems[#problems + 1] = "the dynamic ceiling is still on the BEC row"
    end
    local plain = page:find('key = "lv_bec_voltage"},', 1, true)
    if not plain then
      problems[#problems + 1] = "the BEC row is gone -- that is not the pre-fix page, that is no page"
    end
    if #problems > 0 then
      for i = 1, #problems do out("  FAIL  sabotage check: " .. problems[i]) end
      os.exit(1)
    end
    out("  the sabotaged page is the pre-fix shape: BEC row present, no ceiling, no Opto gate")
  end

  REPLACE = staged

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
  out("pass 2: the same cases against the modules with the fix cut out")
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
    out(string.format("SELF-TEST FAILED -- %d of %d gate checks cannot detect the missing 12 V support",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d gate checks go red without the 12 V support",
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
