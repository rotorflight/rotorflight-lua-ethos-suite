-- Behaviour check for the servo index spaces on the BUS servo page (#2360).
--
-- Run it:
--     lua5.3 bin/servos_bus/verify_servos_bus_index.lua
--     lua5.3 bin/servos_bus/verify_servos_bus_index.lua --self-test
--
-- What it drives, and why:
--   * The real app/pages/servos_bus.lua, loaded the way the radio loads it.
--     The four commands this page sends each carry a servo index as the first
--     payload byte, and the claim being pinned is that all four carry the same
--     one. So the harness records every MSP message the page publishes and
--     reads the index straight out of the payload, rather than calling the
--     page's index helper and asserting on its result: a helper that is right
--     and a call site that does not use it produce identical arithmetic and
--     opposite behaviour.
--
--   * The payload bytes are real. lib/msp_servo_config.lua, msp_servo_center.lua,
--     msp_servo_override.lua, msp_status.lua and msp_mixer_config.lua are the
--     actual modules, and so is lib/mspcodec.lua behind them. Only lib/bus.lua
--     is replaced, by a recorder that answers a read with the module's own
--     simulatorResponse buffer -- the same seam the Ethos simulator uses -- so
--     the decoders run for real and the byte compared here is the byte that
--     goes on the wire.
--
--   * The one reply that is edited is MSP_STATUS, and only in the servo_count
--     byte. That number is the whole reason the pre-fix page was wrong, and it
--     is derived here rather than guessed: msp.c:1098-1104 reports
--     getServoCount() + BUS_SERVO_CHANNELS when bus servos are configured, and
--     getServoCount() is the contiguous servoConfig()->ioTags prefix
--     (src/main/flight/servos.c:154-168), bounded by MAX_SUPPORTED_PWM_SERVOS
--     (common_defaults_post.h:702). Three cyclic servos plus a tail is 4, so
--     the answer is 4 + 18 = 22. The buffer the module ships says 4, which is
--     the simulator fixture value and not what the firmware sends; leaving it
--     alone would make the pre-fix offset zero and hide the defect.
--
--   * The firmware side of the claim is the bound the payload has to respect:
--     every one of the four handlers rejects `i >= MAX_SUPPORTED_SERVOS`
--     (msp.c:2458, :2484, :3094, :3119) and takes the raw servoParams() slot
--     (msp.c:2463-2470, :2488-2495, :3097, :3123). MAX_SUPPORTED_SERVOS is
--     MAX_SUPPORTED_PWM_SERVOS + BUS_SERVO_CHANNELS (common_defaults_post.h:710),
--     so 26. A bound taken from a different pair of constants would agree with
--     the page for the wrong reason, so the constants are named here with the
--     firmware line each came from.
--
-- Which cases go RED on the pre-fix page:
--   * case 3 and case 4 (save) -- the write index was
--     uiIndex + (servo_count - 18), so it differed from the read index by
--     getServoCount() on every row.
--   * cases 1, 2 and 5 pin behaviour the pre-fix page already had right (read,
--     override and the load gate), and they are what a later change has to keep
--     right. A check that cannot fail proves nothing about what it passes, which
--     is why --self-test exists.
--
-- --self-test asserts only the sabotage direction: it reloads a copy of the
-- page with the pre-fix write index put back at the page's own call site and
-- requires the same assertion to fail on it.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PAGE_SRC = SUITE .. "/app/pages/servos_bus.lua"

local SELF_TEST = arg[1] == "--self-test"

local checks, failures = 0, 0
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

-- ---------------------------------------------------------------------------
-- Firmware constants this check bounds against
-- ---------------------------------------------------------------------------

local BUS_SERVO_OFFSET = 8      -- src/main/pg/bus_servo.h:35
local BUS_SERVO_CHANNELS = 18   -- src/main/target/common_defaults_post.h:706
local MAX_SUPPORTED_PWM_SERVOS = 8  -- src/main/target/common_defaults_post.h:702
local MAX_SUPPORTED_SERVOS = MAX_SUPPORTED_PWM_SERVOS + BUS_SERVO_CHANNELS  -- :710

local BUS_OUTPUT_COUNT = 16     -- the page's own tile count, servos_bus.lua:42

-- getServoCount() for a helicopter: three cyclic servos plus a tail servo.
local HELI_PWM_SERVOS = 4

-- Command numbers, from the suite's own codecs rather than from an MSP table:
-- lib/msp_status.lua:41, lib/msp_mixer_config.lua:15, lib/msp_servo_config.lua:16-17,
-- lib/msp_servo_center.lua:10, lib/msp_servo_override.lua:11.
local MSP_STATUS = 101
local MSP_MIXER_CONFIG = 42
local MSP_GET_SERVO_CONFIG = 125
local MSP_SET_SERVO_CONFIG = 212
local MSP_SET_SERVO_CENTER = 213
local MSP_SET_SERVO_OVERRIDE = 193

-- 1-based offset of servo_count in the MSP_STATUS payload, counted through
-- lib/msp_status.lua's FIELDS table (lines 45-63) against its own
-- simulatorResponse (lines 69-89). lib/mspcodec.lua:43-47 reads buf[offset]
-- with offset starting at 1.
local SERVO_COUNT_BYTE = 29

-- ---------------------------------------------------------------------------
-- Ethos environment
-- ---------------------------------------------------------------------------

local SUITE_PREFIX = SUITE .. "/"
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile

-- requireModule() calls loadfile() with a path that carries no directory part;
-- on the radio the working directory is src/rfsuite.
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

_G.package = package
_G.math = math
_G.string = string
_G.table = table

-- os.clock is replaced by a counter the harness advances on purpose.
-- servos_bus.lua:216 refuses to push a live centre until LIVE_SETTLE (0.05s,
-- line 44) has passed in os.clock terms, and os.clock measures CPU time, which
-- a tight harness loop does not accumulate. Left real, the centre write could
-- never fire and case 2 would pass without ever producing the message it
-- claims to check.
local clockValue = 0
local realOs = os
_G.os = setmetatable({
  clock = function() return clockValue end,
  time = realOs.time,
  execute = realOs.execute,
  remove = realOs.remove,
  rename = realOs.rename,
  tmpname = realOs.tmpname,
  date = realOs.date,
  getenv = realOs.getenv,
}, {__index = realOs})

_G.print = function() end
_G.lcd = {
  getWindowSize = function() return 480, 320 end,
  getTextSize = function(t) return #t, 12 end,
  drawRectangle = function() end,
  drawText = function() end,
  drawBitmap = function() end,
  loadMask = function() return 1 end,
  setColor = function() end,
  font = function() return 1 end,
  color = function() end,
}
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
  killEvents = function() end,
}
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

-- Widgets. The number and choice fields keep the accessor pair they were built
-- with, because app/field_layout.lua:432/442 hands the accessor to the form
-- and it is that accessor -- not the widget -- which writes runtime.data. A
-- pilot edit reaches runtime.data.mid through it, and case 2 needs one.
local function widgetStub(name)
  local w
  w = {
    name = name,
    _value = 0,
    focus = function() end,
    enable = function() end,
    value = function(_, v)
      if v ~= nil then w._value = v end
      return w._value
    end,
    setValue = function(_, v) w._value = v end,
    getValue = function() return w._value end,
    setText = function() end,
    decimals = function() end,
    suffix = function() end,
    step = function() end,
    default = function() end,
    show = function() end,
    hide = function() end,
    close = function() end,
  }
  return w
end

-- Buttons on the tile list, in creation order, so a case can press one the way
-- a pilot does. Number and choice fields are kept apart from them, because the
-- editor's mid field is what a pilot edit writes and it is not a button.
local buttons = {}
local fields = {}
local dialogs = {}

_G.form = {
  addButton = function(_, slot, opts)
    local w = widgetStub("button@" .. tostring(slot and slot.x or "?"))
    w.press = opts and opts.press
    buttons[#buttons + 1] = w
    return w
  end,
  addTextButton = function() return widgetStub("textButton") end,
  addStaticText = function() return widgetStub("staticText") end,
  addNumberField = function(_, _, _, _, get, set)
    local w = widgetStub("numberField")
    w.accessor = { get = get, set = set }
    fields[#fields + 1] = w
    return w
  end,
  addChoiceField = function(_, _, _, get, set)
    local w = widgetStub("choiceField")
    w.accessor = { get = get, set = set }
    fields[#fields + 1] = w
    return w
  end,
  addLine = function() return 1 end,
  clear = function() end,
  height = function() return 320 end,
  getFieldSlots = function() return {} end,
  openDialog = function(args)
    local h = { args = args, closed = false }
    h.value = function() end
    h.message = function() end
    h.closeAllowed = function() end
    h.close = function() h.closed = true end
    dialogs[#dialogs + 1] = h
    return h
  end,
  openProgressDialog = function(args)
    local h = { args = args, closed = false }
    h.value = function() end
    h.close = function() h.closed = true end
    dialogs[#dialogs + 1] = h
    return h
  end,
}

_G.TIME_LEFT = 1
_G.TEXT_LEFT = 2
_G.LEFT = 3
_G.CENTERED = 4
_G.RIGHT = 5
_G.TOP_LEFT = 6
_G.FONT_XS = 10
_G.FONT_S = 20
_G.FONT_M = 30
_G.FONT_L = 40
_G.FONT_XL = 50

_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07

-- ---------------------------------------------------------------------------
-- Module stubs
-- ---------------------------------------------------------------------------

local sent = {}

-- The servo_count the flight controller answers with. Not read out of
-- lib/msp_status.lua's own buffer, whose 4 is the simulator fixture value: the
-- number for a helicopter is derived in case 4, and that is the one the page has
-- to cope with. It is handed to the sabotage as _G.harnessServoCount from here,
-- so the pre-fix arithmetic is measured against the same answer.
local replySlices = {servoCount = HELI_PWM_SERVOS + BUS_SERVO_CHANNELS}
_G.harnessServoCount = replySlices.servoCount

local function sentCommands(cmd)
  local found = {}
  for i = 1, #sent do
    if sent[i].command == cmd then found[#found + 1] = sent[i] end
  end
  return found
end

-- Answers a read with the module's own simulatorResponse, the seam the Ethos
-- simulator uses, so the real decoders run. MSP_STATUS is the one reply that is
-- edited: its servo_count byte carries the helicopter's packed total.
local function replyFor(message)
  local buffer = message.simulatorResponse
  if type(buffer) ~= "table" or #buffer == 0 then return nil end
  local copy = {}
  for i = 1, #buffer do copy[i] = buffer[i] end
  if message.command == MSP_STATUS then
    copy[SERVO_COUNT_BYTE] = replySlices.servoCount
  end
  return copy
end

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    sent[#sent + 1] = {
      command = message.command,
      payload = message.payload,
      isWrite = message.isWrite or false,
    }
    local buffer = replyFor(message)
    if buffer and type(message.processReply) == "function" then
      message.processReply(nil, buffer)
    end
  end,
}

-- performSave() would otherwise stop at a confirmation modal. Off is what a
-- pilot who turned the prompt off in Settings -> General -> Safety Prompts has,
-- and it is the only setting under which this check can reach the write.
package.loaded["rfsuite.lib.settings_store"] = {
  saveConfirmEnabled = function() return false end,
  reloadConfirmEnabled = function() return true end,
  developerModeEnabled = function() return false end,
  load = function() return { general = {}, developer = {} } end,
  save = function() end,
  DEFAULTS = { general = {}, developer = {} },
}

package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = {
  print = function(msg)
    if _G.harnessTrace then out("        [trace] " .. tostring(msg)) end
  end,
}

-- app/header.lua's real build() is replaced rather than stubbed widget by
-- widget: the page only ever uses the returned handle and the opts it handed
-- in, and the Save button is reached here through the opts the runtime passed
-- to header.build() -- the same door the pilot's press goes through.
local headerOpts = nil

package.loaded["rfsuite.app.header"] = {
  build = function(_, opts)
    headerOpts = opts
    return {
      _buttons = {},
      focusMenu = function() end,
      focusSave = function() end,
      focusReload = function() end,
      focusTool = function() end,
      setTitle = function() end,
      setSaveEnabled = function() end,
      setReloadEnabled = function() end,
    }
  end,
}

-- ---------------------------------------------------------------------------
-- Driving the page
-- ---------------------------------------------------------------------------

-- The index is the first payload byte on all four commands this check reads.
-- lib/msp_servo_config.lua:67 writes it with the same writeU8 the centre and
-- override codecs use. Returns nil for a message that carries no payload, so a
-- case cannot compare nil == nil and call it agreement.
local function indexOf(message)
  if not message or type(message.payload) ~= "table" then return nil end
  local b = message.payload[1]
  if type(b) ~= "number" then return nil end
  return b
end

local function onlyIndex(cmd)
  local found = sentCommands(cmd)
  if #found ~= 1 then return nil, string.format("%d messages with command %d", #found, cmd) end
  return indexOf(found[1])
end

-- Each setter installs into a side table rather than onto opts itself. Storing
-- the handler back onto opts under the setter's own name would overwrite the
-- setter with the handler, and reading opts.setWakeupHandler would then call
-- the page's own wakeup -- which fires itself and recurses until the stack
-- overflows. The two things are kept apart on purpose: opts is the table the
-- page writes to, `installed` is what the harness reads back.
local function optsWithHandlers()
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
  return opts, installed
end

local function fireWakeup(installed)
  local handler = installed.setWakeupHandler
  if handler then handler() end
end

-- Opens the page, gets it past the STATUS/MIXER_CONFIG load gate, presses tile
-- `tile`, and lets the editor finish its own read. Returns nil plus a reason on
-- the first thing that did not work, so a case never reports an index it never
-- received.
local function openEditorFor(tile, pageFile)
  sent = {}
  buttons = {}
  fields = {}
  dialogs = {}
  headerOpts = nil

  local page = dofile(pageFile)
  local opts, installed = optsWithHandlers()
  page.open(opts)

  if #sentCommands(MSP_STATUS) ~= 1 then
    return nil, string.format("open() published %d MSP_STATUS, expected 1", #sentCommands(MSP_STATUS))
  end
  if #sentCommands(MSP_MIXER_CONFIG) ~= 1 then
    return nil, string.format("open() published %d MSP_MIXER_CONFIG, expected 1", #sentCommands(MSP_MIXER_CONFIG))
  end

  -- The load gate: open() parks both answers and the wakeup turns them into the
  -- tile list.
  fireWakeup(installed)

  local button = buttons[tile]
  if not button then
    return nil, string.format("tile %d was never rendered (%d buttons)", tile, #buttons)
  end
  if not button.press then
    return nil, string.format("tile %d has no press handler", tile)
  end
  button.press()

  -- The editor's own read, then the wakeup that lets page_runtime settle it.
  local reads = sentCommands(MSP_GET_SERVO_CONFIG)
  if #reads ~= 1 then
    return nil, string.format("pressing tile %d published %d MSP_GET_SERVO_CONFIG, expected 1",
      tile, #reads)
  end
  fireWakeup(installed)

  return {page = page, opts = opts, installed = installed, read = indexOf(reads[1])}
end

-- ---------------------------------------------------------------------------
-- cases
-- ---------------------------------------------------------------------------

-- Drives one tile through the four operations and reports the index each one
-- put on the wire. Shared by the cases and by the self-test, so the sabotage is
-- measured by exactly the same instrument as the fix.
local function observe(tile, pageFile)
  local editor, err = openEditorFor(tile, pageFile)
  if not editor then return nil, err end
  local seen = {read = editor.read}

  -- Tool button -> the override dialog -> OK arms the override for this servo.
  --
  -- pcall, and not because something here is allowed to fail: the dialog's OK
  -- action raises on a defect of its own, unrelated to the index. servos_bus.lua
  -- declares `onTool = function(focusFn)` (line 177, and 260 for the list), but
  -- app/page_runtime.lua:213 stores that function verbatim and line 1125 calls
  -- it as a method -- `runtime:onTool(...)` -- so `focusFn` is bound to the
  -- runtime table and the action's `if focusFn then focusFn() end` tries to call
  -- it. The same signature appears in seven pages. That is its own defect and
  -- is not this check's business; what matters here is that the override is
  -- published *before* that line, so the message this case needs has already
  -- been recorded by the time the call raises.
  if headerOpts and headerOpts.onTool then headerOpts.onTool(nil) end
  local dialog = dialogs[#dialogs]
  if dialog and dialog.args and dialog.args.buttons and dialog.args.buttons[1] then
    pcall(dialog.args.buttons[1].action)
  end
  local overrides = sentCommands(MSP_SET_SERVO_OVERRIDE)
  seen.override = #overrides == 1 and indexOf(overrides[1]) or nil

-- With the override armed, a changed mid is pushed as MSP_SET_SERVO_CENTER once
-- LIVE_SETTLE has passed (servos_bus.lua:216). The mid field is the first one
-- the editor builds (servos_bus.lua:231, "@i18n(app.modules.servos.center)@"),
-- and its accessor is the one app/field_layout.lua:442 handed to the form --
-- setWithDirty, so this is also the pilot edit the Save button needs.
local mid = fields[1]
if not (mid and mid.accessor and mid.accessor.set) then
  return nil, "the editor built no mid field with an accessor, so no edit can be made"
end
mid.accessor.set(1600)
clockValue = clockValue + 1
fireWakeup(editor.installed)
local centres = sentCommands(MSP_SET_SERVO_CENTER)
seen.centre = #centres == 1 and indexOf(centres[1]) or nil

  -- Save button -> confirmSave() -> performSave(), with the confirmation off.
  if headerOpts and headerOpts.onSave then headerOpts.onSave() end
  local writes = sentCommands(MSP_SET_SERVO_CONFIG)
  seen.save = #writes == 1 and indexOf(writes[1]) or nil

  return seen
end

local function agree(label, seen, key)
  local value = seen[key]
  if value == nil then
    check(label .. ": produced one message", false,
      "no message recorded, so there is nothing to compare the read index against")
    return false
  end
  check(label, value == seen.read,
    string.format("%s index %s, read index %s", key, tostring(value), tostring(seen.read)))
  return value == seen.read
end

out("case 1: every tile reads the raw bus slot, and the firmware's own bound accepts it")
do
  local bad = nil
  local seen = {}
  for tile = 1, BUS_OUTPUT_COUNT do
    local r, err = openEditorFor(tile, PAGE_SRC)
    if not r then bad = err break end
    seen[tile] = r.read
    if r.read ~= (tile - 1) + BUS_SERVO_OFFSET then
      bad = string.format("tile %d read index %s, expected %d",
        tile, tostring(r.read), (tile - 1) + BUS_SERVO_OFFSET)
      break
    end
  end
  check(string.format("all %d tiles read uiIndex+%d", BUS_OUTPUT_COUNT, BUS_SERVO_OFFSET),
    bad == nil, bad)
  check(string.format("the highest raw index is %d, below MAX_SUPPORTED_SERVOS %d",
    (BUS_OUTPUT_COUNT - 1) + BUS_SERVO_OFFSET, MAX_SUPPORTED_SERVOS),
    (BUS_OUTPUT_COUNT - 1) + BUS_SERVO_OFFSET < MAX_SUPPORTED_SERVOS)
end

out("")
out("case 2: override, centre and save all carry the read index  <- the defect is in save")
do
  local seen, err = observe(5, PAGE_SRC)
  if not seen then
    check("tile 5 opens and reaches the write", false, err)
  else
    check(string.format("tile 5 reads raw index %d", seen.read), seen.read == 4 + BUS_SERVO_OFFSET,
      string.format("read index %s", tostring(seen.read)))
    agree("the override index equals the read index", seen, "override")
    agree("the centre index equals the read index", seen, "centre")
    agree("the save index equals the read index", seen, "save")
  end
end

out("")
out("case 3: read and save agree on every tile, not only the one that was pressed")
do
  local mismatches = {}
  for tile = 1, BUS_OUTPUT_COUNT do
    local seen, err = observe(tile, PAGE_SRC)
    if not seen then
      mismatches[#mismatches + 1] = err
      break
    end
    if seen.save ~= seen.read then
      mismatches[#mismatches + 1] = string.format("tile %d: read %s, save %s",
        tile, tostring(seen.read), tostring(seen.save))
    end
  end
  check(string.format("all %d tiles save to the slot they read from", BUS_OUTPUT_COUNT),
    #mismatches == 0, table.concat(mismatches, "; "))
end

out("")
out("case 4: the offset a helicopter actually reports")
do
  -- The firmware cannot report a servo_count below BUS_SERVO_CHANNELS while bus
  -- servos are configured, so the pre-fix expression servo_count - 18 is never
  -- negative and the `value < 0 then return 0` guard in the old
  -- configWriteIndex() was unreachable on real hardware. What it did instead
  -- was shift every save down by getServoCount().
  local heli = replySlices.servoCount or HELI_PWM_SERVOS + BUS_SERVO_CHANNELS
  check(string.format("a helicopter's servo_count is %d = getServoCount %d + BUS_SERVO_CHANNELS %d",
    heli, HELI_PWM_SERVOS, BUS_SERVO_CHANNELS),
    heli == HELI_PWM_SERVOS + BUS_SERVO_CHANNELS)
  check("servo_count is never below BUS_SERVO_CHANNELS, so the old clamp was unreachable",
    heli >= BUS_SERVO_CHANNELS)
  check(string.format("the pre-fix offset servo_count-18 is %d, not negative", heli - BUS_SERVO_CHANNELS),
    heli - BUS_SERVO_CHANNELS == HELI_PWM_SERVOS)
end

-- ---------------------------------------------------------------------------
-- self-test: the pre-fix write index has to fail the same comparison
-- ---------------------------------------------------------------------------

-- Puts the pre-fix arithmetic back at the page's own call site and loads that
-- copy instead of the file. Two substitutions, both on lines the fix touched.
--
-- The first reproduces configWriteIndex(uiIndex, servoCount) verbatim, including
-- the clamp -- built from `uiIndex`, NOT from the raw index, which is the whole
-- defect: the read used uiIndex + 8 and the write used uiIndex + 4, so the two
-- were two different index spaces rather than one. _G.harnessServoCount is the
-- servo_count the MSP_STATUS answer carries, which is the number the pre-fix
-- page read out of listState, so the sabotage cannot drift from the answer.
--
-- The second routes the save through it, which is what makes them disagree.
--
-- What that arithmetic actually produced, with a helicopter's servo_count of 22:
-- write = max(uiIndex + 4, 0) against a read of uiIndex + 8. So every save lands
-- exactly four slots low, on every tile. The clamp never fires, and cannot: the
-- offset is servo_count - 18 and the firmware only reports servo_count >= 18
-- while bus servos are configured (msp.c:1098-1104), so it is never negative.
-- Every resulting index is below MAX_SUPPORTED_SERVOS, so the firmware accepts
-- all of them and re-runs validateAndFixServoConfig() on a servo the pilot
-- never opened.
local function sabotage()
  local f = assert(io.open(PAGE_SRC, "rb"))
  local src = f:read("a")
  f:close()

  -- The checked-out tree is CRLF on Windows (core.autocrlf=true, no
  -- .gitattributes), so the line ending to write back is the one that was read
  -- rather than a hardcoded "\n" that would not match.
  local nl = src:find("\r\n", 1, true) and "\r\n" or "\n"

  -- Matched without the terminator: the anchor has to survive either ending.
  local anchor = "  local rawIndex = busServoIndex(uiIndex)"
  assert(src:find(anchor, 1, true), "sabotage anchor not found: " .. anchor)
  src = src:gsub(anchor:gsub("(%W)", "%%%1"), function()
    return anchor .. nl
      .. "  local writeIndex = uiIndex + ((tonumber(_G.harnessServoCount) or 18) - 18)" .. nl
      .. "  if writeIndex < 0 then writeIndex = 0 end"
  end, 1)

  local call = "servoConfig.buildWriteMessage(rawIndex, data, onWritten, onError)"
  assert(src:find(call, 1, true), "sabotage call site not found: " .. call)
  src = src:gsub(call:gsub("(%W)", "%%%1"),
    "servoConfig.buildWriteMessage(writeIndex, data, onWritten, onError)", 1)

  local path = os.tmpname() .. "_servos_bus_prefix.lua"
  local w = assert(io.open(path, "wb"))
  w:write(src)
  w:close()
  return path
end

if SELF_TEST then
  out("")
  out("self-test: the pre-fix write index must fail the save comparison on every tile")
  local path = sabotage()
  local agreed = 0
  local samples = {}
  for tile = 1, BUS_OUTPUT_COUNT do
    local s = observe(tile, path)
    if not s then agreed = -1 break end
    if s.save == s.read then agreed = agreed + 1 end
    samples[#samples + 1] = string.format("bus %d: read %s, save %s",
      tile, tostring(s.read), tostring(s.save))
  end
  check("no tile's save index agrees with its read index on the pre-fix page",
    agreed == 0, string.format("%d of %d tiles agreed -- the comparison cannot fail", agreed, BUS_OUTPUT_COUNT))

  -- max(uiIndex + 4, 0) against a read of uiIndex + 8: every tile four slots
  -- low, and the clamp never reached.
  local offset = replySlices.servoCount - BUS_SERVO_CHANNELS
  local function preFixWrite(uiIndex)
    return math.max(uiIndex + offset, 0)
  end
  local low, wrong = 0, nil
  for tile = 1, BUS_OUTPUT_COUNT do
    local s = observe(tile, path)
    if not s or s.read == nil or s.save == nil then
      wrong = "tile " .. tile .. " produced no comparable pair"
      break
    end
    if s.save ~= preFixWrite(tile - 1) then
      wrong = string.format("tile %d saved %s, the pre-fix arithmetic says %d",
        tile, tostring(s.save), preFixWrite(tile - 1))
      break
    end
    if (s.read - s.save) == HELI_PWM_SERVOS then low = low + 1 end
  end
  check(string.format("every one of the %d tiles saved exactly getServoCount() (%d) slots low",
    BUS_OUTPUT_COUNT, HELI_PWM_SERVOS),
    low == BUS_OUTPUT_COUNT and wrong == nil,
    wrong or string.format("only %d of %d tiles were off by %d", low, BUS_OUTPUT_COUNT, HELI_PWM_SERVOS))
  check("and the old `if value < 0 then return 0` clamp never fired",
    offset >= 0 and preFixWrite(0) == offset,
    string.format("servo_count %d gives an offset of %d, so no index was negative",
      replySlices.servoCount, offset))
  out("        observed: " .. table.concat(samples, "; "))
  os.remove(path)
else
  out("")
  out("(run with --self-test to prove the save comparison above is able to fail)")
  check("--self-test not requested", true)
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")