-- Alignment page. Loaded on demand from Setup -> Alignment.
--
-- Ports the original Alignment module's editable configuration plus its
-- custom live 3D helicopter attitude preview. The original page polls
-- MSP_ATTITUDE while open, combines live roll/pitch/yaw with the saved
-- mounting offsets, and draws a projected heli model below the form
-- fields; this page keeps that behavior while routing MSP traffic through
-- this rebuild's bus/page_runtime architecture.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local visual = requireModule("app/alignment_visual.lua")
local attitude = requireModule("lib/msp_attitude.lua")
local boardAlignment = requireModule("lib/msp_board_alignment_config.lua")
local sensorAlignment = requireModule("lib/msp_sensor_alignment.lua")

local PAGE_TITLE = "@i18n(app.modules.alignment.name)@"
local floor = math.floor
local max = math.max
local min = math.min

local MAG_ALIGN_CHOICES = {
  {"@i18n(app.modules.alignment.mag_default)@", 0},
  {"@i18n(app.modules.alignment.mag_cw_0)@", 1},
  {"@i18n(app.modules.alignment.mag_cw_90)@", 2},
  {"@i18n(app.modules.alignment.mag_cw_180)@", 3},
  {"@i18n(app.modules.alignment.mag_cw_270)@", 4},
  {"@i18n(app.modules.alignment.mag_cw_0_flip)@", 5},
  {"@i18n(app.modules.alignment.mag_cw_90_flip)@", 6},
  {"@i18n(app.modules.alignment.mag_cw_180_flip)@", 7},
  {"@i18n(app.modules.alignment.mag_cw_270_flip)@", 8},
  {"@i18n(app.modules.alignment.mag_custom)@", 9},
}

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function textWidth(text)
  local w = lcd.getTextSize(text)
  return w or 0
end

local function buildControl(runtime, line, y, h, x, w, label, spec, preferredFieldW)
  local labelW = textWidth(label .. " ")
  local gap = 4
  local fieldW = preferredFieldW or (w - labelW - gap)
  fieldW = clamp(fieldW, 42, max(42, w - labelW - gap))
  local labelRect = {x = x, y = y, w = labelW, h = h}
  local fieldRect = {x = x + labelW + gap, y = y, w = fieldW, h = h}
  form.addStaticText(line, labelRect, label)
  fieldLayout.buildField(runtime, line, fieldRect, spec)
end

local function buildAlignmentControlRow(runtime)
  local line = form.addLine("")
  local slot = form.getFieldSlots(line, {0})[1]
  local screenW = ({lcd.getWindowSize()})[1]
  local margin = 6
  local gap = 10
  local available = screenW - (margin * 2) - (gap * 3)
  local groupW = floor(available / 4)
  local y = slot.y
  local h = slot.h

  buildControl(runtime, line, y, h, margin, groupW,
    "@i18n(app.modules.alignment.roll)@",
    {key = "roll_degrees", source = "board"},
    min(74, groupW - textWidth("@i18n(app.modules.alignment.roll)@ ") - 4))

  buildControl(runtime, line, y, h, margin + (groupW + gap), groupW,
    "@i18n(app.modules.alignment.pitch)@",
    {key = "pitch_degrees", source = "board"},
    min(74, groupW - textWidth("@i18n(app.modules.alignment.pitch)@ ") - 4))

  buildControl(runtime, line, y, h, margin + ((groupW + gap) * 2), groupW,
    "@i18n(app.modules.alignment.yaw)@",
    {key = "yaw_degrees", source = "board"},
    min(74, groupW - textWidth("@i18n(app.modules.alignment.yaw)@ ") - 4))

  buildControl(runtime, line, y, h, margin + ((groupW + gap) * 3), groupW,
    "@i18n(app.modules.alignment.mag)@",
    {key = "mag_alignment", source = "sensor", choices = MAG_ALIGN_CHOICES})
end

local function open(opts)
  local state = {
    display = {
      roll_degrees = 0,
      pitch_degrees = 0,
      yaw_degrees = 0,
      mag_alignment = 0,
    },
    -- Board offsets as currently saved on the FC at the moment this page
    -- opened -- i.e. the offsets already baked into every MSP_ATTITUDE
    -- sample below, since board alignment is applied to the sensor data
    -- before attitude is computed (rebootAfterSave = true: nothing typed
    -- into the roll/pitch/yaw fields here takes effect until saved and
    -- rebooted). Captured once, on the first syncDisplayFromData() call,
    -- and never touched again for the life of this page instance -- see
    -- its use in alignment_visual.draw()/recenterYaw().
    baseline = {
      roll_degrees = 0,
      pitch_degrees = 0,
      yaw_degrees = 0,
    },
    baselineCaptured = false,
    live = {
      roll = 0,
      pitch = 0,
      yaw = 0,
    },
    viewYawOffset = 0,
    autoRecenterPending = true,
    pendingAttitude = false,
    pendingAt = 0,
    lastAttitudeAt = 0,
    lastInvalidateAt = 0,
    -- Was 0.08 (12.5Hz), then 0.2 (5Hz) -- both too hot in practice on
    -- their own. tasks/msp/queue.lua is strictly single-in-flight (one
    -- request out at a time, one processQueue() call per background-task
    -- tick -- see its own header comment), shared with everything
    -- tasks/session.lua polls continuously in the background (telemetry
    -- every 0.5s, adjustments every 0.2s, ELRS sensor every 0.18s, etc.).
    -- 0.4s (2.5Hz) confirmed working live once paired with two other
    -- fixes: lib/msp_attitude.lua's wider per-request retry budget (was
    -- failing every single attempt outright, unrelated to this rate), and
    -- tasks/session.lua's blackbox-summary poll no longer firing while a
    -- page is open (see its own appRunning comment). With that contention
    -- gone there's headroom to nudge this back up a bit; 0.3s (~3.3Hz).
    attitudeSamplePeriod = 0.3,
    -- Must clear a stuck pendingAttitude flag only *after* the underlying
    -- queued message has had its own fair chance to succeed or fail, or
    -- this page would fire a duplicate requestAttitude() while the first
    -- one is still legitimately retrying, piling up redundant in-flight
    -- messages. lib/msp_attitude.lua's buildReadMessage() now allows up to
    -- 3 attempts at the default 0.8s spacing (~1.6s worst case) -- see its
    -- own comment for why. 3.0s gives that comfortable headroom.
    pendingTimeout = 3.0,
  }

  local runtime
  local syncDisplayFromData

  local function recenterYaw()
    if runtime then
      syncDisplayFromData()
    end
    visual.recenterYaw(state)
    if lcd.invalidate then lcd.invalidate() end
  end

  local function requestAttitude()
    if state.pendingAttitude or runtime.activeDialog then return end
    state.pendingAttitude = true
    state.pendingAt = os.clock()
    bus.publish("msp.request", attitude.buildReadMessage(function(values)
      if not runtime or runtime.disposed then return end
      state.live.roll = ((values and values.roll) or 0) / 10.0
      state.live.pitch = ((values and values.pitch) or 0) / 10.0
      state.live.yaw = (values and values.yaw) or 0
      state.pendingAttitude = false
      if state.autoRecenterPending then
        recenterYaw()
        state.autoRecenterPending = false
      end
    end, function()
      state.pendingAttitude = false
    end))
  end

  syncDisplayFromData = function()
    local board = runtime.data.board or {}
    local sensor = runtime.data.sensor or {}
    state.display.roll_degrees = board.roll_degrees or 0
    state.display.pitch_degrees = board.pitch_degrees or 0
    state.display.yaw_degrees = board.yaw_degrees or 0
    state.display.mag_alignment = sensor.mag_alignment or 0
  end

  -- Deliberately NOT folded into syncDisplayFromData() above: that runs
  -- from onPaint too, and Ethos calls a freshly-built field's paint (so
  -- this page's onPaint, hence syncDisplayFromData()) before loadInitial()
  -- has gotten anywhere -- see page_runtime.lua's PageRuntime.new() comment
  -- on why self.data[source.key] is pre-seeded to {}. Capturing baseline
  -- there would latch it onto that pre-seeded {roll=0,pitch=0,yaw=0}
  -- forever, before the real saved offsets ever arrive, silently turning
  -- the live+display-baseline math back into plain live+display -- the
  -- exact double-count bug this baseline exists to fix. Only call this
  -- from onLoaded, which page_runtime.lua defers until after loadData()'s
  -- full read has actually landed in runtime.data.
  local function captureBaselineIfNeeded()
    if state.baselineCaptured then return end
    state.baseline.roll_degrees = state.display.roll_degrees
    state.baseline.pitch_degrees = state.display.pitch_degrees
    state.baseline.yaw_degrees = state.display.yaw_degrees
    state.baselineCaptured = true
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "alignment",
    sources = {
      {key = "board", mspModule = boardAlignment},
      {key = "sensor", mspModule = sensorAlignment},
    },
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {
      "rfsuite.app.alignment_visual",
      "rfsuite.lib.msp_attitude",
      "rfsuite.lib.msp_board_alignment_config",
      "rfsuite.lib.msp_sensor_alignment",
    },
    onLoaded = function()
      syncDisplayFromData()
      captureBaselineIfNeeded()
      if state.autoRecenterPending then
        recenterYaw()
      end
    end,
    onWakeup = function()
      local now = os.clock()
      if state.pendingAttitude and (now - state.pendingAt) > state.pendingTimeout then
        state.pendingAttitude = false
      end
      if runtime.loaded and not runtime.activeDialog
          and (now - state.lastAttitudeAt) >= state.attitudeSamplePeriod then
        state.lastAttitudeAt = now
        requestAttitude()
      end
      if (now - state.lastInvalidateAt) >= 0.08 then
        state.lastInvalidateAt = now
        if lcd.invalidate then lcd.invalidate() end
      end
    end,
    onPaint = function()
      syncDisplayFromData()
      visual.draw(state)
    end,
    onTool = function(focusFn)
      form.openDialog({
        title = PAGE_TITLE,
        message = "@i18n(app.modules.alignment.msg_reset_tail_view)@",
        buttons = {
          {label = "@i18n(app.btn_ok)@", action = function()
            recenterYaw()
            if focusFn then focusFn() end
            return true
          end},
          {label = "@i18n(app.btn_cancel)@", action = function()
            if focusFn then focusFn() end
            return true
          end},
        },
        wakeup = function() end,
        paint = function() end,
      })
    end,
  })

  form.clear()
  runtime:buildChrome()

  buildAlignmentControlRow(runtime)

  runtime:loadInitial()
end

return {open = open}
