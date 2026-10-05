-- Behaviour check for the profile anchor a page's data is tagged with (#2388).
--
-- Run it:
--     lua5.4 bin/page_runtime/verify_profile_anchor.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/page_runtime.lua under stubs for the six things
--     it reaches out to. The pages themselves are not needed: the anchor is
--     PageRuntime's own state, and every page built on it goes through this one
--     method.
--   * The seam is time. MSP answers are held rather than delivered inline, so a
--     session.update -- the pilot switching profile -- can be delivered while a
--     read is genuinely in flight, which is the window the whole defect lives
--     in. Inline delivery makes every case vacuous: the read would finish
--     before the switch could arrive.
--   * Each read answers with the profile that is active at the moment it is
--     answered, so "whose values does the page hold?" is a value on the page's
--     own data table rather than an inference from a counter.
--
-- Which cases go RED on the pre-fix page_runtime.lua:
--   1. a switch during the initial read -- the page ends up holding profile 1's
--      values while anchored to profile 2, and nothing reloads
--   2. the reload is armed at all -- onSessionUpdate() cannot arm it during that
--      window, because it needs loadedProfile set and loaded true, and both are
--      false until the read lands
--   5. the service-time variant, where the answer carries the new profile: the
--      fix costs one extra read there and must still end on the right data
-- Cases 3, 4 and 6 pin behaviour that has to survive the fix.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

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

-- ── the seams ──────────────────────────────────────────────────────────────

-- The profile the flight controller is actually on. A read answers with
-- whatever this says when it is released, not when it was requested.
local fcProfile = 1
local held = {}                -- read callbacks waiting to be released
local deferReads = false
local readsIssued = 0
local readsAnswered = 0
local sessionHandlers = {}

-- Answers with the profile that was active when the request was queued, which
-- is what a queue that drains on the next background-task tick does. The one
-- exception is case 5, which rewrites this to model a flight controller that
-- applied the switch before it serviced the request.
local function releaseReads()
  local pending = held
  held = {}
  deferReads = false
  for _, message in ipairs(pending) do
    readsAnswered = readsAnswered + 1
    message.onData({ profile = message.answerProfile or fcProfile })
  end
end

local function answerHeldAs(profile)
  for _, message in ipairs(held) do message.answerProfile = profile end
end

local function publishSession(profile)
  -- A profile switch moves the flight controller. Not setting fcProfile here
  -- would leave the reads answering with a profile the pilot already left,
  -- and every case below would be asserting against a page that never existed.
  fcProfile = profile
  for _, handler in ipairs(sessionHandlers) do
    handler({ pidProfile = profile, isArmed = false, mcuId = "0123456789" })
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

-- Forward-declared, because the _G.form closures below call them and a Lua
-- local only counts as captured where it is already in scope: written as
-- "local function" after that table, they resolve to nil globals instead.
local widgetStub, dialogStub

_G.form = {
  addButton = function() return widgetStub("button") end,
  addTextButton = function() return widgetStub("textbutton") end,
  addStaticText = function() return widgetStub("text") end,
  addLine = function() return 1 end,
  clear = function() end,
  height = function() return 320 end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local out = {}
    for i = 1, n do out[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 } end
    return out
  end,
  openDialog = function() return dialogStub("openDialog") end,
  openProgressDialog = function() return dialogStub("openProgressDialog") end,
}

local widgets = {}
widgetStub = function(name)
  local w
  w = {
    name = name,
    enabled = nil,
    focus = function() end,
    enable = function(_, on) w.enabled = on end,
    value = function() end,
    setValue = function() end,
    setText = function() end,
    getValue = function() return 0 end,
    show = function() end,
    hide = function() end,
  }
  widgets[#widgets + 1] = w
  return w
end

dialogStub = function(kind)
  local d
  d = {
    kind = kind,
    closed = false,
    value = function() end,
    message = function() end,
    closeAllowed = function() end,
    close = function() d.closed = true end,
  }
  return d
end

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
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07
_G.KEY_ENTER_BREAK = 0x08

-- ── module stubs ───────────────────────────────────────────────────────────

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function(topic, handler)
    if topic == "session.update" then sessionHandlers[#sessionHandlers + 1] = handler end
  end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    if type(message.onData) ~= "function" then return end
    readsIssued = readsIssued + 1
    if deferReads then
      message.answerProfile = fcProfile
      held[#held + 1] = message
    else
      readsAnswered = readsAnswered + 1
      message.onData({ profile = fcProfile })
    end
  end,
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
  saveConfirmEnabled = function() return true end,
  reloadConfirmEnabled = function() return true end,
  load = function() return {} end,
  save = function() end,
  DEFAULTS = {},
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function() return { onData = function() end, onError = function() end } end,
}
package.loaded["rfsuite.lib.msp_reboot"] = { reboot = function() end }
package.loaded["rfsuite.app.header"] = {
  build = function()
    return {
      setTitle = function() end,
      setSaveEnabled = function() end,
      setReloadEnabled = function() end,
      focusMenu = function() end,
      focusSave = function() end,
      focusReload = function() end,
      focusTool = function() end,
    }
  end,
}

-- The MSP module under test's side of the seam: the payload carries the profile
-- that was active when the answer was produced.
local function mspModuleStub()
  return {
    buildReadMessage = function(onData, onError)
      return { onData = onData, onError = onError }
    end,
    buildWriteMessage = function(_, onData, onError)
      return { onData = onData, onError = onError }
    end,
  }
end

-- ── the subject ────────────────────────────────────────────────────────────

local PageRuntime = dofile(SUITE .. "/app/page_runtime.lua")

local function newPage()
  local opts = {}
  local function setter(name)
    return function(handler) opts[name] = handler end
  end
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() end

  local runtime = PageRuntime.new({
    pageTitle = "Harness",
    logTag = "harness",
    profileField = "pidProfile",
    mspModule = mspModuleStub(),
    opts = opts,
  })
  runtime:buildChrome()
  runtime:registerField("default", widgetStub("field"))

  return runtime, function() if opts.setWakeupHandler then opts.setWakeupHandler() end end
end

-- One page visit, from "pilot is on profile N" to "everything has settled".
-- settleTicks is generous on purpose: a correct fix may need a second read, and
-- a fixed number of ticks would either cut it short or hide a reload loop.
local function settle(runtime, tick, ticks)
  for _ = 1, (ticks or 6) do tick() end
end

local function reset(profile)
  fcProfile = profile or 1
  held = {}
  deferReads = false
  readsIssued = 0
  readsAnswered = 0
end

-- The invariant this whole file is about, in one line.
local function atRest(runtime)
  return runtime.loadedProfile == runtime.lastProfile
    and runtime.data ~= nil
    and runtime.data.profile == runtime.lastProfile
end

local function describe(runtime)
  return string.format("lastProfile=%s loadedProfile=%s data.profile=%s loaded=%s pendingReload=%s",
    tostring(runtime.lastProfile), tostring(runtime.loadedProfile),
    tostring(runtime.data and runtime.data.profile), tostring(runtime.loaded),
    tostring(runtime.pendingReload))
end

-- ── cases ──────────────────────────────────────────────────────────────────

out("case 1: a switch during the initial read")
do
  reset(1)
  local runtime, tick = newPage()

  publishSession(1)                 -- pilot opens the page on profile 1
  deferReads = true
  runtime:loadInitial()             -- read issued, answer held
  check("the read is in flight", readsIssued == 1 and #held == 1,
    "issued=" .. readsIssued .. " held=" .. #held)

  publishSession(2)                 -- the switch the defect lives on
  check("the switch alone arms no reload", runtime.pendingReload == false,
    "onSessionUpdate() must not reload before the page has loaded once")

  releaseReads()                    -- answers carry profile 1: queued on profile 1
  tick()
  settle(runtime, tick)

  check("the page ends on profile 2", runtime.lastProfile == 2, describe(runtime))
  check("the page holds profile 2's values",
    runtime.data ~= nil and runtime.data.profile == 2, describe(runtime))
  check("the anchor names the profile the data came from", atRest(runtime),
    describe(runtime) .. "  <- loadedProfile must be 2 here, not the data's profile")
end

out("")
out("case 2: the reload is armed even though onSessionUpdate() could not arm it")
do
  reset(1)
  local runtime, tick = newPage()

  publishSession(1)
  deferReads = true
  runtime:loadInitial()
  publishSession(2)
  local issuedBefore = readsIssued
  releaseReads()
  tick()                            -- the success branch runs here
  check("a reload was armed by the success branch",
    runtime.pendingReload == true or readsIssued > issuedBefore,
    "nothing armed the re-read, and no re-read happened")
  settle(runtime, tick)
  check("and it settled without a second reload",
    runtime.pendingReload == false and readsIssued == issuedBefore + 1,
    "issued=" .. readsIssued .. " expected " .. (issuedBefore + 1)
      .. ", pendingReload=" .. tostring(runtime.pendingReload))
end

out("")
out("case 3: a switch after a completed read still reloads")
do
  reset(1)
  local runtime, tick = newPage()

  publishSession(1)
  runtime:loadInitial()
  settle(runtime, tick)
  check("the page is at rest on profile 1", atRest(runtime), describe(runtime))
  local before = readsIssued

  publishSession(2)
  tick()
  settle(runtime, tick)
  check("the switch armed a reload", readsIssued > before,
    "issued=" .. readsIssued .. " expected more than " .. before)
  check("and the page ended on profile 2", atRest(runtime) and runtime.lastProfile == 2,
    describe(runtime))
end

out("")
out("case 4: a quiet page does not reload itself")
do
  reset(1)
  local runtime, tick = newPage()

  publishSession(1)
  runtime:loadInitial()
  settle(runtime, tick)
  local before = readsIssued
  for _ = 1, 10 do tick() end
  check("ten more ticks changed nothing", readsIssued == before,
    "issued " .. readsIssued .. " reads for one, expected " .. before)
  check("nothing is pending", runtime.pendingReload == false)
end

out("")
out("case 5: the flight controller answers after the switch")
do
  -- The other model, and the reason this is not simply "capture earlier": the
  -- request is queued, so the answer can carry the profile that became active
  -- while it was queued. Then the captured anchor names profile 1 while the
  -- data is profile 2's -- one read too many, but never wrong data.
  reset(1)
  local runtime, tick = newPage()

  publishSession(1)
  deferReads = true
  runtime:loadInitial()
  publishSession(2)
  answerHeldAs(2)                   -- the FC applied the switch before servicing it
  releaseReads()
  settle(runtime, tick)

  check("the page ends on profile 2", runtime.lastProfile == 2, describe(runtime))
  check("the page holds profile 2's values",
    runtime.data ~= nil and runtime.data.profile == 2, describe(runtime))
  check("and it is anchored correctly", atRest(runtime), describe(runtime))
end

out("")
out("case 6: a reload loop cannot start")
do
  reset(1)
  local runtime, tick = newPage()

  publishSession(1)
  deferReads = true
  runtime:loadInitial()
  publishSession(2)
  releaseReads()
  settle(runtime, tick, 12)        -- deliberately far more ticks than needed
  local after = readsIssued
  for _ = 1, 10 do tick() end
  check("settling stops the reads", readsIssued == after,
    "issued " .. readsIssued .. " reads, expected " .. after .. " once settled")
  check("and the page is still at rest", atRest(runtime), describe(runtime))
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
out(string.format("reads issued: %d   answered: %d", readsIssued, readsAnswered))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")
