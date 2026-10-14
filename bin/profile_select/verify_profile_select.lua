-- Behaviour check for #2498: the Select Profile page reports a refused profile
-- write and keeps the Save button lit (issue #2498).
--
-- Run it:
--     lua5.4 bin/profile_select/verify_profile_select.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/profile_select.lua, the real bus and the real
--     lib/msp_select_profile.lua and lib/mspcodec.lua. The status read, the progress
--     dialog and the header are stubs. The FC's answer to each write is given by the
--     scenario: processReply() on success, errorHandler() on refusal.
--   * A refused rate write, or a refused PID write after the rate write was accepted,
--     must show the save-failed dialog. Before the fix both branches closed the
--     progress dialog and went quiet.
--   * After a refusal the Save button stays lit and a second attempt publishes a new
--     write. An accepted save shows no dialog and darkens the button.

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

local function anything()
  local t = {}
  return setmetatable(t, {
    __index = function() return function() return anything() end end,
    __call = function() return anything() end,
  })
end

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------

lcd = anything()
system = anything()

local dialogs = {}
local choiceSetters = {}
form = anything()
form.clear = function() end
form.addLine = function() return anything() end
form.addChoiceField = function(_, _, _, getter, setter)
  choiceSetters[#choiceSetters + 1] = {get = getter, set = setter}
  return anything()
end
form.openDialog = function(opts) dialogs[#dialogs + 1] = opts end

local headerOpts = nil
local saveEnabledCalls = {}
local headerHandle = anything()
headerHandle.setSaveEnabled = function(v) saveEnabledCalls[#saveEnabledCalls + 1] = v end
package.loaded["rfsuite.app.header"] = {build = function(_, opts) headerOpts = opts; return headerHandle end}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return true end}
package.loaded["rfsuite.app.progress_dialog"] = {open = function() return {value = function() end, close = function() end} end}

-- The status read: the page takes its state from the reply.
local statusRead = nil
package.loaded["rfsuite.lib.msp_status"] = {
  buildReadMessage = function(onOk, onErr)
    statusRead = {
      processReply = function()
        onOk({pid_profile_count = 3, control_rate_profile_count = 3,
              current_pid_profile_index = 0, current_control_rate_profile_index = 0})
      end,
      errorHandler = onErr,
    }
    return statusRead
  end,
}

local bus = requireModule("lib/bus.lua")
local writes = {}   -- every msp.request the page publishes, in order
bus.subscribe("msp.request", function(message) writes[#writes + 1] = message end)

local page = requireModule("app/pages/profile_select.lua")

-- ---------------------------------------------------------------------------
-- Scenario helpers
-- ---------------------------------------------------------------------------

local wakeupHandler = nil
local function open()
  dialogs, saveEnabledCalls, writes, choiceSetters = {}, {}, {}, {}
  headerOpts, wakeupHandler = nil, nil
  page.open({
    onBack = function() end,
    setWakeupHandler = function(fn) wakeupHandler = fn end,
  })
  statusRead.processReply()                   -- the FC answers the status read
  if wakeupHandler then wakeupHandler() end   -- renders the page
end

local function choose(index)
  choiceSetters[2].set(index)                 -- the rate field is the second choice field
end

local function pressSave()
  headerOpts.onSave()                         -- Save
  local confirm = dialogs[#dialogs]
  if confirm and confirm.buttons then confirm.buttons[1].action() end  -- confirm
end

local function failureDialogOpened()
  for _, d in ipairs(dialogs) do
    if d.title == "@i18n(app.msg_save_failed_title)@" and d.message == "@i18n(app.msg_save_failed_body)@" then
      return true
    end
  end
  return false
end

local function lastSaveEnabled()
  return saveEnabledCalls[#saveEnabledCalls]
end

-- ---------------------------------------------------------------------------
-- 1. A refused rate write is reported and the button stays lit
-- ---------------------------------------------------------------------------

print("refused rate write")
open()
choose(1)                                     -- a real change: rate profile 0 -> 1
pressSave()
local rateWrite = writes[#writes]
rateWrite.errorHandler()                      -- the FC refuses the rate write
check("a refused rate write shows the save-failed dialog", failureDialogOpened())
check("a refused rate write keeps the Save button lit", lastSaveEnabled() == true,
      tostring(lastSaveEnabled()))
local before = #writes
pressSave()
check("after a refusal a second attempt is written again", #writes > before,
      "writes=" .. #writes .. " before=" .. before)

-- ---------------------------------------------------------------------------
-- 2. A refused PID write, after the rate write was accepted, is reported
-- ---------------------------------------------------------------------------

print("refused PID write")
open()
choose(2)
pressSave()
writes[#writes].processReply()                -- rate write accepted
local pidWrite = writes[#writes]
pidWrite.errorHandler()                       -- PID write refused
check("a refused PID write shows the save-failed dialog", failureDialogOpened())
check("a refused PID write keeps the Save button lit", lastSaveEnabled() == true,
      tostring(lastSaveEnabled()))

-- ---------------------------------------------------------------------------
-- 3. An accepted save: no failure dialog, the button goes dark
-- ---------------------------------------------------------------------------

print("accepted save")
open()
choose(1)
pressSave()
writes[#writes].processReply()                -- rate accepted
writes[#writes].processReply()                -- PID accepted
check("an accepted save shows no failure dialog", not failureDialogOpened())
check("an accepted save darkens the Save button", lastSaveEnabled() == false,
      tostring(lastSaveEnabled()))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
