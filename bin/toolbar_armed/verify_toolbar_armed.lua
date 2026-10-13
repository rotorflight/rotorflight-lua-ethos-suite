-- Behaviour check for the dashboard toolbar's write items while armed (#2505).
--
-- Run it:
--     lua5.4 bin/toolbar_armed/verify_toolbar_armed.lua
--
-- What it drives, and why:
--   * The real widgets/dashboard.lua, through the descriptor the radio calls
--     (create, wakeup, paint, event). The Erase and Battery tiles are opened
--     the way a pilot taps them: Page long press shows the toolbar, a touch
--     start and end on the tile activates it.
--   * The claim the change makes: while the model is armed, the two toolbar
--     items that write to the flight controller (blackbox erase, battery
--     profile) are disabled, a battery picker open at the moment of arming
--     is closed, and a write that a dialog confirmed after arming is refused
--     at the write itself. Disarmed, both items work as before.
--   * The Reset and Info tiles are not written to the FC here and are checked
--     only to show that the arm state does not disable everything.
--
-- Not established here: that a rotor turning is safe to observe on a
-- simulator, or how the greyed tiles look on a 480x320 radio. The stub lcd
-- does not rasterise. The Ethos simulator check is named in the PR body.
--
-- Against unpatched upstream/master the armed checks must fail; that run is
-- the proof that the checks can go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then
    f:close()
    return name
  end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then
    path = resolvePath(path)
  end
  if env ~= nil then
    return realLoadfile(path, mode, env)
  elseif mode ~= nil then
    return realLoadfile(path, mode)
  else
    return realLoadfile(path)
  end
end

-- rfsuite.lib.require is loadfile() against Ethos' path prefixes on a radio.
local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

-- ---------------------------------------------------------------------------
-- Ethos stubs
-- ---------------------------------------------------------------------------

FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L = 1, 2, 3, 4, 5
CENTERED, TEXT_LEFT = 16, 0
EVT_KEY, EVT_TOUCH = 10, 11
TOUCH_START, TOUCH_MOVE, TOUCH_END = 20, 21, 22
KEY_PAGE_LONG, KEY_ENTER_BREAK, KEY_EXIT_BREAK, KEY_RTN_BREAK, KEY_DOWN_BREAK = 30, 31, 32, 33, 34
ROTARY_LEFT, KEY_ROTARY_RIGHT = 40, 41

lcd = setmetatable({
  RGB = function(_, _, _, alpha) return {alpha = alpha or 1} end,
  color = function() end,
  drawFilledRectangle = function() end,
  drawText = function() end,
  font = function() end,
  getTextSize = function(text) return #tostring(text) * 7, 14 end,
  getWindowSize = function() return 480, 320 end,
  hasFocus = function() return true end,
  isVisible = function() return true end,
  invalidate = function() end,
}, {__index = function() return function() end end})

os.stat = function() return nil end
system = {
  registerWidget = function(w) _G.__widget = w end,
  killEvents = function() end,
  openPage = function() end,
  getMemoryUsage = function() return {mainStackAvailable = 4096} end,
  getVersion = function() return {simulation = false} end,
  voltageRange = function() return 7.2, 8.4 end,
  getSource = function() return nil end,
}
model = {bitmap = function() return nil end}

-- Every form.openDialog is recorded, so a confirm button can be pressed by the
-- check the way a pilot presses OK.
local dialogs = {}
form = setmetatable({
  openDialog = function(opts)
    if type(opts) == "table" then dialogs[#dialogs + 1] = opts end
  end,
  openProgressDialog = function()
    return {value = function() end, closeAllowed = function() end, close = function() end}
  end,
}, {__index = function() return function() end end})

local failures, checks = 0, 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
  return ok
end

-- ---------------------------------------------------------------------------
-- Drive the dashboard
-- ---------------------------------------------------------------------------

local dashboard = requireModule("widgets/dashboard.lua")
local bus = requireModule("lib/bus.lua")

-- Every msp.request the widget publishes, in order.
local requests = {}
bus.subscribe("msp.request", function(payload) requests[#requests + 1] = payload end)

dashboard.init({})
local descriptor = _G.__widget
check("the dashboard widget registered itself", descriptor ~= nil)
if descriptor == nil then
  print(string.format("\n%d checks, %d failed", checks, failures))
  os.exit(1)
end

local state = descriptor.create()
pcall(descriptor.wakeup, state)

-- Connected, several packs, disarmed: the picker opens by itself once.
state.connected = true
state.apiVersionSupported = true
state.isArmed = false
state.batteryConfig = {profiles = {
  [0] = {capacity = 3300}, [1] = {capacity = 4000}, [2] = {capacity = 5000},
  [3] = {capacity = 2200}, [4] = {capacity = 1500}, [5] = {capacity = 6000},
}}
state.batteryProfile = 3
descriptor.wakeup(state)

local function key(value) descriptor.event(state, EVT_KEY, value) end
local function touch(value, x, y) return descriptor.event(state, EVT_TOUCH, value, x, y) end

-- Paint once so the toolbar rectangles (and their enabled flags) are built.
local function paint()
  local ok, err = pcall(descriptor.paint, state)
  if not ok then print("        paint error: " .. tostring(err)) end
end

-- The toolbar rectangles are built by the paint, which can take a few
-- wakeups to reach the toolbar (the same as the battery picker harness).
local function openToolbar()
  key(KEY_PAGE_LONG)
  for _ = 1, 20 do
    paint()
    if state.toolbarRects and state.toolbarRects[1] then break end
    descriptor.wakeup(state)
  end
end

local function enabled(index)
  local r = state.toolbarRects and state.toolbarRects[index]
  if not r then return nil end
  return r.enabled
end

local function tap(index)
  local r = state.toolbarRects and state.toolbarRects[index]
  if not r then return end
  local x, y = r.x + r.w / 2, r.y + r.h / 2
  touch(TOUCH_START, x, y)
  touch(TOUCH_END, x, y)
end

local TILE = {reset = 1, erase = 2, battery = 3, info = 4}

check("disarmed, connected: the picker opens by itself", state.batteryPicker ~= nil)

-- The arm state reaches the widget the way the session delivers it: a
-- session.update snapshot on the bus (widgets/dashboard.lua, update()).
local function setArmed(value)
  -- update() copies batteryConfig and batteryProfile from the snapshot, so the
  -- snapshot must carry them as the session does, or the pack list is lost.
  bus.publish("session.update", {
    connected = true,
    isArmed = value,
    batteryConfig = state.batteryConfig,
    batteryProfile = state.batteryProfile,
  })
  descriptor.wakeup(state)
end

local requestsStart = #requests

-- 1. Arming while the picker that connecting opened is still up closes it.
setArmed(true)
descriptor.wakeup(state)
check("arming closes the battery picker that was open", state.batteryPicker == nil)
check("arming publishes no write", #requests == requestsStart)

-- 2. Armed: the two write items are disabled, the others are not.
openToolbar()
-- Precondition for the tap checks below: without an open toolbar a tap does
-- nothing, and "nothing happened" would prove nothing.
check("armed: the toolbar can be opened for the tap checks", state.toolbarRects ~= nil)
check("armed: the Erase tile is disabled", enabled(TILE.erase) == false)
check("armed: the Battery tile is disabled", enabled(TILE.battery) == false)
check("armed: the Info tile stays enabled", enabled(TILE.info) == true)

local dialogsArmed = #dialogs
tap(TILE.erase)
check("armed: tapping Erase opens no confirmation", #dialogs == dialogsArmed)
check("armed: tapping Erase publishes no write", #requests == requestsStart)

tap(TILE.battery)
check("armed: tapping Battery opens no picker", state.batteryPicker == nil)
check("armed: tapping Battery publishes no write", #requests == requestsStart)

-- 3. Disarmed: the Erase confirmation opens; OK is answered only after arming.
setArmed(false)
descriptor.wakeup(state)
openToolbar()
check("disarmed again: the Erase tile is enabled", enabled(TILE.erase) == true)
check("disarmed again: the Battery tile is enabled", enabled(TILE.battery) == true)

local dialogsBeforeConfirm = #dialogs
tap(TILE.erase)
check("disarmed: tapping Erase opens its confirmation", #dialogs == dialogsBeforeConfirm + 1)
local eraseConfirm = dialogs[#dialogs]
-- Precondition for the confirmed-after-arming check: there must be a dialog.
check("the Erase confirmation exists to be confirmed after arming", eraseConfirm ~= nil)

-- The model is armed while that confirmation is still on screen.
setArmed(true)
descriptor.wakeup(state)
if eraseConfirm and eraseConfirm.buttons and eraseConfirm.buttons[1] then
  pcall(eraseConfirm.buttons[1].action)
end
check("an Erase confirmed after arming writes nothing", #requests == requestsStart,
  "requests=" .. (#requests - requestsStart))

-- 4. Disarmed again: the write goes through, so the refusal is the arm state
--    and not a broken path.
setArmed(false)
descriptor.wakeup(state)
openToolbar()
local dialogsDisarmed = #dialogs
tap(TILE.erase)
check("disarmed: tapping Erase opens its confirmation again", #dialogs == dialogsDisarmed + 1)
local secondConfirm = dialogs[#dialogs]
if secondConfirm and secondConfirm.buttons and secondConfirm.buttons[1] then
  pcall(secondConfirm.buttons[1].action)
end
check("disarmed: a confirmed Erase publishes its write", #requests == requestsStart + 1,
  "requests=" .. (#requests - requestsStart))

-- 5. The link drops while the model is armed and comes back: the session clears
--    isArmed together with connected and publishes the reconnect before the first
--    arm frame, so for a moment the FC is connected and its arm state is nil. That
--    is not disarmed for the two write items, and must not be treated as one.
setArmed(true)
descriptor.wakeup(state)
setArmed(nil)
descriptor.wakeup(state)
openToolbar()
check("arm state lost after arming: the Erase tile is disabled", enabled(TILE.erase) == false)
check("arm state lost after arming: the Battery tile is disabled", enabled(TILE.battery) == false)
check("arm state lost after arming: the Info tile stays enabled", enabled(TILE.info) == true)
local dialogsLost = #dialogs
-- Block 4 confirmed an Erase, which left eraseActive set, and doEraseBlackbox
-- refuses a second one for that reason alone. Cleared here so the write check
-- below measures the arm state and not a leftover run.
state.eraseActive = nil
state.eraseDone = false
check("arm state lost after arming: the precondition erase is cleared",
  state.eraseActive == nil)
tap(TILE.erase)
check("arm state lost after arming: tapping Erase opens no confirmation",
  #dialogs == dialogsLost)
local lostConfirm = dialogs[#dialogs]
if lostConfirm and lostConfirm.buttons and lostConfirm.buttons[1] then
  pcall(lostConfirm.buttons[1].action)
end
check("arm state lost after arming: a confirmed Erase writes nothing",
  #requests == requestsStart + 1, "requests=" .. (#requests - requestsStart))

-- 6. The answer arrives again and says armed: still refused.
setArmed(true)
descriptor.wakeup(state)
openToolbar()
check("armed again: the Erase tile is disabled", enabled(TILE.erase) == false)

-- 7. Disarmed, and THEN the answer is lost: the model was confirmed disarmed, so
--    the missing answer must not grey the tiles out on every reconnect.
setArmed(false)
descriptor.wakeup(state)
setArmed(nil)
descriptor.wakeup(state)
openToolbar()
check("arm state lost after being disarmed: the Erase tile stays enabled",
  enabled(TILE.erase) == true)
check("arm state lost after being disarmed: the Battery tile stays enabled",
  enabled(TILE.battery) == true)

-- 8. An FC that never reports arm flags at all must stay usable: nil with no latch
--    set is "never answered", not "answered and lost", and must not lock the tiles.
setArmed(false)
descriptor.wakeup(state)
state.isArmed = nil
state.armedUnconfirmed = false
descriptor.wakeup(state)
openToolbar()
check("an FC that never reports arm flags: the Erase tile stays enabled",
  enabled(TILE.erase) == true)
check("an FC that never reports arm flags: the Battery tile stays enabled",
  enabled(TILE.battery) == true)

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
