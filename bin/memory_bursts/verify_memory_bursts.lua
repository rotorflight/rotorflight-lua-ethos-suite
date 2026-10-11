-- Behaviour check for memory burst and churn mitigations (issues #2295, #2530).
--
-- Run it:
--     lua5.4 bin/memory_bursts/verify_memory_bursts.lua
--     lua5.4 bin/memory_bursts/verify_memory_bursts.lua --self-test
--
-- What is pinned:
--   1. app/pages/settings_dashboard_settings.lua:
--      Theme discovery in configuredThemes() must probe file presence (via io.open)
--      without compiling chunks via loadfile(). Calling loadfile() across all themes
--      creates an acute memory burst on radios near the 2048 kB heap ceiling.
--   2. app/pages/diagnostics_rfstatus.lua:
--      Updates are rate-limited to at most 1 Hz rather than running unthrottled
--      on every wakeup tick (20-30 Hz) or every session.update snapshot. Rapid
--      frame churn is throttled, but connection state changes update immediately.
--
-- --self-test loads code modified to mirror the pre-fix behaviour and verifies
-- that the checks go RED.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = (scriptDir() .. "/../.."):gsub("\\", "/")
local SUITE = ROOT .. "/src/rfsuite"
local SELF_TEST = arg and arg[1] == "--self-test"

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
  return ok
end

-- ── 1. Dashboard Settings Theme Probing ──────────────────────────────────────

local function runThemeProbingCheck(useOldBehavior)
  local sourcePath = SUITE .. "/app/pages/settings_dashboard_settings.lua"
  local f = assert(io.open(sourcePath, "r"))
  local content = f:read("*a")
  f:close()

  if useOldBehavior then
    -- Revert fileExists check back to loadfile probing
    content = content:gsub(
      "if fileExists%(dir %.%. \"/configure%.lua\"%) then",
      "local ok = pcall(function() return assert(loadfile(dir .. \"/configure.lua\")) end)\n      if ok then"
    )
  end

  local configureLoadfileCalls = 0
  local ioOpenCalls = 0
  local realLoadfile = loadfile
  local realIoOpen = io.open

  local fakeEnv = {}
  for k, v in pairs(_G) do fakeEnv[k] = v end

  fakeEnv.loadfile = function(path, ...)
    local resolved = path
    if type(path) == "string" and path:sub(1, 1) ~= "/" and not path:match("^%a:") then
      resolved = SUITE .. "/" .. path
    end
    if type(path) == "string" and path:match("configure%.lua$") then
      configureLoadfileCalls = configureLoadfileCalls + 1
    end
    return realLoadfile(resolved, ...)
  end

  fakeEnv.io = {
    open = function(path, mode)
      local resolved = path
      if type(path) == "string" and path:sub(1, 1) ~= "/" and not path:match("^%a:") then
        resolved = SUITE .. "/" .. path
      end
      if type(path) == "string" and path:match("configure%.lua$") then
        ioOpenCalls = ioOpenCalls + 1
      end
      return realIoOpen(resolved, mode)
    end
  }

  fakeEnv.lcd = {
    getWindowSize = function() return 800, 480 end,
    loadMask = function() return false end,
  }

  local formButtons = {}
  fakeEnv.form = {
    clear = function() end,
    height = function() return 40 end,
    addButton = function(_, rect, opts)
      formButtons[#formButtons + 1] = opts
      return { focus = function() end }
    end,
    addStaticText = function() end,
  }

  fakeEnv.rfsuite = {
    session = {},
    widgets = {
      dashboard = {
        setPreferences = function() end,
        preferences = function() return {} end,
      }
    }
  }

  fakeEnv.package = {
    loaded = {
      ["rfsuite.lib.require"] = function(p)
        if p == "lib/bus.lua" then
          return { publish = function() end, subscribe = function() return 1 end, unsubscribe = function() end }
        elseif p == "app/close_key.lua" then
          return { shouldHandleClose = function() return false end }
        elseif p == "app/header.lua" then
          return { build = function() return { focusMenu = function() end } end }
        elseif p == "app/tile_grid.lua" then
          return {
            metrics = function() return 4, 100, 60, 10, 1 end,
            fitLabel = function(l) return l end,
          }
        elseif p == "lib/settings_store.lua" then
          return {
            load = function() return {} end,
            save = function() end,
            setDashboardTheme = function() end,
            dashboardTheme = function() return {} end,
            clone = function(s) return s end,
          }
        elseif p == "widgets/dashboard/context.lua" then
          return fakeEnv.rfsuite
        end
        return {}
      end
    }
  }

  local chunk, err = load(content, "@settings_dashboard_settings.lua", "t", fakeEnv)
  assert(chunk, err)
  local mod = chunk()

  local opened = false
  mod.open({
    onBack = function() opened = true end,
  })

  return {
    buttonsCount = #formButtons,
    configureLoadfileCalls = configureLoadfileCalls,
    ioOpenCalls = ioOpenCalls,
  }
end

-- ── 2. Diagnostics Status Wakeup / Rate Limiting ─────────────────────────────

local function runDiagnosticsStatusCheck(useOldBehavior)
  local sourcePath = SUITE .. "/app/pages/diagnostics_rfstatus.lua"
  local f = assert(io.open(sourcePath, "r"))
  local content = f:read("*a")
  f:close()

  if useOldBehavior then
    -- Revert REFRESH_INTERVAL throttling to unthrottled calls
    content = content:gsub("local REFRESH_INTERVAL = 1%.0\n", "")
    content = content:gsub(
      "local lastUpdate = 0.-return {%s*onSession = function%(session%) update%(session, false%) end,%s*wakeup = function%(%) update%(ctx%.session, false%) end,%s*}",
      [[local function update(session)
      common.updateField(fields.memory, memoryText())
      common.updateField(fields.luaMemory, luaMemoryText())
      common.updateStatus(fields.rfModule, moduleEnabled())
      common.updateStatus(fields.mspSensor, haveMspSensor())
      common.updateStatus(fields.connected, session.connected)
      common.updateStatus(fields.api, true)
    end

    update(ctx.session)
    return {
      onSession = update,
      wakeup = function() update(ctx.session) end,
    }]]
    )
  end

  local simClock = 100.0
  local updateFieldCalls = 0
  local updateStatusCalls = 0

  local fakeEnv = {}
  for k, v in pairs(_G) do fakeEnv[k] = v end

  fakeEnv.os = {
    clock = function() return simClock end,
  }

  fakeEnv.system = {
    getMemoryUsage = function() return { ramAvailable = 2000000 } end,
    getSource = function() return nil end,
  }

  fakeEnv.model = {
    getModule = function() return nil end,
  }

  local pageHandlers = nil
  local dummyField = { value = function() end }

  fakeEnv.package = {
    loaded = {
      ["rfsuite.lib.require"] = function(p)
        if p == "app/diagnostics_common.lua" then
          return {
            openReadOnlyPage = function(opts, title, builder)
              local ctx = {
                session = { connected = false },
              }
              pageHandlers = builder(ctx)
            end,
            addValueLine = function() return dummyField end,
            updateField = function() updateFieldCalls = updateFieldCalls + 1 end,
            updateStatus = function() updateStatusCalls = updateStatusCalls + 1 end,
            formatBytes = function(n) return tostring(n) end,
          }
        end
        return {}
      end
    }
  }

  local chunk, err = load(content, "@diagnostics_rfstatus.lua", "t", fakeEnv)
  assert(chunk, err)
  local mod = chunk()
  mod.open({})

  assert(pageHandlers and pageHandlers.wakeup and pageHandlers.onSession, "Page handlers must be returned")

  local initialFieldUpdates = updateFieldCalls

  -- 1. Simulate 30 rapid wakeup ticks over 0.6 seconds (20ms apart)
  for _ = 1, 30 do
    simClock = simClock + 0.02
    pageHandlers.wakeup()
  end
  local fieldUpdatesAfterWakeup = updateFieldCalls

  -- 2. Simulate 20 rapid onSession ticks with same connected state over 0.2s
  for _ = 1, 20 do
    simClock = simClock + 0.01
    pageHandlers.onSession({ connected = false })
  end
  local fieldUpdatesAfterSessionSame = updateFieldCalls

  -- 3. Advance clock past 1.0s interval
  simClock = simClock + 1.1
  pageHandlers.wakeup()
  local fieldUpdatesAfterOneSec = updateFieldCalls

  -- 4. Connection state changes immediately (link connects)
  pageHandlers.onSession({ connected = true })
  local fieldUpdatesAfterStateChange = updateFieldCalls

  return {
    initialFieldUpdates = initialFieldUpdates,
    fieldUpdatesAfterWakeup = fieldUpdatesAfterWakeup,
    fieldUpdatesAfterSessionSame = fieldUpdatesAfterSessionSame,
    fieldUpdatesAfterOneSec = fieldUpdatesAfterOneSec,
    fieldUpdatesAfterStateChange = fieldUpdatesAfterStateChange,
  }
end

-- ── Test Execution ──────────────────────────────────────────────────────────

if not SELF_TEST then
  print("case 1: Dashboard Settings probes theme presence without loadfile()")
  local themeRes = runThemeProbingCheck(false)
  check("configuredThemes() creates buttons for visible themes", themeRes.buttonsCount > 0, themeRes.buttonsCount)
  check("configuredThemes() does not execute loadfile() during discovery", themeRes.configureLoadfileCalls == 0,
    string.format("%d loadfile calls recorded", themeRes.configureLoadfileCalls))
  check("configuredThemes() probes configure.lua via io.open()", themeRes.ioOpenCalls > 0,
    string.format("%d io.open calls recorded", themeRes.ioOpenCalls))

  print("case 2: Diagnostics Status rate limits wakeup and session churn")
  local diagRes = runDiagnosticsStatusCheck(false)
  check("initial page open populates status fields", diagRes.initialFieldUpdates > 0, diagRes.initialFieldUpdates)
  check("rapid 30 wakeup ticks within 0.6s are throttled (0 extra field updates)",
    diagRes.fieldUpdatesAfterWakeup == diagRes.initialFieldUpdates,
    string.format("got %d updates (diff: %d)", diagRes.fieldUpdatesAfterWakeup, diagRes.fieldUpdatesAfterWakeup - diagRes.initialFieldUpdates))
  check("rapid 20 onSession ticks with same connection state are throttled",
    diagRes.fieldUpdatesAfterSessionSame == diagRes.initialFieldUpdates,
    string.format("got %d updates (diff: %d)", diagRes.fieldUpdatesAfterSessionSame, diagRes.fieldUpdatesAfterSessionSame - diagRes.initialFieldUpdates))
  check("wakeup after >= 1.0s interval triggers an update",
    diagRes.fieldUpdatesAfterOneSec > diagRes.fieldUpdatesAfterSessionSame,
    string.format("got %d vs %d", diagRes.fieldUpdatesAfterOneSec, diagRes.fieldUpdatesAfterSessionSame))
  check("connection state flip (session.connected) updates immediately",
    diagRes.fieldUpdatesAfterStateChange > diagRes.fieldUpdatesAfterOneSec,
    string.format("got %d vs %d", diagRes.fieldUpdatesAfterStateChange, diagRes.fieldUpdatesAfterOneSec))

  if failures > 0 then
    print(string.format("\n%d checks, %d failures", checks, failures))
    os.exit(1)
  else
    print(string.format("\nall %d checks passed", checks))
    os.exit(0)
  end
else
  print("self-test: verifying harness detects unthrottled and burst behavior")
  local oldTheme = runThemeProbingCheck(true)
  check("old theme probing triggers loadfile() calls", oldTheme.configureLoadfileCalls > 0,
    string.format("got %d loadfile calls", oldTheme.configureLoadfileCalls))

  local oldDiag = runDiagnosticsStatusCheck(true)
  check("old diagnostics status triggers updates on every wakeup tick",
    oldDiag.fieldUpdatesAfterWakeup > oldDiag.initialFieldUpdates,
    string.format("got %d updates vs initial %d", oldDiag.fieldUpdatesAfterWakeup, oldDiag.initialFieldUpdates))

  if failures > 0 then
    print(string.format("\nself-test: %d checks, %d failures", checks, failures))
    os.exit(1)
  else
    print(string.format("\nself-test: all %d checks passed", checks))
    os.exit(0)
  end
end
