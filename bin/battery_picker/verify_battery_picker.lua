-- Behaviour check for the dashboard's Battery tile picker (#2357).
--
-- Run it:
--     lua5.4 bin/battery_picker/verify_battery_picker.lua
--     lua5.4 bin/battery_picker/verify_battery_picker.lua --self-test
--
-- What it drives, and why:
--   * The real widgets/dashboard/battery_picker.lua: geometry, hit-testing,
--     rotary wrap, name fitting and drawing. The stub lcd measures text at
--     7 px a character and records every string it draws, so the layout
--     numbers are exact and not a matter of taste.
--   * The real widgets/dashboard.lua, through the descriptor the radio calls
--     (create, wakeup, paint, event). The Battery tile is opened the way a
--     pilot opens it: Page long press, rotary to the tile, Enter. The pack is
--     then chosen by tap and by rotary plus Enter, and dismissed by Exit, by
--     Return, by a tap outside the grid and by choosing the pack already
--     active. Each write is answered by the FC's reply (processReply, then the
--     next wakeup), the way the MSP layer answers it, because the widget will
--     not start a second write while the first is in flight.
--   * The claim the change makes: the pack choice no longer opens an Ethos
--     dialog (its one-row button layout is what overflowed a 480x320 screen),
--     and a chosen pack reaches the bus as the msp.request the old dialog's
--     action sent. The one confirmation dialog that remains, for the pack that
--     is already active, is the existing showBatteryInfo() message and is not
--     counted.
--
-- Not established here: how the grid looks on a 480x320 radio. The stub lcd
-- does not rasterise. That is the Ethos simulator check named in the PR body.
--
-- --self-test replaces the column rule with one row of six, and requires the
-- three-across check to go red. A check that cannot fail proves nothing.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"
local SELF_TEST = arg and arg[1] == "--self-test"

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

-- Ethos constants the dashboard compares against. Distinct values, so that a
-- missing constant cannot make two different events compare equal.
FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L = 1, 2, 3, 4, 5
CENTERED, TEXT_LEFT = 16, 0
EVT_KEY, EVT_TOUCH = 10, 11
TOUCH_START, TOUCH_MOVE, TOUCH_END = 20, 21, 22
KEY_PAGE_LONG, KEY_ENTER_BREAK, KEY_EXIT_BREAK, KEY_RTN_BREAK, KEY_DOWN_BREAK = 30, 31, 32, 33, 34
ROTARY_LEFT, KEY_ROTARY_RIGHT = 40, 41

-- Every string the stub lcd is asked to draw in the current paint.
local drawn = {}

-- Every filled rectangle with the colour that was set for it, so the dim
-- behind the panel can be found and its alpha checked.
local rects, currentColor = {}, nil

lcd = setmetatable({
  RGB = function(_, _, _, alpha) return {alpha = alpha or 1} end,
  color = function(c) currentColor = c end,
  drawFilledRectangle = function(x, y, w, h)
    rects[#rects + 1] = {x = x, y = y, w = w, h = h, color = currentColor}
  end,
  drawText = function(_, _, text) drawn[#drawn + 1] = tostring(text) end,
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
}
model = {bitmap = function() return nil end}

-- The title of the pack-choice dialog this change removes. Any form.openDialog
-- with this title is counted; the other confirmation dialogs are not.
local CHOICE_TITLE = "@i18n(widgets.battery.select_title)@"
local choiceDialogs = 0
form = setmetatable({
  openDialog = function(opts)
    if type(opts) == "table" and opts.title == CHOICE_TITLE then
      choiceDialogs = choiceDialogs + 1
    end
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
-- Part A: geometry of the picker module
-- ---------------------------------------------------------------------------

local picker = requireModule("widgets/dashboard/battery_picker.lua")

local function profileItems(n)
  local out = {}
  for i = 1, n do out[i] = {number = i, name = (1000 * i) .. "mAh"} end
  return out
end

local function insideScreen(layout)
  for i, c in ipairs(layout.cells) do
    if c.x < 0 or c.y < 0 or c.x + c.w > layout.w or c.y + c.h > layout.h then
      return false, "cell " .. i .. " lies outside " .. layout.w .. "x" .. layout.h
    end
  end
  return true
end

local function noOverlap(layout)
  local cells = layout.cells
  for i = 1, #cells do
    for j = i + 1, #cells do
      local a, b = cells[i], cells[j]
      if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then
        return false, "cells " .. i .. " and " .. j .. " overlap"
      end
    end
  end
  return true
end

-- The column rule the issue asks for: three across on a screen 400 px wide or
-- more.
local function threeAcrossCheck()
  local layout = picker.layout(480, 320, profileItems(6))
  return check("six profiles on 480x320 sit three to a row (two rows)",
    layout.cols == 3 and layout.rows == 2,
    "cols=" .. tostring(layout.cols) .. " rows=" .. tostring(layout.rows))
end

if SELF_TEST then
  -- The rule under test is replaced by the old one-row layout. The check above
  -- must go red, or it cannot tell the grid from the row.
  picker.columnsFor = function(_) return 6 end
  local redOnRow = not threeAcrossCheck()
  print(string.format("\nself-test: one row of six %s the three-across check",
    redOnRow and "is caught by" or "is NOT caught by"))
  print(string.format("%d checks, %d failed", checks, failures))
  os.exit(redOnRow and 0 or 1)
end

print("Geometry: widgets/dashboard/battery_picker.lua")

threeAcrossCheck()

do
  local layout = picker.layout(480, 320, profileItems(4))
  check("four profiles on 480x320 sit three across, then one row of one",
    layout.cols == 3 and layout.rows == 2, "cols=" .. layout.cols .. " rows=" .. layout.rows)
  layout = picker.layout(480, 320, profileItems(2))
  check("two profiles on 480x320 fill the width, one row",
    layout.cols == 2 and layout.rows == 1, "cols=" .. layout.cols .. " rows=" .. layout.rows)
end

for _, size in ipairs({{480, 320}, {800, 480}, {320, 240}}) do
  local w, h = size[1], size[2]
  local layout = picker.layout(w, h, profileItems(6))
  check(string.format("six profiles on %dx%d: every cell at least %d px in both directions",
      w, h, picker.MIN_TARGET),
    layout.minTarget >= picker.MIN_TARGET,
    "smallest cell " .. layout.minTarget .. " px")
  local inside, why = insideScreen(layout)
  check(string.format("six profiles on %dx%d: every cell lies on the screen", w, h),
    inside, why)
  local apart, where = noOverlap(layout)
  check(string.format("six profiles on %dx%d: no two cells overlap", w, h),
    apart, where)
end

do
  local layout = picker.layout(480, 320, profileItems(6))
  local hits, misses = true, {}
  for i, c in ipairs(layout.cells) do
    local got = picker.hit(layout, c.x + c.w / 2, c.y + c.h / 2)
    if got ~= i then
      hits = false
      misses[#misses + 1] = i .. "->" .. tostring(got)
    end
  end
  check("a tap in the middle of each cell hits that cell", hits, table.concat(misses, ", "))

  local title = picker.hit(layout, 240, 4)
  check("a tap on the title is not a cell", title == nil, "hit " .. tostring(title))
  local outside = picker.hit(layout, -5, -5)
  check("a tap outside the screen is not a cell", outside == nil, "hit " .. tostring(outside))
  local a, b = layout.cells[1], layout.cells[2]
  local gapX = a.x + a.w + (b.x - (a.x + a.w)) / 2
  check("a tap in the gap between two cells is not a cell",
    picker.hit(layout, gapX, a.y + a.h / 2) == nil)
end

do
  local count = 6
  check("rotary step wraps forward past the last profile",
    picker.step(6, 1, count) == 1, tostring(picker.step(6, 1, count)))
  check("rotary step wraps backward past the first profile",
    picker.step(1, -1, count) == 6, tostring(picker.step(1, -1, count)))
  check("rotary step moves one profile within the list",
    picker.step(3, 1, count) == 4)
end

do
  -- Six profiles, so the cells are the narrow three-across ones the name has
  -- to fit in; the first name is far wider than its cell.
  local items = profileItems(6)
  items[1].name = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local layout = picker.layout(480, 320, items)
  local label = layout.labels[1]
  local cellInner = layout.cells[1].w - 12
  local width = #label.name * 7
  check("a long profile name is cut with '..' to fit its cell",
    label.name:sub(-2) == ".." and width <= cellInner,
    "name '" .. label.name .. "' is " .. width .. " px, cell allows " .. cellInner)
  check("a profile name that fits is left whole",
    layout.labels[2].name == "2000mAh", "got '" .. layout.labels[2].name .. "'")
end

-- ---------------------------------------------------------------------------
-- Part B: the real dashboard widget, driven the way the radio drives it
-- ---------------------------------------------------------------------------

print("Widget: widgets/dashboard.lua, Battery tile")

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
local primed, primeErr = pcall(descriptor.wakeup, state)
check("one wakeup primes the widget, not yet connected", primed, primeErr)
check("nothing is shown before the FC connects", state.batteryPicker == nil)

-- Connecting: the FC's battery profiles arrive. The next wakeup is what prompts
-- the chooser, once per connection (widgets/dashboard.lua, wakeup()).
state.connected = true
state.apiVersionSupported = true
state.batteryConfig = {profiles = {
  [0] = {capacity = 3300}, [1] = {capacity = 4000}, [2] = {capacity = 5000},
  [3] = {capacity = 2200}, [4] = {capacity = 1500}, [5] = {capacity = 6000},
}}
state.batteryProfile = 3 -- 0-based: the pack the FC reports as active is index 3
descriptor.wakeup(state)

local function key(value) descriptor.event(state, EVT_KEY, value) end
local function touch(value, x, y) return descriptor.event(state, EVT_TOUCH, value, x, y) end

-- Page long press shows the toolbar with tile 1 selected; two rotary steps
-- reach tile 3, the Battery tile.
local function openPickerFromToolbar()
  key(KEY_PAGE_LONG)
  key(KEY_ROTARY_RIGHT)
  key(KEY_ROTARY_RIGHT)
  key(KEY_ENTER_BREAK)
end

-- The FC's reply to the last write: processReply is what the MSP layer calls
-- (lib/msp_battery_profile.lua buildWriteMessage), and the next wakeup finishes
-- the write, which releases the in-flight guard in writeBatteryProfile().
local function completeLastWrite()
  local message = requests[#requests]
  if message and message.processReply then message.processReply() end
  descriptor.wakeup(state)
end

local function cellCentre(index)
  local items = state.batteryPicker.items
  local layout = picker.layout(480, picker.panelHeight(480, 320, #items), items)
  local c = layout.cells[index]
  return c.x + c.w / 2, c.y + c.h / 2
end

check("connecting with several packs opens the picker by itself", state.batteryPicker ~= nil)
check("the pack choice is not an Ethos dialog", choiceDialogs == 0,
  choiceDialogs .. " choice dialog(s)")
check("the picker lists all six profiles", state.batteryPicker and #state.batteryPicker.items == 6)
check("the picker starts on the pack the FC reports as active",
  state.batteryPicker and state.batteryPicker.selected == 4,
  "selected " .. tostring(state.batteryPicker and state.batteryPicker.selected))

key(KEY_EXIT_BREAK)
check("Exit closes the prompt that connecting opened", state.batteryPicker == nil)
descriptor.wakeup(state)
check("the prompt is not opened again within the same connection", state.batteryPicker == nil)

openPickerFromToolbar()
check("choosing the Battery tile opens the picker", state.batteryPicker ~= nil)
check("choosing the Battery tile hides the toolbar", state.toolbarVisible ~= true)

-- The radio paints on successive ticks. The dashboard's own paint reports "not
-- ready" until its boxes have been woken, and the picker is drawn only once
-- that paint has completed -- the same gate the toolbar and the info panel
-- use. So tick the widget until it paints, and bound the wait.
local painted, paintErr = true, nil
for _ = 1, 20 do
  drawn = {}
  painted, paintErr = pcall(descriptor.paint, state)
  if not painted or #drawn > 0 then break end
  descriptor.wakeup(state)
end
check("painting the open picker runs without error", painted, paintErr)
check("the picker is drawn once the dashboard has painted", #drawn > 0,
  "no text drawn in 20 ticks")
local seen = {}
for _, text in ipairs(drawn) do seen[text] = true end
local allNumbers = true
for n = 1, 6 do
  if not seen[tostring(n)] then allNumbers = false end
end
check("the paint draws the pack numbers 1 to 6", allNumbers)
check("the paint draws the profile names", seen["1500mAh"] == true and seen["2200mAh"] == true)

-- A touch on the picker is held by the picker: TOUCH_START neither closes it
-- nor reaches the toolbar, and TOUCH_END on cell 5 chooses that pack.
local x5, y5 = cellCentre(5)
check("a touch start on the picker is taken by the picker",
  touch(TOUCH_START, x5, y5) == true and state.batteryPicker ~= nil)
touch(TOUCH_END, x5, y5)
check("a tap on cell 5 closes the picker", state.batteryPicker == nil)
check("a tap on cell 5 publishes one pack write", #requests == 1, "requests=" .. #requests)
check("the write is for cell 5's pack (0-based index 4)",
  requests[1] and requests[1].sessionBatteryProfile == 4,
  "sessionBatteryProfile=" .. tostring(requests[1] and requests[1].sessionBatteryProfile))
completeLastWrite()

-- The FC now reports pack index 4 as active, so the picker opens on cell 5.
-- Rotary moves to cell 6, and Enter writes that pack.
openPickerFromToolbar()
check("the picker opens on the pack that became active",
  state.batteryPicker.selected == 5, "selected " .. tostring(state.batteryPicker.selected))
key(KEY_ROTARY_RIGHT)
check("rotary moves the selection to cell 6", state.batteryPicker.selected == 6)
key(KEY_ENTER_BREAK)
check("Enter writes the pack under the cursor and closes the picker",
  state.batteryPicker == nil and #requests == 2 and requests[2].sessionBatteryProfile == 5,
  "requests=" .. #requests)
completeLastWrite()

-- The active pack is now index 5, cell 6. Rotary wraps at both ends.
openPickerFromToolbar()
check("the picker opens on cell 6", state.batteryPicker.selected == 6)
key(KEY_ROTARY_RIGHT)
check("rotary past the last profile wraps to the first", state.batteryPicker.selected == 1,
  "selected " .. tostring(state.batteryPicker.selected))
key(ROTARY_LEFT)
check("rotary back from the first profile wraps to the last", state.batteryPicker.selected == 6)

-- Exit closes the picker without a write.
key(KEY_EXIT_BREAK)
check("Exit closes the picker without a write",
  state.batteryPicker == nil and #requests == 2)

-- Return does the same.
openPickerFromToolbar()
key(KEY_RTN_BREAK)
check("Return closes the picker without a write",
  state.batteryPicker == nil and #requests == 2)

-- A tap on the title, outside the grid, closes it.
openPickerFromToolbar()
touch(TOUCH_END, 240, 4)
check("a tap outside the grid closes the picker without a write",
  state.batteryPicker == nil and #requests == 2)

-- Choosing the pack that is already active publishes no write, as the old
-- dialog did.
openPickerFromToolbar()
local activeX, activeY = cellCentre(6)
touch(TOUCH_END, activeX, activeY)
check("choosing the active pack publishes no write",
  #requests == 2 and state.batteryPicker == nil, "requests=" .. #requests)

-- While the picker is open, Page long press is held by the picker and does not
-- raise the toolbar under it.
openPickerFromToolbar()
key(KEY_PAGE_LONG)
check("Page long press while the picker is open does not raise the toolbar",
  state.batteryPicker ~= nil and state.toolbarVisible ~= true)
key(KEY_EXIT_BREAK)

check("the pack choice was never shown as an Ethos dialog", choiceDialogs == 0,
  choiceDialogs .. " choice dialog(s)")

-- The footer banner must not paint over the picker (CodeRabbit on #2519).
-- paint() draws the footer after the picker unless the picker returns first.
-- Force the banner's own condition -- no background task status, grace
-- expired -- and check the banner text: drawn with the picker closed (so the
-- check can see it), absent with the picker open.
local BANNER = "@i18n(app.msg_background_task_missing_title)@"
state.createdAt = os.clock() - 60
state.taskStatusAt = nil

local function paintUntilDrawn()
  local ok, err = true, nil
  for _ = 1, 20 do
    drawn = {}
    ok, err = pcall(descriptor.paint, state)
    if not ok or #drawn > 0 then break end
    descriptor.wakeup(state)
  end
  return ok, err
end

local function bannerDrawn()
  for _, text in ipairs(drawn) do
    if text == BANNER then return true end
  end
  return false
end

local footerPainted, footerErr = paintUntilDrawn()
check("the footer check paints the dashboard", footerPainted, footerErr)
check("the footer banner is drawn with the picker closed (the check can see it)",
  bannerDrawn(), "banner text not drawn")

openPickerFromToolbar()
check("the picker is open for the footer check", state.batteryPicker ~= nil)
local pickerPainted, pickerErr = paintUntilDrawn()
check("painting the picker over the footer condition runs without error", pickerPainted, pickerErr)
check("the footer banner does not paint over the open picker", not bannerDrawn(),
  "banner drawn while the picker is open")
key(KEY_EXIT_BREAK)

-- Disconnecting the flight controller closes the open picker so touches and
-- keys are no longer trapped in a modal picker while offline.
openPickerFromToolbar()
check("the picker is open before disconnect", state.batteryPicker ~= nil)
bus.publish("session.update", {connected = false})
check("disconnecting the FC closes the open picker", state.batteryPicker == nil)

-- Reconnecting and opening the picker again, then closing the widget resets
-- the picker cleanly.
bus.publish("session.update", {
  connected = true,
  apiVersionSupported = true,
  batteryConfig = {profiles = {
    [0] = {capacity = 3300}, [1] = {capacity = 4000}, [2] = {capacity = 5000},
    [3] = {capacity = 2200}, [4] = {capacity = 1500}, [5] = {capacity = 6000},
  }},
  batteryProfile = 3,
})
-- The picker is a panel from the top, like the info panel, with the dashboard
-- dimmed behind it. A swipe up closes it, and a tap below the panel closes it.
openPickerFromToolbar()
check("the picker is open for the panel checks", state.batteryPicker ~= nil)
local panelH = picker.panelHeight(480, 320, #state.batteryPicker.items)
check("the panel is shorter than the screen and at most 85% of it (six packs on 480x320)",
  panelH < 320 and panelH <= math.floor(320 * 0.85), "panel " .. panelH)
local panelLayout = picker.layout(480, panelH, state.batteryPicker.items)
check("the panel's pack cells are at least 44 px in both directions",
  panelLayout.minTarget >= picker.MIN_TARGET, "smallest cell " .. panelLayout.minTarget)

rects = {}
paintUntilDrawn()
local dimmed = false
for _, r in ipairs(rects) do
  if r.x == 0 and r.y == 0 and r.w == 480 and r.h == 320
      and r.color and r.color.alpha == picker.DIM_ALPHA then
    dimmed = true
  end
end
check("the whole dashboard is dimmed behind the panel", dimmed, "no full-screen dim rectangle")

local requestsBeforeSwipe = #requests
touch(TOUCH_START, 240, 200)
touch(TOUCH_MOVE, 240, 150)
check("a swipe up closes the picker", state.batteryPicker == nil)
touch(TOUCH_MOVE, 240, 60)
touch(TOUCH_END, 240, 60)
check("the rest of the swipe does not reopen the toolbar", state.toolbarVisible ~= true)
check("the swipe writes no pack", #requests == requestsBeforeSwipe)

openPickerFromToolbar()
touch(TOUCH_END, 240, 300)
check("a tap below the panel closes it without a write",
  state.batteryPicker == nil and #requests == requestsBeforeSwipe)

-- Every overlay dims the dashboard behind it: the toolbar and the info panel
-- too, not only the battery picker (the agreed rule, #2357).
local function fullScreenDimPainted()
  rects = {}
  paintUntilDrawn()
  for _, r in ipairs(rects) do
    if r.x == 0 and r.y == 0 and r.w == 480 and r.h == 320
        and r.color and r.color.alpha == picker.DIM_ALPHA then
      return true
    end
  end
  return false
end

key(KEY_EXIT_BREAK)
check("the picker is closed for the overlay checks", state.batteryPicker == nil)
key(KEY_PAGE_LONG)
check("the toolbar is open for the overlay checks", state.toolbarVisible == true)
check("the toolbar dims the dashboard behind it", fullScreenDimPainted())
key(KEY_ROTARY_RIGHT)
key(KEY_ROTARY_RIGHT)
key(KEY_ROTARY_RIGHT)
key(KEY_ENTER_BREAK)
check("choosing Info opens the info panel", state.infoPanelVisible == true)
check("the info panel dims the dashboard behind it", fullScreenDimPainted())
key(KEY_EXIT_BREAK)
check("Exit closes the info panel", state.infoPanelVisible ~= true)

openPickerFromToolbar()
check("the picker is open before widget close", state.batteryPicker ~= nil)
descriptor.close(state)
check("closing the widget resets the picker", state.batteryPicker == nil)

-- The panel is capped at 85% of the screen; at 320x240 the cap leaves the
-- grid short, so the cells must still reach the touch minimum.
do
  local items6 = profileItems(6)
  local panel320 = picker.panelHeight(320, 240, 6)
  local grid320 = picker.layout(320, panel320, items6)
  check("six profiles at 320x240 in the capped panel: every cell at least 44 px",
    grid320.minTarget >= picker.MIN_TARGET, "smallest cell " .. grid320.minTarget)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
