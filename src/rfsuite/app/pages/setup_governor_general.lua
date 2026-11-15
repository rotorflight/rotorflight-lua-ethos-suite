-- Setup -> Governor -> General page.
--
-- The governor runs only while the GOVERNOR feature is on: the firmware starts it at
-- start-up only then (rotorflight-firmware src/main/fc/init.c). With the feature off the
-- page shows OFF, as the Rotorflight Configurator does, whatever mode is stored. The stored
-- mode is kept until the pilot picks a mode here. Saving a picked mode sets the feature to
-- match it (on for any mode but OFF), and the flight controller restarts only when that
-- changes the feature, because the governor is started at start-up (#2649).

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local governorConfig = requireModule("lib/msp_governor_config.lua")
local featureConfig = requireModule("lib/msp_feature_config.lua")

local PAGE_TITLE = "@i18n(app.modules.governor.menu_general)@"

local function storedMode(runtime)
  return tonumber(runtime.data.governor and runtime.data.governor.gov_mode or 0) or 0
end

local function governorFeatureOn(runtime)
  local enabled = runtime.data.feature and tonumber(runtime.data.feature.enabledFeatures)
  if enabled == nil then return false end
  return featureConfig.getBit(enabled, featureConfig.FEATURE_BIT_GOVERNOR)
end

-- The mode on screen. Once the pilot has picked one, it is the picked one. Before that it is the
-- stored mode when the feature is on, and OFF when it is not.
local function shownMode(runtime, state)
  if state.picked or governorFeatureOn(runtime) then return storedMode(runtime) end
  return 0
end

local function refreshModeFields(runtime, state)
  local mode = shownMode(runtime, state)
  local loaded = runtime.loaded and not runtime.activeDialog
  local enabledBasic = loaded and mode >= 1
  local enabledDirect = loaded and mode >= 2
  local fields = runtime.fields or {}
  if fields["governor:gov_throttle_type"] then fields["governor:gov_throttle_type"]:enable(enabledBasic) end
  if fields["governor:governor_idle_throttle"] then fields["governor:governor_idle_throttle"]:enable(enabledBasic) end
  if fields["governor:governor_auto_throttle"] then fields["governor:governor_auto_throttle"]:enable(enabledBasic) end
  if fields["governor:gov_handover_throttle"] then fields["governor:gov_handover_throttle"]:enable(enabledDirect) end
  if fields["governor:gov_throttle_hold_timeout"] then fields["governor:gov_throttle_hold_timeout"]:enable(enabledDirect) end
  if fields["governor:gov_autorotation_timeout"] then fields["governor:gov_autorotation_timeout"]:enable(enabledDirect) end
end

local function open(opts)
  -- picked: the pilot chose a mode on this page; featureChanged: the save will change the
  -- GOVERNOR feature bit, and so needs the restart. lastShown: the mode the fields were last
  -- enabled for.
  local state = {picked = false, featureChanged = false, lastShown = nil}

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "setgovgen",
    sources = {
      {key = "governor", mspModule = governorConfig},
      {key = "feature", mspModule = featureConfig},
    },
    opts = opts,
    profileField = "none",
    -- A save restarts the flight controller only when it changes the GOVERNOR feature bit.
    -- Governor writes alone apply in RAM at once, and a restart then dropped telemetry and
    -- twitched the servos at the field on every RPM or curve correction.
    rebootAfterSave = function()
      return state.featureChanged == true
    end,
    unloadPackageKeys = {"rfsuite.lib.msp_governor_config", "rfsuite.lib.msp_feature_config"},
    -- Picks a mode into the governor's stored mode, and sets the feature bit to match it on
    -- save. A save that did not touch the mode leaves both as they were.
    beforeSave = function(rt)
      state.featureChanged = false
      if not state.picked or not rt.data.feature then return end
      local wasOn = governorFeatureOn(rt)
      local on = storedMode(rt) ~= 0
      rt.data.feature.enabledFeatures = featureConfig.setBit(
        rt.data.feature.enabledFeatures, featureConfig.FEATURE_BIT_GOVERNOR, on)
      state.featureChanged = (on ~= wasOn)
    end,
    onLoaded = function()
      state.picked = false
      state.lastShown = nil
      refreshModeFields(runtime, state)
    end,
    onWakeup = function(rt)
      local shown = shownMode(rt, state)
      if shown ~= state.lastShown then
        state.lastShown = shown
        refreshModeFields(rt, state)
      end
    end,
  })

  form.clear()
  runtime:buildChrome()
  local controlRef = runtime.controlRef

  -- The mode is a choice of its own, not a plain field: what it shows depends on the feature
  -- bit, and picking it changes what the save writes (see shownMode() and beforeSave()).
  local modeLine = form.addLine("@i18n(app.modules.governor.mode)@")
  local modeField = form.addChoiceField(modeLine, nil, governorConfig.MODE_CHOICES,
    function() return shownMode(runtime, state) end,
    function(value)
      if not runtime.data.governor then return end
      state.picked = true
      runtime.data.governor.gov_mode = value
      local rt = controlRef.runtime
      if rt then rt:markDirty() end
      refreshModeFields(runtime, state)
    end)
  runtime:registerField("governor:gov_mode", modeField)

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.throttle_type)@", {
    key = "gov_throttle_type",
    source = "governor",
    choices = governorConfig.THROTTLE_TYPE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(api.GOVERNOR_CONFIG.governor_idle_throttle)@",
    {key = "governor_idle_throttle", source = "governor"})
  fieldLayout.buildSingle(runtime, "@i18n(api.GOVERNOR_CONFIG.governor_auto_throttle)@",
    {key = "governor_auto_throttle", source = "governor"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.handover_throttle)@",
    {key = "gov_handover_throttle", source = "governor"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.throttle_hold_timeout)@",
    {key = "gov_throttle_hold_timeout", source = "governor"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.auto_timeout)@",
    {key = "gov_autorotation_timeout", source = "governor"})

  runtime:loadInitial()
end

return {open = open}
