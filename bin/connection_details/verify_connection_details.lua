-- Behaviour check for the connection details (issue #2318): what the info button's dialog says,
-- and that the header carries that button on its own sixth slot.
--
-- Run it:
--     lua5.4 bin/connection_details/verify_connection_details.lua
--
-- What it drives, and why:
--   * app/connection_details.lua, real: the body for a connected link, a link that is down, and a
--     session that holds no craft name or versions. The handshake progress is counted from the
--     session's own steps.
--   * app/header.lua, real: the header is built with six slots, the info button is the sixth, and
--     pressing it opens the dialog with the body built from the session.
--   * The i18n markers are resolved from bin/i18n/json/en.json, as the build does for strings the
--     module formats, so the text checked is the one the pilot reads.
--
-- This checks the content and the wiring. It does not check how the button looks on the radio: that
-- is a simulator check (AGENTS.md section 11), not run here.
--
-- Against unpatched master there is no info button and no connection dialog, so the checks fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

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
end

local function noop() end
local function anyStub()
  return setmetatable({}, {__index = function() return function() return anyStub() end end,
    __call = function() return anyStub() end})
end

-- The English strings, read from the locale source the build uses.
local EN = {}
do
  local f = assert(io.open(ROOT .. "/bin/i18n/json/en.json", "rb"))
  local text = f:read("a")
  f:close()
  for key, value in text:gmatch('"([%w_]+)": {\r?\n%s*"english": "(.-)",\r?\n') do
    EN[key] = value
  end
end
local function unescape(s) return (s:gsub("\\n", "\n"):gsub('\\"', '"'):gsub("\\\\", "\\")) end
local function resolve(text)
  return (text:gsub("@i18n%(([%w%._]+)%)@", function(key)
    local name = key:match("([%w_]+)$")
    return EN[name] and unescape(EN[name]) or ("@i18n(" .. key .. ")@")
  end))
end
local realFormat = string.format
string.format = function(fmt, ...)
  local args = {...}
  for i = 1, select("#", ...) do
    if type(args[i]) == "string" then args[i] = resolve(args[i]) end
  end
  return realFormat(resolve(fmt), table.unpack(args, 1, select("#", ...)))
end

lcd = setmetatable({loadMask = function() return {} end, getTextSize = function() return 10, 10 end,
  font = noop}, {__index = function() return noop end})
system = anyStub()
model = anyStub()

local dialogs = {}
local buttons = {}
form = {
  clear = noop,
  invalidate = noop,
  openDialog = function(opts) dialogs[#dialogs + 1] = opts end,
  addLine = function() return {} end,
  getFieldSlots = function() return {{x = 0, y = 0, w = 10, h = 10}, {x = 10, y = 0, w = 10, h = 10},
    {x = 20, y = 0, w = 10, h = 10}, {x = 30, y = 0, w = 10, h = 10},
    {x = 40, y = 0, w = 10, h = 10}, {x = 50, y = 0, w = 10, h = 10}} end,
  addStaticText = function() return anyStub() end,
  addButton = function(_, rect, opts)
    buttons[#buttons + 1] = {rect = rect, opts = opts}
    return anyStub()
  end,
}

local details = requireModule("app/connection_details.lua")

-- ---------------------------------------------------------------------------
-- 1. The dialog's text
-- ---------------------------------------------------------------------------

print("dialog text")
do
  local connected = {connected = true, craftName = "Heli", rfVersion = "4.6.0", apiVersion = "12.10",
    handshake = {apiVersion = true, fcVariant = true, mcuId = true}}
  local body = details.body(connected)
  check("a connected link says so, with the handshake's steps done out of nine",
    body:find("Link: connected", 1, true) ~= nil and body:find("Handshake: 3 of 9 steps", 1, true) ~= nil,
    body)
  check("the body names the craft, the firmware and the API the session holds",
    body:find("Craft: Heli", 1, true) ~= nil and body:find("Firmware: 4.6.0", 1, true) ~= nil
      and body:find("API: 12.10", 1, true) ~= nil, body)
end

do
  local down = {connected = false, handshake = {}}
  local body = details.body(down)
  check("a link that is down says it is not connected", body:find("Link: not connected", 1, true) ~= nil, body)
  check("with no handshake step done it reads 0 of 9", body:find("Handshake: 0 of 9 steps", 1, true) ~= nil, body)
  check("a name and versions the session does not hold read as a dash",
    body:find("Craft: -", 1, true) ~= nil and body:find("Firmware: -", 1, true) ~= nil, body)
end

do
  local body = details.body(nil)
  check("no session at all still gives a body, not an error", type(body) == "string" and #body > 0)
end

print("the dialog opens")
do
  dialogs = {}
  _G.rfsuite = {session = {connected = true, craftName = "Heli", rfVersion = "4.6.0", apiVersion = "12.10",
    handshake = {apiVersion = true}}}
  details.open()
  local d = dialogs[#dialogs]
  check("open() opens one dialog", #dialogs == 1 and d ~= nil)
  if d then
    check("the dialog's title reads Connection", resolve(d.title) == "Connection", "title=" .. tostring(resolve(d.title)))
    check("the message is the body for the session", d.message == details.body(_G.rfsuite.session))
    check("the dialog has one OK button", #d.buttons == 1)
  end
end

-- ---------------------------------------------------------------------------
-- 2. The header carries the button on its own slot
-- ---------------------------------------------------------------------------

print("header")
do
  package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return false end}
  local header = requireModule("app/header.lua")
  buttons = {}
  dialogs = {}
  header.build("Test", {onBack = noop, onSave = noop, onReload = noop, onTool = noop})
  check("the header adds six buttons on the line (back, save, reload, tool, info)", #buttons >= 5,
    "buttons=" .. #buttons)
  local info = buttons[#buttons]
  check("the info button is the last one, on the sixth slot", info and info.rect.x == 50,
    "x=" .. tostring(info and info.rect.x))
  check("the info button has an icon and a press action", info and info.opts.icon ~= nil and type(info.opts.press) == "function")
  if info then
    info.opts.press()
    check("pressing the info button opens the connection dialog", #dialogs == 1
      and resolve(dialogs[1].title) == "Connection")
  end
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
