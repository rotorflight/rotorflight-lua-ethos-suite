-- Behaviour check for full-width ESC summary line rendering (#2455 follow-up).
--
-- Run it:
--     lua5.4 bin/esc_summary/verify_esc_summary.lua
--     lua5.4 bin/esc_summary/verify_esc_summary.lua --self-test
--
-- What the defect under test is:
--   app/pages/esc_forward_vendor.lua rendered mspModule.summaryFor(data, pageTitle)
--   using `form.addLine(summary)`.
--   In Ethos, `form.addLine(label)` splits a line into two columns: the left column
--   for the line label and the right column for field widgets. The label column is
--   hard-clipped at ~32 characters on standard screens (e.g. 480x320 FrSky X18RS).
--   When the ESC summary line includes model name, firmware version, and serial number
--   (such as "YGE Saphir 125 / 1.03576 / S/N 100770", 37 characters), the text past
--   character 32 is clipped off: the 33rd character (digit '0') is sliced vertically
--   and appears on the LCD as 'C' ("... / S/N 1C"), and the rest of the serial number
--   is completely cut off while the entire right half of the display line sits empty.
--
-- The fix:
--   esc_forward_vendor.lua now uses `escError.addTextLine(summary)` (which creates an
--   empty form line and spans `form.addStaticText` across the full display width via
--   `w = lcd.getWindowSize()`, `x = 0`). The full 37-character summary fits easily
--   in the 480 px width without column clipping.
--
-- What this harness drives:
--   * The real app/pages/esc_forward_vendor.lua through the real
--     app/esc_error.lua, app/field_layout.lua, and app/page_runtime.lua.
--   * Stubs for form and lcd to record line creation and static text bounds.
--
-- Which checks go RED without the fix:
--   2 of 5, proven by --self-test by restoring the pre-fix `form.addLine(summary)`.

local SELF_TEST = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then SELF_TEST = true end
end

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"

local VENDOR_PAGE_PATH = PREFIX .. "app/pages/esc_forward_vendor.lua"

local checks, failures = 0, 0
local failedLabels = {}
local MUST_GO_RED = {}

local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
    return true
  end
  failures = failures + 1
  failedLabels[label] = true
  out(string.format("  FAIL  %s", label))
  if detail then out("        " .. tostring(detail)) end
  return false
end

local function gateCheck(label, ok, detail)
  MUST_GO_RED[#MUST_GO_RED + 1] = label
  return check(label, ok, detail)
end

-- ---------------------------------------------------------------------------
-- Environment & Stubs
-- ---------------------------------------------------------------------------
package.path = SUITE .. "/?.lua;" .. package.path

local realLoadfile = loadfile

local REDIRECT_MATCH = nil
local REDIRECT_FILE = nil
local redirectHits = 0

_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (PREFIX .. path)
    if REDIRECT_MATCH and absolute == REDIRECT_MATCH then
      redirectHits = redirectHits + 1
      return realLoadfile(REDIRECT_FILE, ...)
    end
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

local obs = {
  addLines = {},
  staticTexts = {},
}

local function resetObs()
  obs.addLines = {}
  obs.staticTexts = {}
end

_G.lcd = {
  getWindowSize = function() return 480, 320 end,
  font = function() return 1 end,
}

_G.form = {
  clear = function() end,
  addLine = function(label)
    local lineIdx = #obs.addLines + 1
    obs.addLines[lineIdx] = label
    return lineIdx
  end,
  addStaticText = function(line, rect, text, align)
    obs.staticTexts[#obs.staticTexts + 1] = {
      line = line,
      rect = rect,
      text = text,
      align = align,
    }
  end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 1
    local slots = {}
    for i = 1, n do
      slots[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 }
    end
    return slots
  end,
  height = function() return 320 end,
  width = function() return 480 end,
  addExpansionPanel = function()
    return { open = function() end }
  end,
  addNumberField = function() return {} end,
  addChoiceField = function() return {} end,
  addButton = function() return {} end,
  addTextButton = function() return {} end,
}

_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
}

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic == "msp.request" and type(message) == "table" then
      if message.processReply and type(message.processReply) == "function" then
        message.processReply()
      end
    end
  end,
}

package.loaded["rfsuite.app.progress_dialog"] = {
  SPEED = { SLOW = 1, DEFAULT = 2 },
  open = function()
    return {
      value = function() end,
      close = function() end,
    }
  end,
}

package.loaded["rfsuite.app.close_key"] = {
  shouldHandleClose = function() return false end,
}

package.loaded["rfsuite.app.header"] = {
  build = function() end,
}

package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = {
  buildWriteMessage = function() return {} end,
}

package.loaded["rfsuite.app.field_layout"] = {
  buildSingle = function() end,
}

package.loaded["rfsuite.app.page_runtime"] = {
  new = function(spec)
    return {
      buildChrome = function() end,
      loadInitial = function() end,
      goBack = function() end,
      dispose = function() end,
    }
  end,
}

local requireModule = assert(realLoadfile(PREFIX .. "lib/require.lua"))()

-- ---------------------------------------------------------------------------
-- Driver helper
-- ---------------------------------------------------------------------------
local function runPageWithSummary(summaryReturn)
  resetObs()
  package.loaded["rfsuite.app.pages.esc_forward_vendor"] = nil

  local escVendor = requireModule("app/pages/esc_forward_vendor.lua")

  local mspModule = {
    EXPECTED_SIGNATURE = 0xA5,
    buildReadMessage = function(onSuccess, onError)
      return {
        isWrite = false,
        processReply = function()
          onSuccess({ esc_signature = 0xA5, serial_number = 100770 })
        end,
      }
    end,
    summaryFor = function(data, title)
      if type(summaryReturn) == "function" then
        return summaryReturn(data, title)
      end
      return summaryReturn
    end,
  }

  local wakeupHandler = nil
  local opts = {
    setEventHandler = function() end,
    setWakeupHandler = function(fn) wakeupHandler = fn end,
    setPaintHandler = function() end,
    setCleanupHandler = function() end,
  }

  local config = {
    mspModule = mspModule,
    fields = {},
    pageTitle = "YGE ESC",
  }

  escVendor.open(opts, config)
  if wakeupHandler then
    wakeupHandler()
  end
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------
local TEST_SUMMARY = "YGE Saphir 125 / 1.03576 / S/N 100770"

local function runChecks()
  out("")
  out("esc summary header rendering")

  -- Case 1: Long summary string (37 chars)
  runPageWithSummary(TEST_SUMMARY)

  local foundInAddLine = false
  for _, lineLabel in ipairs(obs.addLines) do
    if lineLabel == TEST_SUMMARY or (type(lineLabel) == "string" and lineLabel:find("S/N 100770", 1, true)) then
      foundInAddLine = true
      break
    end
  end

  local staticTextItem = nil
  for _, item in ipairs(obs.staticTexts) do
    if item.text == TEST_SUMMARY then
      staticTextItem = item
      break
    end
  end

  gateCheck("summary text is NOT passed to form.addLine (prevents 2-column label clipping)",
    not foundInAddLine,
    "form.addLine was called with the summary string: " .. tostring(TEST_SUMMARY))

  gateCheck("summary text is rendered via addStaticText",
    staticTextItem ~= nil,
    "no addStaticText call contained the full summary string")

  check("summary static text spans full screen width (w >= 480, x == 0)",
    staticTextItem ~= nil and staticTextItem.rect and staticTextItem.rect.w >= 480 and staticTextItem.rect.x == 0,
    staticTextItem and string.format("rect is x=%s, w=%s",
      tostring(staticTextItem.rect and staticTextItem.rect.x),
      tostring(staticTextItem.rect and staticTextItem.rect.w)) or "no static text found")

  -- Case 2: Empty summary string
  runPageWithSummary("")
  local emptyStatic = false
  for _, item in ipairs(obs.staticTexts) do
    if item.text == "" then emptyStatic = true end
  end
  check("empty summary string does not create a static text line",
    not emptyStatic,
    "an empty static text line was created")

  -- Case 3: nil summary
  runPageWithSummary(nil)
  local anyStatic = #obs.staticTexts > 0
  check("nil summary does not create a static text line",
    not anyStatic,
    "static text was created despite summary being nil")
end

-- ---------------------------------------------------------------------------
-- Self-test
-- ---------------------------------------------------------------------------
local function readFile(p)
  local f = assert(io.open(p, "rb"))
  local c = f:read("*a")
  f:close()
  return c
end

local function writeTmp(content)
  local p = os.tmpname()
  local f = assert(io.open(p, "wb"))
  f:write(content)
  f:close()
  return p
end

local function splicePreFixVendorPage(source)
  -- Reverts escError.addTextLine(summary) back to form.addLine(mspModule.summaryFor(data, pageTitle))
  local pattern = "if mspModule%.summaryFor then%s+local summary = mspModule%.summaryFor%(data, pageTitle%)%s+if summary and summary ~= \"\" then%s+escError%.addTextLine%(summary%)%s+end%s+end"
  local replacement = "if mspModule.summaryFor then\n      form.addLine(mspModule.summaryFor(data, pageTitle))\n    end"
  local spliced, n = source:gsub(pattern, replacement)
  if n == 1 then return spliced end
  return nil
end

runChecks()

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: verify that the gates go RED on the pre-fix vendor page")
  out(string.rep("=", 72))

  local orig = readFile(VENDOR_PAGE_PATH)
  local sabotaged = splicePreFixVendorPage(orig)
  if not sabotaged then
    out("  FAIL  could not splice pre-fix vendor page")
    os.exit(1)
  end

  local tmpFile = writeTmp(sabotaged)
  REDIRECT_MATCH = (VENDOR_PAGE_PATH:gsub("\\", "/"))
  REDIRECT_FILE = tmpFile
  redirectHits = 0

  checks, failures = 0, 0
  failedLabels = {}
  local expectedGates = {}
  for _, name in ipairs(MUST_GO_RED) do
    expectedGates[name] = true
  end
  MUST_GO_RED = {}

  out("")
  out("pass 2: running cases against pre-fix vendor page")
  runChecks()

  os.remove(tmpFile)

  out("")
  out(string.format("  (sabotaged file served %d times)", redirectHits))
  if redirectHits == 0 then
    out("  FAIL  sabotaged file was never loaded")
    os.exit(1)
  end

  local missingRed = {}
  for gateName in pairs(expectedGates) do
    if not failedLabels[gateName] then
      missingRed[#missingRed + 1] = gateName
    end
  end

  if #missingRed > 0 then
    out("  FAIL  the following gates did not go RED on pre-fix code:")
    for _, g in ipairs(missingRed) do
      out("        " .. g)
    end
    os.exit(1)
  else
    out("  ok    all gate checks went RED as expected on pre-fix code")
  end
end

if failures > 0 and not SELF_TEST then
  os.exit(1)
end
