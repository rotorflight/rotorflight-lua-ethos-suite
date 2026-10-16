-- Behaviour check for #2501: every adjustment function the Adjustments page offers
-- has a spoken name, and every word of a name has an audio file in the shipped pack.
--
-- Run it:
--     lua5.4 bin/adjfunctions_audio/verify_adjfunctions_audio.lua
--     lua5.4 bin/adjfunctions_audio/verify_adjfunctions_audio.lua --self-test
--
-- What it reads: the real src/rfsuite/tasks/adjfunctions/wavs.lua (the name table) and
-- the real src/rfsuite/app/pages/adjustments.lua (the functions the page offers), and the
-- audio folders of the English pack: default, us and gb.
--
-- Scope: ids 0 to 4 (None, Rate Profile, PID Profile, LED Profile, OSD Profile) are
-- handled outside this table and are not checked here.
--
-- Against unpatched master, the functions 76 to 82 have no name and six names use
-- words that have no file, so the checks go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local WAVS = ROOT .. "/src/rfsuite/tasks/adjfunctions/wavs.lua"
local PAGE = ROOT .. "/src/rfsuite/app/pages/adjustments.lua"
local PACK = ROOT .. "/src/rfsuite/audio/en"
local VARIANTS = { "default", "us", "gb" }
local FIRST_NAMED_ID = 5

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

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

-- Name table: id -> phrase. Loaded from the real file, so the check follows the code.
local function loadNames(path)
  local chunk = assert(loadfile(path))
  return chunk()
end

-- Function ids the Adjustments page offers, with their names.
local function pageIds(path)
  local ids = {}
  for id, name in readFile(path):gmatch('{id = (%d+), name = "([^"]*)"') do
    ids[#ids + 1] = { id = tonumber(id), name = name }
  end
  return ids
end

local function runChecks(names, offered)
  -- C1: every function the page offers (from id 5) has a spoken name.
  local unnamed = {}
  for _, f in ipairs(offered) do
    if f.id >= FIRST_NAMED_ID and names[f.id] == nil then unnamed[#unnamed + 1] = f.id end
  end
  check("C1 every function the page offers has a name", #unnamed == 0,
    "no name for ids: " .. table.concat(unnamed, ", "))

  -- C2: every word of every name has an audio file in every English variant.
  local missing = {}
  local ids = {}
  for id in pairs(names) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    for word in names[id]:gmatch("%S+") do
      for _, variant in ipairs(VARIANTS) do
        local path = PACK .. "/" .. variant .. "/adjfunctions/" .. word .. ".wav"
        if not exists(path) then
          missing[#missing + 1] = string.format("%d '%s' (%s)", id, names[id], variant)
        end
      end
    end
  end
  check("C2 every word of every name has an audio file in default, us and gb",
    #missing == 0, #missing > 0 and ("missing: " .. table.concat(missing, "; ")) or nil)
end

print("names: src/rfsuite/tasks/adjfunctions/wavs.lua")
print("page:  src/rfsuite/app/pages/adjustments.lua")
local names = loadNames(WAVS)
runChecks(names, pageIds(PAGE))

local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print("")
  print("--self-test: the checks must go red without the name for function 76")
  local source = readFile(WAVS)
  local spliced, n = source:gsub('%s*%[76%] = "gov idle throttle",', "", 1)
  if n ~= 1 then
    check("the name for function 76 is present to splice out", false, "no match in wavs.lua")
  else
    local chunk = assert(load(spliced, "@wavs_without_76"))
    local lacking = chunk()
    local before = failures
    runChecks(lacking, pageIds(PAGE))
    local red = failures > before
    failures = before
    check("the name checks go red without the name for function 76", red)
  end
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
