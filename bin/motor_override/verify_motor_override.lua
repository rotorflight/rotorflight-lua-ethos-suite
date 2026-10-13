-- Behaviour check for the Motor Override page (#2307).
--
-- Run it:
--     lua5.4 bin/motor_override/verify_motor_override.lua
--
-- What it drives, and why:
--   * The REAL src/rfsuite/app/pages/motor_override.lua and the REAL
--     src/rfsuite/lib/msp_motor_override.lua, loaded from their paths. The
--     command ids, the payload shape and the keep-alive interval are all read
--     out of those files rather than restated here, so a change in either one
--     that breaks the safety behaviour makes this go red.
--   * The real MSP answer, fed back through the message's own processReply, so
--     the values the page shows are the values the firmware's MSP_MOTOR_OVERRIDE
--     layout produces.
--
-- The four properties, all from the firmware:
--   1. A write names one motor and carries MOTOR_OVERRIDE_TIMEOUT's worth of
--      authority -- motors.c:114-120 stores it with a deadline and motors.c:301
--      -303 resets every override once it passes. So one write is a motor that
--      turns for one more second, and the page has to keep writing or the motor
--      stops on its own. Gate: "the override is written again while it is held".
--   2. motors.c:116 drops the write entirely while armed. Gate: "the switch is
--      refused while the model is armed", plus "an override running when the
--      model arms is released".
--   3. The write is per motor (msp.c:2966-2972), so leaving the page has to name
--      every motor the page could have touched. Gate: "leaving releases every
--      motor, not only the selected one".
--   4. A link that is gone cannot be written to. Gate: "a lost link drops the
--      switch".
--
-- Which checks are gates, and how --self-test proves it:
--   Every gate above is spliced back to its pre-fix form in a copy of the page
--   and required to go red: REFRESH_INTERVAL neutralised (no keep-alive), the
--   armed guard removed, the release narrowed to the selected motor, and the
--   disconnect handling removed. The splice asserts it applied, and package.loaded
--   is cleared first so the real file cannot be picked up. The remaining checks
--   are pinned as controls: a board that reports four motors offers all four, a
--   board reporting zero still shows the first, a page that is not overriding
--   writes nothing at all, and the codec's own read is signed. Those are what
--   stop the gates from passing for the wrong reason.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0
local out = print

-- The i18n tag, not its resolved text: tags are substituted by the deploy step,
-- so the Lua-under-test carries the raw tag and the harness compares like for
-- like (see bin/i18n/check-tags.py and .vscode/scripts/resolve_i18n_tags.py).
local ENABLE_MSG = "@i18n(app.modules.esc_motors.motor_override_enable_msg)@"
local NOTE_TEXT = "@i18n(app.modules.esc_motors.motor_override_note)@"
local NOTE_TEXT_2 = "@i18n(app.modules.esc_motors.motor_override_note_2)@"
local DISCONNECTED_TEXT = "@i18n(app.modules.esc_motors.motor_override_disconnected)@"
local ARMED_TEXT = "@i18n(app.modules.esc_motors.motor_override_armed)@"

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

-- ── Ethos environment ──────────────────────────────────────────────────────

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
_G.package.loaded = package.loaded
_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.print = function() end
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

-- Controllable clock: the keep-alive measures with os.clock(), and the cases
-- below have to reach past the firmware's one-second deadline without the
-- harness sleeping for it.
local fakeClock = 0
os.clock = function() return fakeClock end

local widgetStub

-- Fields are recorded rather than merely stubbed, and each one keeps the
-- getter/setter the page handed it. Several checks are about which controls are
-- enabled while armed, while overriding, or after a link drop, and a stub that
-- swallowed enable() would let a page pass by never calling it; the checks also
-- drive the controls the way a pilot does, which means invoking the page's own
-- setter and reading the page's own getter.
local fieldRegistry

local function fieldStub(name, getter, setter)
  local f = {
    fieldName = name,
    getter = getter,
    setter = setter,
    enabled = true,
    text = nil,
    focused = false,
  }
-- Defined with f. in the signature, not `function f.x()`, because the suite
  -- calls these with colon syntax: `field:suffix("%")`. A `self` there is nil.
  function f.suffix(v) f.suffixValue = v return f end
  function f.default() return f end
  function f.onFocus() return f end
  function f.step() return f end
  -- Every one of these is called with colon syntax by the suite -- `field:enable(v)`,
  -- `field:value(t)` -- so each takes the widget as its first parameter. A stub
  -- written as `function f.enable(v)` receives the widget where it expects the
  -- value, which silently turns every enable() into "enable the widget".
  function f.enable(_, v)
    f.enabled = v
    return f
  end
  function f.value(_, v)
    if v ~= nil then f.text = v end
    if f.getter then return f.getter() end
    return f.text
  end
  function f.focus() f.focused = true end
  function f:getValue() return 0 end
  fieldRegistry[#fieldRegistry + 1] = f
  return f
end

--- Invoke a field the way a touch does: run the setter the page registered.
local function touch(f, value)
  if f and f.setter then f.setter(value) end
end

local function fieldByName(name)
  for _, f in ipairs(fieldRegistry) do
    if f.fieldName == name then return f end
  end
  return nil
end

--- The static-text widget carrying `text`, or nil. Static text is the one widget
--- whose value can be read back, which is how the note lines are identified.
local function staticByText(text)
  for _, f in ipairs(fieldRegistry) do
    if f.fieldName == "static" and f.text == text then return f end
  end
  return nil
end

--- Whether a static text was given the whole line.
---
--- `nil` as the rect means the line's VALUE column -- the narrow right-hand
--- slot -- and that is where the safety note first landed, which is why it
--- arrived on the radio cut off at the right edge with half its sentence gone.
--- The suite's own idiom (app/esc_error.lua:43-61) is x = 0 and w = window.
local function spansFullLine(f)
  if not f or not f.rect then return false end
  return f.rect.x == 0 and f.rect.w == lcd.getWindowSize()
end

_G.form = {
  addButton = function() return widgetStub("button") end,
  addTextButton = function() return widgetStub("textbutton") end,
  -- The rect is kept because where a static text lands is the whole point of
  -- one of the checks below: `nil` here means the line's VALUE column -- the
  -- narrow right-hand slot -- which is where the safety note was first written
  -- and why it arrived on the radio cut off at the right edge.
  addStaticText = function(_, rect, text)
    local f = fieldStub("static")
    f.rect = rect
    f.text = text
    return f
  end,
  -- min/max and the getter/setter, in the order form.addNumberField takes them.
  addNumberField = function(_, _, _min, _max, getter, setter)
    return fieldStub("number", getter, setter)
  end,
  addBooleanField = function(_, _, getter, setter)
    return fieldStub("boolean", getter, setter)
  end,
  addChoiceField = function(_, _, choices, getter, setter)
    local f = fieldStub("choice", getter, setter)
    f.choices = choices
    return f
  end,
  addLine = function(label) return { lineLabel = label } end,
  -- Real Ethos: content-fit slots. The harness needs a plausible y/h and a
  -- width, because the full-width text helper overrides x and w itself.
  getFieldSlots = function() return {{x = 0, y = 12, w = 300, h = 26}} end,
  clear = function() end,
  height = function() return 480 end,
  invalidate = function() end,
  openProgressDialog = function() return widgetStub("progressdialog") end,
}

widgetStub = function(name)
  local w = { name = name }
  w.focus = function() end
  w.enable = function() end
  w.close = function() end
  w.value = function() end
  w.setValue = function() end
  w.setText = function() end
  w.getValue = function() return 0 end
  w.show = function() end
  w.hide = function() end
  return w
end

_G.TEXT_LEFT = 2
_G.LEFT = 3
_G.CENTERED = 4
_G.RIGHT = 5
_G.TOP_LEFT = 6
-- Only the constants Ethos actually provides. SMLSIZE, MIDSIZE and BIGSIZE are
-- EdgeTX's names for the text sizes -- Ethos calls them FONT_XS/S/M/L. They were
-- stubbed here until 2026-10-07, and that stub is exactly why this harness ran
-- green while the page crashed on the radio with
-- "attempt to perform arithmetic on a nil value (global 'SMLSIZE')".
_G.FONT_XS = 10
_G.FONT_S = 20
_G.FONT_M = 30
_G.FONT_L = 40
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07
_G.KEY_ENTER_BREAK = 0x08

_G.lcd = {
  getWindowSize = function() return 800, 480 end,
  invalidate = function() end,
  drawLine = function() end,
  color = function() end,
  loadMask = function() return {} end,
  GREY = function(v) return v end,
  RGB = function(r, g, b) return r, g, b end,
}

-- ── the Ethos constant surface ─────────────────────────────────────────────
--
-- An ALL-CAPS name the page reads is an Ethos constant, and every one this
-- harness declares is listed above. A name it has NOT declared is a constant
-- Ethos does not have -- SMLSIZE, EdgeTX's name for a text size, was exactly
-- that, and it ran green here for a whole session because this harness stubbed
-- it. Reads are recorded rather than raised, so the failure lands as a named
-- check instead of an arithmetic error two frames down.
local undeclaredGlobals = {}

setmetatable(_G, {__index = function(_, k)
  if type(k) == "string" and k:match("^[A-Z][A-Z0-9_]+$") then
    undeclaredGlobals[#undeclaredGlobals + 1] = k
    return 0
  end
  return nil
end})

-- ── shared seams ───────────────────────────────────────────────────────────

local sessionHandlers = {}
local unsubscribes = 0
local published = {}          -- every msp.request, in order
local dialogs = {}            -- every form.openDialog, in order
local headerBuilds = {}       -- every header.build() handle, in order

local function resetTrace()
  fakeClock = 0
  unsubscribes = 0
  published = {}
  dialogs = {}
  sessionHandlers = {}
  headerBuilds = {}
  undeclaredGlobals = {}
end

local function publishSession(connected, isArmed)
  for _, handler in ipairs(sessionHandlers) do
    handler({ connected = connected, isArmed = isArmed, mcuId = "0123456789", pidProfile = 1 })
  end
end

--- Every MSP_SET_MOTOR_OVERRIDE the page published, as {index, value} pairs
--- read back out of the payload the page actually built.
local function overrideWrites()
  local out2 = {}
  for _, message in ipairs(published) do
    if message.command == 195 then
      local payload = message.payload
      out2[#out2 + 1] = { index = payload[1], value = payload[2] + (payload[3] or 0) * 256 }
    end
  end
  return out2
end

--- The most recent non-zero write, or nil. This is "is a motor being driven",
--- which is the question every safety check below is really asking.
local function liveMotor()
  local writes = overrideWrites()
  for i = #writes, 1, -1 do
    if writes[i].value ~= 0 then return writes[i] end
  end
  return nil
end

local function lastDialog()
  return dialogs[#dialogs]
end

-- ── module stubs ───────────────────────────────────────────────────────────

-- The bus is stubbed rather than the real one: the harness needs to hand MSP
-- answers back at a chosen moment, and it needs to see that the page
-- unsubscribes on dispose.
--
-- Writes are answered the way the queue would answer them, by running the
-- message's own processReply. That is not a convenience: the page keeps one
-- write in flight and only sends the next when the previous one has come back
-- or has timed out, so a stub that never answers would measure the give-up path
-- (one write per second) instead of the keep-alive.
package.loaded["rfsuite.lib.bus"] = {
  subscribe = function(topic, handler)
    if topic == "session.update" then sessionHandlers[#sessionHandlers + 1] = handler end
    return handler
  end,
  unsubscribe = function(topic)
    if topic == "session.update" then unsubscribes = unsubscribes + 1 end
  end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    published[#published + 1] = message
    -- A write is answered on the spot: a healthy link, and the only thing the
    -- keep-alive rate depends on.
    if message.isWrite and message.processReply then message.processReply() end
  end,
}
package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = {
  print = function() end, format = function() end, msp = function() end,
  enabled = function() return false end, mspEnabled = function() return false end,
}
package.loaded["rfsuite.app.header"] = {
  build = function(title, opts)
    -- Every header the page builds is recorded, each with the Back callback it
    -- was handed: the page builds one before the load and another once the load
    -- has finished, and the two are separate callbacks.
    local handle
    handle = {
      builtTitle = title,
      currentTitle = title,
      onBack = opts and opts.onBack,
      setTitle = function(t) handle.currentTitle = t end,
      setSaveEnabled = function() end,
      setReloadEnabled = function() end,
      focusMenu = function() end,
      focusSave = function() end,
      focusReload = function() end,
      focusTool = function() end,
    }
    headerBuilds[#headerBuilds + 1] = handle
    return handle
  end,
}

-- MSP_STATUS, stubbed so the harness chooses the motor count. The real module is
-- not loaded here: its full field table is irrelevant to this page, and its
-- answers are what the checks below are about.
local statusModule = { motor_count = 4 }
package.loaded["rfsuite.lib.msp_status"] = {
  buildReadMessage = function(onData, onError)
    return {
      command = 101,
      isWrite = false,
      payload = {},
      -- MSP_STATUS carries motor_count as its first byte after the U16 frame
      -- counters (lib/msp_status.lua's own field table), which is where the
      -- production page reads it from too.
      processReply = function(_, buf)
        onData({ motor_count = (buf and buf[1]) or statusModule.motor_count })
      end,
      errorHandler = onError,
      simulatorResponse = {},
    }
  end,
}

-- ── the page under test ────────────────────────────────────────────────────

local PAGE_PATH = SUITE .. "/app/pages/motor_override.lua"
local CODEC_PATH = SUITE .. "/lib/msp_motor_override.lua"

--- Load the page (optionally from a transformed source) and hand it an opts
--- table whose tick() runs its wakeup handler -- which is where every dialog and
--- every keep-alive below is driven from, exactly as app/tool.lua drives it.
local function openPage(splice)
  resetTrace()
  fieldRegistry = {}

  local savedCodec = package.loaded["rfsuite.lib.msp_motor_override"]
  package.loaded["rfsuite.lib.msp_motor_override"] = nil

  local mod
  if splice then
    local f = assert(io.open(PAGE_PATH, "r"))
    local source = f:read("*a")
    f:close()
    source = splice(source)
    mod = assert(load(source, "@motor_override"))()
  else
    mod = dofile(PAGE_PATH)
  end
  package.loaded["rfsuite.lib.msp_motor_override"] = savedCodec

  assert(type(mod) == "table" and type(mod.open) == "function",
    "motor_override.lua did not return an open()")

  local opts = {}
  -- Modelled on app/tool.lua's own setWakeupHandler: a STABLE setter function
  -- that stores the handler under a different key. Storing the handler back
  -- into opts.setWakeupHandler would replace the setter with the page's own
  -- handler, and the page's `opts.setWakeupHandler(nil)` teardown would then
  -- call the handler with nil instead of uninstalling it -- a harness artefact
  -- that has nothing to do with the real host.
  local function setter(name)
    return function(handler)
      opts[name .. 'Value'] = handler
    end
  end
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() back = true end

  local back = false
  --- Run the installed wakeup handler, as app/tool.lua's own wakeup() does.
  --- It calls the handler the page REGISTERED (opts.setWakeupHandlerValue), not
  --- the setter: calling the setter here would uninstall the handler on the
  --- first tick and every later check would pass for the wrong reason.
  local function tick()
    if opts.setWakeupHandlerValue then opts.setWakeupHandlerValue() end
  end

  -- form.openDialog is the seam the confirm goes through; the handle is
  -- recorded so a check can press OK or Cancel the way a pilot would. It is
  -- installed for the whole life of the page, not just while open() runs: the
  -- confirm is opened from the wakeup tick, long after open() has returned.
  form.openDialog = function(args)
    local d = { args = args, closed = false }
    function d:close() self.closed = true end
    function d:value() end
    dialogs[#dialogs + 1] = d
    return d
  end

  mod.open(opts)

  return {
    opts = opts,
    tick = tick,
    wentBack = function() return back end,
    dispose = function()
      -- The handler the page REGISTERED, not the setter.
      if opts.setCleanupHandlerValue then opts.setCleanupHandlerValue() end
    end,
  }
end

--- Feed MSP_STATUS and MSP_MOTOR_OVERRIDE their real answers and run one tick,
--- so the page reaches its loaded state.
local function loadPage(page, motorCount, overrideValues)
  statusModule.motor_count = motorCount or 4

  for _, message in ipairs(published) do
    if message.command == 101 and message.processReply then
      message.processReply(nil, { statusModule.motor_count })
    elseif message.command == 194 and message.processReply then
      local buf = {}
      for i = 1, 4 do
        local v = (overrideValues and overrideValues[i]) or 0
        if v < 0 then v = v + 0x10000 end
        buf[i * 2 - 1] = v % 256
        buf[i * 2] = math.floor(v / 256) % 256
      end
      message.processReply(nil, buf)
    end
  end

  page.tick()
end

--- The override switch. Its setter must NOT open a dialog by itself:
--- app/page_runtime.lua:1252-1264 and :1318-1338 record two live-caught failures
--- from doing exactly that, so the page defers to its wakeup tick instead.
local function pressSwitch(page)
  return fieldByName("boolean")
end

local function answerDialog(dialog, label)
  if not dialog then return false end
  for _, button in ipairs(dialog.args.buttons or {}) do
    if button.label == label then
      button.action()
      return true
    end
  end
  return false
end

local OK = "@i18n(app.btn_ok)@"
local CANCEL = "@i18n(app.btn_cancel)@"

-- ── run ────────────────────────────────────────────────────────────────────

out("part A: the codec speaks the firmware's MSP_MOTOR_OVERRIDE layout")
do
  package.loaded["rfsuite.lib.msp_motor_override"] = nil
  local codec = dofile(CODEC_PATH)
  check("the write command is MSP_SET_MOTOR_OVERRIDE (195)", codec.WRITE_COMMAND == 195,
    "got " .. tostring(codec.WRITE_COMMAND))
  check("the read command is MSP_MOTOR_OVERRIDE (194)", codec.READ_COMMAND == 194,
    "got " .. tostring(codec.READ_COMMAND))
  check("the range is the firmware's MOTOR_OVERRIDE_MIN..MAX",
    codec.OVERRIDE_MIN == -1000 and codec.OVERRIDE_MAX == 1000 and codec.OVERRIDE_OFF == 0,
    tostring(codec.OVERRIDE_MIN) .. ".." .. tostring(codec.OVERRIDE_MAX) .. " off=" .. tostring(codec.OVERRIDE_OFF))
  check("one motor slot per MAX_SUPPORTED_MOTORS (4)", codec.MOTOR_SLOTS == 4,
    "got " .. tostring(codec.MOTOR_SLOTS))

  -- msp.c:2966-2972 reads the write as U8 index then U16 value.
  local write = codec.buildWriteMessage(2, 1000)
  check("a write is 3 bytes: u8 index, u16 value",
    #write.payload == 3 and write.payload[1] == 2 and write.payload[2] == 0xE8 and write.payload[3] == 0x03,
    "payload " .. tostring(write.payload[1]) .. "," .. tostring(write.payload[2]) .. "," .. tostring(write.payload[3]))

  -- A reverse override is negative and must survive the round trip signed:
  -- read unsigned, -100 comes back as 65516 (0xFF9C).
  local negative = {0x9C, 0xFF, 0, 0, 0, 0, 0, 0}
  local parsed = codec.parse(negative)
  check("a negative override reads back negative", parsed and parsed.motor_1 == -100,
    parsed and ("got " .. tostring(parsed.motor_1)) or "parse returned nil")
  local parsedAgain = codec.parse(negative)
  check("parsing the same buffer resets offset to 1", parsedAgain and parsedAgain.motor_1 == -100)
  check("a short answer is refused rather than half-read", codec.parse({0, 0}) == nil)
  local negWrite = codec.buildWriteMessage(0, -100)
  check("a negative override writes signed int16",
    negWrite.payload[2] == 0x9C and negWrite.payload[3] == 0xFF)
end
-- part B: the page keeps an enabled override alive --------------------------
--
-- Helpers first, because every part below does the same three steps: confirm
-- the override, drive the throttle, then let the clock run.

local OK = "@i18n(app.btn_ok)@"
local CANCEL = "@i18n(app.btn_cancel)@"

local function answerDialog(dialog, label)
  if not dialog then return false end
  for _, button in ipairs(dialog.args.buttons or {}) do
    if button.label == label then
      button.action()
      return true
    end
  end
  return false
end

--- The override switch, as the page registered it.
local function overrideSwitch()
  return fieldByName("boolean")
end

--- The throttle number field.
local function throttleField()
  return fieldByName("number")
end

--- The motor selector, or nil on a single-motor board.
local function motorSelector()
  return fieldByName("choice")
end

local function setThrottle(percent)
  touch(throttleField(), percent)
end

--- Ask for the override and confirm it, the way a pilot does. Returns the
--- confirm dialog, so a caller can inspect it before answering.
local function requestOverride(page, enabled)
  touch(overrideSwitch(), enabled)
  page.tick()
  return lastDialog()
end

local function confirmOverride(page, percent)
  local dialog = requestOverride(page, true)
  answerDialog(dialog, OK)
  if percent then setThrottle(percent) end
  return dialog
end

--- Advance the fake clock in wakeup-sized steps, as app/tool.lua would.
local function run(page, seconds, step)
  step = step or 0.05
  local t = 0
  while t < seconds do
    fakeClock = fakeClock + step
    t = t + step
    page.tick()
  end
end

--- The value last written for a motor, or nil if that motor was never named.
--- Only the last value counts: the history is full of releases and stale
--- writes, and "is a motor being driven" is a question about the board's current
--- state, not about everything the page ever sent.
local function lastValueFor(index)
  local last = nil
  for _, w in ipairs(overrideWrites()) do
    if w.index == index then last = w.value end
  end
  return last
end

--- Every motor's last written value, so a release can be checked per motor.
local function lastValues()
  local values = {}
  for _, w in ipairs(overrideWrites()) do
    values[w.index] = w.value
  end
  return values
end

local function anyMotorRunning()
  for _, value in pairs(lastValues()) do
    if value ~= 0 then return true end
  end
  return false
end

do
  local page = openPage(nil)
  loadPage(page, 4)
  check("the page opens and reads STATUS and MOTOR_OVERRIDE",
    #published >= 2, "published " .. tostring(#published))
  check("the page reads only Ethos globals this harness declares",
    #undeclaredGlobals == 0,
    "undeclared ALL-CAPS global(s) read: " .. table.concat(undeclaredGlobals, ", "))

  -- The safety note is two full-width lines, not one line in the value column.
  -- This is the check that would have caught the note arriving clipped.
  local n1 = staticByText(NOTE_TEXT)
  local n2 = staticByText(NOTE_TEXT_2)
  check("the first safety note line spans the line, not the value column",
    spansFullLine(n1),
    n1 == nil and ("no static text carries " .. NOTE_TEXT)
      or ("rect = " .. (n1.rect and ("x=" .. n1.rect.x .. " w=" .. n1.rect.w)
        or "nil (the line's value column)")))
  check("the second safety note line does too", spansFullLine(n2),
    n2 == nil and ("no static text carries " .. NOTE_TEXT_2)
      or ("rect = " .. (n2.rect and ("x=" .. n2.rect.x .. " w=" .. n2.rect.w)
        or "nil (the line's value column)")))

  check("the page offers an override switch", overrideSwitch() ~= nil)
  check("the page offers a throttle", throttleField() ~= nil)

  -- Nothing may be written before the pilot has confirmed.
  local dialog = requestOverride(page, true)
  check("the confirm asks about the motor before anything is written",
    dialog ~= nil and dialog.args.message == ENABLE_MSG,
    dialog and tostring(dialog.args.message) or "no dialog")
  check("and no override was written before it was confirmed", anyMotorRunning() == false)
  check("the confirm offers OK and Cancel",
    dialog ~= nil and #dialog.args.buttons == 2)

  -- A cancel has to leave the page as it was -- this is the case where the
  -- switch has already drawn itself as on.
  answerDialog(dialog, CANCEL)
  check("a cancelled confirm writes nothing", anyMotorRunning() == false)
  check("a cancelled confirm leaves the switch off", overrideSwitch().enabled == true)

  -- Now a confirmed one, with the throttle actually off zero.
  dialog = confirmOverride(page, 40)
  check("the throttle is only usable while overriding", throttleField().enabled == true)
  local topHeader = headerBuilds[#headerBuilds]
  check("the title carries a * while overriding",
    topHeader and topHeader.currentTitle and topHeader.currentTitle:sub(-2) == " *",
    topHeader and ("title is " .. tostring(topHeader.currentTitle)) or "no header")
  check("a confirmed override writes nothing until the keep-alive runs",
    anyMotorRunning() == false,
    "the confirmation itself drove a motor")

  run(page, 0.3)
  local motor = liveMotor()
  check("the override is written again while it is held", motor ~= nil,
    "no write in the first 0.3 s after confirming")
  check("the keep-alive carries the throttle that was set",
    motor ~= nil and motor.value == 400,
    motor and ("wrote " .. tostring(motor.value) .. ", expected 400 (40 % of 1000)") or "no write")

  -- Four times a second, not once a second: the firmware's deadline is one
  -- second, so 1 Hz would let the override lapse between writes.
  local mark = #overrideWrites()
  run(page, 1.0)
  local perSecond = #overrideWrites() - mark
  check("the keep-alive runs at about 4 Hz, not 1 Hz", perSecond >= 3 and perSecond <= 6,
    "wrote " .. tostring(perSecond) .. " times in one second")

  -- Only the selected motor is kept alive. The selector is locked while the
  -- override runs precisely so this stays true.
  check("the motor selector is locked while overriding", motorSelector().enabled == false)
end

out("")
out("part C: leaving the page hands every motor back")
do
  local page = openPage(nil)
  loadPage(page, 4)

  local selector = motorSelector()
  check("a board with four motors offers the selector", selector ~= nil)
  if selector then
    local offered = 0
    for _ in ipairs(selector.choices or {}) do offered = offered + 1 end
    check("the selector offers every motor the board reports", offered == 4,
      "offered " .. tostring(offered))
  end

  -- Drive motor 1 (index 0), which is what a pilot gets by default.
  confirmOverride(page, 40)
  run(page, 0.3)
  check("motor 1 is being driven", lastValueFor(0) ~= nil and lastValueFor(0) ~= 0,
    "motor 1 last value " .. tostring(lastValueFor(0)))

  -- Select motor 2 and drive it too, so the page has touched more than one:
  -- a release naming only the selected motor leaves the other turning. The
  -- throttle is set again on purpose -- a newly selected motor starts at zero,
  -- because inheriting the previous motor's value would turn a motor the pilot
  -- never touched.
  touch(selector, 1)
  setThrottle(25)
  run(page, 0.3)
  check("motor 2 is being driven as well", lastValueFor(1) ~= nil and lastValueFor(1) ~= 0,
    "motor 2 last value " .. tostring(lastValueFor(1)))
  check("motor 1 keeps its own throttle, not motor 2's", lastValueFor(0) == 400,
    "motor 1 last value " .. tostring(lastValueFor(0)) .. ", expected 400")

  page.dispose()
  check("every motor the page touched is released on close",
    lastValueFor(0) == 0 and lastValueFor(1) == 0,
    "motor 1 = " .. tostring(lastValueFor(0)) .. ", motor 2 = " .. tostring(lastValueFor(1)))
  check("no motor is left running after the release", anyMotorRunning() == false)
  check("the page unsubscribes from session.update on dispose", unsubscribes >= 1,
    "unsubscribes=" .. tostring(unsubscribes))
end

out("")
out("part C2: the built page's own Back button releases too")
do
  -- The header is rebuilt once the load finishes, so its Back button is a
  -- DIFFERENT callback from the one installed before the load. If that second
  -- one were a copy that only released the motor, the page would keep its
  -- wakeup handler after leaving and go on writing to a closed page.
  local page = openPage(nil)
  loadPage(page, 2)
  confirmOverride(page, 40)
  run(page, 0.3)
  check("the override is running before Back", lastValueFor(0) ~= 0,
    "motor 1 = " .. tostring(lastValueFor(0)))

  -- header.build is called twice: once before the load, once by buildFields().
  -- The second handle's onBack is the built page's button.
  local backButton = headerBuilds[#headerBuilds]
  check("the page built its own header", backButton ~= nil and backButton.onBack ~= nil)
  if backButton and backButton.onBack then
    backButton.onBack()
    check("the built page's Back button releases the motor", lastValueFor(0) == 0,
      "motor 1 = " .. tostring(lastValueFor(0)) .. " after Back")
    check("and it tears the wakeup handler down",
      page.opts.setWakeupHandlerValue == nil,
      "the wakeup handler is still installed after Back")

    -- A tick after Back must not reach the page: the handler is gone.
    local before = #overrideWrites()
    run(page, 1.0)
    check("no keep-alive runs after Back", #overrideWrites() == before,
      "wrote " .. tostring(#overrideWrites() - before) .. " time(s) after the page was left")
  end
end

out("")
out("part D: an armed model cannot be overridden")
do
  local page = openPage(nil)
  loadPage(page, 2)
  publishSession(true, true)
  page.tick()

  check("the page subscribed to session.update", #sessionHandlers == 1,
    "handlers=" .. tostring(#sessionHandlers))
  local sw = overrideSwitch()
  check("the switch is disabled while the model is armed", sw ~= nil and sw.enabled == false,
    "switch=" .. tostring(sw) .. " enabled=" .. tostring(sw and sw.enabled))

  local dialog = requestOverride(page, true)
  check("asking for an override while armed opens no confirm",
    dialog == nil or dialog.args.message ~= ENABLE_MSG,
    "a confirm was shown for an armed model")
  check("and nothing was written while armed", anyMotorRunning() == false)

  -- The armed notice is retexted into a line that already exists, so it has to
  -- be a full-width line for the same reason the note does.
  check("the armed notice is drawn across the line",
    spansFullLine(staticByText(ARMED_TEXT)),
    "the armed notice did not get a full-width rect")
end

out("")
out("part E: arming mid-override hands the motor back")
do
  local page = openPage(nil)
  loadPage(page, 2)
  confirmOverride(page, 40)
  run(page, 0.3)
  check("an override can run while disarmed", anyMotorRunning() == true,
    "nothing was written while the override was enabled")

  publishSession(true, true)
  page.tick()
  check("arming releases an override that was running", anyMotorRunning() == false,
    "motor 1 = " .. tostring(lastValueFor(0)) .. " after arming")
  check("and the switch is disabled rather than left claiming an override",
    overrideSwitch().enabled == false)
  check("and the title loses * when disarmed",
    headerBuilds[#headerBuilds].currentTitle ~= nil and not headerBuilds[#headerBuilds].currentTitle:find("%*"))

  -- Disarming hands the control back, so the page is not left permanently dead.
  publishSession(true, false)
  page.tick()
  check("the switch comes back after disarming", overrideSwitch().enabled == true,
    "still disabled after disarm")
end

out("")
out("part F: a lost link hands the motor back")
do
  local page = openPage(nil)
  loadPage(page, 2)
  confirmOverride(page, 40)
  run(page, 0.3)
  check("the override runs while the link is up", anyMotorRunning() == true)

  publishSession(false, false)
  page.tick()
  check("a dropped link releases the motor", anyMotorRunning() == false,
    "motor 1 = " .. tostring(lastValueFor(0)) .. " after the link went")
  check("and the switch is not left claiming an override",
    overrideSwitch().enabled == true,
    "the throttle is still usable, as if an override were running")
end

out("")
out("part G: a page that is not overriding stays off the wire")
do
  local page = openPage(nil)
  loadPage(page, 4)
  local afterLoad = #overrideWrites()
  run(page, 5.0)
  check("no keep-alive runs while the override is off", #overrideWrites() == afterLoad,
    "wrote " .. tostring(#overrideWrites() - afterLoad) .. " time(s) with the override off")
end

out("")
out("part H: what the board already holds is shown, not carried over")
do
  -- A board already driving motor 1 at 40 % when the page opens. Motor 1 is the
  -- selected one, so that is the value the throttle row has to show.
  local page = openPage(nil)
  loadPage(page, 4, {400, 0, 0, 0})
  check("the board's own override is picked up for the selected motor",
    throttleField().value() == 40,
    "the throttle field reads " .. tostring(throttleField().value()) .. ", expected 40")

  -- Enabling the override starts from zero -- the pilot confirms a fresh
  -- engagement, it does not inherit whatever the board had at 40 %.
  confirmOverride(page)
  run(page, 0.3)
  local first = lastValueFor(0)
  check("enabling the override starts from zero, not from the board's value",
    first ~= nil and first == 0,
    "motor 1 = " .. tostring(first) .. " after enabling, expected 0")
end

-- ── self-test ──────────────────────────────────────────────────────────────

local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  out("")
  out("--self-test: the gates above must be able to go red")

  --- Load the page from a transformed copy of its source. The splice asserts
  --- it applied, so a check cannot pass because the pattern had moved.
  ---
  --- A multi-line pattern is tried CRLF-first as well: this repository has
  --- core.autocrlf=true and no .gitattributes, so the working tree's line
  --- endings are not the committed ones, and a pattern written with \n alone
  --- matches nothing on a Windows checkout.
  ---
  --- The `-` in `count() - 1` is written as `%-%`: in a Lua pattern a bare `-`
  --- is a lazy repetition operator, not a literal, and `count() - 1` matches
  --- nothing at all.
  --- The source is read with the carriage returns stripped first: this repository
  --- has core.autocrlf=true and no .gitattributes, so the working tree's line
  --- endings are CRLF while the patterns are written with \n.
  local function splicePage(pattern, replacement)
    return function(source)
      -- Plain find/sub, no gsub: a `%` in either argument would be read as an
      -- escape and silently eaten.
      local at = string.find(source, pattern, 1, true)
      if at == nil then
        out(nil, "splice did not apply: " .. pattern)
        os.exit(1)
      end
      return string.sub(source, 1, at - 1) .. replacement
        .. string.sub(source, at + #pattern)
    end
  end

  -- Gate 0: an EdgeTX-only constant. This is the one that actually happened:
  -- the page read SMLSIZE -- EdgeTX's name for a text size, which Ethos does not
  -- define -- and this harness stubbed it, so the run was green while the radio
  -- raised "attempt to perform arithmetic on a nil value (global 'SMLSIZE')".
  -- The splice puts the EdgeTX name back and requires the undeclared-global
  -- check to name it.
  do
    local page = openPage(splicePage("rect, text, LEFT)", "rect, text, LEFT + SMLSIZE)"))
    loadPage(page, 4)
    check("the EdgeTX-constant gate goes red on an undeclared global",
      #undeclaredGlobals > 0,
      "the spliced page read SMLSIZE and the harness did not record it")
    check("and it names the constant that is not an Ethos one",
      table.concat(undeclaredGlobals, ","):find("SMLSIZE") ~= nil,
      "recorded: " .. table.concat(undeclaredGlobals, ", "))
  end

  -- Gate 0b: the note drawn in the value column. `nil` as a static text's
  -- rect is what shipped: the note landed in the line's narrow right-hand slot
  -- and arrived on the radio cut off at the right edge.
  do
    local page = openPage(splicePage(
      "local rect = {x = 0, y = slot.y or 0, w = width or slot.w or 0, h = slot.h or 0}",
      "local rect = nil"))
    loadPage(page, 4)
    check("the value-column gate goes red when the rect is nil",
      spansFullLine(staticByText(NOTE_TEXT)) == false,
      "the spliced page still gave the note a full-width rect")
  end

  -- Gate 1: no keep-alive. motors.c:301-303 resets the override one second
  -- after the last write, so a page that writes once and stops lets the motor
  -- lapse -- which reads as an intermittent fault, not as a timeout.
  do
    local page = openPage(splicePage("local REFRESH_INTERVAL = 0.25", "local REFRESH_INTERVAL = 99"))
    loadPage(page, 4)
    confirmOverride(page, 40)
    local mark = #overrideWrites()
    run(page, 1.0)
    local perSecond = #overrideWrites() - mark
    check("the keep-alive gate goes red without the refresh", perSecond < 3,
      "the spliced page still wrote " .. tostring(perSecond) .. " times in a second")
    check("and its motor really would have lapsed", anyMotorRunning() == false,
      "the spliced page kept driving, so the splice did not take")
  end

  -- Gate 2: no armed guard. motors.c:116 refuses the write outright, so the
  -- page's own refusal is the only thing between the pilot and a dead control.
  -- Both places carry it -- the disabled switch (refreshEnabled) and the
  -- refusal to open the confirm at all (openConfirm) -- so both are spliced:
  -- a page that only drops one of them still asks an armed pilot.
  do
    local page = openPage(splicePage("local blocked = isArmed == true", "local blocked = false"))
    loadPage(page, 2)
    publishSession(true, true)
    page.tick()
    check("the armed gate goes red without the guard", overrideSwitch().enabled == true,
      "the spliced page still disabled the switch while armed")
  end

  do
    local page = openPage(splicePage(
      "if enabled and isArmed == true then\n      refreshEnabled()\n      return\n    end",
      "if false then\n      return\n    end"))
    loadPage(page, 2)
    publishSession(true, true)
    page.tick()
    local dialog = requestOverride(page, true)
    check("the confirm gate goes red without the refusal",
      dialog ~= nil and dialog.args.message == ENABLE_MSG,
      "the spliced page refused anyway, so the splice did not take")
  end

  -- Gate 4: the release narrowed to the selected motor. The write names one
  -- motor (msp.c:2966-2972), so the others keep whatever they had.
  do
    local page = openPage(splicePage(
      "for i = 0, count() - 1 do\n      percent[i] = 0\n      writeOverride(i, 0)\n    end",
      "percent[selected] = 0\n    writeOverride(selected, 0)"))
    loadPage(page, 4)
    local selector = motorSelector()
    confirmOverride(page, 40)
    run(page, 0.3)
    if selector then
      touch(selector, 1)
      setThrottle(25)
    end
    run(page, 0.3)
    check("both motors are driven before the release",
      lastValueFor(0) ~= nil and lastValueFor(0) ~= 0 and lastValueFor(1) ~= nil and lastValueFor(1) ~= 0,
      "motor 1 = " .. tostring(lastValueFor(0)) .. ", motor 2 = " .. tostring(lastValueFor(1)))
    page.dispose()
    local named = {}
    for _, w in ipairs(overrideWrites()) do named[w.index] = true end
    local count2 = 0
    for _ in pairs(named) do count2 = count2 + 1 end
    check("the every-motor release gate goes red when narrowed to one", count2 < 4,
      "the spliced page still released " .. tostring(count2) .. " motor(s)")
    check("and it leaves the unselected motor running",
      lastValueFor(0) ~= 0,
      "motor 1 = " .. tostring(lastValueFor(0)) .. " after a narrowed release")
  end

  -- Gate 7: the built page's Back button wired to its own copy of the teardown
  -- instead of goBack. The release would still happen -- which is why a check
  -- that only looked at the motor would stay green -- but the wakeup handler
  -- would survive the page, so the last page to be visited would keep its
  -- 4 Hz timer running with nothing on screen.
  do
    local page = openPage(splicePage(
      "onBack = function() goBack() end,",
      "onBack = function() disposed = true; releaseAllMotors() end,"))
    loadPage(page, 2)
    confirmOverride(page, 40)
    run(page, 0.3)
    local backButton = headerBuilds[#headerBuilds]
    if backButton and backButton.onBack then backButton.onBack() end
    check("the Back-teardown gate goes red with a private copy",
      page.opts.setWakeupHandlerValue ~= nil,
      "the spliced page still tore the handler down, so the splice did not take")
    check("and the motor is released either way, which is why the motor check alone is not enough",
      lastValueFor(0) == 0,
      "motor 1 = " .. tostring(lastValueFor(0)))
  end

  -- Gate 8: the session handler never unsubscribes. The page is retained by the
  -- bus for as long as the tool lives, so a page that leaks its handler keeps
  -- reacting to arming and link drops long after it has been left.
  do
    local page = openPage(splicePage(
      "if sessionHandler then\n      bus.unsubscribe(\"session.update\", sessionHandler)\n      sessionHandler = nil\n    end",
      "sessionHandler = nil"))
    loadPage(page, 2)
    page.dispose()
    check("the unsubscribe gate goes red without the teardown", unsubscribes == 0,
      "the spliced page still unsubscribed, so the splice did not take")
  end
  -- leaves the page believing it holds a motor that nobody is writing zeros to
  -- -- the firmware has already stopped honouring the override, and the one
  -- second deadline is running out whether the page likes it or not. There is
  -- deliberately no second copy of this check in the wakeup: the session
  -- handler is the single place that reacts, so removing it here removes the
  -- behaviour outright rather than half of it.
  do
    local page = openPage(splicePage(
      "if connected == false or isArmed == true then stopOverride() end",
      "if connected == false or isArmed == true then inOverride = false end"))
    loadPage(page, 2)
    confirmOverride(page, 40)
    run(page, 0.3)
    publishSession(false, false)
    page.tick()
    check("the lost-link release gate goes red without the handling",
      lastValueFor(0) ~= nil and lastValueFor(0) ~= 0,
      "motor 1 = " .. tostring(lastValueFor(0)) .. " after the link went")
  end

  do
    local page = openPage(splicePage(
      "if connected == false or isArmed == true then stopOverride() end",
      "if connected == false or isArmed == true then inOverride = false end"))
    loadPage(page, 2)
    confirmOverride(page, 40)
    run(page, 0.3)
    publishSession(true, true)
    page.tick()
    check("the arming release gate goes red without the handling",
      lastValueFor(0) ~= nil and lastValueFor(0) ~= 0,
      "motor 1 = " .. tostring(lastValueFor(0)) .. " after arming")
  end
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