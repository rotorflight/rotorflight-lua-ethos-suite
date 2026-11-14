-- Wording check for the Setup Wizard's level step (#2705): the level pages name the three work
-- steps in order (links, trim, blade links), and the shipped strings match the sources.
--
-- Run it (from the repository root):
--     lua5.4 bin/wizard_level_wording/verify_wizard_level_wording.lua
--     lua5.4 bin/wizard_level_wording/verify_wizard_level_wording.lua --self-test
--
-- Text only: no behaviour changes. It checks:
--   1. the English level intro names the three steps in order: links, then trim, then blade links;
--   2. the English level rear text names the same three steps, numbered;
--   3. the gyro card keeps "Blades off", the other half of the blades story;
--   4. the runtime locale file (src/rfsuite/i18n/en.json) carries the same texts as the source;
--   5. the German translations exist for the two level strings.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- The string under a key in a locale file: its "english" and "translation" values.
local function entry(text, key)
  local start = text:find('"' .. key .. '": {', 1, true)
  if not start then return nil end
  local block = text:sub(start, text:find("}", start, true))
  return {
    english = block:match('"english": "([^"]*)"'),
    translation = block:match('"translation": "([^"]*)"'),
  }
end

-- In order: the links, the trim, the blade links.
local function inOrder(s, parts)
  s = s:lower()
  local at = 0
  for _, part in ipairs(parts) do
    local found = s:find(part, at + 1, true)
    if not found then return false end
    at = found
  end
  return true
end

local EN_PATH = ROOT .. "/bin/i18n/json/en.json"
local DE_PATH = ROOT .. "/bin/i18n/json/de.json"
local RUNTIME_EN = ROOT .. "/src/rfsuite/i18n/en.json"

local en = readFile(EN_PATH)
local de = readFile(DE_PATH)
local runtime = readFile(RUNTIME_EN)

local intro = entry(en, "lvl_intro")
local rear = entry(en, "lvl_rear_text")
local gyro = entry(en, "gyr_intro")

print("the level wording")
do
  check("1. the level intro names links, then trim, then blade links",
    intro ~= nil and inOrder(intro.english, {"link", "trim", "blade"}),
    intro and intro.english or "missing")
  check("2. the level rear text names the same three steps, numbered",
    rear ~= nil and inOrder(rear.english, {"1", "link", "2", "trim", "3", "blade"}),
    rear and rear.english or "missing")
  check("3. the gyro card keeps Blades off", gyro ~= nil and gyro.english:find("Blades off", 1, true) ~= nil,
    gyro and gyro.english or "missing")
  local runtimeIntro = entry(runtime, "lvl_intro")
  local runtimeRear = entry(runtime, "lvl_rear_text")
  check("4. the runtime file carries the same level texts as the source",
    runtimeIntro ~= nil and runtimeRear ~= nil and runtimeIntro.english == intro.english
      and runtimeRear.english == rear.english,
    "runtime intro=" .. tostring(runtimeIntro and runtimeIntro.english))
  local deIntro = entry(de, "lvl_intro")
  local deRear = entry(de, "lvl_rear_text")
  check("5. German translations exist for the two level strings",
    deIntro ~= nil and deRear ~= nil and deIntro.translation ~= nil and deRear.translation ~= nil
      and deIntro.translation ~= deIntro.english and deRear.translation ~= deRear.english)
end

-- ---------------------------------------------------------------------------
-- self-test: with the old wording the step check must go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the step check must go red with the wording before this change")
  -- The en.json of the last commit before this change, read from git.
  local handle = io.popen("git show HEAD:bin/i18n/json/en.json")
  local before = handle and handle:read("*a") or ""
  if handle then handle:close() end
  local oldIntro = entry(before, "lvl_intro")
  check("self-test: the wording before this change is read from git", oldIntro ~= nil and oldIntro.english ~= nil,
    "git show gave no lvl_intro")
  if oldIntro and oldIntro.english then
    check("self-test: the old level intro does not name the links, then trim, then blade links (the checks above go red)",
      not inOrder(oldIntro.english, {"link", "trim", "blade"}), oldIntro.english)
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
