-- Behaviour check for the armed warning on the dashboard (#2352).
--
-- Run it:
--     lua5.4 bin/armed_warning/verify_armed_warning.lua
--
-- Drives the real widgets/dashboard.lua paint path with a recording lcd. The claim:
-- while the model is confirmed armed, a red bar runs across the top edge with an
-- "Armed" label hanging from its centre, over whatever theme is shown. Disarmed,
-- nothing red is drawn. The widget property "Armed warning" (default on) switches
-- the bar off; with it off, nothing red is drawn even while armed.
--
-- Not established here: how the bar and label sit on a 480x320 radio over each
-- theme. The stub lcd does not rasterise. That is the Ethos simulator check named
-- in the PR body.
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

-- Widget storage (Ethos storage.read / storage.write), kept in memory for the check.
local stored = {}
storage = {
  read = function(key) return stored[key] end,
  write = function(key, value) stored[key] = value end,
}

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

-- The widget property is built with form.addLine + form.addBooleanField; capture the
-- field's getter and setter so the check can flip it the way the pilot does.
local configField = nil
form.addLine = function() return {} end
form.addBooleanField = function(_, _, get, set) configField = {get = get, set = set} end

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
-- Returns false, and records a failed check, when the paint raises or never draws.
-- The drawing checks after it must not pass against an empty or partial record.
local function paintFrame()
  rects, texts = {}, {}
  for _ = 1, 20 do
    local ok, err = pcall(descriptor.paint, state)
    if not ok then
      check("paint: the dashboard paints without error", false, err)
      return false
    end
    if #rects > 0 then return true end
    descriptor.wakeup(state)
  end
  check("paint: the dashboard draws within 20 wakeups", false)
  return false
end

local LABEL = "@i18n(widgets.dashboard.info_armed)@"

local function isRed(c)
  return type(c) == "table" and c.r == 214 and c.g == 40 and c.b == 40
end

-- The red bar is the full-width strip at the top, and the label hangs from it at y = 4.
-- Any other red rectangle (a frame edge, a second bar) is reported as `other`.
local function redRects()
  local found = {bar = false, label = false, other = false}
  for _, r in ipairs(rects) do
    if isRed(r.color) then
      if r.y == 0 and r.w == 480 and r.h == 4 then
        found.bar = true
      elseif r.y == 4 then
        found.label = true
      else
        found.other = true
      end
    end
  end
  return found
end

-- The label hangs from the centre of the bar: its text sits where a label of its own
-- width, plus the 12 px of badge padding, centred in the 480 px window would put it,
-- and just below the 4 px bar.
local function labelCentred()
  local tw = #LABEL * 7   -- the stub's getTextSize
  local expected = math.floor((480 - tw - 12) / 2) + 6
  for _, t in ipairs(texts) do
    if t.text == LABEL then return t.x == expected and t.y == 7 end
  end
  return false
end

local function hasLabel()
  for _, t in ipairs(texts) do
    if t.text == LABEL then return true end
  end
  return false
end

-- The widget property is stored and read back through the Ethos storage API.
-- Nothing stored yet counts as on.
check("property: default on when nothing is stored", stored.armed_warning == nil)
descriptor.read(state)
check("property: read with nothing stored leaves the warning on", state.armedWarningEnabled == true)

-- 1. Disarmed: no red, no label.
setArmed(false)
paintFrame()
local r = redRects()
check("disarmed: no red bar is drawn", not r.bar)
check("disarmed: no Armed label is drawn", not hasLabel() and not r.label)
check("disarmed: nothing else red is drawn", not r.other)

-- 2. Armed (property on, default): a bar across the top, the label hanging below it,
--    and no frame on the other edges.
setArmed(true)
paintFrame()
r = redRects()
check("armed: the red bar is drawn across the top edge", r.bar)
check("armed: the Armed label is drawn", hasLabel())
check("armed: the label hangs from the centre of the bar", labelCentred())
check("armed: no frame edge or other red rectangle is drawn", not r.other)

-- 3. Disarmed again: the warning goes away.
setArmed(false)
paintFrame()
r = redRects()
check("disarmed again: the red bar is gone", not r.bar and not r.label)

-- 4. The property off: armed draws no warning at all.
state.armedWarningEnabled = true
descriptor.configure(state)
check("property: configure adds the Armed warning field", configField ~= nil)
configField.set(false)
check("property: the field reports off after switching it", configField.get() == false)
descriptor.write(state)
check("property: write stores off", stored.armed_warning == false)
state.armedWarningEnabled = nil
descriptor.read(state)
check("property: read restores off from storage", state.armedWarningEnabled == false)
setArmed(true)
paintFrame()
r = redRects()
check("property off, armed: no red bar is drawn", not r.bar and not r.label and not r.other)
check("property off, armed: no Armed label is drawn", not hasLabel())

-- 5. Switched back on: the warning returns.
configField.set(true)
descriptor.write(state)
check("property: write stores on", stored.armed_warning == true)
paintFrame()
r = redRects()
check("property on again, armed: the red bar is drawn", r.bar)

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
