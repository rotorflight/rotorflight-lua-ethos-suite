-- Behaviour check for the Throttle Protocol list and the Motor Config defaults (#2342).
--
-- Run it:
--     lua5.3 bin/motor_protocol/verify_motor_protocol.lua
--     lua5.3 bin/motor_protocol/verify_motor_protocol.lua --self-test
--
-- WHAT THIS IS ABOUT. Issue #2342 asks for the motor and ESC protocol lists to be
-- built from what the flight controller reports rather than from static arrays, and
-- the motor half of that turned out to be three separate facts, only one of which
-- the issue named.
--
-- 1. THE DISABLED ENTRY WAS ON THE WRONG VALUE. This is the one that mattered.
--
--    rotorflight-firmware src/main/drivers/motor.h (master, 2026-10-04):
--
--        PWM_TYPE_CASTLE_LINK,   9
--        PWM_TYPE_SRXL2,        10
--        PWM_TYPE_DISABLED,     11
--
--    The list in lib/msp_motor_config.lua had no SRXL2, so its DISABLED entry
--    inherited the next free number: 10. Ten is SRXL2. Selecting "DISABLED" wrote
--    SRXL2 to the flight controller -- arming a serial ESC link instead of switching
--    the motor output off.
--
--    It stayed invisible because both ends agreed on the wrong number. The codec said
--    10, and so did the four places that fell back to it: esc_motors_throttle.lua's
--    pwmFieldsEnabled() and refreshProtocolFields(), and esc_motors_rpm.lua's
--    isDshotProtocol() and its wakeup handler. A round trip through this suite's own
--    code therefore agreed perfectly. Only the firmware's enum says otherwise, which
--    is why the enum is transcribed into this file and the constants are named.
--
-- 2. SRXL2 WAS MISSING. It reached drivers/motor.h on 2026-08-08 (e72e209d, "Add
--    support for Spektrum SRXL2 ESC", #421) and the API minor went to 10 nine days
--    later (ac1f1730, #484). So it needs API >= 12.10, which is the floor EdgeTX
--    gates the same list on (esc_motors/throttle/page.lua:395). This suite's own
--    floor is 12.09 (lib/msp_api_version.lua:69-73), so a FC this suite will talk to
--    CAN be older than SRXL2 -- 12.09 exists and is one of the two versions the
--    developer simulator offers.
--
-- 3. BRUSHED IS NOT A PROTOCOL. The firmware removed it on 2022-10-19 (9d1645a8,
--    "RTFL: Remove BRUSHED_MOTORS") and kept slot 4 as a placeholder so the numbers
--    after it would not move; drivers/motor.h still carries "// BRUSHED" on
--    PWM_TYPE_RESERVED. checkMotorProtocolEnabled() in drivers/motor.c:154-176 has
--    no case for it.
--    It is dropped from the menu outright. Keeping it visible when the FC already
--    reports 4 would require rebuilding the form after the FC payload arrives, but
--    field_layout has no re-spec path (a second buildSingle adds a second line).
--    Round-trip integrity is still preserved: decoding slot 4 and saving back commits
--    4 unchanged without corrupting the value.
--
-- WHAT IS NOT CLAIMED HERE. The firmware gates these protocols on BUILD flags --
-- checkMotorProtocolEnabled() lists them under #ifdef USE_DSHOT,
-- #ifdef USE_TELEMETRY_CASTLE and #ifdef USE_SRXL2_ESC -- and NO MSP message reports
-- those flags to the sender. The API version is therefore a PROXY, not the fact: a
-- target built without USE_SRXL2_ESC while reporting 12.10 is still offered SRXL2 and
-- will refuse it at arm time. Nothing on the wire can do better. This file therefore
-- pins the proxy and does not pretend to have the capability bits.
--
-- GATES. 8 of the 22 checks, all required to go red in --self-test.
--
-- --self-test cuts the fix back out of THREE files -- the codec's DISABLED constant,
-- the codec's choice function, and the throttle page's row-state test -- because the
-- pre-fix defect was a static table PLUS four bare `10`s spread across them. Cutting one
-- file left eight of thirteen gates green and looked like a broken harness; it was a
-- broken cut. Each spliced file is verified before use: it changed, the temp file holds
-- exactly the spliced text, and the codec carries the pre-fix signature.
--
-- Five checks are deliberately NOT gates. Four of them are the "must not offer SRXL2"
-- direction, which pre-fix was true for everybody and so cannot detect anything -- they
-- guard against a version check that fails OPEN. The fifth is the ESC RPM page opening
-- at all. A gate that cannot go red is worse than no gate.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local CODEC_SRC = SUITE .. "/lib/msp_motor_config.lua"

local replaceHits = 0

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

local REPLACE_BY_MODULE = nil
local REPLACE_ENABLED = false

_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    -- requireModule() calls loadfile() with a path carrying no directory part; on the
    -- radio the working directory is src/rfsuite.
    --
    -- NO sabotage redirect here. An earlier version of this file put one in, and it
    -- broke two unrelated things at once: it double-prefixed the absolute paths the
    -- page loaders pass (giving "rfsuite/bin/.../rfsuite/app/pages/..."), and because
    -- lib/require.lua resolves its own modules through the global loadfile, it also
    -- re-prefixed names it had already resolved -- "cannot open app/field_layout.lua".
    -- The redirect belongs where the path is built, not in every load in the process.
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
  addStaticText = function(_, _, text)
    obs.staticTexts[#obs.staticTexts + 1] = text
    -- Must RETURN a widget: app/header.lua:178 does
    -- `titleField = form.addStaticText(...)` and its setTitle() then calls
    -- titleField:value(newTitle) (header.lua:191). A stub that returns nil makes
    -- page_runtime's updateTitle() -- which onSessionUpdate() calls -- die with
    -- "attempt to index a nil value (upvalue 'titleField')".
    return widgetStub("staticText")
  end,
  addNumberField = function(line, _, min, max, get, setWithDirty)
    local field = fieldFor(line)
    field.kind, field.min, field.max = "number", min, max
    field.get, field.set = get, setWithDirty
    return widgetStub("numberField", field)
  end,
  -- A choice widget stores the VALUE, not the index the pilot picked, and it gets there
  -- by mapping the chosen row's own value out of the list it was built with.
  --
  -- That mapping is the whole point of this stub. The first version had set() write
  -- whatever number the test handed it, so "select DISABLED, read the byte" passed
  -- against the pre-fix codec: the test wrote 11 itself and encode() dutifully wrote 11
  -- back, proving nothing about which value the DISABLED ROW carried. With the mapping
  -- in place the test picks the row by its label and the row's own value reaches the
  -- wire -- which is how a wrong DISABLED entry becomes a wrong byte.
  addChoiceField = function(line, _, choices, get, setWithDirty)
    local field = fieldFor(line)
    field.kind, field.choices = "choice", choices
    field.get = get
    field.set = function(value)
      -- Resolution order: a row INDEX, then a row LABEL, then a raw value. A case may
      -- say any of the three, and the label is the one that matters for this file --
      -- "DISABLED" is a row, and which number that row carries is the defect.
      --
      -- The first version matched index then VALUE only, so `set("DISABLED")` fell
      -- through to the raw-value branch and handed a STRING to the encoder:
      -- "bad argument #1 to 'math_floor' (number expected, got string)" from
      -- mspcodec.lua:86. The crash was in the harness's own stub, not in the codec.
      local entry = type(value) == "number" and choices[value] or nil
      if not entry and type(value) == "string" then
        for i = 1, #choices do
          if choices[i][1] == value then entry = choices[i]; break end
        end
      end
      if not entry and type(value) == "number" then
        for i = 1, #choices do
          if choices[i][2] == value then entry = choices[i]; break end
        end
      end
      if entry then
        field.chosen = entry[1]
        setWithDirty(entry[2])
      else
        field.chosen = nil
        setWithDirty(value)
      end
    end
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

-- The real bus RETAINS "session.update" and replays it to a new subscriber
-- synchronously (lib/bus.lua:18 and :97). page_runtime subscribes in its constructor,
-- so in the running suite runtime.apiVersionMinor is set BEFORE open() reaches its
-- first buildSingle().
--
-- The stub below used to be a plain no-op subscribe, which made the API version arrive
-- after the field was built -- and then the page cases failed for a reason that does
-- not exist on the radio. A stub that is more faithful than the thing it stands in for
-- is worse than no stub, so subscribe() delivers the snapshot immediately, in the order
-- the real one does.
local sessionSnapshot = nil

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function(topic, handler)
    if topic == "session.update" and sessionSnapshot and type(handler) == "function" then
      handler(sessionSnapshot)
    end
  end,
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

-- The runtime, reached through the REAL field_layout: a pilot edit is the call Ethos
-- makes on the setter it built, and stubbing it would make the page cases vacuous.
-- It keeps no reference to the runtime it builds fields for, so buildSingle() is
-- WRAPPED rather than replaced.
local fieldLayout = requireModule("app/field_layout.lua")
do
  local buildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, label, spec, parent)
    if not obs.runtime then obs.runtime = runtime end
    return buildSingle(runtime, label, spec, parent)
  end
end

-- ---------------------------------------------------------------------------
-- The codec
-- ---------------------------------------------------------------------------

local CODEC_KEY = "rfsuite.lib.msp_motor_config"

local function loadCodec(file)
  package.loaded[CODEC_KEY] = nil
  return assert(realLoadfile(file or CODEC_SRC))()
end

-- The page loaders consult the sabotage table HERE, where the path is built, rather
-- than through the global loadfile.
--
-- realLoadfile on its own would read the checked-out file, so pass 2 would run the real
-- page against the pre-fix codec -- a third combination that is neither the fix nor the
-- pre-fix state, and one whose gates pass for the wrong reason. An earlier version put
-- the redirect inside _G.loadfile instead, which broke lib/require.lua's own resolution
-- and double-prefixed these very paths; see the note on the override above.
local function loadPage(file, moduleName)
  local tmp = REPLACE_BY_MODULE and REPLACE_BY_MODULE[moduleName]
  if tmp then
    replaceHits = replaceHits + 1
    return assert(realLoadfile(tmp))()
  end
  return assert(realLoadfile(file))()
end

local function loadThrottlePage()
  return loadPage(SUITE .. "/app/pages/esc_motors_throttle.lua", "esc_motors_throttle")
end

local function loadRpmPage()
  return loadPage(SUITE .. "/app/pages/esc_motors_rpm.lua", "esc_motors_rpm")
end

local codec

-- ---------------------------------------------------------------------------
-- The firmware's enum, transcribed
-- ---------------------------------------------------------------------------
--
-- rotorflight-firmware src/main/drivers/motor.h. This is the authority for every
-- number below; the values are NOT read from the suite, because a check that reads
-- the suite's own tables only proves the suite agrees with itself. That is precisely
-- how a wrong DISABLED survived here.
local ENUM = {
  PWM = 0, ONESHOT125 = 1, ONESHOT42 = 2, MULTISHOT = 3,
  RESERVED_BRUSHED = 4,
  DSHOT150 = 5, DSHOT300 = 6, DSHOT600 = 7, PROSHOT = 8,
  CASTLE = 9, SRXL2 = 10, DISABLED = 11,
}

local SRXL2_MIN_API_MINOR = 10

-- ---------------------------------------------------------------------------
-- Helpers over a choice list
-- ---------------------------------------------------------------------------

local function labelsOf(choices)
  local out2 = {}
  for i = 1, #choices do out2[i] = tostring(choices[i][1]) end
  return out2
end

local function valuesOf(choices)
  local out2 = {}
  for i = 1, #choices do out2[i] = choices[i][2] end
  return out2
end

local function indexOfLabel(choices, label)
  for i = 1, #choices do
    if choices[i][1] == label then return i end
  end
  return nil
end

local function valueOfLabel(choices, label)
  local i = indexOfLabel(choices, label)
  return i and choices[i][2] or nil
end

local function hasLabel(choices, label)
  return indexOfLabel(choices, label) ~= nil
end

-- ---------------------------------------------------------------------------
-- Driving the pages
-- ---------------------------------------------------------------------------

local ROW_PROTOCOL = "@i18n(app.modules.esc_motors.throttle_protocol)@"
local ROW_PWM_RATE = "@i18n(app.modules.esc_motors.motor_pwm_rate)@"
local ROW_UNSYNCED = "@i18n(app.modules.esc_motors.unsynced)@"

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

-- WHICH byte motor_pwm_protocol occupies, counted from the field lists rather than
-- guessed. READ and WRITE are at DIFFERENT offsets, and that is not a subtlety -- it is
-- the same field in two lists that do not have the same members:
--
--   READ_FIELDS   minthrottle U16, maxthrottle U16, mincommand U16  -> bytes 1..6
--                 motor_count_blheli U8, motor_pole_count_blheli U8,
--                 use_dshot_telemetry U8                            -> bytes 7..9
--                 motor_pwm_protocol                                 -> byte 10
--
--   WRITE_FIELDS  the same three U16                                 -> bytes 1..6
--                 NO motor_count_blheli, so motor_pole_count_blheli  -> byte 7
--                 use_dshot_telemetry                               -> byte 8
--                 motor_pwm_protocol                                 -> byte 9
--
-- One constant for both was the first version of this file, and it produced two
-- failures that read like codec bugs: the decode check reported "all twelve protocols
-- come back as 0" (it was poking byte 7, motor_count_blheli), and the save check read
-- byte 10 of a 28-byte payload. Two constants, derived and commented, is the fix.
local READ_PROTOCOL_BYTE = 10
local WRITE_PROTOCOL_BYTE = 9

local function blockWithProtocol(protocol)
  local message = codec.buildReadMessage(function() end, function() end)
  local buf = {}
  for i, v in ipairs(message.simulatorResponse) do buf[i] = v end
  if protocol ~= nil then buf[READ_PROTOCOL_BYTE] = protocol end
  return buf
end

local function openThrottle(protocol, apiMinor)
  resetObs()
  reply = blockWithProtocol(protocol)
  replyFails = false
  -- Set BEFORE open(), so the stub bus replays it on page_runtime's subscribe exactly
  -- where the real bus would.
  sessionSnapshot = {isArmed = false, apiVersionMinor = apiMinor}

  local opts = freshOpts()
  throttle.open(opts)
  opts.__installed.setWakeupHandler()
  opts.__runtime = obs.runtime
  return obs.runtime, opts
end

local function rowField(key)
  for i = 1, #obs.fieldOrder do
    if obs.fieldOrder[i].label == key then return obs.fieldOrder[i] end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- 1. The DISABLED value
-- ---------------------------------------------------------------------------

local function checkDisabledValue()
  out("")
  out("DISABLED is 11 in the firmware, and 11 is what goes on the wire")

  local wrong = {}
  for _, apiMinor in ipairs({9, 10}) do
    local choices = codec.protocolChoices(apiMinor)
    local got = valueOfLabel(choices, "DISABLED")
    if got ~= ENUM.DISABLED then
      wrong[#wrong + 1] = string.format("at API 12.%d DISABLED is %s, expected %d",
        apiMinor, tostring(got), ENUM.DISABLED)
    end
  end
  gateCheck(string.format("DISABLED is %d, never the neighbouring %d", ENUM.DISABLED, ENUM.SRXL2),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)

  -- Every offered label must carry the value the enum gives that protocol. This is
  -- the check that states the bug rather than the symptom: before the fix the list
  -- was self-consistent and DISABLED sat on SRXL2's number.
  local choices = codec.protocolChoices(10)
  local mismatched = {}
  for _, entry in ipairs(choices) do
    local want = ENUM[tostring(entry[1])]
    if want == nil then
      mismatched[#mismatched + 1] = string.format("%q is not a name in the firmware's enum", tostring(entry[1]))
    elseif entry[2] ~= want then
      mismatched[#mismatched + 1] = string.format("%s carries %s, the enum says %d",
        tostring(entry[1]), tostring(entry[2]), want)
    end
  end
  gateCheck("every offered label carries the value the firmware's enum gives that protocol",
    #mismatched == 0, #mismatched > 0 and table.concat(mismatched, "; ") or nil)

  -- The export the pages use must not be a bare literal that can drift again.
  --
  -- The label deliberately does NOT carry the value. A label that interpolates the
  -- number under test is a different string in the two passes, and the drift check
  -- then reports the gate as "only in pass 1" and "only in pass 2" -- which reads like
  -- two different checks rather than one check that saw two different values. The
  -- first version of this file did exactly that and it cost a self-test iteration.
  gateCheck("the pages read DISABLED from the codec rather than a literal",
    codec.DISABLED_PROTOCOL == ENUM.DISABLED,
    string.format("DISABLED_PROTOCOL is %s, expected %d", tostring(codec.DISABLED_PROTOCOL), ENUM.DISABLED))
end

-- ---------------------------------------------------------------------------
-- 2. SRXL2 appears only on an FC that has it
-- ---------------------------------------------------------------------------

local function checkSrxl2Gating()
  out("")
  out(string.format("SRXL2 needs API %d.%d, and the suite's floor is below that",
    12, SRXL2_MIN_API_MINOR))

-- The four cases below are NOT gates, and the self-test says so rather than the test
  -- passing quietly. All four pass on the pre-fix codec, because pre-fix SRXL2 was
  -- never offered to anyone -- so they cannot detect the defect. They guard the FIX
  -- instead: an apiMinor that fell through to "show everything" would put SRXL2 in
  -- front of a pilot whose FC is older than the protocol, or whose handshake has not
  -- finished, and that is the mistake a version gate invites. Kept as checks, with
  -- that reason here.
  local wrong = {}
  local absent = {
    {what = "a 12.09 FC", minor = 9},
    {what = "a 12.08 FC", minor = 8},
  }
  for _, case in ipairs(absent) do
    if hasLabel(codec.protocolChoices(case.minor), "SRXL2") then
      wrong[#wrong + 1] = case.what .. " is offered SRXL2"
    end
  end
  check(string.format("an FC below API 12.%d is not offered SRXL2", SRXL2_MIN_API_MINOR),
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)

  -- nil is the interesting one: the handshake may not have finished, and a pilot
  -- looking at the page in that window must get the SMALLER list. A nil that fell
  -- through to "show everything" would be the unsafe direction.
  check("an FC whose API version is not known yet is not offered SRXL2",
    not hasLabel(codec.protocolChoices(nil), "SRXL2"),
    "SRXL2 is offered while the API version is unknown")

  -- A non-number must behave like nil, not crash and not leak the big list. The
  -- developer "simulated API version" picker has an "invalid" mode that is a STRING on
  -- purpose (lib/msp_api_version.lua's INVALID_SIM_RESPONSE path), so a string
  -- reaching here is a real case and not a theoretical one.
  local oddWrong = {}
  for _, odd in ipairs({"12.09", "", "invalid", false}) do
    local ok, list = pcall(codec.protocolChoices, odd)
    if not ok then
      oddWrong[#oddWrong + 1] = string.format("apiMinor %s raised %s", tostring(odd), tostring(list))
    elseif hasLabel(list, "SRXL2") then
      oddWrong[#oddWrong + 1] = string.format("apiMinor %s was offered SRXL2", tostring(odd))
    end
  end
  check("a non-numeric API version is treated as unknown, not as new enough",
    #oddWrong == 0, #oddWrong > 0 and table.concat(oddWrong, "; ") or nil)

  local present = codec.protocolChoices(SRXL2_MIN_API_MINOR)
  gateCheck(string.format("a 12.%d FC IS offered SRXL2, with the enum's value %d",
    SRXL2_MIN_API_MINOR, ENUM.SRXL2),
    valueOfLabel(present, "SRXL2") == ENUM.SRXL2,
    string.format("SRXL2 carries %s", tostring(valueOfLabel(present, "SRXL2"))))

  -- CASTLE has no gate, and that is deliberate rather than an omission: this suite
  -- refuses to operate below 12.09 (lib/msp_api_version.lua:69-73) while CASTLE's
  -- floor is 12.08, so a gate here could never refuse anything. NOT a gate of its
  -- own -- it would pass on the pre-fix codec too, which also always offered CASTLE.
  for _, minor in ipairs({8, 9, 10, nil}) do
    local list = codec.protocolChoices(minor)
    check(string.format("CASTLE stays available at API %s, above its own 12.08 floor",
        minor and ("12." .. tostring(minor)) or "unknown"),
      valueOfLabel(list, "CASTLE") == ENUM.CASTLE,
      string.format("CASTLE carries %s, expected %d", tostring(valueOfLabel(list, "CASTLE")), ENUM.CASTLE))
  end
end

-- ---------------------------------------------------------------------------
-- 3. BRUSHED: out of the menu, still visible if already set
-- ---------------------------------------------------------------------------

local function checkBrushed()
  out("")
  out("BRUSHED is a reserved slot, not a protocol, so it leaves the menu")

  -- Not offered, whatever the FC reports and whatever its API version. This is the
  -- only BRUSHED check that can be a gate: the pre-fix list carried it
  -- unconditionally, so it goes red there.
  local wrong = {}
  for _, minor in ipairs({8, 9, 10, nil}) do
    if hasLabel(codec.protocolChoices(minor), "BRUSHED") then
      wrong[#wrong + 1] = string.format("BRUSHED offered at API %s", tostring(minor))
    end
  end
  gateCheck("BRUSHED is not offered as a choice, at any API version",
    #wrong == 0, #wrong > 0 and table.concat(wrong, "; ") or nil)

  -- NOT a gate, and worth being explicit about why: the pre-fix list was
  -- 0,1,2,3,4,5,6,7,8,9,10 -- perfectly ascending. So an ordering check cannot
  -- detect this change at all; it exists only because SRXL2 has to land in front of
  -- DISABLED rather than after it, which is a property of the list, not of the fix.
  -- It caught a real bug once -- the first choicesFor() appended SRXL2, giving
  -- ... 9 11 10 -- but "the list is in order" is not something the old code broke.
  local order = valuesOf(codec.protocolChoices(SRXL2_MIN_API_MINOR))
  local ascending, firstBad = true, nil
  for i = 2, #order do
    if order[i] < order[i - 1] then
      ascending = false
      firstBad = string.format("%d is followed by %d", order[i - 1], order[i])
      break
    end
  end
  check("the offered values are in ascending enum order, SRXL2 before DISABLED",
    ascending,
    "values: " .. table.concat(order, ", ") .. "; first break: " .. tostring(firstBad))

  -- The consequence of dropping it, stated rather than left to be discovered. This is
  -- a COMMENT-shaped fact and not a check: whether Ethos draws a choice row whose value
  -- is absent from the list as blank or snaps it to the first entry cannot be answered
  -- from this repository, and a check that asserts either answer would be asserting a
  -- guess. What IS verifiable is that no data is at risk, and that is checked below.
  local buf = blockWithProtocol(ENUM.RESERVED_BRUSHED)
  local data
  codec.buildReadMessage(function(d) data = d end, function() end).processReply(nil, buf)
  local payload = codec.buildWriteMessage(data, function() end, function() end).payload
  check(string.format("an FC on the reserved slot still decodes to %d and saves it back unchanged",
    ENUM.RESERVED_BRUSHED),
    data ~= nil and tonumber(data.motor_pwm_protocol) == ENUM.RESERVED_BRUSHED
      and payload ~= nil and payload[WRITE_PROTOCOL_BYTE] == ENUM.RESERVED_BRUSHED,
    payload and string.format("decodes %s, saves %s",
      data and tostring(data.motor_pwm_protocol) or "nothing",
      tostring(payload[WRITE_PROTOCOL_BYTE])) or "no payload")
end

-- ---------------------------------------------------------------------------
-- 4. Through the real page
-- ---------------------------------------------------------------------------

local function checkThroughThePage()
  out("")
  out("the Throttle page offers the FC's list, not a table of its own")

  local function labelsFor(apiMinor, protocol)
    openThrottle(protocol, apiMinor)
    local field = rowField(ROW_PROTOCOL)
    return field and field.choices or nil
  end

  -- NOT a gate: pre-fix the page never offered SRXL2 either, so this cannot detect the
  -- defect. It is the guard against the gate going the other way -- a version check that
  -- failed open would put SRXL2 in front of a pilot on 12.09, and that is the mistake
  -- this change is exposed to.
  local old = labelsFor(9, ENUM.SRXL2)
  check("on a 12.09 FC the page does not offer SRXL2",
    old ~= nil and not hasLabel(old, "SRXL2"),
    old and ("offers: " .. table.concat(labelsOf(old), ", ")) or "the row was never built")

  local new = labelsFor(10, ENUM.SRXL2)
  gateCheck("on a 12.10 FC the page offers SRXL2",
    new ~= nil and hasLabel(new, "SRXL2"),
    new and ("offers: " .. table.concat(labelsOf(new), ", ")) or "the row was never built")

  -- And the page's own row-state logic knows SRXL2, which it did not before: the
  -- PWM-rate and throttle-window rows apply to it, exactly as they do to CASTLE.
  do
    local runtime = openThrottle(ENUM.SRXL2, 10)
    local rate, unsynced = rowField(ROW_PWM_RATE), rowField(ROW_UNSYNCED)
    gateCheck("on SRXL2 the PWM-rate row is enabled and the unsynced-PWM row is not",
      rate ~= nil and rate.widget.enabled == true
        and unsynced ~= nil and unsynced.widget.enabled == false,
      string.format("pwm_rate enabled=%s, unsynced enabled=%s",
        rate and tostring(rate.widget.enabled), unsynced and tostring(unsynced.widget.enabled)))
  end

  -- DISABLED through the page and onto the wire. This is the end-to-end statement of
  -- bug 1: pick DISABLED on the row, save, and read the byte the FC is told.
  do
    local runtime, opts = openThrottle(ENUM.DSHOT300, 10)
    local field = rowField(ROW_PROTOCOL)
    if not field then
      gateCheck("selecting DISABLED writes 11, not SRXL2's 10", false, "the row was never built")
    else
      -- The test picks the row by its LABEL, and the widget stub maps that row's own value
      -- onto the data. Against the pre-fix list the DISABLED row carries 10, so this
      -- writes 10 and the gate goes red on the value rather than on the label.
      field.set("DISABLED")
      local writesBefore = #obs.writes
      runtime:confirmSave(runtime.headerHandle.focusSave)
      opts.__installed.setWakeupHandler()
      local payload = nil
      for i = writesBefore + 1, #obs.writes do
        if obs.writes[i].command == codec.WRITE_COMMAND then payload = obs.writes[i].payload end
      end
      -- motor_pwm_protocol is WRITE_FIELDS' 7th entry; see WRITE_PROTOCOL_BYTE above.
      local wrote = payload and payload[WRITE_PROTOCOL_BYTE]
      gateCheck(string.format("picking DISABLED on the row writes %d, not SRXL2's %d",
        ENUM.DISABLED, ENUM.SRXL2),
        wrote == ENUM.DISABLED and field.chosen == "DISABLED",
        payload and string.format("the DISABLED row carries %s, and byte %d is %s",
          tostring(field.chosen), WRITE_PROTOCOL_BYTE, tostring(wrote)) or "no write went out")
    end
  end

  -- The RPM page shares the codec and had the same bare literal in two places.
  do
    resetObs()
    reply = blockWithProtocol(ENUM.DISABLED)
    replyFails = false
    local opts = freshOpts()
    local ok, err = pcall(function() rpm.open(opts) end)
    check("the ESC RPM page opens on a FC whose protocol is DISABLED",
      ok == true,
      not ok and tostring(err) or nil)
  end
end

-- ---------------------------------------------------------------------------
-- 5. Nothing else moved
-- ---------------------------------------------------------------------------

local function checkNothingElseMoved()
  out("")
  out("the rest of MSP_MOTOR_CONFIG is untouched (not gates -- they pass before too)")

  -- What this change did NOT touch: decode() and encode(). They are byte-for-byte
  -- unchanged, and MSP_MOTOR_CONFIG is not a mirror anyway -- READ_FIELDS carries
  -- motor_count_blheli and motor_rpm_lpf_0..2, which WRITE_FIELDS does not have, so a
  -- blanket "every read byte survives" claim is false by construction.
  --
  -- The first version of this file asserted exactly that and reported 7168 failures
  -- ("byte 7 value 0 came back as 6"), then a second version tried "is the value
  -- present somewhere in the payload" and failed on the three U16 fields, whose value
  -- spans two bytes and matches neither. Both were the check being wrong, not the
  -- codec. What is worth asserting is stated below, and the per-protocol decode
  -- check above is the one that covers the protocol field in both directions.
  --
  -- So: the write payload is exactly the length WRITE_FIELDS implies, and the two
  -- commands are the ones MSP_MOTOR_CONFIG is defined with.
  local payload = codec.buildWriteMessage({minthrottle = 1070}, function() end, function() end).payload
  check(string.format("a save produces the 28-byte payload MSP_MOTOR_CONFIG defines"),
    type(payload) == "table" and #payload == 28,
    payload and string.format("payload is %d bytes", #payload) or "no payload")
  check("MSP_MOTOR_CONFIG reads with 131 and writes with 222",
    codec.READ_COMMAND == 131 and codec.WRITE_COMMAND == 222,
    string.format("%s / %s", tostring(codec.READ_COMMAND), tostring(codec.WRITE_COMMAND)))

  -- Every protocol a FC may legitimately report must be DECODABLE, including the two
  -- the menu hides. A list is not allowed to be the only thing that knows a value.
  local undecodable = {}
  for name, value in pairs(ENUM) do
    local data
    codec.buildReadMessage(function(d) data = d end, function() end)
      .processReply(nil, blockWithProtocol(value))
    if data == nil or tonumber(data.motor_pwm_protocol) ~= value then
      undecodable[#undecodable + 1] = string.format("%s (%d) reads back as %s",
        name, value, data and tostring(data.motor_pwm_protocol) or "nothing")
    end
  end
  check(string.format("all %d firmware protocols decode back to themselves, menu or no menu",
    (function()
      local n = 0
      for _ in pairs(ENUM) do n = n + 1 end
      return n
    end)()),
    #undecodable == 0, #undecodable > 0 and table.concat(undecodable, "; ") or nil)

  -- And FIELD_META's fallback must be the SAFE subset, since it is what any caller
  -- that does not ask for the filtered list gets.
  local fallback = codec.FIELD_META.motor_pwm_protocol.choices or {}
  check("FIELD_META's fallback list hides SRXL2 and BRUSHED",
    not hasLabel(fallback, "SRXL2") and not hasLabel(fallback, "BRUSHED"),
    "fallback offers: " .. table.concat(labelsOf(fallback), ", "))
end

local function runChecks()
  throttle = loadThrottlePage()
  rpm = loadRpmPage()
  checkDisabledValue()
  checkSrxl2Gating()
  checkBrushed()
  checkThroughThePage()
  checkNothingElseMoved()
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("Motor Throttle Protocol: the list follows the FC (#2342)")
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

-- The pre-fix choice function, verbatim in behaviour: one static table, DISABLED on
-- 10 because SRXL2 was missing, BRUSHED always in it.
--
-- The SHAPE is kept on purpose -- same name, same one argument, returns a list -- so
-- the pages under test still call it. Splicing the pre-fix FILE instead would leave
-- motorConfig.protocolChoices undefined and the pages would die with "attempt to call
-- a nil value", which is a broken harness rather than a red one.
--
-- Level-two long strings: a bare "]]" inside would close a plain long string early.
local CHOICES_SPLICE = [==[
local function choicesFor(apiMinor)
  return {
    {"PWM", 0},
    {"ONESHOT125", 1},
    {"ONESHOT42", 2},
    {"MULTISHOT", 3},
    {"BRUSHED", 4},
    {"DSHOT150", 5},
    {"DSHOT300", 6},
    {"DSHOT600", 7},
    {"PROSHOT", 8},
    {"CASTLE", 9},
    {"DISABLED", 10},
  }
end

]==]

-- The pre-fix row-state test, verbatim. It knew only CASTLE:
-- `return protocol <= 4 or protocol == 9`.
local PWM_FIELDS_SPLICE = [==[
local function pwmFieldsEnabled(protocol)
  return protocol <= 4 or protocol == 9
end

]==]

-- THREE files carry the fix, and all three have to go back. This is the lesson from
-- the first attempt at this self-test, which spliced only choicesFor() and left 8 of
-- 13 gates green: the pre-fix code was a static table PLUS four bare `10`s across the
-- codec and two pages, so one function is not the defect. Cutting one file and calling
-- the rest "pre-fix" would have produced a self-test that reported eight green gates
-- and looked like the harness was broken, when in fact the sabotage was.
--
-- The pages read DISABLED through motorConfig.DISABLED_PROTOCOL rather than a literal,
-- so putting DISABLED back to 10 in the codec makes BOTH pages wrong again without
-- touching them -- which is exactly what that indirection was for, and the round trip
-- proves it: no page needs its own splice for the wrong value.
local SABOTAGE = {
  {
    file = CODEC_SRC,
    module = "msp_motor_config%.lua$",
    what = "the DISABLED constant",
    apply = function(source, nl)
      local from = assert(source:find("local DISABLED = ", 1, true), "no DISABLED constant")
      local toEol = assert(source:find("\n", from, true), "DISABLED constant has no line end")
      return source:sub(1, from - 1) .. "local DISABLED = 10" .. source:sub(toEol)
    end,
  },
  {
    file = CODEC_SRC,
    module = "msp_motor_config%.lua$",
    what = "the protocol choices",
    apply = function(source, nl)
      -- Closed on ON_OFF_CHOICES, which is the line immediately after choicesFor's
      -- `end`. The first attempt closed on `local msp_motor_config = {` and so cut out
      -- ON_OFF_CHOICES, READ_FIELDS, WRITE_FIELDS, FIELD_META and SIMULATOR_RESPONSE as
      -- well -- five tables the codec needs to exist at all. A too-wide anchor is the
      -- same failure as a too-narrow one, and it looks like nothing at all.
      return presplice(source, "local function choicesFor(apiMinor)",
        "local ON_OFF_CHOICES = {", (CHOICES_SPLICE:gsub("\n", nl)), "protocol choices")
    end,
  },
  {
    file = SUITE .. "/app/pages/esc_motors_throttle.lua",
    module = "esc_motors_throttle%.lua$",
    what = "the PWM-rate row-state test",
    apply = function(source, nl)
      return presplice(source, "local function pwmFieldsEnabled(protocol)",
        "local function unsyncedEnabled(protocol)", (PWM_FIELDS_SPLICE:gsub("\n", nl)),
        "row-state test")
    end,
  },
}

-- Apply every sabotage step, grouped per file, and return one temp file per module.
local function buildSabotage()
  local byFile, order = {}, {}
  for _, step in ipairs(SABOTAGE) do
    if not byFile[step.file] then
      byFile[step.file] = {}
      order[#order + 1] = step.file
    end
    local list = byFile[step.file]
    list[#list + 1] = step
  end

  local temps, texts, applied = {}, {}, {}
  for _, path in ipairs(order) do
    local original = readFile(path)
    local nl = newlineOf(original)
    local sabotaged = original
    for _, step in ipairs(byFile[path]) do
      local before = sabotaged
      sabotaged = step.apply(sabotaged, nl)
      applied[#applied + 1] = {path = path, what = step.what, changed = sabotaged ~= before}
    end
    temps[path] = writeTmp(sabotaged)
    texts[path] = sabotaged
  end
  return temps, texts, applied
end

local function countFiles(applied)
  local n, seen = 0, {}
  for _, e in ipairs(applied) do
    if not seen[e.path] then seen[e.path] = true; n = n + 1 end
  end
  return n
end

-- What each spliced file must be BEFORE it may stand in for the pre-fix one: it
-- changed, it reads back byte for byte, and it loads. On top of that the codec is
-- checked POSITIVELY -- DISABLED on 10, BRUSHED offered, SRXL2 not offered at any
-- version -- and the page is checked by the EFFECT of its local pwmFieldsEnabled(),
-- because a local function cannot be read from outside the page.
--
-- Checking only that SRXL2 is ABSENT is weaker than it looks: a codec that offered
-- SRXL2 on every version would pass that. The first version of this file did check
-- only the absence, which is one of the reasons it needed replacing.
local function verifySabotage(temps, texts, applied)
  local problems = {}

  for _, entry in ipairs(applied) do
    if not entry.changed then
      problems[#problems + 1] = string.format("%s: %s changed nothing",
        entry.path:match("[^/\\]+$") or entry.path, entry.what)
    end
  end

  -- Each temp file must hold EXACTLY the text that was spliced into it. Comparing it
  -- against the checked-out original -- which the first version of this check did --
  -- reports every file as failing, because a splice is supposed to differ. That check
  -- looked like a broken splice and was a broken comparison.
  for path, tmp in pairs(temps) do
    local written = readFile(tmp)
    if written ~= texts[path] then
      problems[#problems + 1] = string.format("%s: temp file holds %d bytes, expected %d",
        path:match("[^/\\]+$") or path, #written, #(texts[path] or ""))
    end
  end

  package.loaded[CODEC_KEY] = nil
  local ok, spliced = pcall(function() return assert(realLoadfile(temps[CODEC_SRC]))() end)
  if not ok then
    problems[#problems + 1] = "msp_motor_config: does not load: "
      .. tostring(spliced):gsub(".*%.lua:%d+: ", "")
  else
    local function probe(minor)
      local disabled, brushed, srxl2 = nil, false, false
      for _, entry in ipairs(spliced.protocolChoices(minor) or {}) do
        if entry[1] == "DISABLED" then disabled = entry[2] end
        if entry[1] == "BRUSHED" then brushed = true end
        if entry[1] == "SRXL2" then srxl2 = true end
      end
      return disabled, brushed, srxl2
    end
    local disabled, brushed10, srxl2_10 = probe(10)
    if disabled ~= 10 then
      problems[#problems + 1] = string.format(
        "msp_motor_config: DISABLED is %s at 12.10, so this is not the pre-fix codec",
        tostring(disabled))
    end
    if not brushed10 then
      problems[#problems + 1] = "msp_motor_config: hides BRUSHED at 12.10, so this is not the pre-fix codec"
    end
    if srxl2_10 then
      problems[#problems + 1] = "msp_motor_config: offers SRXL2 at 12.10, so this is not the pre-fix codec"
    end
    package.loaded[CODEC_KEY] = nil
  end

  -- The PAGE is deliberately NOT probed here. pwmFieldsEnabled is a local, so the only
  -- way to see it is through the row state it drives -- which needs the full form stub,
  -- and the full form stub only exists in runChecks(). An earlier version of this file
  -- built a second, thinner stub for the probe and it died in app/header.lua:131. That
  -- is not a gap in the evidence: pass 2 runs runChecks() with the spliced page and
  -- its own gate ("on SRXL2 the PWM-rate row is enabled and the unsynced-PWM row is
  -- not"), which is the same assertion with a stub that is already known to work.
  if readFile(temps[SUITE .. "/app/pages/esc_motors_throttle.lua"]) == "" then
    problems[#problems + 1] = "esc_motors_throttle: spliced file is empty"
  end

  return #problems == 0, table.concat(problems, "; ")
end

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the protocol-list checks must go red on the pre-fix code")
  out(string.rep("=", 72))

local temps, texts, applied = buildSabotage()

  local spliceOk, spliceDetail = verifySabotage(temps, texts, applied)
  out(string.format("  %s  splice (%d step(s) over %d file(s)): %s", spliceOk and "ok   " or "FAIL ",
    #applied, countFiles(applied),
    spliceDetail ~= "" and spliceDetail
      or "every file changed, reads back, loads, and has the pre-fix signature"))
  if not spliceOk then
    for _, tmp in pairs(temps) do os.remove(tmp) end
    os.exit(1)
  end

  -- One redirect entry per module, so the PAGE is served the spliced page too. A
  -- redirect that only served the codec would leave pass 2 running the real page
  -- against the old codec -- which is a third combination, and not the pre-fix one.
  REPLACE_BY_MODULE = {}
  for path, tmp in pairs(temps) do
    REPLACE_BY_MODULE[path:match("([^/\\]+)%.lua$")] = tmp
  end
  REPLACE_ENABLED = true

  -- Loaded DIRECTLY from the temp file, not through loadCodec()'s default: that helper
  -- reads the checked-out path with realLoadfile, which no redirect touches here.
  --
  -- AND IT STAYS in package.loaded. Clearing it -- as the sibling harnesses do, because
  -- they redirect inside _G.loadfile -- hands the pages the REAL codec: they resolve it
  -- through requireModule, and an empty cache means "load it from disk". The symptom was
  -- a page-level gate reading STAYS GREEN while the same assertion at codec level went
  -- red, which is the worst kind of wrong: the page was quietly testing the fix against
  -- itself. The spliced module must be what the page finds.
  codec = loadCodec(temps[CODEC_SRC])

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = 0

  local pass1Gates = {}
  for i = 1, #MUST_GO_RED do pass1Gates[MUST_GO_RED[i]] = (pass1Gates[MUST_GO_RED[i]] or 0) + 1 end
  MUST_GO_RED = {}

  out("")
  out("pass 2: the same cases against the pre-fix code")
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
  REPLACE_ENABLED = false
  REPLACE_BY_MODULE = {}
  for _, tmp in pairs(temps) do os.remove(tmp) end

  out("")
  out(string.format("  (spliced files served %d time(s))", replaceHits))
  if replaceHits == 0 then
    out("  FAIL  no spliced file ever ran -- pass 2 proved nothing")
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