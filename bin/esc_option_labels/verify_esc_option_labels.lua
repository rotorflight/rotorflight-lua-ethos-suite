-- Behaviour check for #2652: the option names in the ESC parameter lists go through i18n, and the
-- values stay where they were.
--
-- Run it (from the repository root):
--     lua5.4 bin/esc_option_labels/verify_esc_option_labels.lua
--     lua5.4 bin/esc_option_labels/verify_esc_option_labels.lua --self-test
--
-- What it pins:
--   1. every option table keeps its number of entries (values are not touched);
--   2. every label is an @i18n(key)@ tag, or a name that stays as it is (protocol and governor
--      names, CW/CCW, numbers with units, and the flight controller's colour names in FlyRotor,
--      which the issue does not list);
--   3. every tag resolves to an English text in en.json;
--   4. the 4-way progress text has its %s in every locale.
--
-- --self-test puts one English label back and requires check 2 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local failures, checks = 0, 0
local silent = false
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    if not silent then print("FAIL  " .. label .. (detail and ("  -- " .. detail) or "")) end
  end
end

-- The option tables in the files the issue lists, and the number of entries each has on master.
local FILES = {
  {"src/rfsuite/lib/msp_esc_parameters_am32.lua", 23},
  {"src/rfsuite/lib/msp_esc_parameters_blheli_s.lua", 40},
  {"src/rfsuite/lib/msp_esc_parameters_bluejay.lua", 64},
  {"src/rfsuite/lib/msp_esc_parameters_flyrotor.lua", 64},
  {"src/rfsuite/lib/msp_esc_parameters_hw5.lua", 61},
  {"src/rfsuite/lib/msp_esc_parameters_scorpion.lua", 21},
  {"src/rfsuite/lib/msp_esc_parameters_xdfly.lua", 73},
  {"src/rfsuite/lib/msp_esc_parameters_yge.lua", 38},
  {"src/rfsuite/app/pages/esc_forward_yge.lua", 6},
}

-- Names that stay as they are, and why: protocol and governor names the pilot matches with the maker's
-- manual, rotation directions, and the FlyRotor colours (uppercase, outside the issue's listed lines).
local STAYS = {
  ["CW"] = true, ["CCW"] = true, ["PWM"] = true, ["DShot"] = true, ["Serial"] = true,
  ["Dshot 300-600"] = true, ["Servo 1-2ms"] = true, ["BF Safe Arming"] = true,
  ["Heli Gov"] = true, ["Heli Ext Gov"] = true, ["Heli Store"] = true, ["Ext Gov"] = true,
  ["ESC Gov"] = true, ["FW Gov"] = true, ["RF Gov"] = true, ["VBar Gov"] = true,
  ["FLYROTOR"] = true, ["F3A"] = true, ["Standard"] = true, ["VBar"] = true, ["EX Bus"] = true,
  ["Unsolicited"] = true, ["Futaba SBUS"] = true,
  ["4D"] = true, ["4D Reverse"] = true,                              -- hw1128 rotation model names
}

local function staysAsItIs(label, file)
  if STAYS[label] then return true end
  if label:match("^%-?[%d%.]+%s*%S*$") then return true end       -- 7.5V, 80C, 24kHz, 5S, 10x, 3 deg
  if label:match("^[%d%.]+%% %(") then return true end             -- 15% (0.75), 0.5% (0.031)
  if file:find("flyrotor", 1, true) and label:match("^[%u_]+$") then return true end
  return false
end

local EN_JSON = readFile(ROOT .. "/bin/i18n/json/en.json")

-- The English of a tag: the blocks along the key's path, in order, then the first english after them.
local function englishOf(tag)
  local key = tag:match("^@i18n%((.-)%)@$")
  if not key then return nil end
  local pos = 1
  for segment in key:gmatch("[^%.]+") do
    local _, e = EN_JSON:find('"' .. segment .. '": {', pos, true)
    if not e then return nil end
    pos = e + 1
  end
  local _, _, value = EN_JSON:find('"english": "([^"]*)"', pos)
  return value
end

local function checkFiles(sources)
  local pairs_ = "%{\"([^\"]+)\", (%-?%d+)%}"
  for _, spec in ipairs(FILES) do
    local rel, expected = spec[1], spec[2]
    local text = sources[rel]
    local count, leftovers = 0, {}
    for label in text:gmatch(pairs_) do
      count = count + 1
      if not label:match("^@i18n%(") and not staysAsItIs(label, rel) then
        leftovers[#leftovers + 1] = label
      end
    end
    -- Option lists written as choices({"Label", ...}) hold bare strings, which the pair pattern above does not see.
    for body in text:gmatch("choices%(%{(.-)%}%)") do
      for label in body:gmatch('"([^"]*)"') do
        if not label:match("^@i18n%(") and not staysAsItIs(label, rel) then
          leftovers[#leftovers + 1] = label
        end
      end
    end
    check("1. " .. rel .. " keeps its " .. expected .. " option entries", count == expected,
      "entries=" .. count)
    check("2. " .. rel .. " has no translatable English label left",
      #leftovers == 0, "left: " .. table.concat(leftovers, ", "))
    for tag in text:gmatch("\"(@i18n%([^\"]+%)@)\"") do
      local english = englishOf(tag)
      if not english then
        check("3. " .. tag .. " resolves in en.json", false, "no English text")
      end
    end
  end
end

-- 4. The 4-way progress text keeps its %s in every locale.
local LOCALES = {"cs", "de", "en", "es", "fr", "he", "it", "nl", "no", "pl", "pt-br", "zh-cn"}
local function checkSelecting()
  for _, loc in ipairs(LOCALES) do
    local text = readFile(ROOT .. "/bin/i18n/json/" .. loc .. ".json")
    local block = text:match('"selecting_fmt": {(.-)\n%s*}')
    local translation = block and block:match('"translation": "([^"]*)"')
    check("4. the selecting text in " .. loc .. " keeps %s", translation ~= nil and translation:find("%s", 1, true) ~= nil,
      "translation=" .. tostring(translation))
  end
end

local function loadSources()
  local sources = {}
  for _, spec in ipairs(FILES) do sources[spec[1]] = readFile(ROOT .. "/" .. spec[1]) end
  return sources
end

-- Put one English label back into a copy of the sources and require check 2 to go red.
local function mutantCaught(sources, rel, pattern, replacement)
  local mutant, n = sources[rel]:gsub(pattern, replacement, 1)
  assert(n == 1, "could not apply self-test mutation to " .. rel)
  local mutated = {}
  for k, v in pairs(sources) do mutated[k] = v end
  mutated[rel] = mutant
  silent = true
  local before = failures
  checkFiles(mutated)
  local caught = failures - before
  silent = false
  return caught
end

local sources = loadSources()
if SELF_TEST then
  -- A pair-table label (BlueJay) and a choices({...}) label (hw5) each put back in English.
  local cases = {
    {"src/rfsuite/lib/msp_esc_parameters_bluejay.lua", '@i18n%(app%.modules%.esc_tools%.opt%.low%)@', "Low"},
    {"src/rfsuite/lib/msp_esc_parameters_hw5.lua", '@i18n%(api%.BATTERY_INI%.tbl_auto%)@', "Auto"},
  }
  for _, c in ipairs(cases) do
    local caught = mutantCaught(sources, c[1], c[2], c[3])
    if caught == 0 then
      print("SELF-TEST FAILED: the English-label mutant in " .. c[1] .. " did not produce any failure")
      os.exit(1)
    end
    print(string.format("self-test ok: English label in %s caught (%d failure(s))", c[1], caught))
  end
  os.exit(0)
end

checkFiles(sources)
checkSelecting()

if failures > 0 then
  print(string.format("\nFAILED: %d of %d checks failed", failures, checks))
  os.exit(1)
else
  print(string.format("ALL %d CHECKS PASSED", checks))
end
