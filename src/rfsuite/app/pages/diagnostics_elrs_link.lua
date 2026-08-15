-- Tools -> Diagnostics -> ELRS Telemetry page.
--
-- Ported from rotorflight-lua-ethos-suite's master branch
-- (app/modules/diagnostics/tools/elrs_telemetry.lua). Unlike the other
-- diagnostics_*.lua pages here, this one is interactive (three action
-- buttons), so it can't use app/diagnostics_common.lua's
-- openReadOnlyPage() helper -- built directly instead, following the same
-- header/session/dispose idiom app/pages/blackbox_status.lua already
-- uses, plus the form.getFieldSlots(line, {0, " label "}) content-fit
-- button idiom from app/pages/esc_forward_4way.lua's per-row buttons.
--
-- All state (probe/sync progress, the Rotorflight and ELRS-module
-- summaries) lives in lib/elrslink_task.lua, not here -- this page only
-- polls its accessors and renders them.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local elrsTask = requireModule("lib/elrslink_task.lua")

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.elrs_telemetry.name)@"

local T = {
  status = "@i18n(app.modules.elrs_telemetry.status)@",
  rotorflight = "@i18n(app.modules.elrs_telemetry.rotorflight)@",
  elrsModule = "@i18n(app.modules.elrs_telemetry.elrs_module)@",
  action = "@i18n(app.modules.elrs_telemetry.action)@",
  probe = "@i18n(app.modules.elrs_telemetry.action_probe)@",
  rfToElrs = "@i18n(app.modules.elrs_telemetry.action_rf_to_elrs)@",
  elrsToRf = "@i18n(app.modules.elrs_telemetry.action_elrs_to_rf)@",
  connectFirst = "@i18n(app.modules.elrs_telemetry.status_connect_first)@",
  requiresCrsf = "@i18n(app.modules.elrs_telemetry.status_requires_crsf)@",
  waitingTelemetryConfig = "@i18n(app.modules.elrs_telemetry.status_waiting_telemetry_config)@",
  notProbed = "@i18n(app.modules.elrs_telemetry.status_not_probed)@",
  modeNative = "@i18n(app.modules.elrs_telemetry.mode_native)@",
  modeCustom = "@i18n(app.modules.elrs_telemetry.mode_custom)@",
}

local REFRESH_INTERVAL_SECONDS = 0.2

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle = nil
  local sessionHandler = nil
  local session = {connected = false, mspTransport = nil}
  local fields = {}
  local fieldCache = {}
  local buttons = {}
  local buttonsEnabledCache = nil
  local lastRefreshAt = 0

  local function telemetryModeLabel(mode)
    if mode == 0 then return T.modeNative end
    if mode == 1 then return T.modeCustom end
    return tostring(mode or "?")
  end

  local function formatRotorflightSummary()
    if not session.connected then return T.connectFirst end
    if session.mspTransport ~= "crsf" then return T.requiresCrsf end

    local fc = elrsTask.getFcSummary()
    if not fc then return T.waitingTelemetryConfig end

    return "mode=" .. telemetryModeLabel(fc.mode) .. ", rate=" .. tostring(fc.linkRate) .. ", ratio=1:" .. tostring(fc.linkRatio)
  end

  local function formatElrsSummary()
    local link = elrsTask.getLinkSummary()
    if not link then return T.notProbed end

    local rateText = link.packetRateLabel or (link.packetRate and (tostring(link.packetRate) .. "Hz")) or "?"
    local ratioText = link.telemetryRatioLabel or "?"
    local effectiveRatio = link.telemetryRatioEffective

    if effectiveRatio and ratioText ~= ("1:" .. tostring(effectiveRatio)) then
      ratioText = ratioText .. " (effective 1:" .. tostring(effectiveRatio) .. ")"
    end

    return "rate=" .. tostring(rateText) .. ", ratio=" .. tostring(ratioText)
  end

  local function setFieldValue(key, value)
    if fieldCache[key] == value then return end
    fieldCache[key] = value
    local field = fields[key]
    if field and field.value then field:value(value or "-") end
  end

  local function setButtonsEnabled(enabled)
    if buttonsEnabledCache == enabled then return end
    buttonsEnabledCache = enabled
    for _, button in pairs(buttons) do
      if button and button.enable then button:enable(enabled) end
    end
  end

  local function updateDisplay(force)
    if disposed then return end
    if not force then
      local now = os.clock()
      if (now - lastRefreshAt) < REFRESH_INTERVAL_SECONDS then return end
      lastRefreshAt = now
    else
      lastRefreshAt = os.clock()
    end

    setFieldValue("status", elrsTask.getStatus())
    setFieldValue("rotorflight", formatRotorflightSummary())
    setFieldValue("elrs", formatElrsSummary())
    setFieldValue("action", elrsTask.getModeLabel())
    setButtonsEnabled(not elrsTask.isRunning())
  end

  local function startAction(mode)
    elrsTask.start(mode)
    updateDisplay(true)
  end

  local function goBack()
    disposed = true
    if sessionHandler then
      bus.unsubscribe("session.update", sessionHandler)
      sessionHandler = nil
    end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    elrsTask.reset()
    if opts.onBack then opts.onBack() end
  end

  -- Reset the module-side probe state (and, if not already cached from an
  -- earlier visit this connection, kick off the Rotorflight telemetry-
  -- config read) before building any field with an initial value below,
  -- so the very first render already reflects this fresh open rather than
  -- whatever the previous visit to this page left behind.
  elrsTask.reset()
  elrsTask.refreshFcConfig()

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {onBack = goBack})

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

  sessionHandler = bus.subscribe("session.update", function(snapshot)
    if disposed then return end
    session.connected = snapshot and snapshot.connected == true
    session.mspTransport = snapshot and snapshot.mspTransport
    updateDisplay(true)
  end)

  local line = form.addLine(T.status)
  fields.status = form.addStaticText(line, nil, elrsTask.getStatus())

  line = form.addLine(T.rotorflight)
  fields.rotorflight = form.addStaticText(line, nil, formatRotorflightSummary())

  line = form.addLine(T.elrsModule)
  fields.elrs = form.addStaticText(line, nil, formatElrsSummary())

  line = form.addLine(T.action)
  fields.action = form.addStaticText(line, nil, elrsTask.getModeLabel())

  -- All three actions on one row: a single leading flex slot (left blank,
  -- unlike app/header.lua's own use of this same shape for its title text)
  -- followed by three content-fit button slots -- the exact
  -- form.getFieldSlots(line, {0, hint, hint, ...}) shape header.lua's own
  -- Menu/Save/Reload/Tool row already proves works for more than one
  -- button after the flex slot.
  local function addActionButton(line, slot, key, label, mode)
    buttons[key] = form.addButton(line, slot, {
      text = label,
      options = FONT_S + CENTERED,
      press = function() startAction(mode) end,
    })
  end

  local buttonLine = form.addLine("")
  local buttonSlots = form.getFieldSlots(buttonLine, {
    0,
    "   " .. T.probe .. "   ",
    "   " .. T.rfToElrs .. "   ",
    "   " .. T.elrsToRf .. "   ",
  })
  addActionButton(buttonLine, buttonSlots[2], "probe", T.probe, elrsTask.MODE_PROBE)
  addActionButton(buttonLine, buttonSlots[3], "rfToElrs", T.rfToElrs, elrsTask.MODE_ROTORFLIGHT_TO_ELRS)
  addActionButton(buttonLine, buttonSlots[4], "elrsToRf", T.elrsToRf, elrsTask.MODE_ELRS_TO_ROTORFLIGHT)

  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if elrsTask.isRunning() then elrsTask.wakeup() end
      updateDisplay(false)
    end)
  end

  updateDisplay(true)
end

return {open = open}
