-- Mixer -> Tail page.
--
-- Ports the original API >= 12.0.9 Tail page. The visible field set is
-- chosen from the current tail rotor mode: fixed-pitch tails expose yaw
-- center trim in degrees, while motorized/bidirectional tails expose tail
-- idle and use raw percent-like yaw limits.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")
local mixerInputFactory = requireModule("lib/msp_mixer_input.lua")

local PAGE_TITLE = "@i18n(app.modules.mixer.tail)@"

local CHOICES_TAIL_MODE = {
  {"@i18n(api.MIXER_CONFIG.tbl_tail_variable_pitch)@", 0},
  {"@i18n(api.MIXER_CONFIG.tbl_tail_motororized_tail)@", 1},
  {"@i18n(api.MIXER_CONFIG.tbl_tail_bidirectional)@", 2},
}

local CHOICES_DIRECTION = {
  {"@i18n(api.MIXER_INPUT.tbl_reversed)@", 0},
  {"@i18n(api.MIXER_INPUT.tbl_normal)@", 1},
}

local function u16ToS16(value)
  if not value then return 0 end
  if value >= 0x8000 then return value - 0x10000 end
  return value
end

local function s16ToU16(value)
  if value < 0 then return value + 0x10000 end
  return value
end

local function round(value)
  if value >= 0 then return math.floor(value + 0.5) end
  return math.ceil(value - 0.5)
end

local function isMotorizedMode(mode)
  return (tonumber(mode) or -1) >= 1
end

local function rateToDirection(value)
  return u16ToS16(value) < 0 and 0 or 1
end

local function dirSign(direction)
  return direction == 0 and -1 or 1
end

local function open(opts)
  local formData = {}
  local originalMode = nil
  local fields = {}

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mixer_tail",
    sources = {
      {key = "mixer", mspModule = mixerConfig},
      {key = "yaw", mspModule = mixerInputFactory.yaw()},
    },
    opts = opts,
    profileField = "none",
    rebootAfterSave = function()
      return originalMode ~= nil and formData.tail_rotor_mode ~= originalMode
    end,
    unloadPackageKeys = {
      "rfsuite.lib.msp_mixer_config",
      "rfsuite.lib.msp_mixer_input",
    },
    onLoaded = function()
      local mixer = runtime.data.mixer or {}
      local yaw = runtime.data.yaw or {}
      local mode = mixer.tail_rotor_mode or 0
      formData.tail_rotor_mode = mode
      formData.yaw_direction = rateToDirection(yaw.rate_stabilized_yaw)
      formData.yaw_calibration = math.abs(u16ToS16(yaw.rate_stabilized_yaw))
      formData.tail_motor_idle = mixer.tail_motor_idle or 0
      formData.tail_center_offset = mixer.tail_center_trim or 0
      formData.yaw_center_trim = round(math.abs(u16ToS16(mixer.tail_center_trim)) * 24 / 100)
      formData.yaw_cw_limit_motor = math.abs(u16ToS16(yaw.min_stabilized_yaw))
      formData.yaw_ccw_limit_motor = math.abs(u16ToS16(yaw.max_stabilized_yaw))
      formData.yaw_cw_limit_fixed = round(math.abs(u16ToS16(yaw.min_stabilized_yaw)) * 24 / 100)
      formData.yaw_ccw_limit_fixed = round(math.abs(u16ToS16(yaw.max_stabilized_yaw)) * 24 / 100)

      originalMode = mode
      if fields.refresh then fields.refresh() end
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      local mixer = rt.data.mixer
      if mixer then
        mixer.tail_rotor_mode = formData.tail_rotor_mode or 0
        if isMotorizedMode(formData.tail_rotor_mode) then
          mixer.tail_motor_idle = formData.tail_motor_idle or 0
          mixer.tail_center_trim = formData.tail_center_offset or 0
        else
          mixer.tail_center_trim = s16ToU16(round((formData.yaw_center_trim or 0) * 100 / 24))
        end
      end

      local yaw = rt.data.yaw
      if yaw then
        local yawRate = round(formData.yaw_calibration or 0)
        yaw.rate_stabilized_yaw = s16ToU16(yawRate * dirSign(formData.yaw_direction))

        local cw
        local ccw
        if isMotorizedMode(formData.tail_rotor_mode) then
          cw = round(formData.yaw_cw_limit_motor or 0)
          ccw = round(formData.yaw_ccw_limit_motor or 0)
        else
          cw = round(formData.yaw_cw_limit_fixed or 0)
          ccw = round(formData.yaw_ccw_limit_fixed or 0)
          cw = round(cw * 100 / 24)
          ccw = round(ccw * 100 / 24)
        end
        yaw.min_stabilized_yaw = s16ToU16(-math.abs(cw))
        yaw.max_stabilized_yaw = s16ToU16(math.abs(ccw))
      end
    end,
    onWakeup = function()
      if fields.refresh then fields.refresh() end
    end,
  })

  -- Captured instead of closing over `runtime` directly in each field
  -- setter below -- matching app/pages/pids.lua's own dataRef convention
  -- (see its comment): Ethos retains some form callback closures past
  -- this page's own lifetime, and controlRef.runtime gets nilled on
  -- dispose (app/page_runtime.lua's own PageRuntime:dispose()), so
  -- whatever gets retained here stays small instead of pinning the whole
  -- disposed PageRuntime.
  local controlRef = runtime.controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end

  local function addChoice(label, key, choices, onChange)
    local line = form.addLine(label)
    local field = form.addChoiceField(line, nil, choices,
      function() return formData[key] or 0 end,
      function(value)
        markDirty()
        formData[key] = value
        if onChange then onChange(value) end
      end)
    runtime:registerField(key, field)
    fields[key] = field
  end

  local function addNumber(label, key, min, max, suffix, decimals, default)
    local line = form.addLine(label)
    local field = form.addNumberField(line, nil, min, max,
      function() return formData[key] or 0 end,
      function(value)
        markDirty()
        formData[key] = value
      end)
    if suffix then field:suffix(suffix) end
    if decimals then field:decimals(decimals) end
    if default then field:default(default) end
    runtime:registerField(key, field)
    fields[key] = field
  end

  form.clear()
  runtime:buildChrome()

  fields.refresh = function()
    local motorized = isMotorizedMode(formData.tail_rotor_mode)
    if fields.tail_motor_idle then fields.tail_motor_idle:enable(runtime.loaded and motorized) end
    if fields.tail_center_offset then fields.tail_center_offset:enable(runtime.loaded and motorized) end
    if fields.yaw_cw_limit_motor then fields.yaw_cw_limit_motor:enable(runtime.loaded and motorized) end
    if fields.yaw_ccw_limit_motor then fields.yaw_ccw_limit_motor:enable(runtime.loaded and motorized) end
    if fields.yaw_center_trim then fields.yaw_center_trim:enable(runtime.loaded and not motorized) end
    if fields.yaw_cw_limit_fixed then fields.yaw_cw_limit_fixed:enable(runtime.loaded and not motorized) end
    if fields.yaw_ccw_limit_fixed then fields.yaw_ccw_limit_fixed:enable(runtime.loaded and not motorized) end
  end

  addChoice("@i18n(app.modules.mixer.tail_rotor_mode)@", "tail_rotor_mode", CHOICES_TAIL_MODE, fields.refresh)
  addChoice("@i18n(app.modules.mixer.yaw_direction)@", "yaw_direction", CHOICES_DIRECTION)
  addNumber("@i18n(app.modules.mixer.tail_motor_idle)@", "tail_motor_idle", 0, 250, "%", 1, 0)
  addNumber("@i18n(app.modules.mixer.tail_center_offset)@", "tail_center_offset", -500, 500, "%", 1, 0)
  addNumber("@i18n(app.modules.mixer.yaw_center_trim)@", "yaw_center_trim", -250, 250, "%", 1, 0)
  addNumber("@i18n(app.modules.mixer.yaw_calibration)@", "yaw_calibration", 200, 2000, "%", 1, 400)
  addNumber("@i18n(app.modules.mixer.yaw_cw_limit)@", "yaw_cw_limit_motor", 0, 2000, "%", 1, 125)
  addNumber("@i18n(app.modules.mixer.yaw_ccw_limit)@", "yaw_ccw_limit_motor", 0, 2000, "%", 1, 125)
  addNumber("@i18n(app.modules.mixer.yaw_cw_limit)@", "yaw_cw_limit_fixed", 0, 600, "°", 1, 20)
  addNumber("@i18n(app.modules.mixer.yaw_ccw_limit)@", "yaw_ccw_limit_fixed", 0, 600, "°", 1, 20)
  fields.refresh()

  runtime:loadInitial()
end

return {open = open}
