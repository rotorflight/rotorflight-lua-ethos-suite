-- Mixer -> Swash page.
--
-- Ports the original API >= 12.0.9 Swash direction/config page. This
-- edits swash type, main rotor direction, and the sign of the existing
-- roll/pitch/collective mixer input rates; magnitudes and limits are
-- preserved exactly as read from the FC.

local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local mixerConfig = assert(loadfile("lib/msp_mixer_config.lua"))()
local mixerInputFactory = assert(loadfile("lib/msp_mixer_input.lua"))()

local PAGE_TITLE = "@i18n(app.modules.mixer.swash)@"

local CHOICES_SWASH_TYPE = {
  {"None", 0},
  {"Direct", 1},
  {"CPPM 120", 2},
  {"CPPM 135", 3},
  {"CPPM 140", 4},
  {"FPM 90 L", 5},
  {"FPM 90 V", 6},
}

local CHOICES_ROTOR_DIR = {
  {"@i18n(api.MIXER_CONFIG.tbl_cw)@", 0},
  {"@i18n(api.MIXER_CONFIG.tbl_ccw)@", 1},
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

local function rateToDirection(value)
  return u16ToS16(value) < 0 and 0 or 1
end

local function applyDirectionToRate(value, direction)
  local magnitude = math.abs(u16ToS16(value))
  if direction == 0 then magnitude = -magnitude end
  return s16ToU16(magnitude)
end

local function open(opts)
  local formData = {}
  local originalSwashType = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mixer_swash",
    sources = {
      {key = "mixer", mspModule = mixerConfig},
      {key = "pitch", mspModule = mixerInputFactory.pitch()},
      {key = "roll", mspModule = mixerInputFactory.roll()},
      {key = "collective", mspModule = mixerInputFactory.collective()},
    },
    opts = opts,
    profileField = "none",
    rebootAfterSave = function()
      return formData.swash_type ~= originalSwashType
    end,
    unloadPackageKeys = {
      "rfsuite.lib.msp_mixer_config",
      "rfsuite.lib.msp_mixer_input",
    },
    onLoaded = function()
      local mixer = runtime.data.mixer or {}
      local pitch = runtime.data.pitch or {}
      local roll = runtime.data.roll or {}
      local collective = runtime.data.collective or {}
      formData.swash_type = mixer.swash_type or 0
      formData.main_rotor_dir = mixer.main_rotor_dir or 0
      formData.aileron_direction = rateToDirection(roll.rate_stabilized_roll)
      formData.elevator_direction = rateToDirection(pitch.rate_stabilized_pitch)
      formData.collective_direction = rateToDirection(collective.rate_stabilized_collective)
      originalSwashType = formData.swash_type
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      local mixer = rt.data.mixer
      if mixer then
        mixer.swash_type = formData.swash_type or 0
        mixer.main_rotor_dir = formData.main_rotor_dir or 0
      end
      local pitch = rt.data.pitch
      if pitch then
        pitch.rate_stabilized_pitch =
          applyDirectionToRate(pitch.rate_stabilized_pitch, formData.elevator_direction)
      end
      local roll = rt.data.roll
      if roll then
        roll.rate_stabilized_roll =
          applyDirectionToRate(roll.rate_stabilized_roll, formData.aileron_direction)
      end
      local collective = rt.data.collective
      if collective then
        collective.rate_stabilized_collective =
          applyDirectionToRate(collective.rate_stabilized_collective, formData.collective_direction)
      end
    end,
  })

  local function addChoice(label, key, choices)
    local line = form.addLine(label)
    local field = form.addChoiceField(line, nil, choices,
      function() return formData[key] or 0 end,
      function(value)
        runtime:markDirty()
        formData[key] = value
      end)
    runtime:registerField(key, field)
  end

  form.clear()
  runtime:buildChrome()

  addChoice("@i18n(app.modules.mixer.swash_type)@", "swash_type", CHOICES_SWASH_TYPE)
  addChoice("@i18n(app.modules.mixer.main_rotor_dir)@", "main_rotor_dir", CHOICES_ROTOR_DIR)
  addChoice("@i18n(app.modules.mixer.aileron_direction)@", "aileron_direction", CHOICES_DIRECTION)
  addChoice("@i18n(app.modules.mixer.elevator_direction)@", "elevator_direction", CHOICES_DIRECTION)
  addChoice("@i18n(app.modules.mixer.collective_direction)@", "collective_direction", CHOICES_DIRECTION)

  runtime:loadInitial()
end

return {open = open}
