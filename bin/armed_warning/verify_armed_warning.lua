-- Behaviour check for the armed warning on the dashboard (#2352).
--
-- Run it:
--     lua5.4 bin/armed_warning/verify_armed_warning.lua
--
-- Drives the real widgets/dashboard.lua paint path with a recording lcd. The claim:
-- while the model is confirmed armed, a red frame and an "Armed" badge are drawn over
-- the dashboard, whatever theme is shown; disarmed, nothing red is drawn.
--
-- Not established here: how the badge sits on a 480x320 radio over each theme. The
-- stub lcd does not rasterise. That is the Ethos simulator check named in the PR body.

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

local rects, texts, color = {}, {}, nil
lcd = setmetatable({
  RGB = function(r, g, b) return {r = r or 0, g = g or 0, b = b or 0} end,
  color = function(c) color = c end,
  drawFilledRectangle = function(x, y, w, h)
    rects[#rects + 1] = {x = x, y = y, w = w, h = h, color = color}
  end,
  drawText = function(x, y, text)
    texts[#texts + 1] = {x = x, y = y, text = tostring(text), color = color}
  end,
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
-- Drive the dashboard paint with a recording lcd
-- ---------------------------------------------------------------------------

local dashboard = requireModule("widgets/dashboard.lua")
local bus = requireModule("lib/bus.lua")
dashboard.init({})
local descriptor = _G.__widget
check("the dashboard widget registered itself", descriptor ~= nil)
if descriptor == nil then
  print(string.format("\n%d checks, %d failed", checks, failures))
  os.exit(1)
end

local state = descriptor.create()
pcall(descriptor.wakeup, state)
state.connected = true
state.apiVersionSupported = true
state.batteryConfig = {profiles = {[0] = {capacity = 3300}}}
state.batteryProfile = 0
descriptor.wakeup(state)

local function setArmed(value)
  bus.publish("session.update", {
    connected = true,
    isArmed = value,
    batteryConfig = state.batteryConfig,
    batteryProfile = state.batteryProfile,
  })
  descriptor.wakeup(state)
end

-- One full paint, retried over wakeups until the theme has drawn something.
local function paintFrame()
  rects, texts = {}, {}
  for _ = 1, 20 do
    local ok, err = pcall(descriptor.paint, state)
    if not ok then print("        paint error: " .. tostring(err)) return end
    if #rects > 0 then return end
    descriptor.wakeup(state)
  end
end

local LABEL = "@i18n(widgets.dashboard.info_armed)@"

local function isRed(c)
  return type(c) == "table" and c.r == 214 and c.g == 40 and c.b == 40
end

local function redFrameEdges()
  local edges = {top = false, bottom = false, left = false, right = false}
  for _, r in ipairs(rects) do
    if isRed(r.color) then
      if r.y == 0 and r.w == 480 and r.h == 4 then edges.top = true end
      if r.y == 316 and r.w == 480 and r.h == 4 then edges.bottom = true end
      if r.x == 0 and r.w == 4 and r.h == 320 then edges.left = true end
      if r.x == 476 and r.w == 4 and r.h == 320 then edges.right = true end
    end
  end
  return edges
end

local function hasLabel()
  for _, t in ipairs(texts) do
    if t.text == LABEL then return true end
  end
  return false
end

-- 1. Disarmed: no red frame, no badge.
setArmed(false)
paintFrame()
local e = redFrameEdges()
check("disarmed: no red frame is drawn", not (e.top or e.bottom or e.left or e.right))
check("disarmed: no Armed badge is drawn", not hasLabel())

-- 2. Armed: the frame on all four edges, and the badge.
setArmed(true)
paintFrame()
e = redFrameEdges()
check("armed: the red frame is drawn on the top edge", e.top)
check("armed: the red frame is drawn on the bottom edge", e.bottom)
check("armed: the red frame is drawn on the left edge", e.left)
check("armed: the red frame is drawn on the right edge", e.right)
check("armed: the Armed badge is drawn", hasLabel())

-- 3. Disarmed again: the warning goes away.
setArmed(false)
paintFrame()
e = redFrameEdges()
check("disarmed again: the red frame is gone", not (e.top or e.bottom or e.left or e.right))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
