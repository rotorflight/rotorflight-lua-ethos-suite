-- Gate for #2561: every @i18n(key)@ the code uses must resolve in every
-- locale source under bin/i18n/json/.
--
-- The build (bin/i18n/build-single-json.py) regenerates src/rfsuite/i18n/<locale>.json
-- from these sources only. A key that is missing from a source is silently
-- dropped from the next build, and the code then shows a missing string.
--
-- Run it:
--     lua5.4 bin/i18n_sources/verify_i18n_sources.lua
--     lua5.4 bin/i18n_sources/verify_i18n_sources.lua --self-test
--
-- What it checks, and why this is a source check and not a build check: the
-- sources are the input the build loses keys from. Parsing them here needs no
-- Python, so the gate runs in the same Lua job as the other harnesses.
--
-- Against unpatched master, the English, German and every other source are
-- missing edit_battery, msg_main_power_lost_banner and msg_save_failed_local_body,
-- so the gate goes red on all twelve locales.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."

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

-- ---------------------------------------------------------------------------
-- Minimal JSON reader. Enough for the locale sources: objects, arrays,
-- strings with escapes, numbers and literals. Unknown input is an error.
-- ---------------------------------------------------------------------------

local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
  b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
local JSON_NULL = setmetatable({}, { __name = "json_null" })

local function parseJson(text)
  local pos = 1
  local value

  local function skipSpace()
    pos = text:find("[^ \t\r\n]", pos) or (#text + 1)
  end

  local function readString()
    assert(text:sub(pos, pos) == '"', "expected string at byte " .. pos)
    pos = pos + 1
    local out = {}
    while true do
      local i = text:find('["\\]', pos)
      assert(i, "unterminated string")
      out[#out + 1] = text:sub(pos, i - 1)
      if text:sub(i, i) == '"' then
        pos = i + 1
        break
      end
      local e = text:sub(i + 1, i + 1)
      if e == "u" then
        out[#out + 1] = utf8.char(tonumber(text:sub(i + 2, i + 5), 16))
        pos = i + 6
      else
        assert(ESCAPES[e], "bad escape at byte " .. i)
        out[#out + 1] = ESCAPES[e]
        pos = i + 2
      end
    end
    return table.concat(out)
  end

  function value()
    skipSpace()
    local c = text:sub(pos, pos)
    if c == "{" then
      pos = pos + 1
      local obj = {}
      skipSpace()
      if text:sub(pos, pos) == "}" then
        pos = pos + 1
        return obj
      end
      while true do
        skipSpace()
        local key = readString()
        skipSpace()
        assert(text:sub(pos, pos) == ":", "expected ':' at byte " .. pos)
        pos = pos + 1
        obj[key] = value()
        skipSpace()
        local d = text:sub(pos, pos)
        pos = pos + 1
        if d == "}" then return obj end
        assert(d == ",", "expected ',' or '}' at byte " .. pos)
      end
    elseif c == "[" then
      pos = pos + 1
      local arr = {}
      skipSpace()
      if text:sub(pos, pos) == "]" then
        pos = pos + 1
        return arr
      end
      while true do
        arr[#arr + 1] = value()
        skipSpace()
        local d = text:sub(pos, pos)
        pos = pos + 1
        if d == "]" then return arr end
        assert(d == ",", "expected ',' or ']' at byte " .. pos)
      end
    elseif c == '"' then
      return readString()
    elseif text:sub(pos, pos + 3) == "true" then
      pos = pos + 4
      return true
    elseif text:sub(pos, pos + 4) == "false" then
      pos = pos + 5
      return false
    elseif text:sub(pos, pos + 3) == "null" then
      pos = pos + 4
      return JSON_NULL
    end
    local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    assert(num and #num > 0, "unexpected token at byte " .. pos)
    pos = pos + #num
    return tonumber(num)
  end

  local tree = value()
  skipSpace()
  assert(pos > #text, "trailing data at byte " .. pos)
  return tree
end

-- ---------------------------------------------------------------------------
-- Repository access. Listing uses dir on Windows and find elsewhere, so the
-- gate runs the same on the developer's Windows machine and on Linux CI
-- without needing a git checkout.
-- ---------------------------------------------------------------------------

local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local function listFiles(relDir, suffix)
  local list = {}
  local full = ROOT .. "/" .. relDir
  local cmd
  if IS_WINDOWS then
    cmd = 'dir /b /s /a-d "' .. full:gsub("/", "\\") .. '" 2>nul'
  else
    cmd = 'find "' .. full .. '" -type f 2>/dev/null'
  end
  local p = assert(io.popen(cmd, "r"))
  for line in p:lines() do
    line = line:gsub("\r", "")
    if line:sub(-#suffix) == suffix then list[#list + 1] = line end
  end
  p:close()
  table.sort(list)
  return list
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

-- Every @i18n(key)@ reference in the Lua sources.
local function referencedKeys()
  local keys, seen = {}, {}
  for _, path in ipairs(listFiles("src/rfsuite", ".lua")) do
    for key in readFile(path):gmatch("@i18n%(([%w_%.%-]+)%)@") do
      if not seen[key] then
        seen[key] = true
        keys[#keys + 1] = key
      end
    end
  end
  table.sort(keys)
  return keys
end

local function resolves(tree, key)
  local node = tree
  for part in key:gmatch("[^%.]+") do
    if type(node) ~= "table" or node == JSON_NULL then return false end
    node = node[part]
    if node == nil then return false end
  end
  return true
end

-- Keys from `keys` that do not resolve in `tree`.
local function missingIn(tree, keys)
  local missing = {}
  for _, key in ipairs(keys) do
    if not resolves(tree, key) then missing[#missing + 1] = key end
  end
  return missing
end

-- ---------------------------------------------------------------------------
-- Run.
-- ---------------------------------------------------------------------------

local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

local keys = referencedKeys()
local sources = listFiles("bin/i18n/json", ".json")
print(string.format("%d referenced keys, %d locale sources", #keys, #sources))

local locales = {}
for _, path in ipairs(sources) do
  local name = path:match("([^/\\]+)%.json$")
  local ok, tree = pcall(parseJson, readFile(path))
  check(string.format("%s parses", name), ok, ok and nil or tree)
  if ok then locales[#locales + 1] = { name = name, tree = tree } end
end

for _, loc in ipairs(locales) do
  local missing = missingIn(loc.tree, keys)
  check(string.format("%s resolves every referenced key", loc.name), #missing == 0,
    #missing > 0 and ("missing: " .. table.concat(missing, ", ")) or nil)
end

if selfTest then
  print("")
  print("--self-test: the gate must find keys removed from a source")
  local en
  for _, loc in ipairs(locales) do
    if loc.name == "en" then en = loc.tree end
  end
  assert(en, "en source not found")
  local copy = parseJson(readFile(ROOT .. "/bin/i18n/json/en.json"))
  copy.app.modules.power.edit_battery = nil
  copy.app.msg_main_power_lost_banner = nil
  copy.app.msg_save_failed_local_body = nil
  local found = {}
  for _, k in ipairs(missingIn(copy, keys)) do found[k] = true end
  check("the removed keys are reported",
    found["app.modules.power.edit_battery"] and found["app.msg_main_power_lost_banner"]
      and found["app.msg_save_failed_local_body"],
    "reported: " .. table.concat((function()
      local t = {} for k in pairs(found) do t[#t + 1] = k end return t end)(), ", "))
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
