-- Behaviour check for the live Yaw Center Trim of Setup > Mixer > Tail.
--
-- Run it (from the repository root):
--     lua5.4 bin/tail_live_trim/verify_tail_live_trim.lua
--     lua5.4 bin/tail_live_trim/verify_tail_live_trim.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/mixer_tail.lua, with the
-- MSP modules it uses replaced by recording stubs and page_runtime replaced by
-- a small stand-in that calls the page's own hooks (onLoaded, onWakeup,
-- onTool, onDispose). The page's live-trim logic is under test; the runtime's
-- save and reboot machinery is not.
--
-- Pinned:
--   1. opening the override sends no trim, and no trim is sent before an edit;
--   2. an edit of the centre field is sent once, after the settle time, with the
--      write's confirmation callbacks attached;
--   3. while a write is pending nothing else is sent;
--   4. a refused write keeps the confirmed trim and is retried after the settle time;
--   5. no live write while the model is armed, nor while it is not known to be
--      disarmed (armedOrUnconfirmed: isArmed nil with armedUnconfirmed true);
--   6. leaving without saving restores the saved trim while disarmed, and sends
--      nothing while armed.
--
-- --self-test runs the same checks on two broken copies of the page (a write
-- sent without callbacks; the armed gate reduced to isArmed == true). Both must
-- go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local PAGE = ROOT .. "/src/rfsuite/app/pages/mixer_tail.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

-- ── environment ───────────────────────────────────────────────────────

local clock = 0
os.clock = function() return clock end

local function newField()
  local w = {}
  w.rect = function() return nil end
  w.enable = function(self, v) self.enabled = v end
  for _, m in ipairs({ "suffix", "decimals", "default", "enableInstantChange" }) do
    w[m] = function() end
  end
  return w
end

local numberFields = {}
local lastDialog = nil

_G.form = {
  addLine = function() return {} end,
  clear = function() end,
  openDialog = function(o) lastDialog = o; return {} end,
  addStaticText = function() return newField() end,
  addChoiceField = function() return newField() end,
  addNumberField = function(_, _, _, _, get, set)
    local f = newField()
    f.get, f.set = get, set
    numberFields[#numberFields + 1] = f
    return f
  end,
}
_G.TEXT_LEFT, _G.LEFT, _G.FONT_S = 2, 3, 20
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }
_G.system = { getVersion = function() return { simulation = false } end }

-- ── recording stubs ───────────────────────────────────────────────────

local published = {}
local rt = nil

local stubs = {}
stubs["lib/bus.lua"] = {
  publish = function(topic, msg) if topic == "msp.request" then published[#published + 1] = msg end end,
  subscribe = function() end,
  unsubscribe = function() end,
}
stubs["lib/msp_mixer_config.lua"] = {
  buildWriteMessage = function(mixer, onWritten, onError)
    return { kind = "config", trim = mixer.tail_center_trim, onWritten = onWritten, onError = onError }
  end,
}
stubs["lib/msp_mixer_override.lua"] = {
  OVERRIDE_OFF = 0,
  buildWriteMessage = function(yaw, mode) return { kind = "override", yaw = yaw, mode = mode } end,
}
stubs["lib/msp_mixer_input.lua"] = { yaw = function() return {} end }
stubs["lib/msp_tail_motor_output.lua"] = {
  movable = function() return false end,
  OUTPUT = { NONE = 0, SERVO = 1, MOTOR = 2, BOTH = 3 },
  RESULT = { CUSTOM = 1, NO_MAIN_MOTOR = 2, NO_TIMER = 3, TIMER_SHARED = 4, NO_DMA = 5 },
}

-- A stand-in for app/page_runtime.lua with the members the page uses.
local function newRuntime(opts)
  local r = { opts = opts, loaded = false, busy = false, activeDialog = nil, data = {},
    isArmed = nil, armedUnconfirmed = nil, controlRef = {} }
  r.controlRef.runtime = r
  function r:armedOrUnconfirmed()
    return self.isArmed == true or (self.isArmed == nil and self.armedUnconfirmed == true)
  end
  function r:markDirty() end
  function r:updateToolEnabled() end
  function r:registerField() end
  function r:buildChrome() end
  function r:loadInitial()
    self.data = {
      mixer = { tail_rotor_mode = 0, tail_center_trim = 0, tail_motor_idle = 0 },
      yaw = { rate_stabilized_yaw = 0, min_stabilized_yaw = 0, max_stabilized_yaw = 0 },
      tail = {},
    }
    self.loaded = true
    self.opts.onLoaded(self)
  end
  rt = r
  return r
end
stubs["app/page_runtime.lua"] = { new = newRuntime }

package.loaded["rfsuite.lib.require"] = function(path)
  local s = stubs[path]
  if not s then error("unexpected require: " .. tostring(path)) end
  return s
end

-- ── helpers ───────────────────────────────────────────────────────────

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local function sent(kind)
  local out = {}
  for _, m in ipairs(published) do if m.kind == kind then out[#out + 1] = m end end
  return out
end

local function openPage(source)
  published = {}
  numberFields = {}
  lastDialog = nil
  rt = nil
  local chunk = assert(load(source, "@mixer_tail.lua", "t"))
  local page = chunk()
  page.open()
  return rt
end

-- Drives the page's hooks through one scenario and returns how many checks failed.
local function run(source)
  local before = failures
  clock = 100
  local r = openPage(source)
  local o = r.opts
  local centre = numberFields[1] -- addSlot("center") is the first number field

  -- Turn the override on through the tool dialog.
  o.onTool(function() end)
  lastDialog.buttons[1].action()
  check("override on sends the override, not a trim",
    #sent("override") == 1 and #sent("config") == 0)

  -- 1. No trim before an edit, even with the override on.
  clock = 200; o.onWakeup(r)
  check("no trim is sent before the centre field is edited", #sent("config") == 0)

  -- 2. One edit, sent once after the settle time, with callbacks.
  centre.set(3)
  clock = 200.2; o.onWakeup(r)
  check("nothing is sent before the settle time", #sent("config") == 0)
  clock = 201; o.onWakeup(r)
  local first = sent("config")
  check("one trim is sent after the settle time", #first == 1, "sent " .. #first)
  check("the trim write carries its confirmation callbacks",
    #first >= 1 and type(first[1].onWritten) == "function" and type(first[1].onError) == "function")

  -- 3. While the write is pending, nothing else goes out.
  clock = 300; o.onWakeup(r)
  check("no second trim while a write is pending", #sent("config") == 1)

  -- 4. The FC refuses: keep the confirmed trim, retry after the settle time.
  if first[1] and first[1].onError then first[1].onError() end
  clock = 301; o.onWakeup(r)
  check("a refused write is retried after the settle time", #sent("config") == 2)
  if sent("config")[2] and sent("config")[2].onWritten then sent("config")[2].onWritten() end

  -- 5. No live write while armed, nor while not known to be disarmed.
  centre.set(6)
  clock = 400
  r.isArmed = true
  o.onWakeup(r)
  check("no live write while armed", #sent("config") == 2)
  r.isArmed = nil; r.armedUnconfirmed = true
  o.onWakeup(r)
  check("no live write while armed is unconfirmed", #sent("config") == 2)
  r.armedUnconfirmed = nil; r.isArmed = false
  clock = 402; o.onWakeup(r)
  check("the live write goes out once disarmed", #sent("config") == 3)
  if sent("config")[3] and sent("config")[3].onWritten then sent("config")[3].onWritten() end

  -- 6. Leaving without saving: restore the saved trim, but not while armed.
  local base = #sent("config")
  r.isArmed = true
  o.onDispose(r)
  check("no restore write while armed", #sent("config") == base)
  r.isArmed = false
  o.onDispose(r)
  check("leaving disarmed restores the saved trim", #sent("config") == base + 1)

  return failures - before
end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return s
end

local source = readFile(PAGE)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  tail live trim: override, settle, retry, armed gate and restore behave as pinned (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- Two broken copies of the page; each must make the checks red.
local mutants = {
  { name = "write sent without confirmation callbacks",
    from = "mixerConfig.buildWriteMessage(liveMixer, onTrimWritten, onTrimError)",
    to = "mixerConfig.buildWriteMessage(liveMixer)" },
  { name = "armed gate reduced to isArmed == true",
    from = "rt:armedOrUnconfirmed()", to = "(rt.isArmed == true)" },
}
local red = 0
for _, m in ipairs(mutants) do
  local escaped = m.from:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
  local mutated, count = source:gsub(escaped, (m.to:gsub("%%", "%%%%")))
  if count == 0 then
    print("FAIL  self-test: pattern for '" .. m.name .. "' not found; update this harness")
  else
    failures, checks = 0, 0
    local caught = run(mutated)
    if caught > 0 then
      red = red + 1
      print("ok    mutant red: " .. m.name .. " (" .. caught .. " failed checks)")
    else
      print("FAIL  mutant passed the checks: " .. m.name)
    end
  end
end
if red == #mutants then
  print("OK  self-test: both broken copies go red")
  os.exit(0)
end
os.exit(1)
