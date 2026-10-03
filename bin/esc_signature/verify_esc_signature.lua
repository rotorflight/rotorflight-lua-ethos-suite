-- Behaviour check for the ESC forward-programming signature gate (#2335).
--
-- Run it:
--     lua5.4 bin/esc_signature/verify_esc_signature.lua
--     lua5.4 bin/esc_signature/verify_esc_signature.lua --self-test
--
-- What the defect under test is:
--   Three of the ten ESC tiles in tool.lua's esc_forward_menu -- AM32, BLHeli_S
--   and Bluejay -- all carry `escProtocolId = 1` (tool.lua:227-229), so the menu
--   gate esc_protocol_guard.lua cannot tell them apart: a pilot who opens the
--   wrong one gets a fully populated editor. All three speak MSP 217/218 with
--   the same two-byte header (PARAM_HEADER_SIG at offset 0, PARAM_HEADER_VER at
--   offset 1), so a reply from one is a structurally valid reply to the others.
--
--   The gate is app/pages/esc_forward_vendor.lua:228-236 (isCompatibleEsc),
--   called from the read's reply callback at :281-295: a mismatch sets
--   pendingError = {kind = "signature"} and never sets pendingData, so the
--   wakeup at :251-267 renders app/esc_error.lua:24-27's "wrong ESC" text and
--   buildEditor() at :184 is never reached. No editor means no fields, no Save
--   button and no MSP 218 anywhere -- a stronger state than the issue asked
--   for, which was to disable Save on a form that was already built.
--
--   The three constants it compares, all read off the wire rather than guessed:
--     lib/msp_esc_parameters_am32.lua:197     EXPECTED_SIGNATURE = 194 (0xC2)
--     lib/msp_esc_parameters_blheli_s.lua:149 EXPECTED_SIGNATURE = 193 (0xC1)
--       + isCompatible() at :154-157, which also wants main_revision == 16
--     lib/msp_esc_parameters_bluejay.lua:217  EXPECTED_SIGNATURE = 193 (0xC1)
--       + isCompatible() at :222-225, which also wants main_revision == 0
--   Those match rotorflight-firmware's ESC_SIG_AM32 0xC2 / ESC_SIG_BLHELI_S
--   0xC1 (src/main/sensors/esc_sensor.c:129-130).
--
-- Why the tool-side gate has to exist even though the flight controller also
-- checks -- read, not assumed:
--   * msp.c:3385-3396 (MSP_SET_ESC_PARAMETERS) copies escGetParamBufferLength()
--     bytes out of the sender's payload and calls escCommitParameters(); it
--     inspects no field itself. The FC is a pass-through.
--   * esc_sensor.c:4591-4622 (is4wayParamBufferValid) does check signature,
--     protocol version and payload length, and :4724-4746 turns a false into
--     MSP_RESULT_ERROR. So a cross-signature write is refused -- but as an
--     ERROR RETURN, after the pilot has already been shown a complete editor
--     full of another ESC's bytes with a live Save button.
--   * That check cannot see the BLHeli_S / Bluejay pair apart at all:
--     fwifGetEepromAddress() at :703-729 reports every BLHeli-family target as
--     ESC_SIG_BLHELI_S with payloadLength 0x70, and both protocols carry
--     version 0 (esc_sensor.c:571, :587). Signature, version and length are
--     identical for the two, so for that pair the editor gate is the only one.
--
-- What it drives, and why:
--   * The real app/pages/esc_forward_{am32,blheli_s,bluejay}.lua, so the wiring
--     is under test too -- which codec each page hands the shared editor is
--     half of what makes the gate correct. Each page is entered through its own
--     open(), and the 4-way target selector is stubbed: it only decides WHICH
--     ESC to talk to and holds no signature state.
--   * The real app/pages/esc_forward_vendor.lua, the real app/esc_error.lua, the
--     real app/header.lua and the real app/page_runtime.lua. header.lua is
--     wrapped rather than replaced, because both the wrong-ESC message and the
--     Save button reach the pilot through it, and the wrapper is how the harness
--     gets at the pilot's own Save door. page_runtime is real because "no
--     parameter block reaches the ESC" is only a fact if a save is actually
--     attempted: with a stubbed runtime nothing presses Save and the write checks
--     pass in both passes. The first version of this harness did exactly that,
--     and its own --self-test is what found it -- see case 4 and case 6.
--   * The real three codecs, answered with each other's own
--     _simulatorResponse -- the same fixtures the Ethos simulator replays (see
--     tasks/msp/queue.lua), decoded by the production decoders.
--   * app/field_layout.lua is stubbed, and it is also where the runtime object
--     comes from: buildSingle() receives it as its first argument
--     (esc_forward_vendor.lua:221), so the harness reaches the very runtime the
--     page built. Stubbing it avoids having to fake form widgets for every
--     choice field, which says nothing about this gate.
--   * The 4-way target selector is stubbed, for the reason given above.
--
-- The half that must not be lost -- a gate that also locks out real hardware:
--   case 4 answers each page with its OWN fixture and requires the editor to be
--   built, bound to that vendor's own codec, and its Save to put an MSP 218 on
--   the bus. A check that only ever proves "blocked" would pass just as happily
--   against a module whose EXPECTED_SIGNATURE were 0, which is a tool no pilot
--   could use -- and the MSP 218 half is what keeps case 6 from being a check
--   that cannot fail.
--
-- Which checks go RED on the pre-gate vendor page:
--   All 30 gate checks: the six of case 5, the six of case 6, the twelve of case
--   7 and the six of case 8. --self-test proves that rather than asserting it: it
--   re-runs the whole file against a copy of esc_forward_vendor.lua whose
--   isCompatibleEsc() is replaced by `return true`, and requires every one of
--   them to fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local VENDOR_PAGE = SUITE .. "/app/pages/esc_forward_vendor.lua"

local SELF_TEST = arg[1] == "--self-test"

-- The names of every check the sabotage has to turn red. Collected as they run
-- so the self-test cannot drift away from the checks as they are written.
local MUST_GO_RED = {}

local checks, failures = 0, 0
local failedLabels = {}
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    failedLabels[label] = true
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

-- Registers a check whose passing is only meaningful if it can fail.
local function gateCheck(label, ok, detail)
  MUST_GO_RED[#MUST_GO_RED + 1] = label
  check(label, ok, detail)
end

-- ---------------------------------------------------------------------------
-- Ethos environment
-- ---------------------------------------------------------------------------

package.path = PREFIX .. "?.lua;" .. package.path
_G.PREFIX = PREFIX

local realLoadfile = loadfile

-- Set by the self-test: the module the redirect serves from a temp file, and how
-- often that happened. A redirect that never fires makes the second pass a
-- disguise of the first, so the hit count is reported and required.
local REPLACE_MATCH, REPLACE_FILE, replaceHits = nil, nil, 0

-- requireModule() calls loadfile() with a path carrying no directory part; on
-- the radio the working directory is src/rfsuite.
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    if REPLACE_MATCH and REPLACE_FILE and path:match(REPLACE_MATCH) then
      replaceHits = replaceHits + 1
      return realLoadfile(REPLACE_FILE, ...)
    end
    return realLoadfile(PREFIX .. path, ...)
  end
  return realLoadfile(path, ...)
end

_G.package = package
_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.print = function() end
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }
_G.lcd = { getWindowSize = function() return 480 end, loadMask = function() return 0 end }

_G.LEFT = 1
_G.CENTERED = 2
_G.RIGHT = 3
_G.TIME_LEFT = 4
_G.TEXT_LEFT = 5
_G.FONT_XS = 6
_G.FONT_S = 7
_G.FONT_M = 8
_G.FONT_L = 9
_G.FONT_XL = 10
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07
_G.KEY_ENTER_BREAK = 0x08

-- ---------------------------------------------------------------------------
-- What the form, the runtime and the bus are allowed to do
-- ---------------------------------------------------------------------------

-- Everything this run observed, cleared before each drive so one case cannot
-- see another's editor.
local obs = {}

local function resetObs()
  -- The runtime the page built, reached through field_layout.buildSingle(). nil
  -- after a reset is what "no editor was constructed" means.
  obs.runtime = nil
  obs.fieldsBuilt = 0
  obs.expansionPanels = 0
  obs.reads = 0
  obs.writes = {}
  obs.staticTexts = {}
  obs.lines = {}
end

local function widgetStub(name)
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

local function dialogStub()
  local d
  d = {
    value = function() end,
    message = function() end,
    closeAllowed = function() end,
    close = function() end,
  }
  return d
end

_G.form = {
  addButton = function() return widgetStub("button") end,
  addTextButton = function() return widgetStub("textbutton") end,
  -- esc_error.addTextLine calls form.addStaticText(line, rect, text, LEFT), so
  -- the text is the THIRD argument. Reading the fourth collected LEFT on every
  -- call and the message checks passed or failed for the wrong reason.
  addStaticText = function(_, _, text) obs.staticTexts[#obs.staticTexts + 1] = text end,
  addNumberField = function() return widgetStub("numberField") end,
  addChoiceField = function() return widgetStub("choiceField") end,
  addExpansionPanel = function()
    obs.expansionPanels = obs.expansionPanels + 1
    return {open = function() end}
  end,
  -- form.addLine() is called as a plain function everywhere (esc_forward_vendor.lua:211,
  -- esc_error.lua:58, header.lua), so the label is the FIRST argument.
  addLine = function(label)
    obs.lines[#obs.lines + 1] = label
    return #obs.lines
  end,
  clear = function() end,
  height = function() return 320 end,
  width = function() return 480 end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local slots = {}
    for i = 1, n do slots[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 } end
    return slots
  end,
  openDialog = function() return dialogStub() end,
  openProgressDialog = function() return dialogStub() end,
}

-- The bus records what went out and answers reads with whatever the current
-- case staged. It answers inline, which is the same order the radio sees: the
-- gate runs in the reply callback, the editor would be built in the wakeup.
local reply = nil
local replyFails = false

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    if message.isWrite then
      obs.writes[#obs.writes + 1] = message
      if type(message.processReply) == "function" then message.processReply() end
      return
    end
    obs.reads = obs.reads + 1
    if type(message.processReply) ~= "function" then return end
    if replyFails then
      if message.errorHandler then message.errorHandler("simulated read failure") end
      return
    end
    message.processReply(nil, reply)
  end,
}

-- app/page_runtime.lua is the REAL module, because "no parameter block reaches
-- the ESC" is only a fact if a save is actually attempted: with a stubbed
-- runtime nothing ever presses Save and the write checks would pass in both
-- passes -- which is exactly what the first version of this harness did, and
-- what its --self-test caught.
--
-- app/field_layout.lua is stubbed, and that is where the runtime object comes
-- from: buildSingle() receives it as its first argument
-- (esc_forward_vendor.lua:221), so the harness can reach the very runtime the
-- page built, dirty it, and save through the pilot's own Save button.
package.loaded["rfsuite.app.field_layout"] = {
  buildSingle = function(runtime)
    obs.fieldsBuilt = obs.fieldsBuilt + 1
    obs.runtime = runtime
  end,
  buildGroup = function(runtime)
    obs.fieldsBuilt = obs.fieldsBuilt + 1
    obs.runtime = runtime
  end,
  releaseRuntime = function() end,
  poolStats = function() return {} end,
}

package.loaded["rfsuite.app.progress_dialog"] = {
  open = function() return dialogStub() end,
  SPEED = { DEFAULT = 1, SLOW = 2, VSLOW = 3 },
}

package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = {
  print = function() end,
  format = function() end,
  msp = function() end,
  enabled = function() return false end,
  mspEnabled = function() return false end,
}
-- Off, so confirmSave() routes straight into performSave() instead of stopping
-- at a confirmation modal. Without it the write path is not reachable at all,
-- and a check that "no write went out" would prove nothing. It is a real setting
-- (Settings -> General -> Safety Prompts).
package.loaded["rfsuite.lib.settings_store"] = {
  saveConfirmEnabled = function() return false end,
  reloadConfirmEnabled = function() return true end,
  developerModeEnabled = function() return false end,
  load = function() return { general = {}, developer = {} } end,
  save = function() end,
  DEFAULTS = { general = {}, developer = {} },
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function() return { command = 250, isWrite = true } end,
}
package.loaded["rfsuite.lib.msp_reboot"] = { reboot = function() end }

local requireModule = assert(realLoadfile(PREFIX .. "lib/require.lua"))()

-- The real app/header.lua, wrapped rather than replaced: the wrong-ESC message
-- and the Save button both reach the pilot through it, and a stub could only
-- report what it was told. The wrapper records what it was told, which is how
-- the harness gets at the pilot's own Save door.
local headerBuilds = {}

local function installHeader()
  package.loaded["rfsuite.app.header"] = nil
  local header = requireModule("app/header.lua")
  local build = header.build
  header.build = function(title, opts)
    headerBuilds[#headerBuilds + 1] = { title = title, opts = opts }
    return build(title, opts)
  end
end

-- ---------------------------------------------------------------------------
-- The three pages and the three codecs under test
-- ---------------------------------------------------------------------------

-- One entry per ESC tool the issue names. `mainRevision` is what tells BLHeli_S
-- and Bluejay apart -- they share signature 0xC1, so the signature alone cannot.
-- AM32 has no main_revision in its payload at all (its wire fields are
-- version_major/version_minor, lib/msp_esc_parameters_am32.lua:75-76), which is
-- why it needs no isCompatible() and the other two do.
local TOOLS = {
  {
    label = "AM32",
    page = "esc_forward_am32",
    codec = "am32",
    signature = 0xC2,
  },
  {
    label = "BLHeli_S",
    page = "esc_forward_blheli_s",
    codec = "blheli_s",
    signature = 0xC1,
    mainRevision = 16,
  },
  {
    label = "Bluejay",
    page = "esc_forward_bluejay",
    codec = "bluejay",
    signature = 0xC1,
    mainRevision = 0,
  },
}

-- The MSP command that carries a parameter block to the ESC. Counted by
-- command rather than by "any write", because leaving the page publishes a
-- 4-way reset write (esc_forward_vendor.lua:85-90) that is not this.
local ESC_PARAM_WRITE = 218

local function codecFor(name)
  return requireModule("lib/msp_esc_parameters_" .. name .. ".lua")
end

-- Drops everything the previous drive left in package.loaded, so the next one
-- re-runs the real module bodies. The vendor page self-caches under its own key
-- (esc_forward_vendor.lua:3-5), which is also what makes the self-test's file
-- swap take effect.
local function resetModules()
  package.loaded["rfsuite.app.pages.esc_forward_vendor"] = nil
  package.loaded["rfsuite.app.esc_error"] = nil
  package.loaded["rfsuite.app.close_key"] = nil
  package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = nil
  for _, tool in ipairs(TOOLS) do
    package.loaded["rfsuite.app.pages." .. tool.page] = nil
    package.loaded["rfsuite.lib.msp_esc_parameters_" .. tool.codec] = nil
  end
  installHeader()
end

-- ---------------------------------------------------------------------------
-- Driving one page
-- ---------------------------------------------------------------------------

local function optsWithHandlers()
  local opts = {}
  local installed = {}
  -- Stored in a side table, not back onto opts: writing a handler under the
  -- setter's own name would replace the setter with the handler.
  local function setter(name)
    return function(handler) installed[name] = handler end
  end
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() end
  opts.__installed = installed
  return opts
end

-- One wakeup tick, which is what settles a load on the radio.
local function tick(opts)
  if opts.__installed.setWakeupHandler then opts.__installed.setWakeupHandler() end
end

-- Runs a page end to end and returns what happened, INCLUDING a save attempt.
-- `staged` is the raw MSP payload the flight controller answers the parameter
-- read with, or the string "error" to fail the read instead.
--
-- The save is not optional. A run that only opens the page cannot tell "the
-- gate held the write back" from "nothing ever asked for a write", and the first
-- version of this harness made exactly that mistake -- its own --self-test found
-- six write checks that stayed green with the gate removed.
local function drive(tool, staged)
  resetModules()
  resetObs()
  headerBuilds = {}
  reply = (staged ~= "error") and staged or nil
  replyFails = (staged == "error")

  -- The 4-way selector only picks which ESC to address; the gate under test is
  -- in the editor it opens. Stubbed so the case does not have to step that
  -- page's os.clock() delays.
  local captured
  package.loaded["rfsuite.app.pages.esc_forward_4way"] = {
    open = function(_, config) captured = config end,
  }

  local opts = optsWithHandlers()
  local page = requireModule("app/pages/" .. tool.page .. ".lua")
  page.open(opts, {})

  if captured and captured.openEditor then
    captured.openEditor(opts, {label = "Parameters"})
  end

  -- One wakeup, which is what settles a read on the radio: the reply callback
  -- stores pendingData or pendingError, and this tick is where the editor would
  -- be built.
  tick(opts)

  -- The pilot edits something and presses Save -- through the header's onSave,
  -- which is the same function the physical key and the on-screen button both
  -- reach. Only attempted when an editor was built at all: with no runtime there
  -- is no Save door, and pretending otherwise would count as a refusal when it
  -- is really an absence.
  local saved = false
  if obs.runtime then
    obs.runtime:markDirty()
    for i = #headerBuilds, 1, -1 do
      local onSave = headerBuilds[i].opts and headerBuilds[i].opts.onSave
      if onSave then
        onSave()
        saved = true
        break
      end
    end
    -- performSave() queues its writes and the wakeup consumes them.
    tick(opts)
    tick(opts)
  end

  -- Then leave the page, so "no parameter block was dispatched" covers the exit
  -- path too and not only the save path.
  if opts.__installed.setCleanupHandler then opts.__installed.setCleanupHandler() end

  local paramWrites = 0
  for i = 1, #obs.writes do
    if obs.writes[i].command == ESC_PARAM_WRITE then paramWrites = paramWrites + 1 end
  end

  return {
    built = obs.runtime ~= nil,
    fields = obs.fieldsBuilt,
    panels = obs.expansionPanels,
    reads = obs.reads,
    savePressed = saved,
    paramWrites = paramWrites,
    texts = obs.staticTexts,
    lines = obs.lines,
  }
end

-- Every static text the page put on the form, as one string, so a check can ask
-- "was the wrong-ESC message the one shown" without depending on line order.
local function shownText(run)
  return table.concat(run.texts, "\n")
end
-- Every line label, joined. buildEditor() renders mspModule.summaryFor() as one
-- of them (esc_forward_vendor.lua:210-212), so this is where the identity of the
-- codec the editor was actually bound to becomes visible.
local function shownLines(run)
  return table.concat(run.lines, "\n")
end

-- ---------------------------------------------------------------------------
-- cases
-- ---------------------------------------------------------------------------

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  return content
end

local function runChecks()
  -- Cleared per pass: without this the list would hold one pass plus the next,
  -- and the verdict below would report every gate check twice and count 60.
  MUST_GO_RED = {}

  out("")
  out("case 1: the three signatures are the ones the firmware uses")
  do
    -- rotorflight-firmware src/main/sensors/esc_sensor.c:129-130:
    --   #define ESC_SIG_BLHELI_S 0xC1
    --   #define ESC_SIG_AM32     0xC2
    for _, tool in ipairs(TOOLS) do
      local codec = codecFor(tool.codec)
      check(string.format("%s declares signature 0x%02X", tool.label, tool.signature),
        codec.EXPECTED_SIGNATURE == tool.signature,
        string.format("EXPECTED_SIGNATURE = %s", tostring(codec.EXPECTED_SIGNATURE)))
    end

    -- The three are not three distinct signatures, and that is the whole
    -- difficulty: BLHeli_S and Bluejay are both 0xC1 and are told apart by
    -- main_revision alone.
    local blheli = codecFor("blheli_s")
    local bluejay = codecFor("bluejay")
    check("BLHeli_S and Bluejay share one signature, so main_revision has to decide",
      blheli.EXPECTED_SIGNATURE == bluejay.EXPECTED_SIGNATURE,
      string.format("0x%02X vs 0x%02X", blheli.EXPECTED_SIGNATURE, bluejay.EXPECTED_SIGNATURE))
    check("and they expect different main_revisions",
      blheli.isCompatible({esc_signature = 0xC1, main_revision = 16}) == true
      and blheli.isCompatible({esc_signature = 0xC1, main_revision = 0}) == false
      and bluejay.isCompatible({esc_signature = 0xC1, main_revision = 0}) == true
      and bluejay.isCompatible({esc_signature = 0xC1, main_revision = 16}) == false,
      "isCompatible() does not separate 0xC1 main_revision 16 from 0")
  end

  out("")
  out("case 2: each codec decodes its own reply to the signature it expects")
  do
    -- Every case below drives the page with these fixtures, so a fixture that
    -- did not carry the right signature would make cases 4..7 pass for the
    -- wrong reason.
    for _, tool in ipairs(TOOLS) do
      local codec = codecFor(tool.codec)
      local data = codec._decode(codec._simulatorResponse)
      check(string.format("%s: its own fixture reads back as signature 0x%02X",
        tool.label, tool.signature),
        data.esc_signature == tool.signature,
        string.format("got 0x%02X", data.esc_signature or -1))
      if tool.mainRevision then
        check(string.format("%s: and as main_revision %d, which its gate also wants",
          tool.label, tool.mainRevision),
          data.main_revision == tool.mainRevision,
          string.format("got %s", tostring(data.main_revision)))
      else
        check("AM32 carries no main_revision at all, so its signature is the only gate",
          data.main_revision == nil,
          string.format("got %s", tostring(data.main_revision)))
      end
      check(string.format("%s: and its own gate accepts it", tool.label),
        (codec.isCompatible or function() return true end)(data) == true)
    end
  end

  out("")
  out("case 3: a read that fails is not mistaken for a matching ESC")
  do
    -- An unanswered read must not be read as "no objection". esc_error renders
    -- a failure reason, not the wrong-ESC text, and no editor is built either.
    for _, tool in ipairs(TOOLS) do
      local run = drive(tool, "error")
      check(string.format("%s: no editor is built from a failed read", tool.label),
        run.built == false, run.built and "an editor was built anyway" or nil)
    end
  end

  out("")
  out("case 4: each page opens on its own ESC  <- the half that must not be lost")
  do
    for _, tool in ipairs(TOOLS) do
      local codec = codecFor(tool.codec)
      local run = drive(tool, codec._simulatorResponse)
      check(string.format("%s: the editor IS built for its own ESC", tool.label),
        run.built == true, "no editor was built")
      check(string.format("%s: fields are built", tool.label),
        run.fields > 0, string.format("%d fields", run.fields))
      check(string.format("%s: the editor is bound to %s's own codec",
        tool.label, tool.label),
        shownLines(run):find(tool.label .. " / ", 1, true) ~= nil,
        "lines: " .. shownLines(run):gsub("\n", " / "))
      -- The positive control for case 6. Without it, "no parameter block was
      -- sent" would also be true of a harness whose write path was never live,
      -- and the six checks in case 6 would be worth nothing. Here the same
      -- Save press that case 6 watches stay silent DOES put a block on the bus.
      check(string.format("%s: Save on the matching page DOES send MSP %d",
        tool.label, ESC_PARAM_WRITE),
        run.savePressed == true and run.paramWrites == 1,
        string.format("save pressed = %s, %d parameter write(s)",
          tostring(run.savePressed), run.paramWrites))
    end
  end

  out("")
  out("case 5: another vendor's ESC builds no editor  <- the gate")
  do
    -- The issue's two named confusions, plus AM32 against the BLHeli family.
    for _, page in ipairs(TOOLS) do
      for _, esc in ipairs(TOOLS) do
        if page.label ~= esc.label then
          local codec = codecFor(esc.codec)
          local run = drive(page, codec._simulatorResponse)
          gateCheck(string.format("%s page + %s ESC: no editor is built",
            page.label, esc.label),
            run.built == false, "an editor was built from another vendor's reply")
        end
      end
    end
  end

  out("")
  out("case 6: no MSP parameter block reaches the ESC  <- the gate")
  do
    for _, page in ipairs(TOOLS) do
      for _, esc in ipairs(TOOLS) do
        if page.label ~= esc.label then
          local codec = codecFor(esc.codec)
          local run = drive(page, codec._simulatorResponse)
          gateCheck(string.format("%s page + %s ESC: MSP %d is never sent",
            page.label, esc.label, ESC_PARAM_WRITE),
            run.paramWrites == 0, string.format("%d parameter write(s)", run.paramWrites))
        end
      end
    end
  end

  out("")
  out("case 7: the pilot is told it is the wrong ESC  <- the gate")
  do
    for _, page in ipairs(TOOLS) do
      for _, esc in ipairs(TOOLS) do
        if page.label ~= esc.label then
          local codec = codecFor(esc.codec)
          local run = drive(page, codec._simulatorResponse)
          local text = shownText(run)
          gateCheck(string.format("%s page + %s ESC: the wrong-ESC message is shown",
            page.label, esc.label),
            text:find("app.modules.esc_tools.error_wrong_esc", 1, true) ~= nil,
            "shown: " .. (text == "" and "(nothing)" or text:gsub("\n", " / ")))
          gateCheck(string.format("%s page + %s ESC: and it names the other vendor's page",
            page.label, esc.label),
            text:find("app.modules.esc_tools.error_choose_esc", 1, true) ~= nil,
            "shown: " .. (text == "" and "(nothing)" or text:gsub("\n", " / ")))
        end
      end
    end
  end

  out("")
  out("case 8: a reply with no signature byte is refused by all three")
  do
    -- mspcodec.lua reads a byte past the end of the buffer as 0 rather than nil,
    -- so a truncated reply decodes into a table of numbers -- the gate has to
    -- decide on the byte, not on the table's existence.
    local truncated = {}
    for _, tool in ipairs(TOOLS) do
      local run = drive(tool, truncated)
      gateCheck(string.format("%s: an empty reply is refused", tool.label),
        run.built == false, "an editor was built from an empty reply")
    end

    -- And the signature byte one short of the right one.
    for _, tool in ipairs(TOOLS) do
      local codec = codecFor(tool.codec)
      local payload = {}
      for i = 1, #codec._simulatorResponse do payload[i] = codec._simulatorResponse[i] end
      payload[1] = (tool.signature + 1) % 256
      local run = drive(tool, payload)
      gateCheck(string.format("%s: 0x%02X is refused where 0x%02X is expected",
        tool.label, payload[1], tool.signature),
        run.built == false, "an editor was built from a wrong signature byte")
    end
  end

  out("")
  out("case 9: no ESC tool ships without a signature to check against")
  do
    -- The defect class, not one instance: a new esc_forward_*.lua whose codec has
    -- no EXPECTED_SIGNATURE would open on any ESC at all, because
    -- esc_forward_vendor.lua:233-234 treats a missing constant as "accept".
    -- The page list is read out of tool.lua so a new tile cannot be added
    -- without being checked here.
    local toolSource = readFile(SUITE .. "/app/tool.lua")
    local pages = {}
    for page in toolSource:gmatch('script = "app/pages/(esc_forward_[%w_]+)%.lua"') do
      pages[#pages + 1] = page
    end
    check("the ESC tool tiles are found in tool.lua", #pages >= 10,
      string.format("%d found", #pages))

    local ungated = {}
    for _, page in ipairs(pages) do
      local source = readFile(SUITE .. "/app/pages/" .. page .. ".lua")
      local codecName = source:match('requireModule%("(lib/msp_esc_parameters_[%w_]+%.lua)"%)')
      if not codecName then
        ungated[#ungated + 1] = page .. " (no codec)"
      else
        local key = "rfsuite." .. codecName:gsub("/", "."):gsub("%.lua$", "")
        package.loaded[key] = nil
        local codec = requireModule(codecName)
        if tonumber(codec.EXPECTED_SIGNATURE) == nil then
          ungated[#ungated + 1] = page .. " (" .. codecName .. ")"
        end
      end
    end
    check(string.format("all %d ESC tool pages declare an EXPECTED_SIGNATURE", #pages),
      #ungated == 0, table.concat(ungated, ", "))
  end
end

-- ---------------------------------------------------------------------------
-- Pass 1: the real tree
-- ---------------------------------------------------------------------------

out(string.rep("=", 72))
out("ESC forward-programming signature gate (#2335)")
out(string.rep("=", 72))

runChecks()

local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the same cases against a vendor page with no gate
-- ---------------------------------------------------------------------------
if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the gate checks must go red without the gate")
  out(string.rep("=", 72))

  local source = readFile(VENDOR_PAGE)
  -- core.autocrlf=true and no .gitattributes, so the checkout is CRLF. Detect
  -- rather than assume; a mismatch would make the plain find below miss.
  local nl = source:find("\r\n", 1, true) and "\r\n" or "\n"

  local OPEN = "  local function isCompatibleEsc(data)"
  local CLOSE = "    return tonumber(data and data.esc_signature) == tonumber(expected)" .. nl .. "  end"

  -- The counter proves the sabotaged body actually ran. Without it a redirect
  -- that served the file but nothing called would leave pass 2 identical to
  -- pass 1, and every check below would stay green for the wrong reason.
  local GATE_LESS = table.concat({
    "  local function isCompatibleEsc(data)",
    "    _G.__sabotageRan = (_G.__sabotageRan or 0) + 1",
    "    return true",
    "  end",
  }, nl)

  local first = source:find(OPEN, 1, true)
  local last = first and source:find(CLOSE, first, true)
  if not (first and last) then
    out("  FAIL  could not locate isCompatibleEsc() in esc_forward_vendor.lua")
    out("        the sabotage has to be updated when that function changes shape")
    os.exit(1)
  end
  last = last + #CLOSE

  local tmp = os.tmpname()
  local sabotaged = source:sub(1, first - 1) .. GATE_LESS .. source:sub(last + 1)
  local fh = assert(io.open(tmp, "wb"))
  fh:write(sabotaged)
  fh:close()

  -- Read it straight back. A temp file that kept stale contents would make the
  -- whole self-test vacuous.
  local readBack = readFile(tmp)
  if readBack ~= sabotaged then
    out(string.format("  FAIL  the sabotage file does not read back (%d written, %d read)",
      #sabotaged, #readBack))
    os.exit(1)
  end
  out(string.format("  sabotage file: %d bytes, verified by read-back (newline %s)",
    #readBack, nl == "\r\n" and "CRLF" or "LF"))

  REPLACE_MATCH = "esc_forward_vendor%.lua$"
  REPLACE_FILE = tmp

  checks, failures = 0, 0
  failedLabels = {}
  _G.__sabotageRan = 0
  replaceHits = 0

  out("")
  out("pass 2: the same cases against a vendor page whose isCompatibleEsc always agrees")
  runChecks()

  os.remove(tmp)
  REPLACE_MATCH, REPLACE_FILE = nil, nil

  out("")
  out(string.format("  (sabotaged page served %d time(s), its body ran %d time(s))",
    replaceHits, _G.__sabotageRan or 0))
  if replaceHits == 0 or (_G.__sabotageRan or 0) == 0 then
    out("  FAIL  the sabotaged page never ran -- pass 2 proved nothing")
    os.exit(1)
  end

  out("")
  out("self-test verdict:")
  local stayedGreen = {}
  for _, label in ipairs(MUST_GO_RED) do
    local red = failedLabels[label] == true
    out(string.format("  %s  %s", red and "goes red " or "STAYS GREEN", label))
    if not red then stayedGreen[#stayedGreen + 1] = label end
  end
  out("")
  if #stayedGreen > 0 then
    out(string.format("SELF-TEST FAILED -- %d of %d gate checks cannot detect a missing gate",
      #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format("SELF-TEST PASSED -- all %d gate checks go red without the gate",
    #MUST_GO_RED))
  out(string.format("pass 1 against the real tree: %d checks, %d failures",
    pass1Checks, pass1Failures))
end

-- The verdict below is pass 1's: without --self-test, pass 2 never ran, and
-- with it pass 2's red is the expected outcome rather than a failure here.
checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 72))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("OK")
