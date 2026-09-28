-- Small helpers for read-only Diagnostics pages.

if package.loaded["rfsuite.app.diagnostics_common"] then
  return package.loaded["rfsuite.app.diagnostics_common"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")

local diagnostics_common = {}

function diagnostics_common.text(value)
  if value == nil or value == "" then return "-" end
  return tostring(value)
end

function diagnostics_common.yesNo(value)
  if value == nil then return "-" end
  return value and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@"
end

function diagnostics_common.formatBytes(bytes)
  bytes = tonumber(bytes or 0) or 0
  if bytes <= 0 then return "0 B" end
  if bytes < 1024 then return string.format("%d B", bytes) end
  local kb = bytes / 1024
  if kb < 1024 then return string.format("%.1f kB", kb) end
  local mb = kb / 1024
  if mb < 1024 then return string.format("%.1f MB", mb) end
  return string.format("%.2f GB", mb / 1024)
end

function diagnostics_common.addValueLine(label, initial)
  local line = form.addLine(label)
  return form.addStaticText(line, nil, diagnostics_common.text(initial))
end

function diagnostics_common.updateField(field, value)
  if field and field.value then
    field:value(diagnostics_common.text(value))
  end
end

-- A line whose text spans the whole window instead of the narrow right-hand
-- value column that addValueLine() writes into.
--
-- Same construction app/esc_error.lua already ships for its reason lines:
-- a blank form.addLine, one flex slot, and a static text laid out from x = 0
-- to the window width. It is a separate function rather than a mode of
-- addValueLine() because the two produce differently shaped lines and mixing
-- them at a call site would be the ambiguity worth avoiding.
--
-- Returns the static text widget, so the caller can retext it in place --
-- form.addStaticText is the one control whose value can be changed at
-- runtime. That is what lets a Diagnostics page grow a list after its first
-- MSP read without rebuilding (and flickering) the page.
function diagnostics_common.addTextLine(text, indent)
  local line = form.addLine("")
  local slots = form.getFieldSlots(line, {0})
  local slot = (slots and slots[1]) or {}
  local width = nil
  if lcd and lcd.getWindowSize then
    width = lcd.getWindowSize()
  end
  return form.addStaticText(line, {
    x = indent or 0,
    y = slot.y or 0,
    w = width or slot.w or 0,
    h = slot.h or 0,
  }, text, LEFT)
end

-- Only GREEN and RED are used as colour globals anywhere in the suite, both
-- here; anything else would be a guess about the Ethos API.
function diagnostics_common.setFieldColor(field, color)
  if field and field.color then
    field:color(color)
  end
end

function diagnostics_common.updateStatus(field, value)
  if not field then return end
  diagnostics_common.updateField(field, diagnostics_common.yesNo(value))
  if field.color and value ~= nil then
    field:color(value and GREEN or RED)
  end
end

function diagnostics_common.openReadOnlyPage(opts, pageTitle, build)
  opts = opts or {}
  local disposed = false
  local session = {}
  local sessionHandler = nil
  local headerHandle = nil
  local page = nil

  local function goBack()
    disposed = true
    if sessionHandler then
      bus.unsubscribe("session.update", sessionHandler)
      sessionHandler = nil
    end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    if opts.onBack then opts.onBack() end
  end

  form.clear()
  headerHandle = header.build(pageTitle, {
    onBack = goBack,
    onReload = function()
      if page and page.onReload then
        page.onReload()
      elseif page and page.wakeup then
        page.wakeup()
      end
      if headerHandle then headerHandle.focusReload() end
    end,
  })

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end

  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      disposed = true
      if sessionHandler then
        bus.unsubscribe("session.update", sessionHandler)
        sessionHandler = nil
      end
    end)
  end

  page = build({
    session = session,
    header = headerHandle,
    isDisposed = function() return disposed end,
  }) or {}

  sessionHandler = bus.subscribe("session.update", function(snapshot)
    if disposed then return end
    for k in pairs(session) do session[k] = nil end
    for k, v in pairs(snapshot or {}) do session[k] = v end
    if page.onSession then page.onSession(session) end
  end)

  if opts.setWakeupHandler and page.wakeup then
    opts.setWakeupHandler(function()
      if disposed then return end
      page.wakeup()
    end)
  end
end

package.loaded["rfsuite.app.diagnostics_common"] = diagnostics_common
return diagnostics_common
