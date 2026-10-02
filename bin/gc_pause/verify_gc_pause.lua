-- Behaviour check for the incremental collector's pause (issue #2389).
--
-- Run it:
--     lua5.3 bin/gc_pause/verify_gc_pause.lua
--     lua5.3 bin/gc_pause/verify_gc_pause.lua --self-test
--
-- Four claims, none of which needs a radio:
--
--   1. `collectgarbage("setpause", n)` returns the PREVIOUS value, and
--      `collectgarbage("setpause")` -- with the argument omitted -- does not
--      read the current one, it SETS THE PAUSE TO 0. Pause 0 is "collect as
--      constantly as possible". This is what makes the function unusable as a
--      getter, and it is the reason main.lua prints the value it applied
--      instead of reading it back. Measured on the Lua 5.3.6 in this checkout,
--      and pinned so a future interpreter cannot quietly change it under a
--      comment that cites it.
--   2. main.lua's init() sets the pause exactly once per call, to the one
--      documented constant, with an explicit value, and does so BEFORE
--      background_task.init() -- the point is to be on the new schedule while
--      the subsystems allocate.
--   3. No file under src/ calls collectgarbage("setpause") or
--      ("setstepmul") without an explicit value. Claim 1 makes that a
--      foot-gun, and it is the kind of line that comes back.
--   4. The forced full collects in src/ are exactly the teardown ones: three
--      ESC forward-programming dispose paths and Queue:clear(). The hot path
--      Queue:_finish() must stay clean -- that behaviour is checked
--      functionally by bin/msp_gc/verify_msp_disconnect.lua, so this is only
--      the tripwire that the call sites do not move.
--
-- What this harness deliberately does NOT claim: that a pause of 120 is right.
-- Nothing in the repository states Ethos's Lua heap limit and there is no
-- on-device run yet. The value is a starting point to be measured
-- (docs/memory-and-module-lifecycle.md section 9.4), and this check pins the
-- contract around it, not the outcome.
--
-- --self-test proves the checks can go red by pointing the same predicates at
-- deliberately sabotaged copies, the way bin/ci/verify_pr_workflow.py does. A
-- bound that both the real code and the broken code satisfy proves nothing.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local MAIN = SRC .. "/main.lua"

local realPrint = print
local realCollectgarbage = collectgarbage

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
  return ok
end

local function banner(title)
  print()
  print(title)
end

local function readFile(path)
  local fh = assert(io.open(path, "rb"), "cannot read " .. path)
  local text = fh:read("*a")
  fh:close()
  return text
end

local function writeFile(path, text)
  local fh = assert(io.open(path, "wb"), "cannot write " .. path)
  fh:write(text)
  fh:close()
end

-- ---------------------------------------------------------------------------
-- 1. what the interpreter actually does with "setpause"
-- ---------------------------------------------------------------------------
banner("the collector pause as this Lua treats it")

do
  -- Ask for a known value first, so the "previous" answer to the bare call is
  -- unambiguous no matter what the default on this interpreter happens to be.
  local known = 150
  local wasDefault = realCollectgarbage("setpause", known)

  -- No value at all. If this were a getter, the pause would still be `known`.
  realCollectgarbage("setpause")

  -- The setter returns the value that was in force before it ran, so the next
  -- call reports whatever the bare call just left behind.
  local afterBare = realCollectgarbage("setpause", known)
  check('collectgarbage("setpause") without a value sets the pause to 0, it does not read it',
    afterBare == 0, "pause in force afterwards was " .. tostring(afterBare) .. ", expected 0")
  check("the bare call did not merely report the value it was given",
    afterBare ~= known, "it returned " .. tostring(afterBare))

  -- Put the interpreter back the way it was found. Leaving the pause at 0 would
  -- make every later measurement in this process meaningless.
  realCollectgarbage("setpause", wasDefault)
  local restored = realCollectgarbage("setpause", known)
  check("the original pause is restored afterwards",
    restored == wasDefault,
    string.format("expected %s, found %s", tostring(wasDefault), tostring(restored)))
  realCollectgarbage("setpause", wasDefault)

  print(string.format("        .. Lua default pause reported by the setter: %s", tostring(wasDefault)))
end

-- ---------------------------------------------------------------------------
-- predicates, written so the self-test can aim them at a broken copy
-- ---------------------------------------------------------------------------

-- Loads a main.lua with the three subsystems replaced by recorders and the
-- collectgarbage global replaced by a spy, then calls its init().
--
-- The subsystems are stubbed because the claim is about WHEN and HOW the pause
-- is set relative to them, not about what they do -- main.lua's own header
-- states it "does nothing else". Stubbing them also keeps the check independent
-- of Ethos.
local function loadMainAndInit(path)
  local order = {}
  local gcCalls = {}
  local printed = {}

  local function stub(name)
    return {
      init = function()
        order[#order + 1] = name
        return name .. "Handle"
      end,
    }
  end

  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "tasks/background.lua" then return stub("background") end
    if name == "app/tool.lua" then return stub("tool") end
    if name == "widgets/dashboard.lua" then return stub("dashboard") end
    return {}
  end

  -- main.lua's init() asks for system.registerGlassesWidget; leave it absent so
  -- the ActiveLook branch is not taken and the check stays about the pause.
  _G.system = { getMemoryUsage = function() return {} end }

  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(parts, "\t")
  end

  _G.collectgarbage = function(...)
    gcCalls[#gcCalls + 1] = { n = select("#", ...), a1 = (...), a2 = (select(2, ...)) }
    return realCollectgarbage(...)
  end

  local ok, mod = pcall(dofile, path)
  local err = nil
  if ok and type(mod) == "table" and type(mod.init) == "function" then
    local ok2, err2 = pcall(mod.init)
    if not ok2 then err = err2 end
  else
    err = not ok and mod or "main.lua did not return {init=...}"
  end

  _G.print = realPrint
  _G.collectgarbage = realCollectgarbage
  package.loaded["rfsuite.lib.require"] = nil

  return { gcCalls = gcCalls, printed = printed, order = order, err = err }
end

-- Claims 2. Returns how many of them failed, so the self-test can compare a
-- real main.lua against a sabotaged one without its own output counting.
local function mainPauseChecks(path, quiet)
  local beforeFail, beforeChecks = failures, checks
  local quietBefore = quiet

  local run = loadMainAndInit(path)
  if not quietBefore then
    check("main.lua loads and its init() runs under this harness", run.err == nil, run.err)
  end

  if run.err == nil then
    local setpause = {}
    for _, call in ipairs(run.gcCalls) do
      if call.a1 == "setpause" then setpause[#setpause + 1] = call end
    end

    check("init() calls collectgarbage(\"setpause\") exactly once",
      #setpause == 1, "found " .. #setpause .. " such calls")

    if setpause[1] then
      check("it passes an explicit value, so the pause cannot land on 0",
        setpause[1].n == 2 and type(setpause[1].a2) == "number",
        string.format("argument count %s, value %s", tostring(setpause[1].n), tostring(setpause[1].a2)))
      check("the value is the documented 120% of live",
        setpause[1].a2 == 120, "found " .. tostring(setpause[1].a2))
    end

    local sawBackground = false
    for _, label in ipairs(run.order) do
      if label == "background" then sawBackground = true end
    end
    check("the pause is set before background_task.init(), not after",
      sawBackground, "background_task.init() was never reached: " .. table.concat(run.order, ","))

    local reported = false
    for _, line in ipairs(run.printed) do
      if line:find("pause=120") then reported = true end
    end
    check("init() reports the pause it applied instead of reading it back",
      reported, "the boot log carries no pause= line; it has to, because the setter cannot be used as a getter")
  end

  local found = failures - beforeFail
  local total = checks - beforeChecks
  if quietBefore then
    -- undo the accounting the sabotaged run just did; the self-test judges it
    -- by comparing counts, not by inheriting a failure
    failures = beforeFail
    checks = beforeChecks
  end
  return found, total
end

-- Windows has no find(1) and POSIX shells have no dir(1), and the Lua stdlib
-- has no directory API at all, so listing needs one shell command. This is the
-- platform branch that keeps the check runnable on both: the first version used
-- `dir /s /b` unconditionally and was green on the author's Windows box while
-- reporting "scanned 0 .lua files" on the CI runner -- a check that passes by
-- finding nothing is worse than no check, because the count is what catches it.
local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local function listLuaFiles(dir)
  local cmd = IS_WINDOWS
    and ('dir /s /b "' .. dir .. '\\*.lua" 2>nul')
    or ("find '" .. dir .. "' -type f -name '*.lua'")
  local pipe = io.popen(cmd)
  if not pipe then return nil end
  local files = {}
  for line in pipe:lines() do files[#files + 1] = line end
  pipe:close()
  return files
end

-- Returns offenders and the number of files looked at. Takes a file list rather
-- than a directory, so the self-test can point it at a single planted file
-- without having to create a directory to plant it in.
local function scanBareSetters(files)
  local offenders = {}
  if not files then return offenders, 0 end
  for _, path in ipairs(files) do
    local short = path:match("[^/\\]+$") or path
    local lineNo = 0
    for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
      lineNo = lineNo + 1
      local body = line:gsub("^%s*", "")
      if body:sub(1, 2) ~= "--"
        and (body:find("collectgarbage%s*%(%s*[\"']setpause[\"']%s*%)")
          or body:find("collectgarbage%s*%(%s*[\"']setstepmul[\"']%s*%)")) then
        offenders[#offenders + 1] = string.format("%s:%d", short, lineNo)
      end
    end
  end
  return offenders, #files
end

-- Counts real forced cycles in a file, not the prose about them: queue.lua's
-- header is mostly a paragraph about the collect it used to have, and a search
-- that does not skip comments finds four "collectgarbage(" there and one in
-- clear().
local function forcedCollectsIn(path)
  local count = 0
  for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
    local body = line:gsub("^%s*", "")
    if body:sub(1, 2) ~= "--" then
      -- A forced cycle: collectgarbage() or collectgarbage("collect"). The
      -- quoted "count" is a reading, not a cycle.
      if body:find("collectgarbage%s*%(%s*[\"']collect[\"']%s*%)")
        or body:find("collectgarbage%s*%(%s*%)") then
        count = count + 1
      end
    end
  end
  return count
end

-- ---------------------------------------------------------------------------
-- 2. main.lua's contract
-- ---------------------------------------------------------------------------
banner("main.lua sets the pause, once, before the subsystems run")
mainPauseChecks(MAIN)

-- ---------------------------------------------------------------------------
-- 3. the setter is never called without a value anywhere in src/
-- ---------------------------------------------------------------------------
banner("src/ never calls the pause/stepmul setters without a value")
do
  local files = listLuaFiles(SRC)
  check("could list the Lua sources under src/rfsuite", files ~= nil)
  local offenders, scanned = scanBareSetters(files)
  check(string.format("scanned %d .lua files under src/rfsuite", scanned), scanned > 40, scanned)
  check("no collectgarbage(\"setpause\") or (\"setstepmul\") without a value",
    #offenders == 0, table.concat(offenders, ", "))
end

-- ---------------------------------------------------------------------------
-- 4. the forced full collects are the teardown ones
-- ---------------------------------------------------------------------------
banner("forced full collects stand only at teardown boundaries")
do
  local queue = SRC .. "/tasks/msp/queue.lua"
  local fourway = SRC .. "/app/pages/esc_forward_4way.lua"
  local vendor = SRC .. "/app/pages/esc_forward_vendor.lua"

  local text = readFile(queue)
  local body = text:match("(function Queue:_finish%b())%s*(.-)\nend")
  check("Queue:_finish() forces no cycle -- the hot path",
    body ~= nil and body:find("collectgarbage") == nil,
    "queue.lua's _finish() body calls collectgarbage()")
  check("Queue:clear() still forces one -- a real teardown",
    forcedCollectsIn(queue) == 1, forcedCollectsIn(queue))
  check("the three ESC forward-programming dispose paths still force theirs",
    forcedCollectsIn(fourway) == 1 and forcedCollectsIn(vendor) == 2,
    string.format("4way=%d vendor=%d", forcedCollectsIn(fourway), forcedCollectsIn(vendor)))
end

-- ---------------------------------------------------------------------------
-- self-test: the same predicates, aimed at sabotaged copies
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--self-test" then
  local savedFail, savedChecks = failures, checks
  -- Sabotage (b) really does put the collector at pause 0, because the spy
  -- forwards to the real function -- which is the point. Put it back after each
  -- attempt so the next measurement means anything.
  local pauseBefore = realCollectgarbage("setpause", 200)
  -- os.tmpname() rather than a directory this harness creates: it is portable,
  -- and nothing here needs a directory now.
  local source = readFile(MAIN)

  print()
  print("self-test: each check is shown going red on a sabotaged copy")
  local ok = true

  -- Plain find/replace: no pattern escaping, and the needle can be read as the
  -- thing it is actually looking for.
  local function sabotage(label, path, needle, replacement)
    local s, e = source:find(needle, 1, true)
    if not s then
      ok = false
      print(string.format("  FAIL  %s -- Muster nicht gefunden: %s", label, needle))
      return
    end
    writeFile(path, source:sub(1, s - 1) .. replacement .. source:sub(e + 1))
    local found, total = mainPauseChecks(path, true)
    realCollectgarbage("setpause", pauseBefore)
    local wentRed = found > 0
    ok = ok and wentRed
    print(string.format("  %s  %s -- %d von %d Checks rot",
      wentRed and "ok  " or "FAIL", label, found, total))
    os.remove(path)
  end

  -- (a) the call never happens
  sabotage("applyGcPause() nie aufgerufen",
    os.tmpname(), "  applyGcPause()", "  -- removed on purpose")

  -- (b) the trap: read the pause back with the argument omitted
  sabotage('collectgarbage("setpause") ohne Wert als Getter benutzt',
    os.tmpname(),
    'pcall(collectgarbage, "setpause", GC_PAUSE_PERCENT)',
    'pcall(collectgarbage, "setpause")')

  -- (c) a different value than the one the boot log reports
  sabotage("ein anderer Wert als der dokumentierte",
    os.tmpname(), "GC_PAUSE_PERCENT = 120", "GC_PAUSE_PERCENT = 90")

  -- (d) the scanner finds a planted bare setter
  local planted = os.tmpname()
  writeFile(planted, 'local p = collectgarbage("setpause")\nreturn p\n')
  local offenders = scanBareSetters({ planted })
  local caught = #offenders > 0
  ok = ok and caught
  print(string.format("  %s  ein gepflanzter blinder Setter wird gefunden -- %d Treffer",
    caught and "ok  " or "FAIL", #offenders))
  os.remove(planted)

  -- (e) a teardown collect that quietly disappeared
  local queueCopy = os.tmpname()
  local queueText = readFile(SRC .. "/tasks/msp/queue.lua")
  local qs, qe = queueText:find("\n  collectgarbage()", 1, true)
  if not qs then
    ok = false
    print("  FAIL  der Teardown-Collect in Queue:clear() wurde nicht gefunden")
  else
    writeFile(queueCopy, queueText:sub(1, qs - 1) .. queueText:sub(qe + 1))
    local kept = forcedCollectsIn(queueCopy)
    local reported = kept == 0
    ok = ok and reported
    print(string.format("  %s  ein verschwundener Teardown-Collect wird gezaehlt -- clear() hat noch %d",
      reported and "ok  " or "FAIL", kept))
  end
  os.remove(queueCopy)

  realCollectgarbage("setpause", pauseBefore)

  failures, checks = savedFail, savedChecks
  print()
  print("self-test: " .. (ok and "every check went red as it should" or "SOME CHECKS STAYED GREEN"))
  os.exit(ok and 0 or 1)
end

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)