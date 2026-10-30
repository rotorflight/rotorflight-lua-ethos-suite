-- Settings -> ActiveLook -> Alerts. Values are persisted in the ActiveLook section.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageCommon = requireModule("app/pages/settings_activelook_common.lua")
local activeConfig = requireModule("lib/activelook_config.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local function open(opts)
  pageCommon.openPage("@i18n(app.modules.settings.name)@ / ActiveLook / @i18n(app.modules.settings.activelook_alerts)@", opts,
    function(settings, updateSaveEnabled)
      local values = activeConfig.withDefaults(settings.activelook)
      settings.activelook = values
      local fahrenheit = settingsStore.temperatureUnit(settings) == 1
      local fields, enabled = {}, {}
      local function enable(key, value)
        if fields[key] and enabled[key] ~= value then
          fields[key]:enable(value)
          enabled[key] = value
        end
      end
      local function updateEnabled()
        enable("fuel_seconds", values.low_fuel_warning)
        enable("fuel_audio", values.low_fuel_warning)
        enable("fuel_repeats", values.low_fuel_warning and not values.low_fuel_use_audio_limit)
        enable("fuel_icon", values.low_fuel_warning)
        local esc = values.esc_temp_warning
        enable("esc_audio", esc)
        enable("esc_limit", esc and not values.esc_temp_use_audio_limit)
        enable("esc_seconds", esc)
        enable("esc_repeats", esc and not values.esc_temp_use_audio_limit)
        enable("esc_icon", esc)
        enable("link_limit", values.rf_link_warning)
        enable("link_percent_limit", values.rf_link_warning)
        enable("link_seconds", values.rf_link_warning)
        enable("link_repeats", values.rf_link_warning)
        enable("link_icon", values.rf_link_warning)
        enable("lost_seconds", values.governor_lost_warning)
        enable("status_seconds", values.governor_status_overlays)
      end
      local function boolean(panel, label, key)
        return form.addBooleanField(panel:addLine(label), nil,
          function() return values[key] end,
          function(value)
            values[key] = value == true
            updateEnabled()
            updateSaveEnabled()
          end)
      end
      local function number(panel, label, key, minimum, maximum, validate, suffix, getter)
        local field = form.addNumberField(panel:addLine(label), nil, minimum, maximum,
          getter or function() return values[key] end,
          function(value) values[key] = validate(value); updateSaveEnabled() end)
        if suffix and field.suffix then field:suffix(suffix) end
        return field
      end
      local fuelPanel = form.addExpansionPanel("@i18n(app.modules.settings.activelook_low_fuel)@")
      fuelPanel:open(true)
      boolean(fuelPanel, "@i18n(app.modules.settings.activelook_low_fuel_warning)@", "low_fuel_warning")
      fields.fuel_audio = boolean(fuelPanel, "@i18n(app.modules.settings.activelook_use_audio_repeats)@", "low_fuel_use_audio_limit")
      fields.fuel_repeats = number(fuelPanel, "@i18n(app.modules.settings.activelook_low_fuel_repeats)@", "low_fuel_repeats",
        activeConfig.LOW_FUEL_REPEATS_MIN, activeConfig.LOW_FUEL_REPEATS_MAX, activeConfig.clampLowFuelRepeats, "x",
        function() return activeConfig.alertRepeats(values, settings.events, "low_fuel") end)
      fields.fuel_seconds = number(fuelPanel, "@i18n(app.modules.settings.activelook_low_fuel_seconds)@", "low_fuel_seconds",
        activeConfig.LOW_FUEL_SECONDS_MIN, activeConfig.LOW_FUEL_SECONDS_MAX, activeConfig.clampLowFuelSeconds, "s")
      fields.fuel_icon = boolean(fuelPanel, "@i18n(app.modules.settings.activelook_low_fuel_icon)@", "low_fuel_icon")
      local escPanel = form.addExpansionPanel("@i18n(app.modules.settings.activelook_esc_temp_warning)@")
      escPanel:open(false)
      boolean(escPanel, "@i18n(app.modules.settings.activelook_esc_temp_warning)@", "esc_temp_warning")
      fields.esc_audio = boolean(escPanel, "@i18n(app.modules.settings.activelook_use_audio_limit)@", "esc_temp_use_audio_limit")
      fields.esc_limit = form.addNumberField(escPanel:addLine("@i18n(app.modules.settings.activelook_esc_temp_limit)@"), nil,
        fahrenheit and 140 or 60, fahrenheit and 572 or 300,
        function()
          local limit = activeConfig.escTempLimit(values, settings.events)
          return fahrenheit and math.floor(limit * 1.8 + 32 + 0.5) or limit
        end,
        function(value)
          if fahrenheit then value = (value - 32) / 1.8 end
          values.esc_temp_limit = activeConfig.clampEscTempLimit(value)
          updateSaveEnabled()
        end)
      if fields.esc_limit.suffix then fields.esc_limit:suffix(fahrenheit and "°F" or "°C") end
      fields.esc_repeats = number(escPanel, "@i18n(app.modules.settings.activelook_low_fuel_repeats)@", "esc_temp_repeats", 0, 10, activeConfig.clampEscTempRepeats, "x",
        function() return activeConfig.alertRepeats(values, settings.events, "esc_temp") end)
      fields.esc_seconds = number(escPanel, "@i18n(app.modules.settings.activelook_low_fuel_seconds)@", "esc_temp_seconds", 3, 30, activeConfig.clampAlertSeconds, "s")
      fields.esc_icon = boolean(escPanel, "@i18n(app.modules.settings.activelook_low_fuel_icon)@", "esc_temp_icon")
      local lostPanel = form.addExpansionPanel("@i18n(app.modules.settings.activelook_governor_lost)@")
      lostPanel:open(false)
      boolean(lostPanel, "@i18n(app.modules.settings.activelook_governor_lost)@", "governor_lost_warning")
      fields.lost_seconds = number(lostPanel, "@i18n(app.modules.settings.activelook_low_fuel_seconds)@", "governor_lost_seconds", 3, 30, activeConfig.clampAlertSeconds, "s")
      local linkPanel = form.addExpansionPanel("@i18n(app.modules.settings.activelook_rf_link_warning)@")
      linkPanel:open(false)
      boolean(linkPanel, "@i18n(app.modules.settings.activelook_rf_link_warning)@", "rf_link_warning")
      fields.link_limit = number(linkPanel, "@i18n(app.modules.settings.activelook_rf_link_limit)@", "rf_link_limit", 1, 100, activeConfig.clampRfLinkLimit, "dB")
      fields.link_percent_limit = number(linkPanel, "@i18n(app.modules.settings.activelook_rf_link_percent_limit)@", "rf_link_percent_limit", 1, 100, activeConfig.clampRfLinkPercentLimit, "%")
      fields.link_repeats = number(linkPanel, "@i18n(app.modules.settings.activelook_low_fuel_repeats)@", "rf_link_repeats", 1, 10, activeConfig.clampLowFuelRepeats, "x")
      fields.link_seconds = number(linkPanel, "@i18n(app.modules.settings.activelook_low_fuel_seconds)@", "rf_link_seconds", 3, 30, activeConfig.clampAlertSeconds, "s")
      fields.link_icon = boolean(linkPanel, "@i18n(app.modules.settings.activelook_low_fuel_icon)@", "rf_link_icon")
      local statusPanel = form.addExpansionPanel("@i18n(app.modules.settings.activelook_governor_status)@")
      statusPanel:open(false)
      boolean(statusPanel, "@i18n(app.modules.settings.activelook_governor_status)@", "governor_status_overlays")
      fields.status_seconds = number(statusPanel, "@i18n(app.modules.settings.activelook_status_duration)@", "governor_status_seconds", 1, 5, activeConfig.clampGovernorStatusSeconds, "s")
      local activePanel = fuelPanel
      local function bindPreview(panel, mode)
        panel:event(function(event)
          if event == EVT_OPEN then
            if activePanel == panel then return end
            local previous = activePanel
            activePanel = panel
            if previous then previous:open(false) end
            bus.publish("activelook.control", {previewMode = mode})
          elseif event == EVT_CLOSE and activePanel == panel then
            activePanel = nil
            bus.publish("activelook.control", {previewMode = nil})
          end
        end)
      end
      bindPreview(fuelPanel, "low_fuel")
      bindPreview(escPanel, "esc_temp")
      bindPreview(lostPanel, "governor_lost")
      bindPreview(linkPanel, "rf_link")
      bindPreview(statusPanel, "governor_status")
      bus.publish("activelook.control", {previewMode = "low_fuel"})
      updateEnabled()
    end)
end
return {open = open}
