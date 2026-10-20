-- Settings -> ActiveLook -> Low Fuel.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageCommon = requireModule("app/pages/settings_activelook_common.lua")
local activeConfig = requireModule("lib/activelook_config.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / ActiveLook / @i18n(app.modules.settings.activelook_low_fuel)@"

local function open(opts)
  pageCommon.openPage(PAGE_TITLE, opts, function(settings, updateSaveEnabled)
    settings.activelook = activeConfig.withDefaults(settings.activelook)
    bus.publish("activelook.control", {previewMode = "low_fuel"})

    local dependentFields = {}
    local function enableDependent()
      local on = settings.activelook.low_fuel_warning == true
      for i = 1, #dependentFields do
        local field = dependentFields[i]
        if field and field.enable then field:enable(on) end
      end
    end

    local line = form.addLine("@i18n(app.modules.settings.activelook_low_fuel_warning)@")
    form.addBooleanField(line, nil,
      function() return settings.activelook.low_fuel_warning == true end,
      function(value)
        settings.activelook.low_fuel_warning = value == true
        enableDependent()
        updateSaveEnabled()
      end)

    line = form.addLine("    @i18n(app.modules.settings.activelook_low_fuel_seconds)@")
    local durationField = form.addNumberField(line, nil, activeConfig.LOW_FUEL_SECONDS_MIN, activeConfig.LOW_FUEL_SECONDS_MAX,
      function() return activeConfig.clampLowFuelSeconds(settings.activelook.low_fuel_seconds) end,
      function(value)
        settings.activelook.low_fuel_seconds = activeConfig.clampLowFuelSeconds(value)
        updateSaveEnabled()
      end)
    if durationField and durationField.suffix then durationField:suffix("s") end
    dependentFields[#dependentFields + 1] = durationField

    line = form.addLine("    @i18n(app.modules.settings.activelook_low_fuel_repeats)@")
    local repeatsField = form.addNumberField(line, nil, activeConfig.LOW_FUEL_REPEATS_MIN, activeConfig.LOW_FUEL_REPEATS_MAX,
      function() return activeConfig.clampLowFuelRepeats(settings.activelook.low_fuel_repeats) end,
      function(value)
        settings.activelook.low_fuel_repeats = activeConfig.clampLowFuelRepeats(value)
        updateSaveEnabled()
      end)
    if repeatsField and repeatsField.suffix then repeatsField:suffix("x") end
    dependentFields[#dependentFields + 1] = repeatsField

    line = form.addLine("    @i18n(app.modules.settings.activelook_low_fuel_icon)@")
    local iconField = form.addBooleanField(line, nil,
      function() return settings.activelook.low_fuel_icon == true end,
      function(value)
        settings.activelook.low_fuel_icon = value == true
        updateSaveEnabled()
      end)
    dependentFields[#dependentFields + 1] = iconField

    enableDependent()
  end)
end

return {open = open}
