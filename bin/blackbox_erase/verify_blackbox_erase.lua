-- Behaviour check for #2495: the dataflash erase on Controls -> Blackbox -> Status.
--
-- Run it:
--     lua5.4 bin/blackbox_erase/verify_blackbox_erase.lua
--     lua5.4 bin/blackbox_erase/verify_blackbox_erase.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/blackbox_status.lua. The header, the
-- progress dialog, the form and the MSP messages are stubs; every message the page
-- publishes is recorded, and the scenario answers each read and write by hand, in the
-- order it wants. Nothing is timed.
--
-- The three defects, and the scenario for each:
--   1. A read that was asked for before the erase can satisfy the erase wait, because
--      it carries the flash state from before the erase (S1).
--   2. A read asked for while another is in flight is dropped, so after the erase no
--      read follows it and the wait never sees the erased flash (S2).
--   3. The Tool button is always offered, and a second erase can start while one runs (S3).
--
-- Against unpatched master the S1, S2 and S3 checks fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local PAGE = ROOT .. "/src/rfsuite/app/pages/blackbox_status.lua"

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

local FLAG_READY, FLAG_SUPPORTED = 1, 2

-- ---------------------------------------------------------------------------
-- Stubs.
-- ---------------------------------------------------------------------------

local sent, dialogs, progresses, headerOpts, header
local function resetScene()
  sent, dialogs, progresses = {}, {}, {}
  headerOpts = nil
  header = {toolEnabled = nil, reloadEnabled = nil}
end

local function anyStub()
  return setmetatable({}, { __index = function() return function() return {} end end })
end

package.loaded["rfsuite.lib.require"] = function(name)
  if name == "lib/bus.lua" then
    return {
      publish = function(topic, msg)
        if topic == "msp.request" then sent[#sent + 1] = msg end
      end,
      subscribe = function() end,
    }
  elseif name == "app/close_key.lua" then
    return { shouldHandleClose = function() return false end }
  elseif name == "app/header.lua" then
    return {
      build = function(_, opts)
        headerOpts = opts
        header.setToolEnabled = function(v) header.toolEnabled = v and true or false end
        header.setReloadEnabled = function(v) header.reloadEnabled = v end
        header.focusTool = function() end
        header.focusMenu = function() end
        header.focusReload = function() end
        return header
      end,
    }
  elseif name == "app/progress_dialog.lua" then
    return {
      open = function()
        local p = { closed = false, value = function() end }
        p.close = function() p.closed = true end
        progresses[#progresses + 1] = p
        return p
      end,
    }
  elseif name == "lib/msp_dataflash_summary.lua" then
    return { buildReadMessage = function(ok, err) return { kind = "summary", ok = ok, err = err } end }
  elseif name == "lib/msp_sdcard_summary.lua" then
    return { buildReadMessage = function(ok, err) return { kind = "sdcard", ok = ok, err = err } end }
  elseif name == "lib/msp_dataflash_erase.lua" then
    return { buildWriteMessage = function(ok, err) return { kind = "erase", ok = ok, err = err } end }
  end
  return anyStub()
end

form = {
  clear = function() end,
  addLine = function() return {} end,
  addStaticText = function() return { value = function() end } end,
  openDialog = function(o)
    dialogs[#dialogs + 1] = o
  end,
}

-- ---------------------------------------------------------------------------
-- Helpers.
-- ---------------------------------------------------------------------------

local function latest(kind)
  for i = #sent, 1, -1 do
    if sent[i].kind == kind then return sent[i] end
  end
  return nil
end

local function countOf(kind)
  local n = 0
  for _, m in ipairs(sent) do if m.kind == kind then n = n + 1 end end
  return n
end

-- Answers the summary and sdcard reads of one poll. The sdcard answer is always ok.
local function answerPoll(summaryMsg, sdcardMsg, flags, total, used)
  summaryMsg.ok({ flags = flags, total = total or 100, used = used or 10 })
  sdcardMsg.ok({ flags = 0, state = 4, filesystemLastError = 0, freeSizeKB = 1000, totalSizeKB = 2000 })
end

local function openPage(opts)
  resetScene()
  local blackbox = dofile(PAGE)
  blackbox.open(opts or {})
end

-- Opens the page and answers the first poll as a supported, ready board.
local function openReady()
  openPage({})
  local s, c = latest("summary"), latest("sdcard")
  answerPoll(s, c, FLAG_READY + FLAG_SUPPORTED)
end

-- Presses Tool, then OK in the confirmation: starts the erase. Returns the erase message.
local function startErase()
  headerOpts.onTool()
  local confirm = dialogs[#dialogs]
  confirm.buttons[1].action()
  return latest("erase")
end

local function runChecks()
  -- S1: a read asked for before the erase must not end the erase wait.
  do
    openReady()
    headerOpts.onReload()                 -- P2: a read in flight, asked before the erase
    local staleSummary, staleSdcard = latest("summary"), latest("sdcard")
    local erase = startErase()
    erase.ok()                            -- the erase command is acknowledged
    -- P2 answers with the flash as it was before the erase: ready, and not yet erased.
    answerPoll(staleSummary, staleSdcard, FLAG_READY + FLAG_SUPPORTED)
    check("S1 a read asked for before the erase does not close the erase dialog",
      progresses[#progresses].closed == false,
      "the dialog closed on a read taken before the erase")
  end

  -- S2: a read asked for while another is in flight is queued, and a read after the
  -- erase closes the wait.
  do
    openReady()
    headerOpts.onReload()                 -- P2 in flight, its answer still outstanding
    local staleSummary, staleSdcard = latest("summary"), latest("sdcard")
    local erase = startErase()
    erase.ok()                            -- the erase is done; the next read must be a new one
    local before = countOf("summary")
    answerPoll(staleSummary, staleSdcard, FLAG_SUPPORTED)   -- P2 answers: not ready (erasing)
    check("S2 a read is issued after the erase even though another was in flight",
      countOf("summary") > before, "no read was issued after the erase")
    local fresh = latest("summary")
    local freshSdcard = latest("sdcard")
    answerPoll(fresh, freshSdcard, FLAG_READY + FLAG_SUPPORTED)   -- the flash is erased and ready
    check("S2 the first read after the erase ends the wait",
      progresses[#progresses].closed == true, "the erase dialog is still open")
  end

  -- S3a: the Tool button follows the board: off without dataflash, on when ready.
  do
    openPage({})
    answerPoll(latest("summary"), latest("sdcard"), 0)   -- no dataflash on this board
    check("S3 the Tool button is off on a board without dataflash",
      header.toolEnabled == false, "toolEnabled = " .. tostring(header.toolEnabled))
    headerOpts.onReload()
    answerPoll(latest("summary"), latest("sdcard"), FLAG_READY + FLAG_SUPPORTED)
    check("S3 the Tool button is on once the board is ready",
      header.toolEnabled == true, "toolEnabled = " .. tostring(header.toolEnabled))
  end

  -- S3b: a second press while an erase runs does not offer a second erase.
  do
    openReady()
    local erase = startErase()
    local dialogCount = #dialogs
    headerOpts.onTool()
    check("S3 a second press while erasing opens no second confirmation",
      #dialogs == dialogCount, "confirmations opened: " .. (#dialogs - dialogCount))
    check("S3 the erase is still a single command", countOf("erase") == 1)
    erase.ok()
  end
end

-- ---------------------------------------------------------------------------
-- Run.
-- ---------------------------------------------------------------------------

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

print("page: src/rfsuite/app/pages/blackbox_status.lua")
runChecks()

if selfTest then
  print("")
  print("--self-test: the erase wait must go red without the sequence test")
  local source = readFile(PAGE)
  local spliced, n = source:gsub(
    "if eraseInProgress and eraseDoneSeq and seq and seq >= eraseDoneSeq and pending == 0 and dataflash%.ready then",
    "if eraseInProgress and dataflash.ready then", 1)
  if n ~= 1 then
    check("the sequence test is present in the page to splice out", false, "no match in blackbox_status.lua")
  else
  local realLoad = _G.load
  local original = dofile
  dofile = function(path)
    if path == PAGE then return assert(realLoad(spliced, "@blackbox_status_pre_fix"))() end
    return original(path)
  end
  local before = failures
  runChecks()
  local red = failures > before
  failures = before
  dofile = original
  check("the S1 wait goes red without the sequence test", red)
  end
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
