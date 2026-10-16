-- Behaviour check for #2507: a board without dataflash reports total = 0. The
-- BLACKBOX text object must say the board has no dataflash, not draw 0.00/0.00 MB.
--
-- Run it:
--     lua5.4 bin/blackbox_text/verify_blackbox_text.lua
--     lua5.4 bin/blackbox_text/verify_blackbox_text.lua --self-test
--
-- What it drives: the real src/rfsuite/widgets/dashboard/objects/text/blackbox.lua,
-- render.wakeup(), with the session fields set the way tasks/session.lua sets them.
-- The layout and paint functions are stubs; the value the widget decided to show
-- is read back from box._currentDisplayValue.
--
-- The no-dataflash text is the existing key app.modules.blackbox.not_supported. The
-- gate is the displayed value, not the key: the packager resolves the tag, so the
-- check looks for the tag the widget emits.
--
-- Against unpatched master the total = 0 case shows "0.00/0.00 MB" and goes red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local WIDGET = ROOT .. "/src/rfsuite/widgets/dashboard/objects/text/blackbox.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local NOT_SUPPORTED = "@i18n(app.modules.blackbox.not_supported)@"
local MIB = 1024 * 1024

-- ---------------------------------------------------------------------------
-- Stubs for the dashboard context the widget requires.
-- ---------------------------------------------------------------------------

local ctx = { session = {}, widgets = { dashboard = {} } }

local utils = {
  getParam = function() return nil end,
  resolveThemeColor = function() return nil end,
  prepareTextLayout = function() end,
  paintTextLayout = function() end,
  applyOffset = function(x, y) return x, y end,
  boxContentRect = function(x, y, w, h) return x, y, w, h end,
  resolveThresholdColor = function() return nil end,
  drawBoxBackground = function(x, y, w, h) return x, y, w, h end,
  ensureCfg = function(box, fill)
    box._cfg = box._cfg or {}
    fill(box._cfg, box)
    return box._cfg
  end,
  transformValue = function(v) return v end,
}
ctx.widgets.dashboard.utils = utils

package.loaded["rfsuite.lib.require"] = function(name)
  if name == "widgets/dashboard/context.lua" then return ctx end
  return setmetatable({}, { __index = function() return function() return {} end end })
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local function loadWidget(source)
  if source then return assert(load(source, "@blackbox_text_under_test"))() end
  return dofile(WIDGET)
end

-- Wakes the widget once with the given summary and returns what it would show.
local function wake(render, box, total, used)
  ctx.session.bblSize = total
  ctx.session.bblUsed = used
  render.wakeup(box)
  return box._currentDisplayValue
end

local function runChecks(render)
  -- A1: the board has no dataflash.
  do
    local shown = wake(render, {}, 0, 0)
    check("A1 total = 0 shows the no-dataflash text", shown == NOT_SUPPORTED,
      "shows: " .. tostring(shown))
    check("A2 total = 0 does not draw a used/total capacity",
      type(shown) == "string" and not shown:find("/", 1, true),
      "shows: " .. tostring(shown))
  end

  -- A3: before the first summary the loading dots stay (not the no-dataflash text).
  do
    local shown = wake(render, {}, nil, nil)
    check("A3 no summary yet shows the loading dots",
      type(shown) == "string" and shown:match("^%.+$") ~= nil, "shows: " .. tostring(shown))
  end

  -- A4 control: a board with a flash still shows its used/total capacity.
  do
    local shown = wake(render, {}, 2048 * MIB, 1024 * MIB)
    check("A4 control: a board with dataflash shows used/total",
      type(shown) == "string" and shown:find("1024.0/2048.0", 1, true) ~= nil,
      "shows: " .. tostring(shown))
  end

  -- A5: the same box goes from no-dataflash back to a capacity without sticking.
  do
    local box = {}
    wake(render, box, 0, 0)
    local shown = wake(render, box, 2048 * MIB, 512 * MIB)
    check("A5 a box that showed no-dataflash shows the capacity again",
      type(shown) == "string" and shown:find("512.0/2048.0", 1, true) ~= nil,
      "shows: " .. tostring(shown))
  end
end

-- ---------------------------------------------------------------------------
-- Run.
-- ---------------------------------------------------------------------------

local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

print("widget: src/rfsuite/widgets/dashboard/objects/text/blackbox.lua")
runChecks(loadWidget(nil))

if selfTest then
  print("")
  print("--self-test: the gate must go red without the no-dataflash branch")
  local source = readFile(WIDGET)
  local spliced, n = source:gsub("if totalSize == 0 then", "if false then", 1)
  assert(n == 1, "splice did not apply")
  local before = failures
  runChecks(loadWidget(spliced))
  local red = failures > before
  failures = before
  check("the no-dataflash checks go red without the branch", red)
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
