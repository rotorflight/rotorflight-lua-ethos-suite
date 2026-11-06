-- Behaviour check for #2661: Tools > Copy Profiles offers the profiles the board has, for the
-- chosen type, and no more. A copy onto a profile the board lacks is acknowledged and changes
-- nothing, so the page must not offer one.
--
-- Run it (from the repository root):
--     lua5.4 bin/copy_profiles_count/verify_copy_profiles_count.lua
--     lua5.4 bin/copy_profiles_count/verify_copy_profiles_count.lua --self-test
--
-- What it pins, on the real page:
--   1. before the board's counts are read, no profile line is built and Save stays off;
--   2. once read, the source and destination lists have the board's PID count;
--   3. a destination above the count is clamped to the last profile;
--   4. changing the type to rate rebuilds the lists with the board's rate count;
--   5. Save stays off while source and destination are the same profile;
--   6. a count above six is offered as six, the most the page knows;
--   7. a save pressed before the counts are read sends nothing.
--
-- --self-test restores the fixed list of six and requires check 2 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"
local PAGE = SUITE .. "/app/pages/copy_profiles.lua"

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

local function noop() end
local function anyStub()
  return setmetatable({}, {__index = function() return function() return anyStub() end end,
    __call = function() return anyStub() end})
end

lcd = anyStub()
system = anyStub()
model = anyStub()
TEXT_LEFT = nil

-- Form state for the page under test: the choice fields in build order, and the open dialogs.
local choiceFields, dialogs = {}, {}
form = {
  clear = function() choiceFields = {} end,
  invalidate = noop,
  openDialog = function(opts) dialogs[#dialogs + 1] = opts end,
  addLine = function(label) return {label = label} end,
  addChoiceField = function(_, _, choices, getter, setter)
    local field = {choices = choices, get = getter, set = setter}
    choiceFields[#choiceFields + 1] = field
    return {enable = noop}
  end,
  addNumberField = function() return {enable = noop} end,
}

-- The header records whether Save is lit, and keeps the Save handler.
local saveLit, headerOpts = nil, nil
package.loaded["rfsuite.app.header"] = {build = function(_, opts)
  headerOpts = opts
  return {setSaveEnabled = function(v) saveLit = v end, setReloadEnabled = noop,
    focusSave = noop, focusReload = noop, focusMenu = noop}
end}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return false end}
package.loaded["rfsuite.app.progress_dialog"] = {open = function() return {close = noop, value = noop} end, SPEED = {}}
local sentMessages = 0
package.loaded["rfsuite.lib.msp_copy_profile"] = {buildWriteMessage = function()
  sentMessages = sentMessages + 1
  return {}
end}
package.loaded["rfsuite.lib.msp_eeprom"] = {buildWriteMessage = function() return {} end}

-- The status read: the test decides when, and with what counts, the board answers.
local statusCallbacks = {}
package.loaded["rfsuite.lib.msp_status"] = {buildReadMessage = function(onData)
  statusCallbacks[#statusCallbacks + 1] = onData
  return {}
end}

-- The page's own requires resolve to the real modules, once, through this cache.
local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(SUITE .. "/" .. name)
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

local function answerStatus(pid, rate)
  local onData = table.remove(statusCallbacks, 1)
  onData({pid_profile_count = pid, control_rate_profile_count = rate})
end

local function runTests(pageSource)
  local page = assert(load(pageSource, "@copy_profiles.lua", "t"))()

  -- Opens a fresh page and returns its wakeup. Nothing is answered yet.
  local function openPage()
    choiceFields, dialogs, statusCallbacks, saveLit, headerOpts = {}, {}, {}, nil, nil
    sentMessages = 0
    local wakeup = nil
    page.open({onBack = noop, setWakeupHandler = function(h) wakeup = h end})
    return function() if wakeup then wakeup() end end
  end

  do
    local wake = openPage()
    check("1. before the counts are read, no profile line is built", #choiceFields == 0,
      "fields=" .. #choiceFields)
    check("1. and Save stays off", saveLit ~= true, "saveLit=" .. tostring(saveLit))
    answerStatus(4, 2)
    wake()
    check("2. the lists have the board's four PID profiles",
      #choiceFields == 3 and #choiceFields[2].choices == 4 and #choiceFields[3].choices == 4,
      "fields=" .. #choiceFields)
    check("2. and Save is lit for the default source 1 and destination 2", saveLit == true)
  end

  do
    local wake = openPage()
    answerStatus(4, 2)
    wake()
    choiceFields[3].set(9)
    wake()
    check("3. a destination above the count is clamped to the last profile",
      choiceFields[3].get() == 3, "dest=" .. tostring(choiceFields[3].get()))
  end

  do
    local wake = openPage()
    answerStatus(4, 2)
    wake()
    choiceFields[1].set(1) -- rate
    wake()
    check("4. the rate type rebuilds the lists with the board's two rate profiles",
      #choiceFields[2].choices == 2 and #choiceFields[3].choices == 2,
      "lengths=" .. tostring(choiceFields[2] and #choiceFields[2].choices) .. "/"
        .. tostring(choiceFields[3] and #choiceFields[3].choices))
    check("4. and the destination is clamped to the last rate profile", choiceFields[3].get() <= 1,
      "dest=" .. tostring(choiceFields[3].get()))
  end

  do
    local wake = openPage()
    answerStatus(4, 2)
    wake()
    choiceFields[2].set(2)
    choiceFields[3].set(2)
    wake()
    check("5. Save is off while source and destination are the same profile", saveLit == false,
      "saveLit=" .. tostring(saveLit))
  end

  do
    local wake = openPage()
    answerStatus(9, 2)
    wake()
    check("6. a count above six is offered as six", #choiceFields[2].choices == 6,
      "length=" .. tostring(#choiceFields[2].choices))
  end

  do
    local wake = openPage()
    headerOpts.onSave() -- opens the confirmation, before the counts are read
    local confirm = dialogs[#dialogs]
    if confirm and confirm.buttons and confirm.buttons[1] then confirm.buttons[1].action() end
    check("7. a save before the counts are read sends nothing", sentMessages == 0,
      "sent=" .. sentMessages)
    answerStatus(4, 2)
    wake()
  end
end

local src = readFile(PAGE)
if SELF_TEST then
  -- The fixed list of six, as before the fix: the page offers six whatever the board has.
  local mutant, count = src:gsub("if count > MAX_PROFILE_COUNT then return MAX_PROFILE_COUNT end",
    "do return MAX_PROFILE_COUNT end")
  assert(count == 1, "could not apply self-test mutation to countFor")
  silent = true
  local before = failures
  runTests(mutant)
  local caught = failures - before
  silent = false
  if caught == 0 then
    print("SELF-TEST FAILED: the fixed-six mutant did not produce any failure")
    os.exit(1)
  end
  print(string.format("self-test ok: fixed-six mutant caught %d failure(s)", caught))
  os.exit(0)
end

runTests(src)

if failures > 0 then
  print(string.format("\nFAILED: %d of %d checks failed", failures, checks))
  os.exit(1)
else
  print(string.format("ALL %d CHECKS PASSED", checks))
end
