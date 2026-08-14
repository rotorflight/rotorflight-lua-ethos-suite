-- Mixer -> Geometry page.
--
-- Ports the API >= 12.0.9 swash geometry page, including Swash Setup
-- Mode: the Tool button toggles passthrough mixer override and live-writes
-- edits without EEPROM while it is enabled. Save still commits the current
-- values to EEPROM through page_runtime's normal flow.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageRuntime = requireModule("app/page_runtime.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")
local mixerInputFactory = requireModule("lib/msp_mixer_input.lua")
local mixerOverride = requireModule("lib/msp_mixer_override.lua")

local PAGE_TITLE = "@i18n(app.modules.mixer.geometry)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

local LIVE_INTERVAL = 0.25

local FIELD_ORDER = {
  "cyclic_calibration",
  "collective_calibration",
  "geo_correction",
  "cyclic_pitch_limit",
  "collective_pitch_limit",
  "swash_pitch_limit",
  "swash_phase",
  "collective_tilt_correction_pos",
  "collective_tilt_correction_neg",
}

local SPECS = {
  cyclic_calibration = {label = "@i18n(app.modules.mixer.cyclic_calibration)@", min = 200, max = 2000, suffix = "%", decimals = 1, default = 400},
  collective_calibration = {label = "@i18n(app.modules.mixer.collective_calibration)@", min = 200, max = 2000, suffix = "%", decimals = 1, default = 400},
  geo_correction = {label = "@i18n(app.modules.mixer.geo_correction)@", min = -250, max = 250, suffix = "%", decimals = 1, default = 0},
  cyclic_pitch_limit = {label = "@i18n(app.modules.mixer.cyclic_pitch_limit)@", min = 0, max = 200, suffix = "°", decimals = 1, default = 20},
  collective_pitch_limit = {label = "@i18n(app.modules.mixer.collective_pitch_limit)@", min = 0, max = 200, suffix = "°", decimals = 1, default = 20},
  swash_pitch_limit = {label = "@i18n(app.modules.mixer.swash_pitch_limit)@", min = 0, max = 360, suffix = "°", decimals = 1, default = 200},
  swash_phase = {label = "@i18n(app.modules.mixer.swash_phase)@", min = -1800, max = 1800, suffix = "°", decimals = 1, default = 0},
  collective_tilt_correction_pos = {label = "@i18n(app.modules.mixer.collective_tilt_correction_pos)@", min = -100, max = 100, suffix = "%", default = 0},
  collective_tilt_correction_neg = {label = "@i18n(app.modules.mixer.collective_tilt_correction_neg)@", min = -100, max = 100, suffix = "%", default = 10},
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

local function rateToDirection(value)
  return u16ToS16(value) < 0 and 0 or 1
end

local function dirSign(direction)
  return direction == 0 and -1 or 1
end

local function digest(formData)
  local parts = {}
  for i = 1, #FIELD_ORDER do
    parts[i] = tostring(formData[FIELD_ORDER[i]] or "")
  end
  return table.concat(parts, "|")
end

local function queueOverride(value)
  for i = 1, 4 do
    bus.publish("msp.request", mixerOverride.buildWriteMessage(i, value))
  end
end

local function open(opts)
  local formData = {}
  local directions = {}
  local inOverride = false
  local lastLiveDigest = nil
  local lastLiveAt = 0

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mixer_geometry",
    sources = {
      {key = "mixer", mspModule = mixerConfig},
      {key = "pitch", mspModule = mixerInputFactory.pitch()},
      {key = "roll", mspModule = mixerInputFactory.roll()},
      {key = "collective", mspModule = mixerInputFactory.collective()},
    },
    opts = opts,
    profileField = "none",
    unloadPackageKeys = {
      "rfsuite.lib.msp_mixer_config",
      "rfsuite.lib.msp_mixer_input",
      "rfsuite.lib.msp_mixer_override",
    },
    onLoaded = function()
      local mixer = runtime.data.mixer or {}
      local pitch = runtime.data.pitch or {}
      local roll = runtime.data.roll or {}
      local collective = runtime.data.collective or {}

      directions.elevator = rateToDirection(pitch.rate_stabilized_pitch)
      directions.aileron = rateToDirection(roll.rate_stabilized_roll)
      directions.collective = rateToDirection(collective.rate_stabilized_collective)

      formData.cyclic_calibration = math.abs(u16ToS16(pitch.rate_stabilized_pitch))
      formData.collective_calibration = math.abs(u16ToS16(collective.rate_stabilized_collective))
      formData.geo_correction = (mixer.swash_geo_correction or 0) * 2
      formData.cyclic_pitch_limit = round(math.abs(u16ToS16(pitch.max_stabilized_pitch)) * 12 / 100)
      formData.collective_pitch_limit = round(math.abs(u16ToS16(collective.max_stabilized_collective)) * 12 / 100)
      formData.swash_pitch_limit = round((mixer.swash_pitch_limit or 0) * 12 / 100)
      formData.swash_phase = mixer.swash_phase or 0
      formData.collective_tilt_correction_pos = mixer.collective_tilt_correction_pos or 0
      formData.collective_tilt_correction_neg = mixer.collective_tilt_correction_neg or 0
      lastLiveDigest = digest(formData)
      lastLiveAt = os.clock()
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      local mixer = rt.data.mixer
      if mixer then
        mixer.swash_geo_correction = round((formData.geo_correction or 0) / 2)
        mixer.swash_pitch_limit = round((formData.swash_pitch_limit or 0) * 100 / 12)
        mixer.swash_phase = formData.swash_phase or 0
        mixer.collective_tilt_correction_pos = formData.collective_tilt_correction_pos or 0
        mixer.collective_tilt_correction_neg = formData.collective_tilt_correction_neg or 0
      end

      local cyclicRate = round(formData.cyclic_calibration or 0)
      local cyclicLimit = round((formData.cyclic_pitch_limit or 0) * 100 / 12)
      local pitch = rt.data.pitch
      if pitch then
        pitch.rate_stabilized_pitch = s16ToU16(cyclicRate * dirSign(directions.elevator))
        pitch.max_stabilized_pitch = s16ToU16(math.abs(cyclicLimit))
        pitch.min_stabilized_pitch = s16ToU16(-math.abs(cyclicLimit))
      end
      local roll = rt.data.roll
      if roll then
        roll.rate_stabilized_roll = s16ToU16(cyclicRate * dirSign(directions.aileron))
        roll.max_stabilized_roll = s16ToU16(math.abs(cyclicLimit))
        roll.min_stabilized_roll = s16ToU16(-math.abs(cyclicLimit))
      end
      local collective = rt.data.collective
      if collective then
        local collectiveRate = round(formData.collective_calibration or 0)
        local collectiveLimit = round((formData.collective_pitch_limit or 0) * 100 / 12)
        collective.rate_stabilized_collective = s16ToU16(collectiveRate * dirSign(directions.collective))
        collective.max_stabilized_collective = s16ToU16(math.abs(collectiveLimit))
        collective.min_stabilized_collective = s16ToU16(-math.abs(collectiveLimit))
      end
    end,
    onTool = function(focusFn)
      form.openDialog({
        title = inOverride and "@i18n(app.modules.mixer.disable_swash_override)@"
          or "@i18n(app.modules.mixer.enable_swash_override)@",
        message = inOverride and "@i18n(app.modules.mixer.disable_swash_override_message)@"
          or "@i18n(app.modules.mixer.enable_swash_override_message)@",
        buttons = {
          {label = BTN_OK, action = function()
            if inOverride then
              queueOverride(mixerOverride.OVERRIDE_OFF)
              inOverride = false
            else
              queueOverride(mixerOverride.OVERRIDE_PASSTHROUGH)
              inOverride = true
              lastLiveDigest = digest(formData)
              lastLiveAt = os.clock()
            end
            if focusFn then focusFn() end
            return true
          end},
          {label = BTN_CANCEL, action = function()
            if focusFn then focusFn() end
            return true
          end},
        },
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT,
      })
    end,
    onWakeup = function(rt)
      if not inOverride or not rt.loaded or rt.activeDialog then return end
      local now = os.clock()
      local current = digest(formData)
      if current ~= lastLiveDigest and (now - lastLiveAt) >= LIVE_INTERVAL then
        rt.beforeSave(rt)
        for _, source in ipairs(rt.sources) do
          local values = rt.data[source.key]
          bus.publish("msp.request", source.mspModule.buildWriteMessage(values))
        end
        lastLiveDigest = current
        lastLiveAt = now
      end
    end,
    onDispose = function()
      if inOverride then
        queueOverride(mixerOverride.OVERRIDE_OFF)
        inOverride = false
      end
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

  local function addNumber(key)
    local spec = SPECS[key]
    local line = form.addLine(spec.label)
    local field = form.addNumberField(line, nil, spec.min, spec.max,
      function() return formData[key] or 0 end,
      function(value) markDirty(); formData[key] = value end)
    if spec.suffix then field:suffix(spec.suffix) end
    if spec.decimals then field:decimals(spec.decimals) end
    field:default(spec.default or 0)
    if field.enableInstantChange then field:enableInstantChange(true) end
    runtime:registerField(key, field)
  end

  form.clear()
  runtime:buildChrome()
  for _, key in ipairs(FIELD_ORDER) do
    addNumber(key)
  end
  runtime:loadInitial()
end

return {open = open}
