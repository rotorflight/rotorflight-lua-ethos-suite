-- Developer -> MSP Speed.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local batteryConfig = requireModule("lib/msp_battery_config.lua")
local governorConfig = requireModule("lib/msp_governor_config.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.txt_developer)@ / @i18n(app.modules.msp_speed.name)@"
local TESTING_TITLE = "@i18n(app.modules.msp_speed.testing)@"
local TESTING_BODY = "@i18n(app.modules.msp_speed.testing_performance)@"

local TESTS = {
  {label = "@i18n(app.modules.msp_speed.seconds_600)@", seconds = 600},
  {label = "@i18n(app.modules.msp_speed.seconds_300)@", seconds = 300},
  {label = "@i18n(app.modules.msp_speed.seconds_120)@", seconds = 120},
  {label = "@i18n(app.modules.msp_speed.seconds_30)@", seconds = 30},
}

local REQUESTS = {
  {name = "BATTERY_CONFIG", module = batteryConfig},
  {name = "GOVERNOR_CONFIG", module = governorConfig},
  {name = "MIXER_CONFIG", module = mixerConfig},
}

local function round(value, places)
  local scale = 10 ^ (places or 0)
  return math.floor((tonumber(value) or 0) * scale + 0.5) / scale
end

local function fmtSeconds(value)
  if not value then return "-" end
  return tostring(round(value, 2)) .. "s"
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local fields = {}
  local session = {}
  local sessionHandler
  local dialog
  local active = false
  local inFlight = false
  local requestIndex = 0
  local startedAt = 0
  local duration = 0
  local lastDispatch = 0
  local currentStartedAt = 0
  local stats = {total = 0, success = 0, retries = 0, timeouts = 0, checksum = 0, totalTime = 0, minTime = nil, maxTime = nil}

  local function updateFields()
    if disposed then return end
    if fields.rf then fields.rf:value(session.mspTransport and string.upper(session.mspTransport) or "-") end
    if fields.runtime then fields.runtime:value(duration > 0 and (tostring(duration) .. "s") or "-") end
    if fields.total then fields.total:value(tostring(stats.total)) end
    if fields.success then fields.success:value(tostring(stats.success)) end
    if fields.timeouts then fields.timeouts:value(tostring(stats.timeouts)) end
    if fields.retries then fields.retries:value(tostring(stats.retries)) end
    if fields.checksum then fields.checksum:value(tostring(stats.checksum)) end
    if fields.mintime then fields.mintime:value(fmtSeconds(stats.minTime)) end
    if fields.maxtime then fields.maxtime:value(fmtSeconds(stats.maxTime)) end
    if fields.time then
      fields.time:value(stats.success > 0 and fmtSeconds(stats.totalTime / stats.success) or "-")
    end
  end

  local function closeDialog()
    if dialog then
      dialog:value(100)
      dialog:close()
      dialog = nil
    end
  end

  local function stopTest()
    active = false
    inFlight = false
    closeDialog()
    updateFields()
    if headerHandle then
      headerHandle.focusTool()
    end
  end

  local function recordSuccess()
    local elapsed = os.clock() - currentStartedAt
    stats.success = stats.success + 1
    stats.totalTime = stats.totalTime + elapsed
    if not stats.minTime or elapsed < stats.minTime then stats.minTime = elapsed end
    if not stats.maxTime or elapsed > stats.maxTime then stats.maxTime = elapsed end
    inFlight = false
  end

  local function recordError()
    stats.timeouts = stats.timeouts + 1
    inFlight = false
  end

  local function dispatchRequest()
    requestIndex = (requestIndex % #REQUESTS) + 1
    local spec = REQUESTS[requestIndex]
    stats.total = stats.total + 1
    inFlight = true
    currentStartedAt = os.clock()
    lastDispatch = currentStartedAt
    bus.publish("msp.request", spec.module.buildReadMessage(recordSuccess, recordError))
  end

  local function wakeup()
    if not active or disposed then return end
    local now = os.clock()
    local elapsed = now - startedAt

    if dialog then
      dialog:value(math.min(100, elapsed * 100 / duration))
    end

    if elapsed >= duration then
      stopTest()
      return
    end

    if (not inFlight) and (now - lastDispatch) >= 0.25 then
      dispatchRequest()
      updateFields()
    end
  end

  local function startTest(seconds)
    stats = {total = 0, success = 0, retries = 0, timeouts = 0, checksum = 0, totalTime = 0, minTime = nil, maxTime = nil}
    duration = seconds
    startedAt = os.clock()
    lastDispatch = 0
    requestIndex = 0
    inFlight = false
    active = true
    dialog = form.openProgressDialog({
      title = TESTING_TITLE,
      message = TESTING_BODY,
      close = function()
        active = false
        dialog = nil
      end,
      wakeup = function() end,
    })
    if dialog then
      dialog:value(0)
      dialog:closeAllowed(true)
    end
    updateFields()
  end

  local function openStartDialog()
    local buttons = {}
    for i = 1, #TESTS do
      local test = TESTS[i]
      buttons[#buttons + 1] = {
        label = test.label,
        action = function()
          startTest(test.seconds)
          return true
        end,
      }
    end
    form.openDialog({
      title = "@i18n(app.modules.msp_speed.start)@",
      message = "@i18n(app.modules.msp_speed.start_prompt)@",
      buttons = buttons,
      options = TEXT_LEFT,
    })
  end

  local function goBack()
    if disposed then return end
    disposed = true
    closeDialog()
    if sessionHandler then bus.unsubscribe("session.update", sessionHandler); sessionHandler = nil end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    fields = nil
    if opts.onBack then opts.onBack() end
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onTool = openStartDialog,
  })

  fields.rf = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.rf_protocol)@"), nil, "-")
  fields.runtime = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.test_length)@"), nil, "-")
  fields.total = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.total_queries)@"), nil, "0")
  fields.success = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.successful_queries)@"), nil, "0")
  fields.timeouts = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.timeouts)@"), nil, "0")
  fields.retries = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.retries)@"), nil, "0")
  fields.checksum = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.checksum_errors)@"), nil, "0")
  fields.mintime = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.min_query_time)@"), nil, "-")
  fields.maxtime = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.max_query_time)@"), nil, "-")
  fields.time = form.addStaticText(form.addLine("@i18n(app.modules.msp_speed.avg_query_time)@"), nil, "-")

  updateFields()

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(wakeup) end
  if opts.setCleanupHandler then opts.setCleanupHandler(goBack) end

  sessionHandler = bus.subscribe("session.update", function(snapshot)
    session.mspTransport = snapshot and snapshot.mspTransport
  end)
end

return {open = open}
