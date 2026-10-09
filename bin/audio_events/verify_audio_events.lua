-- Behaviour check for the Settings -> Audio -> Events split (issue #2308) and
-- for the audio events the split's pages switch (#2310, #2311).
--
-- Run it:
--     lua5.4 bin/audio_events/verify_audio_events.lua
--
-- What it drives, and why:
--   * The real app/pages/settings_audio_events_*.lua pages and their shared
--     helper, loaded under an Ethos form stub, opened exactly the way
--     app/menu_container.lua opens them: page.open(opts) with the four
--     set*Handler setters, and the cleanup handler fired the way
--     app/tool.lua:close() fires it.
--   * The real lib/settings_store.lua is read for its DEFAULTS.events key
--     list, so "every event is still configurable" is checked against the
--     store itself rather than against a list this file also wrote.
--
-- Why a harness at all: nothing in the build or the package step can see a
-- page that stopped offering a setting. The failure mode that matters here is
-- quiet -- a key that no page edits any more simply loses its toggle, and the
-- pilot finds out in the air. So the load-bearing check is the coverage one:
-- every key in DEFAULTS.events is edited by exactly one category page.
--
-- Which cases go RED on a bad split:
--   1. a key is edited by no page                     -> case 1
--   2. a key is edited by two pages                   -> case 1
--   3. a page edits a key the store never had          -> case 1
--   4. a page builds another category's fields         -> case 2
--   5. a page's fields do not reach the store on save -> case 4
--   6. a page marks itself dirty / never re-arms Save -> case 4
--   7. a page keeps writing after it was left         -> case 3
--   8. the old monolithic page is still reachable     -> case 5
--   9. a menu entry points at a page that is not there -> case 5
--
-- and on the events those pages switch:
--  10. a link loss while disarmed is announced        -> case 8
--  11. a link coming back is announced without a loss -> case 8
--  12. a link loss while armed is not announced       -> case 8
--
-- A check that cannot fail proves nothing about the behaviour it passes, so
-- two of the load-bearing ones guard their own instruments:
--   * case 1 counts the add* call sites in the page sources and fails if its
--     own scanner did not see every one of them -- a partial read would
--     understate coverage and let a dropped key pass.
--   * case 4 ties each field widget to the key its source line names, by
--     matching the field's label against that line's i18n tag. If the two ever
--     stop lining up, the case fails instead of writing the wrong key and
--     reporting success.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0

-- The real print, held before _G.print is replaced below: the suite prints
-- through the same global and a silent stub must not swallow this file's own
-- output.
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

local function fileExists(path)
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  -- CRLF to LF. This repository is worked on with core.autocrlf=true and has
  -- no .gitattributes, so the sources on this disk are CRLF -- and the patterns
  -- below anchor on "\n  }," and "\n    key =", which a stray CR would quietly
  -- stop matching. Reading raw would make this file pass or fail with the
  -- checkout settings of whoever ran it.
  return (content:gsub("\r\n", "\n"))
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

-- ── the categories, and the keys each one edits ─────────────────────────────

-- The category pages, in the order app/tool.lua's settings_audio_events_menu
-- lists them. Kept next to the file names on purpose: case 5 reads the menu back
-- out of tool.lua and compares, so a page added there without a row here is
-- caught there rather than silently untested.
--
-- Seven, not five: PR #2488 adds four settings.events keys for the FC status
-- callouts and gave them their own expansion panel, so they are a page here too,
-- and issue #2311 adds the telemetry lost/recovered pair as its own Link page.
local CATEGORIES = {
  {key = "voltage",      file = "settings_audio_events_voltage.lua"},
  {key = "esc",          file = "settings_audio_events_esc.lua"},
  {key = "fuel",         file = "settings_audio_events_fuel.lua"},
  {key = "state",        file = "settings_audio_events_state.lua"},
  {key = "status",       file = "settings_audio_events_status.lua"},
  {key = "link",         file = "settings_audio_events_link.lua"},
  {key = "announcement", file = "settings_audio_events_announcement.lua"},
}

-- DEFAULTS.events, read out of the real settings store's source.
--
-- Its `events = {` block is a list of `name = <scalar>,` lines and ends at the
-- first line that is exactly `  },`. Anything else in that table (a nested table,
-- a computed value) would break the reading, so the block has to match before a
-- single key is trusted.
--
-- The raw assignment count is returned next to the key list, and case 1 requires
-- them to be equal. The block carries comment lines (PR #2488 added two), and a
-- scanner that half-read it would report a key count below the real one -- which
-- is precisely the direction that lets a dropped key pass. A duplicate name would
-- move the count the same way, so this catches that too.
local function readDefaultsEventKeys()
  local src = readFile(SUITE .. "/lib/settings_store.lua")
  local block = src:match("events%s*=%s*{(.-)\n  },\n")
  if not block then return nil, "no events block found in lib/settings_store.lua" end
  local keys, seen, raw = {}, {}, 0
  for name in block:gmatch("\n%s+([%a_][%w_]*)%s*=") do
    raw = raw + 1
    if not seen[name] then
      seen[name] = true
      keys[#keys + 1] = name
    end
  end
  table.sort(keys)
  return keys, nil, raw
end

-- The (label, key) pairs one category page declares, in source order, plus the
-- raw source so the caller can count call sites independently.
--
-- Every addBool/addNumber/addChoice call in these pages passes the label first
-- and the settings.events key second, which is what this pattern anchors on.
-- The i18n tag is kept verbatim: it is resolved by a build-time preprocessor
-- (.vscode/scripts/resolve_i18n_tags.py), so the page hands the literal tag
-- string to form.addLine at runtime. That is what lets case 4 line a field up
-- with its source line.
--
-- Only the tagged form is matched, and countAddCallSites() below has to agree
-- with the number of matches -- so a page that ever passes a literal label
-- instead of an i18n tag fails loudly rather than dropping that field out of
-- the coverage count.
local function readPageFields(file)
  local src = readFile(SUITE .. "/app/pages/" .. file)
  local declared = {}
  for label, key in src:gmatch('"(@i18n%b()@)"%s*,%s*"([%w_]+)"') do
    declared[#declared + 1] = {label = label, key = key}
  end
  return declared, src
end

local function countAddCallSites(src)
  local n = 0
  for _ in src:gmatch("%f[%a]add[%a]+%s*%(") do n = n + 1 end
  return n
end

-- ── Ethos environment ──────────────────────────────────────────────────────

local SUITE_PREFIX = SUITE .. "/"
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile

-- requireModule() calls loadfile() with a path that carries no directory part;
-- on the radio the working directory is src/rfsuite. Same redirect the
-- dialog_lifecycle and tool_ui harnesses use, for the same reason.
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
_G.lcd = {
  getWindowSize = function() return 480, 320 end,
  getTextSize = function(t) return #t, 12 end,
  drawRectangle = function() end,
  drawText = function() end,
  drawBitmap = function() end,
  setColor = function() end,
  font = function() return 1 end,
  color = function() end,
}
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
}
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

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

-- ── Ethos form stub ─────────────────────────────────────────────────────────
--
-- Widget census. This is the instrument the whole "one category at a time" claim
-- rests on: every field handle is recorded in creation order, and form.clear()
-- starts a new page -- so the harness can say how many fields a page built and
-- what each one is, without inferring either from the source.

local fields = {}
local lines = {}
local dialogs = {}
local cleared = 0

local function slotsStub(count)
  local out = {}
  for i = 1, (count or 6) do
    out[i] = {x = (i - 1) * 80, y = 0, w = 80, h = 30}
  end
  return out
end

-- One table, built first and then given its methods, so enable/suffix/decimals
-- can write onto the handle they were handed rather than onto a name that is
-- only bound later.
local function widget(kind, label, get, set)
  local w = {kind = kind, label = label, get = get, set = set, enabled = nil}
  w.focus = function() end
  w.show = function() end
  w.hide = function() end
  w.enable = function(_, on) w.enabled = on end
  w.suffix = function(_, s) w.suffixText = s end
  w.decimals = function(_, d) w.decimalsCount = d end
  return w
end

local function addField(kind, line, get, set, extra)
  local w = widget(kind, line.label, get, set)
  for k, v in pairs(extra or {}) do w[k] = v end
  fields[#fields + 1] = w
  return w
end

-- Each of these mirrors how the pages call them: the label is the first
-- argument to addLine, and a field is handed its line, then nil for the layout.
-- Ethos takes them positionally, so the stubs below do too.
_G.form = {
  addLine = function(label)
    local line = {label = label, index = #lines + 1}
    lines[#lines + 1] = line
    return line
  end,
  clear = function()
    fields = {}
    lines = {}
    cleared = cleared + 1
  end,
  addBooleanField = function(line, _, get, set) return addField("bool", line, get, set) end,
  addNumberField = function(line, _, min, max, get, set)
    return addField("number", line, get, set, {min = min, max = max})
  end,
  addChoiceField = function(line, _, choices, get, set)
    return addField("choice", line, get, set, {choices = choices})
  end,
  addStaticText = function() return widget("text") end,
  addButton = function() return widget("button") end,
  addTextButton = function() return widget("textbutton") end,
  height = function() return 320 end,
  getFieldSlots = function(_, hints) return slotsStub(type(hints) == "table" and #hints or 6) end,
  openDialog = function(args)
    dialogs[#dialogs + 1] = args
    return {close = function() end}
  end,
}

-- ── header stub ─────────────────────────────────────────────────────────────
--
-- app/header.lua's real build() is replaced rather than stubbed field by field:
-- the pages under test only ever use the returned handle, and driving onSave
-- through the recorded opts is what puts a confirmation modal on screen the way
-- the pilot does.

local headerOpts = nil
local headerHandle = nil

local function headerStub()
  return {
    build = function(_, opts)
      headerOpts = opts
      headerHandle = {
        focusMenu = function() end,
        focusSave = function() end,
        focusReload = function() end,
        focusTool = function() end,
        setTitle = function() end,
        setSaveEnabled = function(on) headerHandle.saveEnabled = on end,
        setReloadEnabled = function() end,
      }
      return headerHandle
    end,
  }
end

-- ── settings store stub ─────────────────────────────────────────────────────
--
-- A real deep clone and a real deep compare, because the dirty check these pages
-- rely on is settingsStore.same(settings, original), and a stub that answered
-- "always equal" would make every save case pass without a save ever happening.

local DEFAULT_EVENTS = {}

local function deepCopy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = deepCopy(v) end
  return out
end

local function deepSame(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deepSame(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- A fresh store per page open, so a snapshot left over from a previous page
-- cannot make the next case's dirty check lie.
--
-- loadedSnapshots holds every table load() has handed out. That is the sharp
-- instrument for case 3: a page that keeps its snapshot alive would write into
-- exactly that table, and the settings store would show nothing -- save() takes
-- its own deep copy, so a write into a released table is invisible from out
-- here unless the table itself is held on to.
local saves = 0
local published = {}
local snapshot = {events = {}}
local loadedSnapshots = {}

local function newStore()
  saves = 0
  published = {}
  snapshot = {events = deepCopy(DEFAULT_EVENTS)}
  loadedSnapshots = {}
  dialogs = {}
  headerOpts, headerHandle = nil, nil
end

package.loaded["rfsuite.lib.settings_store"] = {
  load = function()
    local t = deepCopy(snapshot)
    loadedSnapshots[#loadedSnapshots + 1] = t
    return t
  end,
  clone = function(t) return deepCopy(t) end,
  same = deepSame,
  save = function(t)
    saves = saves + 1
    snapshot = deepCopy(t)
  end,
}
package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() return function() end end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic == "settings.update" then published[#published + 1] = message end
  end,
}
package.loaded["rfsuite.app.header"] = headerStub()

-- ── helpers ────────────────────────────────────────────────────────────────

-- Builds the opts table app/menu_container.lua hands page.open(): onBack plus
-- the four set*Handler setters.
--
-- The setters stay on `opts` for the whole life of the page and record what
-- they were handed under `opts.installed`, which is how app/tool.lua's own
-- setCleanupHandler behaves (currentCleanupHandler = handler). Writing the
-- handler back over opts.setCleanupHandler -- the shorter shape another harness
-- in this tree uses -- would make a page's own "release the cleanup handler"
-- call re-enter the handler instead of clearing it, and case 3 below would then
-- be testing the stub rather than the page.
local function makeOpts()
  local installed = {}
  local opts = {backs = 0, installed = installed}
  local function setter(name)
    return function(handler) installed[name] = handler end
  end
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() opts.backs = opts.backs + 1 end
  return opts
end

-- Opens one category page the way menu_container's loadPage() does: re-read the
-- page file, run its module body, call open(opts). The shared helper stays
-- memoized underneath it, exactly as it does on the radio.
--
-- fresh == false keeps the settings store as it stands, which is what lets case
-- 4 re-open a page after a save and read back what was stored.
local function openCategory(category, fresh)
  if fresh ~= false then newStore() end
  local page = dofile(SUITE .. "/app/pages/" .. category.file)
  local opts = makeOpts()
  page.open(opts)
  return opts, fields, headerHandle, headerOpts
end

-- Every key the store holds, with its value, for the "did this reach the store"
-- comparisons.
local function storedEvents()
  return deepCopy(snapshot).events
end

-- ── setup: one key list, shared by every case ───────────────────────────────

local DEFAULT_KEYS, DEFAULT_ERR, DEFAULT_RAW = readDefaultsEventKeys()

out("Settings -> Audio -> Events category pages (issue #2308)")
out("")
if DEFAULT_KEYS then
  for _, k in ipairs(DEFAULT_KEYS) do DEFAULT_EVENTS[k] = 0 end
end

-- ── case 1: coverage ───────────────────────────────────────────────────────

out("case 1: every settings.events key is edited by exactly one category page")
do
  check("the store's events block could be read", DEFAULT_KEYS ~= nil, DEFAULT_ERR)

  if DEFAULT_KEYS then
    out("        DEFAULTS.events has " .. #DEFAULT_KEYS .. " keys")
    check("every assignment in the store's events block was read",
      DEFAULT_RAW == #DEFAULT_KEYS,
      DEFAULT_RAW .. " assignments, " .. #DEFAULT_KEYS ..
      " distinct keys -- a half-read block would understate the key count")

    local editedBy = {}
    local scanComplete = true

    for _, category in ipairs(CATEGORIES) do
      local declared, src = readPageFields(category.file)
      local callSites = countAddCallSites(src)
      if #declared ~= callSites then
        scanComplete = false
        out(string.format("        %s: %d add* call sites but %d fields parsed",
          category.file, callSites, #declared))
      end
      for _, d in ipairs(declared) do
        editedBy[d.key] = editedBy[d.key] or {}
        table.insert(editedBy[d.key], category.key)
      end
    end

    check("every add* call site was parsed, so the coverage number is complete",
      scanComplete, "a missed call site would understate coverage and let a dropped key pass")

    local missing, doubled, extra = {}, {}, {}
    for _, k in ipairs(DEFAULT_KEYS) do
      local owners = editedBy[k]
      if owners == nil or #owners == 0 then
        missing[#missing + 1] = k
      elseif #owners > 1 then
        doubled[#doubled + 1] = k .. " (" .. table.concat(owners, ", ") .. ")"
      end
    end
    for _, k in ipairs(sortedKeys(editedBy)) do
      if DEFAULT_EVENTS[k] == nil then
        extra[#extra + 1] = k .. " (" .. table.concat(editedBy[k], ", ") .. ")"
      end
    end

    check(string.format("no key lost its toggle (%d keys, all covered)", #DEFAULT_KEYS),
      #missing == 0, table.concat(missing, ", "))
    check("no key is offered on two pages", #doubled == 0, table.concat(doubled, ", "))
    check("no page edits a key the store does not have", #extra == 0, table.concat(extra, ", "))
  end
end

-- ── case 2: one category per open ──────────────────────────────────────────

out("")
out("case 2: a page builds only its own fields")
do
  local perPage = {}
  local total = 0
  local widths = {}

  for _, category in ipairs(CATEGORIES) do
    local _, built = openCategory(category)
    local declared = readPageFields(category.file)
    check(string.format("%s: %d fields built, %d fields declared", category.file, #built, #declared),
      #built == #declared,
      "a page building more than it declares is building another category's fields")
    perPage[#perPage + 1] = #built
    widths[#widths + 1] = #built
    total = total + #built
  end

  if DEFAULT_KEYS then
    check(string.format("the category pages together build exactly the store's key count (%d)", total),
      total == #DEFAULT_KEYS, "the split must neither drop a field nor duplicate one")
    local widest = 0
    for _, n in ipairs(widths) do if n > widest then widest = n end end
    check("no single page builds the whole set any more (widest: " .. widest .. ")",
      widest < #DEFAULT_KEYS, "per page: " .. table.concat(widths, ", "))
  end
end

-- ── case 3: dispose drops the snapshot ─────────────────────────────────────

out("")
out("case 3: a page that has been left keeps nothing and writes nothing")
do
  for _, category in ipairs(CATEGORIES) do
    local opts, built = openCategory(category)

    -- The tool is closed while this page is on screen: app/tool.lua:close()
    -- runs the cleanup handler and does not come back.
    local handler = opts.installed.setCleanupHandler
    check(string.format("%s: installed a cleanup handler", category.file), handler ~= nil)
    local ok, err = true, nil
    if handler then ok, err = pcall(handler) end
    check(string.format("%s: cleanup did not raise", category.file), ok, err)
    check(string.format("%s: cleanup released the cleanup handler", category.file),
      opts.installed.setCleanupHandler == nil,
      "the tool would keep calling into a disposed page")

    -- A field callback held past teardown would still be able to reach the
    -- snapshot it closed over. Drive every field after teardown, then look at
    -- the snapshot table itself rather than at the settings store: save() takes
    -- its own deep copy, so a write into a released snapshot is invisible from
    -- the store and only shows here. Comparing tables rather than whether the
    -- callback raised is what makes this a real check -- a setter that silently
    -- returns, or one whose guard was dropped along with its cleanup, is the
    -- failure, and the first does not raise at all.
    local pristine = {}
    for i, snap in ipairs(loadedSnapshots) do pristine[i] = deepCopy(snap) end
    local before = storedEvents()

    local raisedCount = 0
    for _, w in ipairs(built) do
      local probe = (w.kind == "bool") and (not (w.get() == true)) or 6
      if not pcall(w.set, probe) then raisedCount = raisedCount + 1 end
    end
    check(string.format("%s: no field raised after teardown", category.file), raisedCount == 0,
      raisedCount .. " field(s) raised")

    local mutated = {}
    for i, snap in ipairs(loadedSnapshots) do
      if not deepSame(pristine[i], snap) then mutated[#mutated + 1] = "snapshot " .. i end
    end
    check(string.format("%s: no field wrote into a snapshot the page had let go of", category.file),
      #mutated == 0, table.concat(mutated, ", "))
    check(string.format("%s: the settings store is untouched", category.file),
      deepSame(before, storedEvents()))
  end
end

-- ── case 4: the save round trip, field by field ────────────────────────────

out("")
out("case 4: every field a page builds reaches the store on save")
do
  for _, category in ipairs(CATEGORIES) do
    local opts, built, handle, hops = openCategory(category)
    local declared = readPageFields(category.file)

    check(string.format("%s: a freshly opened page is not dirty", category.file),
      handle.saveEnabled == false, "saveEnabled=" .. tostring(handle.saveEnabled))

    -- Tie each widget to the key its source line names. The label is the i18n
    -- tag both sides carry verbatim, so this is an identity check rather than a
    -- position assumption -- and it fails loudly if the two ever stop lining up.
    local aligned = #built == #declared
    for i = 1, math.min(#built, #declared) do
      if built[i].label ~= declared[i].label then
        aligned = false
        out(string.format("        %s: field %d is labelled %s but its source line says %s",
          category.file, i, tostring(built[i].label), tostring(declared[i].label)))
      end
    end
    check(string.format("%s: every field matches the source line that declares it", category.file),
      aligned, string.format("%d built, %d declared", #built, #declared))

    -- Drive each field with a value its own getter would not answer, so a setter
    -- that writes the wrong key cannot pass by coincidence.
    --
    -- The probe for a number field is 6, inside every range these pages declare
    -- -- 5..120 in seconds, 60..300 in degrees, 30..150 in tenths of a volt,
    -- 1..10 in repeats. It is deliberately not the same number as any default,
    -- so a setter that never runs leaves a visible difference.
    local probes = {}
    for i, w in ipairs(built) do
      local probe
      if w.kind == "bool" then
        probe = not (w.get() == true)
      elseif w.kind == "number" then
        probe = 6
      else
        probe = w.choices[#w.choices][2]
      end
      probes[i] = probe
      w.set(probe)
    end

    check(string.format("%s: editing every field arms Save", category.file),
      handle.saveEnabled == true, "saveEnabled=" .. tostring(handle.saveEnabled))

    hops.onSave()
    local modal = dialogs[#dialogs]
    check(string.format("%s: a dirty save asks first", category.file), modal ~= nil,
      "saving straight through would skip the confirmation the pilot relies on")
    if modal then
      modal.buttons[1].action()
      check(string.format("%s: OK wrote the settings store once", category.file), saves == 1,
        "saves=" .. saves)
      check(string.format("%s: settings.update was published once", category.file), #published == 1,
        "published=" .. #published)
      check(string.format("%s: Save is disarmed again after saving", category.file),
        handle.saveEnabled == false, "saveEnabled=" .. tostring(handle.saveEnabled))
    end

    -- What the pilot actually sees: leave, come back, and every field has to
    -- read back what was typed. Read through the page's own getter rather than
    -- against the store, because two of these fields store in different units
    -- than they display (the BEC and RX thresholds are held in volts and shown
    -- in tenths), and a harness that knew the scale would be a second place to
    -- get it wrong. This is also the check a wrong-key setter cannot pass.
    openCategory(category, false)
    local reopened = fields
    local wrong = {}
    for i = 1, math.min(#reopened, #declared) do
      local got = reopened[i].get()
      if got ~= probes[i] then
        wrong[#wrong + 1] = string.format("%s reads %s (typed %s)",
          declared[i].key, tostring(got), tostring(probes[i]))
      end
    end
    check(string.format("%s: all %d fields read back what was typed, after re-opening",
      category.file, #declared), #wrong == 0, table.concat(wrong, ", "))

    -- Going back must leave the tool's event handler behind too.
    hops.onBack()
    check(string.format("%s: going back pops the screen once", category.file), opts.backs == 1,
      "backs=" .. opts.backs)
  end
end

-- ── case 5: the menu reaches every category page ───────────────────────────

out("")
out("case 5: the menu in tool.lua reaches exactly these category pages")
do
  local tool = readFile(SUITE .. "/app/tool.lua")

  check("the monolithic page is gone from the menu",
    not tool:find('script = "app/pages/settings_audio_events.lua"', 1, true),
    "settings_audio_events.lua as a menu entry would be a second copy of every event")
  check("the monolithic page file is gone from the tree",
    not fileExists(SUITE .. "/app/pages/settings_audio_events.lua"),
    "a stale page file is what the next rename would silently resurrect")
  check("the Events tile is a menu now",
    tool:find('menuId = "settings_audio_events_menu"', 1, true) ~= nil)

  local block = tool:match("settings_audio_events_menu%s*=%s*{(.-)\n  },\n")
  check("settings_audio_events_menu is declared", block ~= nil)
  if block then
    local scripts = {}
    for s in block:gmatch('script = "([^"]+)"') do scripts[#scripts + 1] = s end
    check(string.format("the menu lists %d entries", #CATEGORIES), #scripts == #CATEGORIES,
      "found " .. #scripts .. " script entries")

    local reachable, orphans = {}, {}
    for i, category in ipairs(CATEGORIES) do
      local expected = "app/pages/" .. category.file
      check(category.file .. " is menu slot " .. i, scripts[i] == expected,
        "slot " .. i .. " holds " .. tostring(scripts[i]))
      check(category.file .. " exists", fileExists(SUITE .. "/" .. expected),
        "menu entry " .. expected .. " points at nothing")
      reachable[expected] = true
    end
    for _, category in ipairs(CATEGORIES) do
      local p = "app/pages/" .. category.file
      if not reachable[p] then orphans[#orphans + 1] = category.file end
    end
    check("no category page is orphaned", #orphans == 0, table.concat(orphans, ", "))
  end
end

-- ── case 6: unassigned number fields return scaled defaults ────────────────

out("")
out("case 6: unassigned number fields return within declared bounds")
do
  snapshot = {events = {}}
  for _, category in ipairs(CATEGORIES) do
    local _, built = openCategory(category, false)
    for _, w in ipairs(built) do
      if w.kind == "number" then
        local got = w.get()
        check(string.format("%s: '%s' default is within [%s, %s] (got %s)",
          category.file, tostring(w.label), tostring(w.min), tostring(w.max), tostring(got)),
          got ~= nil and got >= w.min and got <= w.max,
          string.format("got %s outside [%s, %s]", tostring(got), tostring(w.min), tostring(w.max)))
      end
    end
  end
end

do
-- ── case 7: the main-power alert (issue #2310) ─────────────────────────────
--
-- A pack that goes while the FC stays alive on a BEC or a backup battery.
-- Nothing in the build or the package step exercises tasks/audio_events.lua's
-- announceMainPowerLost(), and the failure is quiet: without the pack-seen
-- latch a model whose pack is simply not measured alarms on every flight, and
-- without the BEC guard a pack that goes on the ground does too.
--
-- The real task is loaded here with the bus, settings store, system audio and
-- os.clock stubbed, and driven one wakeup at a time against a controllable
-- clock. The pack the sound resolves from is stated to the task through an
-- io.open shim below: every packaged sound path is "SCRIPTS:/...", which does
-- not exist in a checkout, so a resolver that only plays files it can open
-- would otherwise be untestable here.
--
-- Pinned:
--   * a pack that has read a voltage and then goes, with a BEC still up,
--     fires the alert, speaks the BEC voltage and buzzes;
--   * with none of the loss sounds available, the BEC voltage and the haptic
--     still fire;
--   * a model whose pack is not measured at all stays silent, and so does one
--     with no BEC reading -- the two guards that keep this quiet;
--   * the alert repeats only after the repeat interval;
--   * the pack coming back speaks once, and only after a loss was announced;
--   * main_power_lost = false keeps it silent.
--
-- A check that cannot fail proves nothing, so the last check strips the
-- pack-seen latch from a copy of the task and requires a never-measured pack
-- to fire there. If that check ever stops turning red, the instrument has gone
-- blind.

local AUDIO_PATH = SUITE .. "/tasks/audio_events.lua"
-- io.open is answered for the "SCRIPTS:" paths in `scriptFiles` and left to the
-- real filesystem for everything else (the harness's own readFile() shares it).
-- The globals the rigs replace are put back once the case is done, so nothing
-- that runs after it -- today only the summary -- sees a stub.
local realIoOpen = io.open
local savedSystem = _G.system
local savedOsClock = os.clock
local savedRequire = package.loaded["rfsuite.lib.require"]
local savedUnitVolt = _G.UNIT_VOLT
local scriptFiles = {}
io.open = function(path, mode)
  if type(path) == "string" and path:sub(1, 8) == "SCRIPTS:" then
    if scriptFiles[path] then return {close = function() end} end
    return nil
  end
  return realIoOpen(path, mode)
end

-- The rig behind both event cases: the real tasks/audio_events.lua, driven one
-- wakeup at a time against a controllable clock. `events` is the settings.events
-- table the task reads, and `source` lets a can-fail case load a modified copy.
local function newTaskRig(events, source)
  local handlers = {}
  local played, spoken, haptics = {}, {}, {}

  -- The main-power fallbacks: every shipped pack carries these two, and the
  -- dedicated main-power words ship in none yet, so these are what a pack
  -- resolves to today. A scenario that declares mainpower.wav present overwrites
  -- this to prove the order, and one that wants a silent pack calls noSounds().
  scriptFiles = {
    ["SCRIPTS:/rfsuite/audio/en/default/status/alerts/lowbat.wav"] = true,
    ["SCRIPTS:/rfsuite/audio/en/default/events/alerts/battery.wav"] = true,
  }

  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return {
        subscribe = function(topic, fn) handlers[topic] = fn end,
        publish = function() end,
      }
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {events = events} end,
        audioEvents = function(s) return s.events or {} end,
        audioTimer = function() return {} end,
      }
    elseif name == "lib/engine_type.lua" then
      return {isElectric = function() return true end}
    end
    return loadfile(name)()
  end

  _G.UNIT_VOLT = "V"
  _G.system = {
    playFile = function(path) played[#played + 1] = path end,
    playNumber = function(value, unit, decimals)
      spoken[#spoken + 1] = {value = value, unit = unit, decimals = decimals}
    end,
    playHaptic = function() haptics[#haptics + 1] = true end,
    getAudioVoice = function() return "en/default" end,
  }

  local clock = 0
  _G.os.clock = function() return clock end

  local audio = assert(load(source or readFile(AUDIO_PATH), "@" .. AUDIO_PATH))()

  local rig = {spoken = spoken, haptics = haptics}
  function rig.setClock(t) clock = t end
  function rig.step(snapshot)
    handlers["session.update"](snapshot)
    handlers["settings.update"]({events = events})
    audio.wakeup()
  end
  function rig.count(file)
    local n = 0
    for _, path in ipairs(played) do
      if path:find(file, 1, true) then n = n + 1 end
    end
    return n
  end
  function rig.lastPlayed() return played[#played] end
  -- For the case where a pack carries none of the loss sounds.
  function rig.noSounds() scriptFiles = {} end
  return rig
end

local function mainPowerChecks()
  -- A pack that has read a voltage, then goes while the BEC stays up. The first
  -- wakeup only initializes the task, so the pack is seen on the second.
  do
    local rig = newTaskRig({main_power_lost = true})
    rig.setClock(0); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0}) -- seed
    rig.setClock(1); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0}) -- pack seen
    rig.setClock(2); rig.step({connected = true, voltage = 0, becVoltage = 5.0})    -- gone
    check("a pack that goes while the BEC stays up fires the main-power alert",
      rig.count("lowbat.wav") == 1, "lowbat.wav played " .. rig.count("lowbat.wav") .. "x")
    check("the resolved fallback is the pack's own 'battery empty' word",
      (rig.lastPlayed() or ""):find("status/alerts/lowbat.wav", 1, true) ~= nil,
      tostring(rig.lastPlayed()))
    local n = rig.spoken[#rig.spoken]
    check("the alert speaks the BEC voltage in tenths of a volt",
      n ~= nil and n.value == 50 and n.unit == "V" and n.decimals == 1,
      n and string.format("%s %s %s", n.value, tostring(n.unit), tostring(n.decimals)))
    check("the alert buzzes", #rig.haptics == 1, #rig.haptics .. " haptic(s)")
  end

  -- A pack that carries none of the loss sounds still gets the spoken BEC
  -- voltage and the haptic; only the sound is missing. The voice is the part
  -- that says how long is left, so it must not depend on a file resolving.
  do
    local rig = newTaskRig({main_power_lost = true})
    rig.noSounds()
    rig.setClock(0); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(1); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(2); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
    check("with no loss sound available, no file is played",
      rig.count(".wav") == 0, rig.count(".wav") .. " file(s) played")
    local n = rig.spoken[#rig.spoken]
    check("with no loss sound available, the BEC voltage is still spoken",
      n ~= nil and n.value == 50 and n.decimals == 1,
      n and string.format("value=%s decimals=%s", tostring(n.value), tostring(n.decimals)))
    check("with no loss sound available, the alert still buzzes",
      #rig.haptics == 1, #rig.haptics .. " haptic(s)")
  end

  -- A dedicated mainpower.wav, once a pack carries it, is preferred over the
  -- fallback. Proves the candidate list is ordered rather than decorative.
  do
    local rig = newTaskRig({main_power_lost = true})
    scriptFiles["SCRIPTS:/rfsuite/audio/en/default/status/alerts/mainpower.wav"] = true
    rig.setClock(0); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(1); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(2); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
    check("a pack that carries mainpower.wav plays it instead of the fallback",
      (rig.lastPlayed() or ""):find("status/alerts/mainpower.wav", 1, true) ~= nil,
      tostring(rig.lastPlayed()))
  end

  -- A model whose pack is never measured: a reading of 0 from the start must
  -- not be read as a pack that has gone, or every such model alarms.
  do
    local rig = newTaskRig({main_power_lost = true})
    rig.setClock(0); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
    rig.setClock(1); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
    rig.setClock(2); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
    check("a pack that has never read a voltage stays silent",
      rig.count("lowbat.wav") == 0, "lowbat.wav played " .. rig.count("lowbat.wav") .. "x")
  end

  -- No BEC reading: there is no evidence anything is still powered.
  do
    local rig = newTaskRig({main_power_lost = true})
    rig.setClock(0); rig.step({connected = true, voltage = 22.2})
    rig.setClock(1); rig.step({connected = true, voltage = 22.2})
    rig.setClock(2); rig.step({connected = true, voltage = 0})
    check("a gone pack with no BEC reading stays silent",
      rig.count("lowbat.wav") == 0, "lowbat.wav played " .. rig.count("lowbat.wav") .. "x")
  end

  -- The repeat interval still governs a pack that stays gone.
  do
    local rig = newTaskRig({main_power_lost = true})
    rig.setClock(0); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(1); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(2); rig.step({connected = true, voltage = 0, becVoltage = 5.0})   -- fire
    rig.setClock(6); rig.step({connected = true, voltage = 0, becVoltage = 5.0})   -- within 10s
    check("a pack that stays gone is not repeated before the interval",
      rig.count("lowbat.wav") == 1, "lowbat.wav played " .. rig.count("lowbat.wav") .. "x")
    rig.setClock(12); rig.step({connected = true, voltage = 0, becVoltage = 5.0})  -- 10s after
    check("a pack that stays gone repeats after the interval",
      rig.count("lowbat.wav") == 2, "lowbat.wav played " .. rig.count("lowbat.wav") .. "x")
  end

  -- The pack comes back: one recovery callout, and none if nothing was lost.
  do
    local rig = newTaskRig({main_power_lost = true})
    rig.setClock(0); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(1); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(2); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
    rig.setClock(3); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0}) -- back
    check("the pack coming back plays one recovery callout",
      rig.count("battery.wav") == 1, "battery.wav played " .. rig.count("battery.wav") .. "x")
    local n = rig.spoken[#rig.spoken]
    check("the recovery speaks the pack total in tenths of a volt",
      n ~= nil and n.value == 222 and n.unit == "V" and n.decimals == 1,
      n and string.format("%s %s %s", n.value, tostring(n.unit), tostring(n.decimals)))
    rig.setClock(4); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    check("a healthy pack that was never lost speaks no recovery",
      rig.count("battery.wav") == 1, "battery.wav played " .. rig.count("battery.wav") .. "x")
  end

  -- The setting off keeps the whole thing silent.
  do
    local rig = newTaskRig({main_power_lost = false})
    rig.setClock(0); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(1); rig.step({connected = true, voltage = 22.2, becVoltage = 5.0})
    rig.setClock(2); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
    check("main_power_lost = false keeps the alert silent",
      rig.count("lowbat.wav") == 0, "lowbat.wav played " .. rig.count("lowbat.wav") .. "x")
  end

  -- Can-fail: strip the pack-seen latch and require a never-measured pack to
  -- fire. If this stops turning red, the checks above prove nothing.
  local source = readFile(AUDIO_PATH)
  local stripped = source:gsub("if not packVoltageSeen then return false end", "", 1)
  check("the pack-seen latch could be located in mainPowerLost()", stripped ~= source)
  local rig = newTaskRig({main_power_lost = true}, stripped)
  rig.setClock(0); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
  rig.setClock(1); rig.step({connected = true, voltage = 0, becVoltage = 5.0})
  check("without the pack-seen latch a never-measured pack fires (this check can go red)",
    rig.count("lowbat.wav") == 1, "lowbat.wav played " .. rig.count("lowbat.wav") .. "x")
end

out("")
out("case 7: the main-power alert")
mainPowerChecks()

-- ── case 8: the telemetry link, gated by the armed state (issue #2311) ─────
--
-- The one announcement in this file that is gated on the state the model was in
-- *before* the event, and the two halves are gated on each other. Nothing in the
-- build or the package step reaches tasks/audio_events.lua's
-- announceTelemetryLost()/announceTelemetryRecovered(), and both failure modes
-- are quiet in the direction that costs the pilot something: drop the armed gate
-- and every bench power-down shouts, drop the pending flag and a model that was
-- told it lost the link is never told it got it back.
--
-- The same rig the main-power case uses, with no sound present by default: no
-- pack carries the two telemetry words yet, so "haptic only until a pack gains
-- them" is what has to be pinned, and a scenario that declares one present
-- proves the resolution order.
--
-- Pinned:
--   * a link loss while armed is announced once, with the haptic, and never
--     again while the link stays down;
--   * a link loss while disarmed says nothing at all -- the bench case the
--     issue was filed about;
--   * the link coming back is announced once, and only for a loss that was
--     announced;
--   * a model that answers again after the recovery window gets no recovery;
--   * telemetry_lost = false keeps both halves silent;
--   * nothing is announced for a link that was already down at startup.
--
-- The last check strips the armed gate from a copy of the task and requires a
-- disarmed loss to fire there. If it stops turning red, the instrument has gone
-- blind.

local TELEMETRY_LOST_FILE = "SCRIPTS:/rfsuite/audio/en/default/events/alerts/telemetrylost.wav"
local TELEMETRY_OK_FILE = "SCRIPTS:/rfsuite/audio/en/default/events/alerts/telemetryok.wav"

local function newLinkRig(events, source)
  local rig = newTaskRig(events, source)
  -- No pack carries either word yet.
  rig.noSounds()
  return rig
end

local function telemetryLinkChecks()
  -- Armed, and the link goes. The first wakeup only initializes the task, so the
  -- loss is on the second connected tick's successor.
  do
    local rig = newLinkRig({telemetry_lost = true})
    rig.setClock(0); rig.step({connected = true, isArmed = true}) -- initialize
    rig.setClock(1); rig.step({connected = true, isArmed = true}) -- armed tick
    rig.setClock(2); rig.step({connected = false})                -- link lost
    check("a link loss while armed buzzes",
      #rig.haptics == 1, #rig.haptics .. " haptic(s)")
    check("with no telemetrylost.wav in the pack, no file is played",
      rig.count(".wav") == 0, rig.count(".wav") .. " file(s) played")
    rig.setClock(3); rig.step({connected = false})                -- still down
    check("a loss that stands is not announced again",
      #rig.haptics == 1, #rig.haptics .. " haptic(s)")
  end

  -- A pack that carries the words plays them: the dedicated file on the way
  -- out, and its pair on the way back in.
  do
    local rig = newLinkRig({telemetry_lost = true})
    scriptFiles[TELEMETRY_LOST_FILE] = true
    scriptFiles[TELEMETRY_OK_FILE] = true
    rig.setClock(0); rig.step({connected = true, isArmed = true})
    rig.setClock(1); rig.step({connected = true, isArmed = true})
    rig.setClock(2); rig.step({connected = false})
    check("a pack that carries telemetrylost.wav plays it",
      (rig.lastPlayed() or ""):find("telemetrylost.wav", 1, true) ~= nil,
      tostring(rig.lastPlayed()))
    rig.setClock(3); rig.step({connected = true, isArmed = true}) -- back
    check("the link coming back plays telemetryok.wav",
      rig.count("telemetryok.wav") == 1, "telemetryok.wav played " .. rig.count("telemetryok.wav") .. "x")
    check("the recovery buzzes once",
      #rig.haptics == 2, #rig.haptics .. " haptic(s)")
    rig.setClock(4); rig.step({connected = true, isArmed = true})
    check("the recovery is not announced again",
      rig.count("telemetryok.wav") == 1, "telemetryok.wav played " .. rig.count("telemetryok.wav") .. "x")
  end

  -- The bench case from the issue: disarmed, pack unplugged. Nothing at all --
  -- no file, no haptic -- and no recovery either, because nothing was lost.
  do
    local rig = newLinkRig({telemetry_lost = true})
    rig.setClock(0); rig.step({connected = true, isArmed = false})
    rig.setClock(1); rig.step({connected = true, isArmed = false})
    rig.setClock(2); rig.step({connected = false})
    check("a link loss while disarmed is silent",
      #rig.haptics == 0 and rig.count(".wav") == 0,
      #rig.haptics .. " haptic(s), " .. rig.count(".wav") .. " file(s)")
    rig.setClock(3); rig.step({connected = true, isArmed = false})
    check("a model that was never told it lost the link is not told it recovered",
      rig.count("telemetryok.wav") == 0 and #rig.haptics == 0,
      #rig.haptics .. " haptic(s), " .. rig.count(".wav") .. " file(s)")
  end

  -- The window: a model that answers again long after the loss is a new flight.
  do
    local rig = newLinkRig({telemetry_lost = true})
    scriptFiles[TELEMETRY_LOST_FILE] = true
    scriptFiles[TELEMETRY_OK_FILE] = true
    rig.setClock(0); rig.step({connected = true, isArmed = true})
    rig.setClock(1); rig.step({connected = true, isArmed = true})
    rig.setClock(2); rig.step({connected = false})
    rig.setClock(200); rig.step({connected = true, isArmed = true})
    check("a link back after the recovery window gets no recovery callout",
      rig.count("telemetryok.wav") == 0, "telemetryok.wav played " .. rig.count("telemetryok.wav") .. "x")
  end

  -- The setting off keeps both halves silent.
  do
    local rig = newLinkRig({telemetry_lost = false})
    rig.setClock(0); rig.step({connected = true, isArmed = true})
    rig.setClock(1); rig.step({connected = true, isArmed = true})
    rig.setClock(2); rig.step({connected = false})
    check("telemetry_lost = false keeps the loss silent",
      #rig.haptics == 0, #rig.haptics .. " haptic(s)")
    rig.setClock(3); rig.step({connected = true, isArmed = true})
    check("telemetry_lost = false keeps the recovery silent",
      #rig.haptics == 0, #rig.haptics .. " haptic(s)")
  end

  -- A task that starts on a down link has no `previous` to read an edge from.
  do
    local rig = newLinkRig({telemetry_lost = true})
    rig.setClock(0); rig.step({connected = false})
    rig.setClock(1); rig.step({connected = false})
    check("a link that was already down at startup is not a loss",
      #rig.haptics == 0, #rig.haptics .. " haptic(s)")
  end

  -- Can-fail: strip the armed gate and require a disarmed loss to fire. If this
  -- stops turning red, the checks above prove nothing.
  local source = readFile(AUDIO_PATH)
  local stripped = source:gsub("if previous.isArmed ~= true then return end", "", 1)
  check("the armed gate could be located in announceTelemetryLost()", stripped ~= source)
  local rig = newTaskRig({telemetry_lost = true}, stripped)
  rig.setClock(0); rig.step({connected = true, isArmed = false})
  rig.setClock(1); rig.step({connected = true, isArmed = false})
  rig.setClock(2); rig.step({connected = false})
  check("without the armed gate a disarmed loss fires (this check can go red)",
    #rig.haptics == 1, #rig.haptics .. " haptic(s)")

  -- Can-fail the other way round: read the armed state off the session instead
  -- of the snapshot. The session clears isArmed in the same step that clears
  -- connected, so this copy answers with an empty value and has to stay quiet --
  -- and it is what the real code would do if the announcement ran after
  -- rememberCurrent() instead of before it.
  local stale = source:gsub("if previous.isArmed ~= true then return end",
    "if session.isArmed ~= true then return end", 1)
  check("the armed gate could be re-pointed at the session", stale ~= source)
  local quiet = newTaskRig({telemetry_lost = true}, stale)
  quiet.setClock(0); quiet.step({connected = true, isArmed = true})
  quiet.setClock(1); quiet.step({connected = true, isArmed = true})
  quiet.setClock(2); quiet.step({connected = false})
  check("a gate reading the session's armed state says nothing (this check can go red)",
    #quiet.haptics == 0, #quiet.haptics .. " haptic(s)")
end

out("")
out("case 8: the telemetry link, gated by the armed state")
telemetryLinkChecks()

-- Put the globals the rigs replaced back, so nothing after this case -- the
-- summary today, anything added later -- runs against a stub.
io.open = realIoOpen
_G.system = savedSystem
os.clock = savedOsClock
package.loaded["rfsuite.lib.require"] = savedRequire
_G.UNIT_VOLT = savedUnitVolt

end

do
local savedSystem, savedOsClock = _G.system, os.clock
local savedRequire = package.loaded["rfsuite.lib.require"]
local savedUnitVolt = _G.UNIT_VOLT
-- ── case 8: the low-voltage hold filter and spoken callout (issue #2309) ────
--
-- This behaviour lives in tasks/audio_events.lua's announceVoltage(), which
-- neither the build nor the package step exercises. The failure is quiet and
-- the pilot finds out in the air: either the alarm sounds on a momentary 3D
-- voltage sag, or it stops speaking the reading it used to. So the real task
-- is loaded here with the bus, settings store, system audio and os.clock
-- stubbed, and driven one wakeup at a time against a controllable clock.
--
-- Pinned:
--   * a reading below the threshold that has not held for events.voltage_hold
--     seconds stays silent, and a recovery restarts the hold;
--   * once it has held, the alarm fires, and repeats only after the repeat
--     interval;
--   * voltage_callout speaks the pack total (tenths), the average cell
--     (hundredths) or nothing, per its value.
--
-- A check that cannot fail proves nothing, so the last check loads a copy of
-- the task with the hold guard stripped and requires the sag to fire there.
-- If that check ever stops turning red, the instrument has gone blind.

local AUDIO_PATH = SUITE .. "/tasks/audio_events.lua"

-- A fresh rig per scenario: the task's own upvalues (the hold start and the
-- last-alert clock) must not carry between them. `source` overrides the file
-- the module is loaded from, which is what the can-fail check uses.
local function newVoltageRig(events, source)
  local handlers = {}
  local played, spoken = {}, {}

  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return {
        subscribe = function(topic, fn) handlers[topic] = fn end,
        publish = function() end,
      }
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {events = events} end,
        audioEvents = function(s) return s.events or {} end,
        audioTimer = function() return {} end,
      }
    elseif name == "lib/engine_type.lua" then
      return {isElectric = function() return true end}
    end
    return loadfile(name)()
  end

  _G.UNIT_VOLT = "V"
  _G.system = {
    playFile = function(path) played[#played + 1] = path end,
    playNumber = function(value, unit, decimals)
      spoken[#spoken + 1] = {value = value, unit = unit, decimals = decimals}
    end,
    playHaptic = function() end,
    getAudioVoice = function() return "en/default" end,
  }

  local clock = 0
  _G.os.clock = function() return clock end

  local audio = assert(load(source or readFile(AUDIO_PATH), "@" .. AUDIO_PATH))()

  local rig = {spoken = spoken}
  function rig.setClock(t) clock = t end
  -- 20.4 V over 6 cells is 3.40 V/cell, below the 3.50 V warning threshold;
  -- 22.2 V is 3.70, above it. The first step after connecting only seeds the
  -- module's state, so each scenario steps once at clock 0 before measuring.
  function rig.step(voltage, config, newEvents)
    if newEvents ~= nil then events = newEvents end
    local batt = {cellCount = 6, vbatWarningCell = 3.5}
    if config == false then
      batt = nil
    elseif type(config) == "table" then
      batt = config
    end
    handlers["session.update"]({
      connected = true,
      voltage = voltage,
      batteryConfig = batt,
    })
    handlers["settings.update"]({events = events})
    audio.wakeup()
  end
  function rig.countLow()
    local n = 0
    for _, path in ipairs(played) do
      if path:find("lowvoltage.wav", 1, true) then n = n + 1 end
    end
    return n
  end
  return rig
end

local function voltageChecks()
  -- The sag: below the threshold but not yet held -> silent; then a reading
  -- that holds -> fires.
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)   -- seed
    rig.setClock(1); rig.step(20.4)   -- hold starts, 0 < 2
    rig.setClock(2.9); rig.step(20.6) -- 1.9 < 2
    check("a low reading held for less than the hold time stays silent",
      rig.countLow() == 0, "lowvoltage.wav played " .. rig.countLow() .. "x")
    rig.setClock(3.0); rig.step(20.4) -- 2.0 >= 2 -> fire
    check("a low reading held for the hold time fires", rig.countLow() == 1,
      "lowvoltage.wav played " .. rig.countLow() .. "x")
  end

  -- A recovery between two dips restarts the hold.
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)   -- seed
    rig.setClock(1); rig.step(20.4)   -- hold starts
    rig.setClock(1.5); rig.step(22.2) -- recovered -> hold cleared
    check("a recovery between two dips does not fire", rig.countLow() == 0)
    rig.setClock(3); rig.step(20.4)   -- hold restarts at 3, 0 < 2
    rig.setClock(4); rig.step(20.4)   -- 1 < 2
    check("a fresh dip after a recovery still waits out the hold",
      rig.countLow() == 0, "lowvoltage.wav played " .. rig.countLow() .. "x")
    rig.setClock(5); rig.step(20.4)   -- 2 >= 2 -> fire
    check("the fresh dip fires once it has held", rig.countLow() == 1,
      "lowvoltage.wav played " .. rig.countLow() .. "x")
  end

  -- A missing voltage reading or missing battery configuration during a dip clears the hold.
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)   -- seed
    rig.setClock(1); rig.step(20.4)   -- hold starts
    rig.setClock(1.5); rig.step(nil)  -- telemetry dropout (voltage = nil) -> hold cleared
    check("telemetry dropout during dip does not fire", rig.countLow() == 0)
    rig.setClock(3.0); rig.step(20.4) -- dip resumes; hold restarts at 3.0 (0 < 2)
    rig.setClock(4.0); rig.step(20.4) -- 1.0 < 2
    check("dip after telemetry dropout still waits out the full hold",
      rig.countLow() == 0, "lowvoltage.wav played " .. rig.countLow() .. "x")
    rig.setClock(5.0); rig.step(20.4) -- 2.0 >= 2 -> fires
    check("dip after telemetry dropout fires once hold elapsed",
      rig.countLow() == 1, "lowvoltage.wav played " .. rig.countLow() .. "x")
  end

  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)   -- seed
    rig.setClock(1); rig.step(20.4)   -- hold starts
    rig.setClock(1.5); rig.step(20.4, false) -- missing batteryConfig -> hold cleared
    check("missing batteryConfig during dip does not fire", rig.countLow() == 0)
    rig.setClock(3.0); rig.step(20.4) -- dip resumes; hold restarts at 3.0 (0 < 2)
    rig.setClock(4.0); rig.step(20.4) -- 1.0 < 2
    check("dip after missing batteryConfig still waits out the full hold",
      rig.countLow() == 0, "lowvoltage.wav played " .. rig.countLow() .. "x")
    rig.setClock(5.0); rig.step(20.4) -- 2.0 >= 2 -> fires
    check("dip after missing batteryConfig fires once hold elapsed",
      rig.countLow() == 1, "lowvoltage.wav played " .. rig.countLow() .. "x")
  end

  -- Disabling and re-enabling the alert clears any partial hold.
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)   -- seed
    rig.setClock(1); rig.step(20.4)   -- hold starts
    rig.setClock(1.5); rig.step(20.4, nil, {voltage = false, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10})
    check("disabled alert does not fire", rig.countLow() == 0)
    rig.setClock(3.0); rig.step(20.4, nil, {voltage = true, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10}) -- re-enabled, hold restarts at 3.0
    rig.setClock(4.0); rig.step(20.4) -- 1.0 < 2
    check("re-enabled alert still waits out full hold",
      rig.countLow() == 0, "lowvoltage.wav played " .. rig.countLow() .. "x")
    rig.setClock(5.0); rig.step(20.4) -- 2.0 >= 2 -> fires
    check("re-enabled alert fires once hold elapsed",
      rig.countLow() == 1, "lowvoltage.wav played " .. rig.countLow() .. "x")
  end

  -- hold = 0 disables the filter and fires on the first low reading.
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)   -- seed
    rig.setClock(1); rig.step(20.4)
    check("hold = 0 fires on the first low reading", rig.countLow() == 1,
      "lowvoltage.wav played " .. rig.countLow() .. "x")
  end

  -- The callout: pack total, average cell, or nothing.
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 0, voltage_callout = 1, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)
    rig.setClock(1); rig.step(20.4)
    local n = rig.spoken[#rig.spoken]
    check("callout = 1 speaks the pack total in tenths of a volt",
      n ~= nil and n.value == 204 and n.unit == "V" and n.decimals == 1,
      n and string.format("%s %s %s", n.value, tostring(n.unit), tostring(n.decimals)))
  end
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 0, voltage_callout = 2, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)
    rig.setClock(1); rig.step(20.4)
    local n = rig.spoken[#rig.spoken]
    check("callout = 2 speaks the average cell in hundredths of a volt",
      n ~= nil and n.value == 340 and n.unit == "V" and n.decimals == 2,
      n and string.format("%s %s %s", n.value, tostring(n.unit), tostring(n.decimals)))
  end
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)
    rig.setClock(1); rig.step(20.4)
    check("callout = 0 speaks nothing", #rig.spoken == 0,
      #rig.spoken .. " number(s) spoken")
  end

  -- The repeat interval still governs a standing low reading.
  do
    local rig = newVoltageRig({voltage = true, voltage_hold = 0, voltage_callout = 0, voltage_repeat_interval = 10})
    rig.setClock(0); rig.step(20.4)   -- seed
    rig.setClock(1); rig.step(20.4)   -- fire
    rig.setClock(5); rig.step(20.4)   -- within 10s
    check("a standing low reading is not repeated before the interval",
      rig.countLow() == 1, "lowvoltage.wav played " .. rig.countLow() .. "x")
    rig.setClock(11); rig.step(20.4)  -- 10s after the first
    check("a standing low reading repeats after the interval",
      rig.countLow() == 2, "lowvoltage.wav played " .. rig.countLow() .. "x")
  end

  -- Settings normalization clamps stored voltage_hold to 0..10 and voltage_callout to 0..2.
  do
    local savedStore = package.loaded["rfsuite.lib.settings_store"]
    package.loaded["rfsuite.lib.settings_store"] = nil
    local store = assert(loadfile("lib/settings_store.lua"))()
    package.loaded["rfsuite.lib.settings_store"] = savedStore

    local lower = store.audioEvents({events = {voltage_hold = -5, voltage_callout = -2}})
    check("negative voltage_hold is clamped to 0", lower.voltage_hold == 0,
      "got " .. tostring(lower.voltage_hold))
    check("negative voltage_callout is clamped to 0", lower.voltage_callout == 0,
      "got " .. tostring(lower.voltage_callout))

    local upper = store.audioEvents({events = {voltage_hold = 25, voltage_callout = 99}})
    check("voltage_hold > 10 is clamped to 10", upper.voltage_hold == 10,
      "got " .. tostring(upper.voltage_hold))
    check("voltage_callout > 2 is clamped to 2", upper.voltage_callout == 2,
      "got " .. tostring(upper.voltage_callout))
  end

  -- Can-fail: strip the hold guard and require the sag to fire.
  local source = readFile(AUDIO_PATH)
  local stripped = source:gsub("if %(now %- lowVoltageHoldStart%) < hold then return end", "", 1)
  check("the hold guard could be located in announceVoltage()", stripped ~= source)
  local rig = newVoltageRig(
    {voltage = true, voltage_hold = 2.0, voltage_callout = 0, voltage_repeat_interval = 10}, stripped)
  rig.setClock(0); rig.step(20.4)
  rig.setClock(1); rig.step(20.4)
  check("without the hold guard the sag fires (this check can go red)",
    rig.countLow() == 1, "lowvoltage.wav played " .. rig.countLow() .. "x")
end

out("")
out("case 8: the low-voltage hold filter and spoken callout")
voltageChecks()


_G.system, os.clock = savedSystem, savedOsClock
package.loaded["rfsuite.lib.require"] = savedRequire
_G.UNIT_VOLT = savedUnitVolt
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
out("form.clear() calls: " .. cleared)
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")