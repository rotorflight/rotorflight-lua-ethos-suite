-- Behaviour check for the dashboard's image/bitmap caches.
--
-- Run it:
--
--     lua5.3 bin/dashboard/verify_image_caches.lua
--     (or from src/rfsuite: lua5.3 ../../bin/dashboard/verify_image_caches.lua)
--
-- What it drives, and why:
--   * The claim is about *retention*, not about a return value. A decoded
--     bitmap is a userdata handle plus its own pixel buffer, so the only
--     honest way to ask "is it still held?" is to ask the collector. Every
--     stub bitmap below is handed to exactly one strong reference outside
--     this file (a weak table), so `collectgarbage("collect")` followed by a
--     count of the survivors *is* the measurement. Nothing here inspects a
--     private upvalue.
--   * The cases go after the shape of the fix, not just its absence:
--     (1) a cached bitmap is genuinely retained, so a later "0 survivors"
--     cannot be an artefact of a stub that was never cached at all;
--     (2) the decoded-bitmap map has a ceiling, because its key space is
--     open-ended -- every distinct model photo, dial panel and per-box
--     `image` parameter mints a new key;
--     (3) that ceiling evicts least-recently-*used*, not least-recently
--     *inserted*, since every caller of loadImage() runs on a repaint;
--     (4)/(5) the `images` and `theme` flags stay distinct, so the gating is
--     still a gate and not an unconditional clear;
--     (6) session.dialImageCache -- the table objects/dial/image.lua actually
--     writes its panels into -- is one of the tables the images branch owns;
--     (7) the registry added for object modules that memoise their own
--     bitmaps runs, and one raising clearer does not stop the next;
--     (8) objects/image/model.lua's own _imgCache is inside the images
--     branch, proved through its *negative* memo: with the photo absent it
--     stores `false` for the craft name, so if the memo survives a clear the
--     module never re-probes the filesystem and a photo that has since
--     appeared stays invisible;
--     (9) the caller the issue is actually about -- a theme reload. This one
--     drives the real dashboard widget over its real bus event, so it is the
--     case that goes red on the pre-fix tree, where clearThemeCache() passed
--     {theme = true} and the images branch had no caller anywhere.
--
-- Not established here, and deliberately so: how many kilobytes any of this
-- is worth on a radio. That needs a `live` vs `churn` split around
-- collectgarbage("count") per #2364; see docs/memory-and-module-lifecycle.md
-- section 7. What these cases establish is the reachability: the bitmaps
-- were reachable from a live reference, and after the fix they are not.

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

local failures = 0
local checks = 0

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

-- ---------------------------------------------------------------------------
-- Harness
-- ---------------------------------------------------------------------------

-- rfsuite.lib.require is loadfile() against Ethos' path prefixes on a radio.
-- Here it resolves relative to the suite directory when run from repository root.
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

-- Which paths the stub filesystem claims to have. Kept explicit so a case can
-- make a file appear between two resolutions -- that is the only way to tell
-- a cleared negative memo from a retained one (case 8).
local existingFiles = {}

-- Every bitmap the stub lcd has handed out, keyed by resolved path. `issued`
-- and `outstanding` are both weak and neither is ever read for the purpose of
-- keeping a bitmap alive: the stub mints a *fresh* handle on every decode, so
-- "the handle I got back is the same object" means "served from cache" and
-- anything else means "re-decoded". Holding a handle in a local is how a case
-- keeps one specific bitmap alive on purpose, and `outstanding` then reports
-- it as retained even after the suite has let go -- which is the honest
-- outcome for a reference the test itself owns.
local issued = setmetatable({}, {__mode = "v"})
local outstanding = setmetatable({}, {__mode = "v"})
local loadBitmapCalls = 0

lcd = setmetatable({
  RGB = function() return 0 end,
  getWindowSize = function() return 800, 480 end,
  isVisible = function() return true end,
  font = function() end,
  getTextSize = function() return 0, 0 end,
  loadBitmap = function(path)
    loadBitmapCalls = loadBitmapCalls + 1
    local bitmap = {path = path}
    issued[path] = bitmap
    outstanding[path] = bitmap
    return bitmap
  end,
}, {__index = function() return function() end end})

os.stat = function(path)
  if existingFiles[path] then return {size = existingFiles[path]} end
  return nil
end

system = {registerWidget = function(w) _G.__widget = w end}
model = {bitmap = function() return nil end}
form = setmetatable({}, {__index = function() return function() end end})

local function retainedBitmaps()
  collectgarbage("collect")
  collectgarbage("collect")
  local n = 0
  for _ in pairs(outstanding) do n = n + 1 end
  return n
end

local function resetStubFilesystem()
  for key in pairs(existingFiles) do existingFiles[key] = nil end
  for key in pairs(issued) do issued[key] = nil end
  for key in pairs(outstanding) do outstanding[key] = nil end
  loadBitmapCalls = 0
end

local context = requireModule("widgets/dashboard/context.lua")
local dashboardUtils = context.widgets.dashboard.utils
local clearCaches = context.widgets.dashboard.clearCaches

-- Every path used by the cases lives under a `BITMAPS:` prefix so
-- imageCandidates()'s probing stays a single candidate plus its .bmp sibling:
-- a case that means "this file exists" says so and nothing else is consulted.
local function photoPath(name) return "BITMAPS:/models/" .. name .. ".png" end

local function loadDistinct(count, prefix)
  for i = 1, count do
    local path = photoPath((prefix or "img") .. i)
    existingFiles[path] = 64
    dashboardUtils.loadImage(path)
  end
end

-- ---------------------------------------------------------------------------
-- Case 1 -- a cached bitmap is actually retained
-- ---------------------------------------------------------------------------

resetStubFilesystem()
clearCaches({renders = true, theme = true, images = true, liveSources = true})
loadDistinct(5)
check("case 1: 5 loaded bitmaps, 5 still retained after a full collect",
  retainedBitmaps() == 5, "retained=" .. retainedBitmaps())

-- ---------------------------------------------------------------------------
-- Case 2 -- the decoded-bitmap map is bounded
-- ---------------------------------------------------------------------------

resetStubFilesystem()
clearCaches({images = true})
loadDistinct(40)
local after40 = retainedBitmaps()
check("case 2: 40 distinct paths retained no more than the 32-entry ceiling",
  after40 <= 32, "retained=" .. after40)
check("case 2: the ceiling is a real bound, not an accidental clear-all",
  after40 > 0, "retained=" .. after40)

resetStubFilesystem()
clearCaches({images = true})
for i = 1, 40 do
  local path = photoPath("rect" .. i)
  existingFiles[path] = 64
  dashboardUtils.drawImageInRect(0, 0, 100, 100, path)
end
local afterDraw40 = retainedBitmaps()
check("case 2: 40 distinct drawImageInRect paths retained no more than the 32-entry ceiling",
  afterDraw40 <= 32, "retained=" .. afterDraw40)

-- ---------------------------------------------------------------------------
-- Case 3 -- eviction is least-recently-used, not least-recently-inserted
-- ---------------------------------------------------------------------------

resetStubFilesystem()
clearCaches({images = true})
loadDistinct(32, "lru")
local firstIssued = issued[photoPath("lru1")]
local secondIssued = issued[photoPath("lru2")]

-- One more loadImage() on the oldest entry: a cache hit, so it must be
-- re-stamped as most recently used without being decoded again.
local callsBeforeTouch = loadBitmapCalls
local touched = dashboardUtils.loadImage(photoPath("lru1"))
check("case 3: re-requesting the oldest path is served from cache (no re-decode)",
  touched == firstIssued and loadBitmapCalls == callsBeforeTouch,
  "same handle=" .. tostring(touched == firstIssued)
    .. ", loadBitmap calls=" .. tostring(loadBitmapCalls - callsBeforeTouch))

-- One path over the ceiling now.
local overflow = photoPath("lru-overflow")
existingFiles[overflow] = 64
dashboardUtils.loadImage(overflow)

local firstAgain = dashboardUtils.loadImage(photoPath("lru1"))
local secondAgain = dashboardUtils.loadImage(photoPath("lru2"))
check("case 3: the re-stamped entry survives the eviction",
  firstAgain == firstIssued,
  "expected the original handle, got a re-decode: " .. tostring(firstAgain ~= firstIssued))
check("case 3: the true oldest entry is the one evicted",
  secondAgain ~= secondIssued,
  "the least-recently-*used* entry was kept and a more recent one dropped")

-- ---------------------------------------------------------------------------
-- Case 4 / 5 -- the images and theme flags stay distinct
-- ---------------------------------------------------------------------------

resetStubFilesystem()
clearCaches({images = true})
loadDistinct(4)
clearCaches({images = true})
check("case 4: clearCaches({images = true}) releases every decoded bitmap",
  retainedBitmaps() == 0, "retained=" .. retainedBitmaps())

resetStubFilesystem()
clearCaches({images = true})
loadDistinct(4)
clearCaches({theme = true})
check("case 5: clearCaches({theme = true}) alone still leaves the bitmaps alone",
  retainedBitmaps() == 4, "retained=" .. retainedBitmaps())

-- ---------------------------------------------------------------------------
-- Case 6 -- session.dialImageCache belongs to the images branch
-- ---------------------------------------------------------------------------

-- objects/dial/image.lua holds this table under `rfsuite.session`, and
-- `rfsuite` there is this very module (its own header does
-- `local rfsuite = requireModule("widgets/dashboard/context.lua")`).
context.session.dialImageCache = {panel1 = {}}
clearCaches({theme = true})
check("case 6: a theme-only clear does not touch session.dialImageCache",
  context.session.dialImageCache.panel1 ~= nil)
clearCaches({images = true})
check("case 6: the images branch empties session.dialImageCache",
  context.session.dialImageCache.panel1 == nil)

-- ---------------------------------------------------------------------------
-- Case 7 -- the clearer registry runs, and isolates a failing clearer
-- ---------------------------------------------------------------------------

local ranFirst, ranSecond = false, false
local boomCount = 0

-- Guarded so the script still reaches the end-to-end case below on a tree
-- that has no registry at all: cases 7 and 8 are about an API this change
-- introduces, and a check that aborts the run on the way there would hide
-- whether the *caller* case goes red, which is the one the issue is about.
if type(dashboardUtils.registerImageCacheClearer) ~= "function" then
  check("case 7: widgets/dashboard/context.lua offers a clearer registry", false,
    "utils.registerImageCacheClearer is missing")
else
  dashboardUtils.registerImageCacheClearer(function() ranFirst = true end)
  dashboardUtils.registerImageCacheClearer(function()
    -- Raises once, then stays quiet: the registry has to isolate a bad
    -- clearer from the ones after it, and the cases below need every later
    -- clear to be silent so their own output stays readable.
    boomCount = boomCount + 1
    if boomCount == 1 then error("clearer blew up") end
  end)
  dashboardUtils.registerImageCacheClearer(function() ranSecond = true end)
  clearCaches({theme = true})
  check("case 7: a registered clearer is not run by a non-images clear",
    not ranFirst and not ranSecond)
  clearCaches({images = true})
  check("case 7: the images branch runs every registered clearer",
    ranFirst and ranSecond,
    "first=" .. tostring(ranFirst) .. " second=" .. tostring(ranSecond))
end

-- ---------------------------------------------------------------------------
-- Case 8 -- objects/image/model.lua's own memo is inside the images branch
-- ---------------------------------------------------------------------------

-- Proved through the negative memo rather than through a handle identity,
-- because the context-side cache is cleared by the same call and would mask
-- the result: model.lua stores `false` for a craft whose photo does not
-- exist, so a surviving memo means the module never re-probes and a photo
-- that has since appeared on the card stays invisible.
local modelImage = assert(loadfile(resolvePath("widgets/dashboard/objects/image/model.lua")))()

resetStubFilesystem()
clearCaches({images = true})
context.session.craftName = "Later"
local box = {}
modelImage.wakeup(box) -- photo absent -> memoises `false` for "Later"

local callsBeforeAppear = loadBitmapCalls
local appeared = photoPath("Later")
existingFiles[appeared] = 64
clearCaches({images = true})
box._cfg = nil
modelImage.wakeup(box)

check("case 8: the memoised miss is re-probed after the images branch ran",
  loadBitmapCalls > callsBeforeAppear,
  "no re-probe: objects/image/model.lua kept its _imgCache entry")
check("case 8: the photo that appeared is the one now resolved",
  box._currentDisplayValue == issued[appeared],
  "resolved " .. tostring(box._currentDisplayValue and box._currentDisplayValue.path)
    .. " instead of " .. appeared)

-- The same resolution with the memo deliberately retained, to show the check
-- above can go red: the negative entry is only re-probed because the branch
-- reached the module's own cache.
context.session.craftName = "NeverCleared"
local neverClearedBox = {}
existingFiles = {[photoPath("NeverCleared")] = nil}
clearCaches({images = true})
modelImage.wakeup(neverClearedBox) -- memoises `false` again
existingFiles[photoPath("NeverCleared")] = 64
neverClearedBox._cfg = nil
local callsBeforeStale = loadBitmapCalls
modelImage.wakeup(neverClearedBox)
check("case 8: a retained memo does block re-probing (the check can go red)",
  loadBitmapCalls == callsBeforeStale,
  "the memo was re-probed anyway, so case 8's first check proves nothing")

-- ---------------------------------------------------------------------------
-- Case 9 -- a theme reload actually reaches the images branch
-- ---------------------------------------------------------------------------

-- The end-to-end case, and the one the issue is about. It drives the real
-- widget through its real bus event rather than calling clearCaches() with
-- the flags this change happens to pass -- otherwise the case would only
-- prove that the flags work, not that anything asks for them.
local dashboard = requireModule("widgets/dashboard.lua")
local bus = requireModule("lib/bus.lua")
dashboard.init({})
local descriptor = _G.__widget

check("case 9: the dashboard widget registered itself",
  descriptor ~= nil and descriptor.name ~= nil)
if descriptor == nil then
  print(string.format("\n%d checks, %d failed", checks, failures))
  os.exit(1)
end

-- create() hands back the mutable state table the widget's own callbacks are
-- driven with; the callbacks themselves live on the descriptor, not on it.
local state = descriptor.create()

-- One wakeup is what primes the widget's dashboard context; without it every
-- later cache trim is a silent no-op and the case would pass for the wrong
-- reason.
local primed, primeErr = pcall(descriptor.wakeup, state)
check("case 9: one wakeup primes the dashboard context", primed, primeErr)

resetStubFilesystem()
clearCaches({images = true})
loadDistinct(4)
context.session.dialImageCache = {panel1 = {}}

-- A theme reload as the radio reaches it: the settings bus event, which
-- widgets/dashboard.lua's own settings handler turns into
-- requestThemeReload() -> clearThemeCache().
local reloaded, reloadErr = pcall(function() bus.publish("settings.update", {}) end)

check("case 9: the settings.update reload ran without error", reloaded, reloadErr)
check("case 9: a theme reload releases every decoded dashboard bitmap",
  retainedBitmaps() == 0, "retained=" .. retainedBitmaps())
check("case 9: a theme reload empties session.dialImageCache",
  context.session.dialImageCache.panel1 == nil)

-- ---------------------------------------------------------------------------

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
