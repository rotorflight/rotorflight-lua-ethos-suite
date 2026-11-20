-- Behaviour check for Setup > Governor > Bypass Curve (#2782): a point the pilot did not edit keeps
-- the value the flight controller stored.
--
-- Run it:
--     lua5.4 bin/governor_bypass_curve/verify_governor_bypass_curve.lua
--     lua5.4 bin/governor_bypass_curve/verify_governor_bypass_curve.lua --self-test
--
-- The FC stores each bypass point in half-percent steps (gov_bypass_throttle / 200 in
-- governorInit(); the Configurator writes x * 2). The page shows whole percent, read as
-- clampPercent(raw / 2), and wrote all nine points back as clampPercent(curve[i]) * 2 on every
-- save, so a stored 12.5 % (raw 25) became 13 % (raw 26) on a save that changed nothing, or
-- changed another point.
--
-- Drives the real app/pages/setup_governor_curves.lua with a stand-in page runtime that loads the
-- test's raw points, runs the page's onLoaded(), lets the test set fields the way the pilot does,
-- and runs beforeSave the way the runtime does. --self-test restores the write-back of every point
-- and requires the untouched-point checks to fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/setup_governor_curves.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print("  ok    " .. label)
  else
    failures = failures + 1
    print("  FAIL  " .. label)
    if detail then print("        " .. tostring(detail)) end
  end
end

-- Ethos stand-ins: only what the page touches
system = {getVersion = function() return {lcdWidth = 800, lcdHeight = 480} end}
lcd = {getWindowSize = function() return 800, 480 end, invalidate = function() end}

local numberFields = {}
form = {
  clear = function() end,
  invalidate = function() end,
  addNumberField = function(_, _, _, _, getter, setter)
    local field = {get = getter, set = setter}
    function field:suffix() end
    function field:default() end
    function field:enable() end
    numberFields[#numberFields + 1] = field
    return field
  end,
}

-- The runtime: data and the page's own callbacks
local config, runtime
local pageRuntime = {
  new = function(cfg)
    config = cfg
    runtime = {data = {}, controlRef = {}}
    runtime.controlRef.runtime = runtime
    function runtime:buildChrome() end
    function runtime:registerField() end
    function runtime:loadInitial() end
    function runtime:markDirty() self.dirty = true end
    return runtime
  end,
}

local cache = {["app/page_runtime.lua"] = pageRuntime}
package.loaded["rfsuite.lib.require"] = function(name)
  if cache[name] == nil then cache[name] = assert(loadfile(SRC .. "/" .. name))() end
  return cache[name]
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end

local function key(i) return "gov_bypass_throttle_curve_" .. i end

-- Opens the page on raw points (half-percent steps) and returns a copy of what was read
local function open(rawPoints, source)
  numberFields = {}
  local page = source and assert(load(source, "@" .. PAGE_PATH))() or dofile(PAGE_PATH)
  page.open({})
  for i = 1, 9 do runtime.data[key(i)] = rawPoints[i] end
  config.onLoaded()
  local read = {}
  for i = 1, 9 do read[i] = rawPoints[i] end
  return read
end

local function save()
  config.beforeSave(runtime)
end

local RAW = {0, 25, 51, 75, 101, 125, 151, 175, 200}   -- 0, 12.5, 25.5, ... 100 %

local function runChecks(source)
  local results = {}

  open(RAW, source)
  check("a half-percent point shows as whole percent", numberFields[2].get() == 13,
    "shown=" .. tostring(numberFields[2].get()))
  save()
  local same = true
  for i = 1, 9 do if runtime.data[key(i)] ~= RAW[i] then same = false end end
  results.untouched = same
  check("a save that changes nothing writes back every point as stored", same,
    "point 2 raw=" .. tostring(runtime.data[key(2)]))

  open(RAW, source)
  numberFields[5].set(60)
  save()
  results.other = runtime.data[key(2)] == 25 and runtime.data[key(3)] == 51
  check("editing another point leaves the half-percent points as stored", results.other,
    "point 2 raw=" .. tostring(runtime.data[key(2)]) .. ", point 3 raw=" .. tostring(runtime.data[key(3)]))
  check("the edited point is written in half-percent units", runtime.data[key(5)] == 120,
    "point 5 raw=" .. tostring(runtime.data[key(5)]))

  open(RAW, source)
  numberFields[2].set(20)
  save()
  check("an edited half-percent point takes the new value", runtime.data[key(2)] == 40,
    "point 2 raw=" .. tostring(runtime.data[key(2)]))

  open(RAW, source)
  numberFields[4].set(50)
  config.onLoaded()   -- a reload discards the edit
  save()
  check("a reload forgets the edits", runtime.data[key(4)] == 75, "point 4 raw=" .. tostring(runtime.data[key(4)]))

  return results
end

print("Bypass Curve")
runChecks(nil)

local selfTest = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then selfTest = true end end
if selfTest then
  print()
  print("--self-test: writing every point back must turn the untouched checks red")
  local source = readFile(PAGE_PATH)
  local spliced, n = source:gsub("if edited%[i%] then (rt%.data%[curveKey%(i%)%] = clampPercent%(curve%[i%]%) %* 2) end", "%1", 1)
  check("self-test: the write-back splice applies", n == 1)
  local before = failures
  local results = runChecks(spliced)
  failures = before
  check("self-test: an unchanged save goes red without the edit tracking", results.untouched == false)
  check("self-test: editing another point goes red without the edit tracking", results.other == false)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
