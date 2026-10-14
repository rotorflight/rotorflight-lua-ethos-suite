-- Behaviour check for Issue #2493: the tune advisor codec refuses a reply it does not
-- understand, instead of decoding it into plausible numbers.
--
-- Run it:
--     lua5.4 bin/tune_advisor_payload/verify_tune_advisor_payload.lua
--
-- What it drives: the real src/rfsuite/lib/msp_tune_advisor.lua, through the message
-- its read builder returns, so the reply goes through processReply exactly as the
-- transport hands it over. The replies are the simulator's own 67-byte reply (the
-- layout the firmware writes, payload version 1), and variants of it.
--
-- Against unpatched master the version-2, short and long replies reach onData as
-- decoded numbers; the checks for those go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  local last = 0
  for i = 1, #path do
    local ch = path:sub(i, i)
    if ch == "/" or ch == string.char(92) then last = i end
  end
  if last == 0 then return "." end
  return path:sub(1, last - 1)
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
  if ok then print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local tuneAdvisor = requireModule("lib/msp_tune_advisor.lua")

local function copy(buf)
  local out = {}
  for i = 1, #buf do out[i] = buf[i] end
  return out
end

-- Feeds one reply through the read message's processReply and records what happened.
local function deliver(buf)
  local got = {data = nil, reason = nil, errors = 0}
  local msg = tuneAdvisor.buildReadMessage(1,
    function(data) got.data = data end,
    function(reason) got.errors = got.errors + 1; got.reason = reason end)
  msg.processReply(nil, buf)
  return got
end

-- The simulator reply for axis 1 is the firmware's own 67-byte layout, version 1.
local sim = tuneAdvisor.buildReadMessage(1, function() end, function() end).simulatorResponse

print("the firmware's 67-byte reply, payload version 1")
do
  check("the reply is 67 bytes", #sim == 67, "length " .. #sim)
  local got = deliver(copy(sim))
  check("it decodes and reaches onData", got.data ~= nil and got.errors == 0,
    "errors " .. got.errors .. ", reason " .. tostring(got.reason))
  check("the decoded axis and P gain are the reply's", got.data ~= nil and got.data.axis == 1
    and got.data.a ~= nil and got.data.a.P == sim[6] + sim[7] * 256,
    "axis " .. tostring(got.data and got.data.axis))
end

print("payload version 2 (a layout this suite does not know)")
do
  local v2 = copy(sim)
  v2[1] = 2
  local got = deliver(v2)
  check("onData is not called with a decoded record", got.data == nil,
    "decoded version " .. tostring(got.data and got.data.version))
  check("onError is called with the reason", got.errors == 1 and type(got.reason) == "string"
    and got.reason:find("version 2", 1, true) ~= nil,
    "errors " .. got.errors .. ", reason " .. tostring(got.reason))
end

print("a truncated reply (66 bytes)")
do
  local short = copy(sim)
  short[#short] = nil
  local got = deliver(short)
  check("onData is not called", got.data == nil,
    "decoded, with the missing bytes as zeros: P = " .. tostring(got.data and got.data.a and got.data.a.relaxCutoff))
  check("onError is called with the reason", got.errors == 1 and type(got.reason) == "string",
    "errors " .. got.errors)
end

print("a longer reply (68 bytes)")
do
  local long = copy(sim)
  long[#long + 1] = 0
  local got = deliver(long)
  check("onData is not called", got.data == nil)
  check("onError is called with the reason", got.errors == 1 and type(got.reason) == "string",
    "errors " .. got.errors)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
