-- lua5.4 bin/startup_glasses/verify_startup_glasses.lua
-- Exercise the real reader, compare it with the full INI/settings reader,
-- and drive the real main.init with unrelated subsystems replaced by recorders.
local source = debug.getinfo(1, "S").source:sub(2)
local root = (source:match("^(.*)[/\\][^/\\]+$") or ".") .. "/../../src/rfsuite/"
local checks = 0
local function check(label, ok)
  checks = checks + 1
  assert(ok, label)
end

local fixture, opens, reads, closes = nil, 0, 0, 0
local env = setmetatable({
  package = {loaded = {}},
  os = {clock = os.clock}, -- no directory creation or settings writes
  print = function() end,
  collectgarbage = function() end,
  io = {
    open = function(path, mode)
      assert(path == "SCRIPTS:/rfsuite.user/settings.ini" and mode == "rb")
      opens = opens + 1
      if fixture == nil then return nil end
      return {text = fixture, pos = 1, closed = false}
    end,
    read = function(file, mode)
      assert(mode == "L" and not file.closed)
      reads = reads + 1
      if file.pos > #file.text then return nil end
      local last = file.text:find("\n", file.pos, true) or #file.text
      local line = file.text:sub(file.pos, last)
      file.pos = last + 1
      return line
    end,
    close = function(file)
      assert(not file.closed)
      file.closed = true
      closes = closes + 1
    end,
  },
}, {__index = _G})

local function requireModule(path)
  local key = "rfsuite." .. path:gsub("%.lua$", ""):gsub("/", ".")
  if env.package.loaded[key] == nil then
    env.package.loaded[key] = assert(loadfile(root .. path, "t", env))()
  end
  return env.package.loaded[key]
end
env.package.loaded["rfsuite.lib.require"] = requireModule
local store = requireModule("lib/settings_store.lua")

local function readerCase(label, text, expected)
  fixture = text
  local beforeOpen, beforeClose = opens, closes
  local result = store.startupGlassesEnabled()
  check(label, result == expected)
  check(label .. ": one open attempt", opens == beforeOpen + 1)
  check(label .. ": file closed", closes == beforeClose + (text ~= nil and 1 or 0))
  -- This runs ini.lua's actual parseLine and the normal schema coercion.
  -- Neither reader is replaced with a table-returning stub.
  check(label .. ": same as full reader", result == store.load().activelook.register_glasses)
end

readerCase("missing file defaults off", nil, false)
readerCase("empty file defaults off", "", false)
readerCase("missing key defaults off", "[activelook]\nenabled=true\n", false)
readerCase("another section does not enable", "[general]\nregister_glasses=true\n", false)
readerCase("key before section is ignored", "register_glasses=true\n", false)
readerCase("another section does not override", "[activelook]\nregister_glasses=true\n[general]\nregister_glasses=false\n", true)
readerCase("last duplicate disables", "[activelook]\nregister_glasses=true\nregister_glasses=false\n", false)
readerCase("last duplicate enables", "[activelook]\nregister_glasses=false\nregister_glasses=true\n", true)
readerCase("repeated section", "[activelook]\nregister_glasses=false\n[other]\nregister_glasses=false\n[activelook]\nregister_glasses=true", true)
for _, value in ipairs({"true", "false", "1", "0", "1.0", "garbage", ""}) do
  local expected = value == "true" or value == "1" or value == "1.0"
  readerCase("value " .. value, "[activelook]\nregister_glasses=" .. value .. "\n", expected)
end
readerCase("garbage overrides earlier true", "[activelook]\nregister_glasses=true\nregister_glasses=garbage\n", false)
readerCase("comments and CRLF", "; comment\r\n [ activelook ] \r\n ;register_glasses=false\r\n register_glasses=true \r\n", true)
-- Preserve existing parser behavior: spaces before '=' are allowed, a space
-- after '=' remains part of a nonnumeric value, while tonumber accepts it.
readerCase("space before equals", "[activelook]\nregister_glasses =true\n", true)
readerCase("space after equals with text", "[activelook]\nregister_glasses = true\n", false)
readerCase("spaces with numeric value", "[activelook]\nregister_glasses = 1 \n", true)

local readerCalls, registrations, subsystemCalls, widgetCalls = 0, 0, 0, 0
local startupStore = {
  startupGlassesEnabled = function()
    readerCalls = readerCalls + 1
    return store.startupGlassesEnabled()
  end,
  load = function() error("main.init must not load the full settings schema") end,
}
env.package.loaded["rfsuite.lib.require"] = function(path)
  if path == "lib/settings_store.lua" then return startupStore end
  assert(path == "tasks/background.lua" or path == "app/tool.lua"
    or path == "widgets/dashboard.lua" or path == "widgets/activelook.lua", path)
  return {init = function()
    if path == "widgets/activelook.lua" then widgetCalls = widgetCalls + 1
    else subsystemCalls = subsystemCalls + 1 end
  end}
end

local function startupCase(label, api, text, shouldRegister, widgetApi)
  fixture = text
  readerCalls, registrations, subsystemCalls, widgetCalls = 0, 0, 0, 0
  env.system = {}
  if api then
    env.system.registerGlasses = function(...)
      check(label .. ": registration takes no arguments", select("#", ...) == 0)
      registrations = registrations + 1
    end
  end
  if widgetApi then env.system.registerGlassesWidget = function() end end
  local beforeOpen, beforeRead = opens, reads
  local main = assert(loadfile(root .. "main.lua", "t", env))()
  check(label .. ": no read at chunk load", opens == beforeOpen and readerCalls == 0)
  check(label .. ": no registration at chunk load", registrations == 0)
  main.init()
  check(label .. ": first registration", registrations == (shouldRegister and 1 or 0))
  check(label .. ": reader called only with API", readerCalls == (api and 1 or 0))
  check(label .. ": file opened only with API", opens == beforeOpen + (api and 1 or 0))
  if not api then check(label .. ": no file reads", reads == beforeRead) end
  local opened, read = opens, reads
  -- A UI save in this lifetime must not change the startup decision.
  fixture = "[activelook]\nregister_glasses=" .. (shouldRegister and "false" or "true") .. "\n"
  main.init()
  check(label .. ": no second read", opens == opened and reads == read and readerCalls == (api and 1 or 0))
  check(label .. ": at most one registration", registrations == (shouldRegister and 1 or 0))
  check(label .. ": other subsystems unchanged", subsystemCalls == 6)
  check(label .. ": widget registration independent", widgetCalls == (widgetApi and 2 or 0))
end

for _, widgetApi in ipairs({false, true}) do
  startupCase("enabled", true, "[activelook]\nregister_glasses=true\n", true, widgetApi)
  startupCase("disabled", true, "[activelook]\nregister_glasses=false\n", false, widgetApi)
  startupCase("missing file", true, nil, false, widgetApi)
  startupCase("API absent", false, "[activelook]\nregister_glasses=true\n", false, widgetApi)
end
print(string.format("Glasses startup: %d checks passed", checks))
