-- Behaviour check for user dashboard themes: a theme folder the pilot puts in
-- SCRIPTS:/rfsuite.user/dashboard/<folder>/ is listed, can be chosen, keeps
-- settings of its own, and is drawn by the widget -- and one that is missing or
-- broken is replaced by Default instead of stopping the dashboard.
--
-- Run it from anywhere:
--     lua5.4 bin/user_themes/verify_user_themes.lua [--self-test]
--
-- What it drives, and why:
--   * lib/dashboard_themes.lua and lib/settings_store.lua, real. The user
--     folder is the fixtures/dashboard/ folder beside this file, served at
--     SCRIPTS:/rfsuite.user/dashboard through loadfile, io.open and
--     system.listFiles. The listing carries "..", a file and a folder name
--     with a space, as a card can.
--   * widgets/dashboard.lua, real, on bin/perf/instruction_harness.lua's Ethos
--     stubs, once per stored theme, each in its own interpreter so every theme
--     starts cold, as on the radio. The scenarios: a working user theme, one
--     whose init.lua does not compile, one whose preflight screen errors, one
--     that is no longer on the card, and the shipped Default as the control.
--
-- --self-test takes out one piece at a time (the "user/" source in the parser,
-- the widget's init.lua fallback, its state fallback, the listing's init.lua
-- test, the settings store's use of the parser) and requires at least one
-- check to go red for each. The baseline run is required to be green first.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local DIR = scriptDir()
local LUA = os.getenv("LUA") or (arg and arg[-1]) or "lua5.4"
local USER = "SCRIPTS:/rfsuite.user/dashboard"

local MUTATIONS = {
  parse_user = {file = "lib/dashboard_themes.lua", from = 'elseif source == "user" then', to = "elseif false then"},
  widget_init_fallback = {file = "widgets/dashboard.lua", from = "if isUser then", to = "if false then"},
  widget_state_fallback = {file = "widgets/dashboard.lua", from = "if def.user then", to = "if false then"},
  list_needs_init = {file = "lib/dashboard_themes.lua", from = 'if fileExists(dir .. "/init.lua") then', to = "if true then"},
  store_uses_parser = {file = "lib/settings_store.lua", from = "return dashboardThemes.path(value) or default", to = "return default"},
}
local MUTATION_ORDER = {"parse_user", "widget_init_fallback", "widget_state_fallback", "list_needs_init", "store_uses_parser"}

-- ---------------------------------------------------------------------------
-- Scenario process: one stored theme (or "lib"), one optional mutation.
-- Prints "CHECK <1|0> <label> [detail]" lines.
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--scenario" then
  local SCENARIO = arg[2]
  local MUTATION = MUTATIONS[arg[3] or ""]
  local rawLoadfile, rawOpen = loadfile, io.open
  local H = dofile(DIR .. "/../perf/instruction_harness.lua")
  local out = H.print
  local hLoadfile, hOpen = loadfile, io.open
  local FIXTURES = DIR .. "/fixtures/dashboard"

  local function emit(ok, label, detail)
    out(string.format("CHECK %d %s%s", ok and 1 or 0, label, detail and (" | " .. tostring(detail)) or ""))
  end

  local function fixturePath(path)
    if type(path) == "string" and path:sub(1, #USER) == USER then
      return FIXTURES .. path:sub(#USER + 1)
    end
  end

  local function replacePlain(s, from, to)
    local i, j = s:find(from, 1, true)
    assert(i, "mutation text not found: " .. from)
    return s:sub(1, i - 1) .. to .. s:sub(j + 1)
  end

  local loaded = {}
  loadfile = function(path, ...)
    local real = fixturePath(path)
    if real then
      loaded[#loaded + 1] = path
      return rawLoadfile(real, ...)
    end
    loaded[#loaded + 1] = tostring(path)
    if MUTATION and path == MUTATION.file then
      local f = assert(rawOpen(H.ROOT .. "/" .. path, "r"))
      local src = f:read("a")
      f:close()
      return load(replacePlain(src, MUTATION.from, MUTATION.to), "@" .. path)
    end
    return hLoadfile(path, ...)
  end
  io.open = function(path, mode)
    local real = fixturePath(path)
    if real then return rawOpen(real, mode) end
    return hOpen(path, mode)
  end

  local listCalls = 0
  system.listFiles = function(path)
    listCalls = listCalls + 1
    if path == USER then
      return {"..", "noinit", "notes.txt", "has space", "good", "broken", "badstate"}
    end
    return nil
  end

  local function loadedPath(path)
    for i = 1, #loaded do if loaded[i] == path then return true end end
    return false
  end

  if SCENARIO == "lib" then
    local requireModule = assert(loadfile("lib/require.lua"))()
    local themes = requireModule("lib/dashboard_themes.lua")

    local source, folder = themes.parse("user/good")
    emit(source == "user" and folder == "good", "parse reads user/<folder>", tostring(source) .. " " .. tostring(folder))
    emit(themes.key("user/good") == "user/good", "a user theme keeps the user/ prefix in its key", themes.key("user/good"))
    local dir, isUser = themes.dir("user/good")
    emit(dir == USER .. "/good" and isUser == true, "a user theme loads from the user folder", dir)
    emit(themes.key("system/default") == "default" and themes.key("default") == "default" and themes.key("@kse4") == "kse4",
      "shipped keys are unchanged")
    emit(themes.key("system/nope") == nil, "an unknown shipped theme is refused")
    emit(themes.key("user/has space") == nil and themes.key("user/../x") == nil and themes.key("user/a/b") == nil,
      "a user folder name with a space or a path in it is refused")

    local list = themes.listUser(true)
    local names = {}
    for i = 1, #list do names[i] = list[i].folder end
    local joined = table.concat(names, ",")
    emit(joined == "badstate,broken,good", "the listing has each folder with an init.lua, sorted", joined)
    emit(list[3] and list[3].path == "user/good" and list[3].label == "good", "a listed theme is stored as user/<folder>")
    local before = listCalls
    local again = themes.listUser()
    emit(again == list and listCalls == before, "the listing is kept until it is refreshed")

    local store = requireModule("lib/settings_store.lua")
    H.settings = {
      dashboard = {use_same_theme = false, theme_preflight = "user/good", theme_inflight = "user/gone", theme_postflight = "system/nope"},
      ["dashboard.user/good"] = {v_min = 11},
      ["dashboard.default"] = {v_min = 22},
    }
    local settings = store.load()
    local d = settings.dashboard
    emit(d.theme_preflight == "user/good", "a stored user theme survives a load", d.theme_preflight)
    emit(d.theme_inflight == "user/gone", "a user theme not on the card is kept as stored", d.theme_inflight)
    emit(d.theme_postflight == "user/good", "an unknown theme falls back to the preflight choice", d.theme_postflight)
    emit(d.theme == "user/good", "the theme key names the user theme", d.theme)
    local prefs = store.dashboardTheme(settings, "user/good")
    emit(prefs and tonumber(prefs.v_min) == 11, "a user theme reads its own settings section", prefs and prefs.v_min)
    -- A user copy named like a shipped theme ("user/default" beside "default").
    store.setDashboardTheme(settings, "user/default", {v_min = 12})
    local shipped = settings["dashboard.default"]
    emit(settings["dashboard.user/default"] and settings["dashboard.user/default"].v_min == 12
      and shipped and tonumber(shipped.v_min) == 22,
      "saving a user theme's settings leaves a shipped theme of the same name alone")
    local reloaded = store.withDefaults(settings)
    emit(reloaded["dashboard.user/good"] and tonumber(reloaded["dashboard.user/good"].v_min) == 11,
      "a user theme's settings section is kept when the settings are normalised")
    out("DONE")
    return
  end

  H.settings = {dashboard = {use_same_theme = true, theme_preflight = SCENARIO}}
  H.watchPrint("not loaded, using Default")
  H.watchPrint("paint failed")
  local errors = {}

  local requireModule = assert(loadfile("lib/require.lua"))()
  local bus = requireModule("lib/bus.lua")
  requireModule("widgets/dashboard.lua").init({})
  local def = assert(H.registered.widgets[1], "dashboard did not register a widget")
  local widget = def.create()
  widget.flightmode = {update = function() return "preflight" end, reset = H.noop}

  -- Errors are collected here rather than through H.measure, which only prints them.
  local TICKS = 12
  local function run(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then errors[#errors + 1] = tostring(err) end
  end
  for i = 1, TICKS do
    H.advance(0.05)
    if i == 3 then run(bus.publish, "session.update", H.sessionSnapshot(false)) end
    run(def.wakeup, widget)
    run(def.paint, widget)
  end

  local fallbacks = H.watched("not loaded, using Default")
  local paintFailed = H.watched("paint failed")
  emit(#errors == 0, SCENARIO .. ": no callback raised an error", errors[1])
  emit(paintFailed == 0, SCENARIO .. ": no paint failed")
  emit(widget.dashboardEverPainted == true, SCENARIO .. ": the dashboard was drawn")

  local folder = SCENARIO:match("^user/(.+)$")
  if SCENARIO == "user/good" then
    emit(loadedPath(USER .. "/good/init.lua") and loadedPath(USER .. "/good/preflight.lua"),
      "user/good: its init.lua and preflight.lua were loaded from the user folder")
    emit(fallbacks == 0, "user/good: no fallback to Default")
  elseif folder then
    emit(fallbacks > 0, SCENARIO .. ": the widget fell back to Default", fallbacks)
    -- Once per theme load (boot, then the reload a connect makes), not once a frame.
    emit(fallbacks <= 3, SCENARIO .. ": the broken theme is not read again every frame", fallbacks .. " in " .. TICKS .. " ticks")
    emit(loadedPath("widgets/dashboard/themes/default/preflight.lua"), SCENARIO .. ": the Default preflight screen was loaded")
  else
    local anyUser = false
    for i = 1, #loaded do if loaded[i]:sub(1, #USER) == USER then anyUser = true end end
    emit(not anyUser and fallbacks == 0, SCENARIO .. ": a shipped theme reads nothing from the user folder")
  end
  out("DONE")
  return
end

-- ---------------------------------------------------------------------------
-- Driver
-- ---------------------------------------------------------------------------
local SCENARIOS = {"lib", "user/good", "user/broken", "user/badstate", "user/gone", "system/default"}

local function runScenario(scenario, mutation)
  local cmd = string.format('%s "%s/verify_user_themes.lua" --scenario "%s" "%s" 2>&1', LUA, DIR, scenario, mutation or "")
  local pipe = assert(io.popen(cmd, "r"))
  local text = pipe:read("a")
  pipe:close()
  return text
end

local function runAll(mutation, quiet)
  local failures, checks = 0, 0
  for _, scenario in ipairs(SCENARIOS) do
    local text = runScenario(scenario, mutation)
    local found = 0
    for flag, rest in text:gmatch("CHECK (%d) ([^\n]*)") do
      found = found + 1
      checks = checks + 1
      if flag ~= "1" then failures = failures + 1 end
      if not quiet then print(string.format("  %s  %s", flag == "1" and "ok  " or "FAIL", rest)) end
    end
    -- A scenario that stops part-way (an error after some checks) must not pass.
    if found == 0 or not text:find("\nDONE\n", 1, true) and text:sub(1, 5) ~= "DONE\n" then
      checks = checks + 1
      failures = failures + 1
      if not quiet then
        print("  FAIL  " .. scenario .. " ran to the end")
        print("        " .. text:sub(-600))
      end
    end
  end
  return failures, checks
end

local selfTest = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then selfTest = true end end

print("User dashboard themes:")
local failures, checks = runAll(nil, false)
if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\nall %d checks passed", checks))

if selfTest then
  print("\nSelf-test (each piece taken out must turn a check red):")
  local missed = 0
  for _, name in ipairs(MUTATION_ORDER) do
    local f = runAll(name, true)
    print(string.format("  %s  without %s: %d check(s) red", f > 0 and "ok  " or "FAIL", name, f))
    if f == 0 then missed = missed + 1 end
  end
  if missed > 0 then
    print(string.format("\n%d piece(s) taken out went unnoticed", missed))
    os.exit(1)
  end
  print("\nself-test passed")
end
