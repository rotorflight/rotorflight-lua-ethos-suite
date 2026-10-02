-- Behaviour check for the governor-profile write guard (#2348).
--
-- Run it:
--     lua5.3 bin/governor_profile/verify_governor_profile_write.lua
--     lua5.3 bin/governor_profile/verify_governor_profile_write.lua --self-test
--
-- What it drives, and why:
--   * The real app/page_runtime.lua with the real lib/msp_governor_profile.lua,
--     under an Ethos stub, because the claim is about what the runtime does
--     with a message the codec declines to build. Asserting on encode() alone
--     would pass while page_runtime happily published the nil -- which is what
--     a codec returning nil only buys if the caller treats it as a refusal.
--   * The real page_runtime is driven the way the radio drives it: open() ->
--     loadInitial() -> the reads answer -> a wakeup settles the load -> a pilot
--     edit -> the Save button. The MSP requests it publishes are recorded, so
--     "did it write MSP_SET_GOVERNOR_PROFILE" is a fact about what went out
--     rather than about what a return value said.
--
-- What the firmware does with what arrives, so the bounds below are not guessed:
--   * MSP_GOVERNOR_PROFILE (read, cmd 148) writes 15 fields unconditionally --
--     src/main/msp/msp.c:2123-2139, 13x U8 plus 2x U16 = 17 bytes, no
--     remaining-byte-count guard. A short reply can only be a transport fault,
--     not a shape this firmware produces.
--   * So the encoder's only honest question is PRESENCE: 0 is a legitimate
--     governor_gain and a legitimate governor_d_gain, and 0 is also what
--     `data[name] or 0` invents for a field that never arrived. The firmware
--     cannot tell those apart either -- headspeed 0 and max throttle 0 are
--     in range -- which is why the refusal has to happen here.
--
-- Which cases go RED on the pre-fix codec:
--   * case 3 (buildWriteMessage) returned a message carrying a 17-byte payload
--     of zeros.
--   * case 4 (the runtime) published MSP_SET_GOVERNOR_PROFILE with it.
--   * case 2 refuses nothing at all.
-- Cases 1, 5 and 6 pin behaviour that has to survive this: the happy path
-- still writes, and the load gate that was already in page_runtime (a failed
-- source keeps loaded == false and canSave() false, page_runtime.lua:607-622
-- and :462-471) still holds. A check that cannot fail proves nothing about what
-- it passes, which is what --self-test is for: it re-runs cases 2, 3 and 4
-- against a copy of the codec with the guard removed and requires each to fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local CODEC_SRC = SUITE .. "/lib/msp_governor_profile.lua"

local SELF_TEST = arg[1] == "--self-test"

local checks, failures = 0, 0
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

-- The wire struct the firmware writes: 13 U8 + 2 U16. Counted from
-- msp.c:2123-2139, and it is the length the suite's own module header calls
-- "the full 17-byte struct".
local EXPECTED_BYTES = 17

-- ---------------------------------------------------------------------------
-- Ethos environment
-- ---------------------------------------------------------------------------

local SUITE_PREFIX = SUITE .. "/"
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile

-- requireModule() calls loadfile() with a path that carries no directory part;
-- on the radio the working directory is src/rfsuite.
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

_G.package = package
_G.package.loaded = package.loaded
_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.print = function() end
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

local widgetStub, dialogStub

_G.form = {
  addButton = function() return widgetStub("button") end,
  addTextButton = function() return widgetStub("textbutton") end,
  addStaticText = function() return widgetStub("text") end,
  addNumberField = function() return widgetStub("numberField") end,
  addChoiceField = function() return widgetStub("choiceField") end,
  addLine = function() return 1 end,
  clear = function() end,
  height = function() return 320 end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local slots = {}
    for i = 1, n do slots[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 } end
    return slots
  end,
  openDialog = function() return dialogStub("openDialog") end,
  openProgressDialog = function() return dialogStub("openProgressDialog") end,
}

widgetStub = function(name)
  local w
  w = {
    name = name,
    enabled = nil,
    focus = function() end,
    enable = function(_, on) w.enabled = on end,
    value = function(_, v) return v end,
    setValue = function() end,
    setText = function() end,
    getValue = function() return 0 end,
    decimals = function() end,
    suffix = function() end,
    step = function() end,
    default = function() end,
    show = function() end,
    hide = function() end,
    close = function() end,
  }
  return w
end

dialogStub = function(kind)
  local d
  d = {
    kind = kind,
    closed = false,
    value = function() end,
    message = function() end,
    closeAllowed = function() end,
    close = function() d.closed = true end,
  }
  return d
end

_G.TIME_LEFT = 1
_G.TEXT_LEFT = 2
_G.LEFT = 3
_G.CENTERED = 4
_G.RIGHT = 5
_G.TOP_LEFT = 6
_G.FONT_XS = 10
_G.FONT_S = 20
_G.FONT_M = 30
_G.FONT_L = 40
_G.FONT_XL = 50
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07
_G.KEY_ENTER_BREAK = 0x08

-- ---------------------------------------------------------------------------
-- Module stubs
-- ---------------------------------------------------------------------------

-- Every MSP message the page publishes, in order. This is the whole point of
-- the harness: "did it write MSP_SET_GOVERNOR_PROFILE" is answered from what
-- went onto the bus, not from a return value.
local sent = {}
local writes = {}

-- The command whose read is made to FAIL, or nil. Set per case, so "the pid read
-- fails" and "the governor read fails" are different situations and both can be
-- driven -- the governor half is the subject, so the case that must fail the
-- governor read has to fail *that* one and let the other through.
local failCommand = nil

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    sent[#sent + 1] = message
    if message.isWrite then
      writes[#writes + 1] = message
      -- Acknowledge it, the way the flight controller does. Without this the
      -- source chain in performSave() stops at the first write and the
      -- governor half of the page is never even asked -- so a case could pass
      -- because the second source was unreachable rather than because the
      -- guard worked. This is also the only thing that makes case 6 mean
      -- anything.
      if type(message.processReply) == "function" then message.processReply() end
      return
    end
    if type(message.processReply) ~= "function" then return end
    if failCommand and message.command == failCommand then
      if message.errorHandler then message.errorHandler("simulated read failure") end
      return
    end
    -- Answered with the module's own simulatorResponse, which is the seam the
    -- Ethos simulator uses (see tasks/msp/queue.lua). The decoders are therefore
    -- the real ones and the reply is the real fixture.
    message.processReply(nil, message.selfAnswering and nil or message.simulatorResponse)
  end,
}

-- Off, so confirmSave() routes straight into performSave() instead of stopping
-- at a confirmation modal. It is the only setting under which the write path is
-- reachable at all, and it is a real one (Settings -> General -> Safety Prompts).
package.loaded["rfsuite.lib.settings_store"] = {
  saveConfirmEnabled = function() return false end,
  reloadConfirmEnabled = function() return true end,
  developerModeEnabled = function() return false end,
  load = function() return { general = {}, developer = {} } end,
  save = function() end,
  DEFAULTS = { general = {}, developer = {} },
}

package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = {
  print = function() end,
  format = function() end,
  msp = function() end,
  enabled = function() return false end,
  mspEnabled = function() return false end,
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function() return { command = 250, isWrite = true } end,
}
package.loaded["rfsuite.lib.msp_reboot"] = { reboot = function() end }

-- The header is what the pilot's Save button is: page_runtime passes onSave in
-- here and the stub keeps it, so the save is driven through the same door the
-- pilot's press goes through.
local headerOpts = nil

package.loaded["rfsuite.app.header"] = {
  build = function(_, opts)
    headerOpts = opts
    return {
      setTitle = function() end,
      setSaveEnabled = function() end,
      setReloadEnabled = function() end,
      focusMenu = function() end,
      focusSave = function() end,
      focusReload = function() end,
      focusTool = function() end,
    }
  end,
}

-- The second source of app/pages/tail_rotor.lua's multi-source page. A stub,
-- because the governor half is the subject and this half only has to exist.
-- `selfAnswering` marks its processReply as not wanting a byte buffer, so the
-- bus stub can answer both sources without knowing either one's wire shape.
local PID_FIELDS = {yaw_cw_stop_gain = 10, yaw_ccw_stop_gain = 20}

local function pidStub()
  return {
    buildReadMessage = function(onData, onError)
      return {
        command = 94,
        selfAnswering = true,
        onData = onData,
        onError = onError,
        errorHandler = onError,
        processReply = function()
          local values = {}
          for k, v in pairs(PID_FIELDS) do values[k] = v end
          onData(values)
        end,
      }
    end,
    buildWriteMessage = function(values, onWritten)
      -- processReply is what carries the acknowledgement, exactly as the real
      -- codecs build it (lib/msp_governor_profile.lua's buildWriteMessage).
      -- Leaving it out stops performSave()'s source chain after the first write,
      -- and every "the governor source was never asked" check then passes
      -- vacuously.
      return {
        command = 95,
        isWrite = true,
        payload = values,
        processReply = function()
          if onWritten then onWritten() end
        end,
      }
    end,
  }
end

-- ---------------------------------------------------------------------------
-- The codec under test
-- ---------------------------------------------------------------------------

-- Loaded from a given file so the self-test can put the pre-fix codec in the
-- same seat. realLoadfile, deliberately, not the redirect above: the redirect
-- prepends the suite prefix to anything ending in .lua, which is right for
-- requireModule()'s bare "lib/..." paths and wrong for this absolute-ish one.
-- The file's OWN loadfile() calls still go through the redirect, so its codec
-- and mspcodec load as usual.
local function loadCodec(file)
  package.loaded["rfsuite.lib.msp_governor_profile"] = nil
  return assert(realLoadfile(file))()
end

local codec = loadCodec(CODEC_SRC)

-- The table decode() produces for a complete reply: every field in FIELDS, none
-- of them zero, so "the payload is all zeros" is a statement about a refusal
-- rather than about this fixture.
local function completeValues()
  local values = {}
  for i = 1, #codec.FIELDS do
    local name = codec.FIELDS[i][1]
    values[name] = 100 + i
  end
  return values
end

local function countZeroBytes(payload)
  local n = 0
  for i = 1, #payload do
    if payload[i] == 0 then n = n + 1 end
  end
  return n
end

-- ---------------------------------------------------------------------------
-- Driving page_runtime the way the radio does
-- ---------------------------------------------------------------------------

local PageRuntime = dofile(SUITE .. "/app/page_runtime.lua")

local function optsWithHandlers()
  local opts = {}
  local installed = {}
  local function setter(name)
    return function(handler) installed[name] = handler end
  end
  -- Stored in a side table, not back onto opts: writing the handler under the
  -- setter's own name would replace the setter with the handler, and the wakeup
  -- would then call itself.
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() end
  -- So tick() can reach the currently-installed handlers without reading them
  -- back off opts, where a name is already taken by the setter.
  opts.__installed = installed
  return opts, installed
end

local function openTail(opts)
  sent = {}
  writes = {}
  headerOpts = nil
  failCommand = nil

  opts = opts or optsWithHandlers()
  local runtime = PageRuntime.new({
    pageTitle = "Harness",
    logTag = "tailrotor",
    sources = {
      {key = "pid", mspModule = pidStub()},
      {key = "governor", mspModule = codec},
    },
    opts = opts,
  })
  runtime:buildChrome()
  runtime:loadInitial()
  opts.__runtime = runtime
  return runtime, opts
end

-- One wakeup tick, which is what settles a load on the radio: loadData queues
-- its success branch and the wakeup runs it.
local function tick(opts)
  local installed = opts.__installed
  if installed and installed.setWakeupHandler then installed.setWakeupHandler() end
end

local function countGovernorWrites()
  local n = 0
  for i = 1, #writes do
    if writes[i].command == codec.WRITE_COMMAND then n = n + 1 end
  end
  return n
end

-- The pilot's Save button: the header's onSave, which is the same function the
-- physical key and the button both reach. Returns what the pilot was shown.
local function pressSave(opts)
  -- performSave() sets pendingSaveError and the wakeup consumes it into
  -- showSaveError(). Watching the flag instead would read it after the wakeup
  -- has already cleared it, so the outcome is watched where the pilot meets it.
  local shown = {}
  local runtime = opts.__runtime
  if runtime then
    local realShowSaveError = runtime.showSaveError
    runtime.showSaveError = function(self, focusFn)
      shown[#shown + 1] = "save"
      return realShowSaveError(self, focusFn)
    end
    local realShowLoadError = runtime.showLoadError
    runtime.showLoadError = function(self, focusFn)
      shown[#shown + 1] = "load"
      return realShowLoadError(self, focusFn)
    end
  end
  if headerOpts and headerOpts.onSave then headerOpts.onSave() end
  tick(opts)
  return shown
end

local function countWritesBy(cmd)
  local n = 0
  for i = 1, #writes do
    if writes[i].command == cmd then n = n + 1 end
  end
  return n
end

local EEPROM_COMMAND = 250

-- ---------------------------------------------------------------------------
-- cases
-- ---------------------------------------------------------------------------

out("case 1: a complete table encodes to the full wire struct")
do
  local payload = codec.encode(completeValues())
  check("encode() returns a payload", type(payload) == "table")
  if type(payload) == "table" then
    check(string.format("the payload is %d bytes, the struct msp.c:2123-2139 writes",
      EXPECTED_BYTES),
      #payload == EXPECTED_BYTES, string.format("got %d", #payload))
    check("and it is not a field of zeros",
      countZeroBytes(payload) < EXPECTED_BYTES,
      string.format("%d of %d bytes are 0", countZeroBytes(payload), #payload))
  end
end

out("")
out("case 2: every single missing field is refused, not zero-filled")
do
  -- One missing field proves the guard exists; all fifteen prove it is a loop
  -- over FIELDS and not a spot check on one name.
  local leaked, bad = 0, nil
  for i = 1, #codec.FIELDS do
    local values = completeValues()
    local name = codec.FIELDS[i][1]
    values[name] = nil
    local payload = codec.encode(values)
    if payload ~= nil then
      leaked = leaked + 1
      if not bad then
        bad = string.format("%s: encode() returned %d bytes (%d of them 0)",
          name, #payload, countZeroBytes(payload))
      end
    end
  end
  check(string.format("encode() refuses with any one of the %d fields missing",
    #codec.FIELDS),
    leaked == 0, string.format("%d of %d were still encoded%s", leaked, #codec.FIELDS,
      bad and ("; first: " .. bad) or ""))
  check("an empty table -- what an unanswered read leaves behind -- is refused",
    codec.encode({}) == nil)
  check("a non-table is refused rather than indexed",
    codec.encode(nil) == nil)
end

out("")
out("case 3: buildWriteMessage() declines instead of returning a message")
do
  local values = completeValues()
  values.governor_headspeed = nil
  local message, missing = codec.buildWriteMessage(values)
  check("no message is returned for an incomplete table", message == nil,
    message and string.format("returned a message with a %d-byte payload",
      type(message.payload) == "table" and #message.payload or -1))
  check("and it names the field it refused on", missing == "governor_headspeed",
    string.format("missing = %s", tostring(missing)))

  local good = codec.buildWriteMessage(completeValues())
  check("a complete table still yields a message", type(good) == "table")
  if type(good) == "table" then
    check(string.format("whose payload is %d bytes", EXPECTED_BYTES),
      type(good.payload) == "table" and #good.payload == EXPECTED_BYTES)
  end
end

out("")
out("case 4: page_runtime does not publish a refused write  <- the runtime half")
do
  local runtime, opts = openTail()
  tick(opts)
  check("the page loaded", runtime.loaded == true,
    string.format("loaded = %s", tostring(runtime.loaded)))

  -- The shape the issue describes: the governor table never received a read.
  runtime.data.governor = {}
  runtime:markDirty()

  local shown = pressSave(opts)

  check("MSP_SET_GOVERNOR_PROFILE was NOT published", countGovernorWrites() == 0,
    string.format("%d governor writes went out", countGovernorWrites()))
  check("the pid source, which came first, was written", countWritesBy(95) == 1,
    string.format("%d pid writes", countWritesBy(95)))
  check("and the EEPROM commit was NOT reached", countWritesBy(EEPROM_COMMAND) == 0,
    "the save must stop at the refusal, not commit half of it")
  check("the pilot is shown a save error", #shown == 1 and shown[1] == "save",
    "shown: " .. (#shown == 0 and "(nothing)" or table.concat(shown, ", ")))
end

out("")
out("case 5: the load gate that was already there still holds")
do
  -- Not repaired by this change and not to be broken by it: if the GOVERNOR read
  -- fails, page_runtime must not consider the page loaded and must not offer a
  -- save. page_runtime.lua:607-622 sets loaded = false; :462-471 is canSave().
  -- The governor read is the one made to fail, so the pid read still succeeds --
  -- a page where the first source fails never even issues the second read, which
  -- would test a different thing.
  local opts = optsWithHandlers()
  local runtime = PageRuntime.new({
    pageTitle = "Harness",
    logTag = "tailrotor",
    sources = {
      {key = "pid", mspModule = pidStub()},
      {key = "governor", mspModule = codec},
    },
    opts = opts,
  })
  runtime:buildChrome()
  sent, writes = {}, {}
  failCommand = codec.READ_COMMAND
  runtime:loadInitial()
  tick(opts)
  failCommand = nil

  check("the governor read was actually issued and failed",
    #sent == 2, string.format("%d MSP messages went out", #sent))
  check("a page whose source never answered is not loaded", runtime.loaded == false,
    string.format("loaded = %s", tostring(runtime.loaded)))
  runtime:markDirty()
  check("and cannot save even after an edit", runtime:canSave() == false)
  check("a load error is pending for the pilot to see", runtime.pendingLoadError ~= nil)
end

out("")
out("case 6: the happy path still writes -- so case 4 cannot pass by breaking saving")
do
  local runtime, opts = openTail()
  tick(opts)
  check("the page loaded", runtime.loaded == true)
  runtime:markDirty()
  check("and can save", runtime:canSave() == true)

  pressSave(opts)

  check("both sources were written", countWritesBy(95) == 1 and countGovernorWrites() == 1,
    string.format("pid %d, governor %d -- expected one of each",
      countWritesBy(95), countGovernorWrites()))
  check("and then the single EEPROM commit", countWritesBy(EEPROM_COMMAND) == 1,
    string.format("%d eeprom writes", countWritesBy(EEPROM_COMMAND)))
  check("in that order", (function()
    local order = {}
    for i = 1, #writes do order[i] = writes[i].command end
    local pidAt, govAt, eepAt
    for i = 1, #order do
      if order[i] == 95 then pidAt = i end
      if order[i] == codec.WRITE_COMMAND then govAt = i end
      if order[i] == EEPROM_COMMAND then eepAt = i end
    end
    return pidAt and govAt and eepAt and pidAt < govAt and govAt < eepAt
  end)(), "pid, then governor, then the EEPROM commit that persists both")
  local gov
  for i = 1, #writes do
    if writes[i].command == codec.WRITE_COMMAND then gov = writes[i] end
  end
  check("whose payload is the full struct", gov ~= nil and type(gov.payload) == "table"
    and #gov.payload == EXPECTED_BYTES,
    gov and string.format("%d bytes", type(gov.payload) == "table" and #gov.payload or -1) or "no message")
end

-- ---------------------------------------------------------------------------
-- self-test: the pre-fix codec has to fail cases 2, 3 and 4
-- ---------------------------------------------------------------------------

-- Replaces encode() wholesale with the pre-fix version: `data[name] or 0` and no
-- presence loop, which is the whole of the old code.
--
-- One substitution is enough, and that is not an assumption: the pre-fix encode
-- never returned nil, so buildWriteMessage()'s `if not payload then` branch --
-- which did not exist then either -- is unreachable with the sabotaged encoder
-- in place. The self-test then proves it rather than asserting it, by requiring
-- the sabotaged codec to build a 17-byte all-zero payload from an empty table.
--
-- Matched by plain find() and slicing, not by pattern: the two anchors are
-- unique in the file, and a %%-escaped pattern over a CRLF line terminator is a
-- needless way to get "invalid pattern capture".
local PRE_FIX_ENCODE = [[function msp_governor_profile.encode(data)
  local payload = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    if wireType == "U16" then
      mspcodec.writeU16(payload, data[name] or 0)
    else
      mspcodec.writeU8(payload, data[name] or 0)
    end
  end
  return payload
end]]

local function preFixCodecFile()
  local f = assert(io.open(CODEC_SRC, "rb"))
  local src = f:read("a")
  f:close()

  -- The checked-out tree is CRLF on Windows (core.autocrlf=true, no
  -- .gitattributes), so the terminator written back is the one that was read.
  local nl = src:find("\r\n", 1, true) and "\r\n" or "\n"

  local head = assert(src:find("function msp_governor_profile.encode(data)", 1, true),
    "sabotage: encode() not found")
  local ret = assert(src:find("  return payload", head, true),
    "sabotage: the end of encode() not found")
  local afterRet = assert(src:find(nl, ret, true),
    "sabotage: no line ending after `return payload`")
  local closeEnd = assert(src:find("end", afterRet, true),
    "sabotage: encode() is not closed by `end`")
  local resume = assert(src:find(nl, closeEnd, true),
    "sabotage: no line ending after encode()'s closing `end`") + #nl

  -- PRE_FIX_ENCODE carries its own closing `end`, so the slice resumes past the
  -- original one rather than at it -- otherwise the two join into `endend`.
  local body = PRE_FIX_ENCODE:gsub("\n", nl)
  src = src:sub(1, head - 1) .. body .. nl .. src:sub(resume)

  local path = os.tmpname() .. "_governor_prefix.lua"
  local w = assert(io.open(path, "wb"))
  w:write(src)
  w:close()
  return path
end

if SELF_TEST then
  out("")
  out("self-test: the pre-fix codec must fail cases 2, 3 and 4")
  local path = preFixCodecFile()
  local pre = loadCodec(path)
  local savedCodec = codec

  -- case 2: an empty table must produce a payload there, or the guard is untested
  local leaked = 0
  for i = 1, #pre.FIELDS do
    local values = completeValues()
    values[pre.FIELDS[i][1]] = nil
    if pre.encode(values) ~= nil then leaked = leaked + 1 end
  end
  check("the pre-fix codec encoded with a field missing",
    leaked == #pre.FIELDS,
    string.format("only %d of %d were encoded -- the sabotage is not reproducing the old code",
      leaked, #pre.FIELDS))

  local msg = pre.buildWriteMessage({})
  check("the pre-fix codec built a message from an empty table",
    type(msg) == "table",
    "it refused, so cases 2/3 prove nothing about the old behaviour")

  -- case 4: page_runtime must publish with the sabotaged codec in the seat
  package.loaded["rfsuite.lib.msp_governor_profile"] = pre
  codec = pre

  local runtime, opts = openTail()
  tick(opts)
  runtime.data.governor = {}
  runtime:markDirty()
  pressSave(opts)

  check("the pre-fix codec's zeroed governor struct WAS published",
    countGovernorWrites() == 1,
    string.format("%d governor writes -- the runtime half is not being exercised",
      countGovernorWrites()))
  check("and it was all zeros", (function()
    for i = 1, #writes do
      if writes[i].command == pre.WRITE_COMMAND then
        local p = writes[i].payload
        if type(p) == "table" and #p == EXPECTED_BYTES
            and countZeroBytes(p) == EXPECTED_BYTES then
          return true
        end
        return false
      end
    end
    return false
  end)(), "expected 17 zero bytes -- the payload the guard now refuses")

  codec = savedCodec
  package.loaded["rfsuite.lib.msp_governor_profile"] = savedCodec
  os.remove(path)
else
  out("")
  out("(run with --self-test to prove cases 2, 3 and 4 are able to fail)")
  check("--self-test not requested", true)
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")