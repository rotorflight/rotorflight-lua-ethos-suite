-- Settings -> ActiveLook -> Alerts. Values are persisted in the ActiveLook section.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageCommon = requireModule("app/pages/settings_activelook_common.lua")
local activeConfig = requireModule("lib/activelook_config.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local escStatus = requireModule("lib/esc_status.lua")

local AVAILABILITY = {
  offline = "@i18n(app.modules.settings.activelook_esc_offline)@",
  missing = "@i18n(app.modules.settings.activelook_esc_missing)@",
  unknown = "@i18n(widgets.escstatus.unknown)@",
  unsupported = "@i18n(app.modules.settings.activelook_esc_unsupported)@",
  generic = "@i18n(app.modules.settings.activelook_esc_generic)@",
  detailed = "@i18n(app.modules.settings.activelook_esc_available)@",
}
local ESC_MESSAGES = {
  {"@i18n(app.modules.settings.activelook_esc_messages_all)@", 1},
  {"@i18n(app.modules.settings.activelook_esc_messages_errors)@", 2},
  {"@i18n(app.modules.settings.activelook_esc_messages_warnings)@", 3},
}

local function open(opts)
  opts = opts or {}
  pageCommon.openPage("@i18n(app.modules.settings.name)@ / ActiveLook / @i18n(app.modules.settings.activelook_alerts)@", opts,
    function(settings, updateSaveEnabled, leaveTo)
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
        enable("esc_messages", values.esc_status_warning)
        enable("esc_status_seconds", values.esc_status_warning)
        enable("esc_status_repeats", values.esc_status_warning)
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
      local escStatusPanel = form.addExpansionPanel("@i18n(app.modules.settings.activelook_esc_status)@")
      escStatusPanel:open(false)
      boolean(escStatusPanel, "@i18n(app.modules.settings.activelook_esc_status_warning)@", "esc_status_warning")
      fields.esc_messages = form.addChoiceField(escStatusPanel:addLine("@i18n(app.modules.settings.activelook_esc_messages)@"), nil, ESC_MESSAGES,
        function()
          if values.esc_status_errors then return values.esc_status_warnings and 1 or 2 end
          return 3
        end,
        function(value)
          if value ~= 1 and value ~= 2 and value ~= 3 then return end
          values.esc_status_errors = value == 1 or value == 2
          values.esc_status_warnings = value == 1 or value == 3
          updateSaveEnabled()
        end)
      fields.esc_messages:help("@i18n(app.modules.settings.activelook_esc_telemetry_help)@")
      fields.esc_status_seconds = number(escStatusPanel, "@i18n(app.modules.settings.activelook_low_fuel_seconds)@", "esc_status_seconds", 3, 30, activeConfig.clampAlertSeconds, "s")
      fields.esc_status_repeats = number(escStatusPanel, "@i18n(app.modules.settings.activelook_low_fuel_repeats)@", "esc_status_repeats", 1, 10, activeConfig.clampLowFuelRepeats, "x")
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
      -- One full-width status line, rather than squeezing protocol + availability
      -- into the value column on the X18. Geometry is resolved only on page open.
      local availabilityLine = escStatusPanel:addLine("")
      local slot = form.getFieldSlots(availabilityLine, {0})[1]
      local width = lcd.getWindowSize()
      local availabilityField = form.addStaticText(availabilityLine,
        {x = 24, y = slot.y, w = width - 40, h = slot.h}, AVAILABILITY.offline, LEFT)
      local connected, armed, lastProtocol, lastAvailability, setupEnabled
      local setupButton
      local function canOpenTelemetry()
        return connected and not armed and lastAvailability == "missing"
      end
      local function openTelemetry()
        if not canOpenTelemetry() then return end
        leaveTo(function()
          local childOpts = {}
          for key, value in pairs(opts) do childOpts[key] = value end
          childOpts.onBack = function() open(opts) end
          assert(loadfile("app/pages/telemetry.lua"))().open(childOpts)
        end, canOpenTelemetry)
      end
      setupButton = form.addButton(escStatusPanel:addLine(""), nil, {
        text = "@i18n(app.modules.settings.activelook_esc_setup)@", press = openTelemetry,
      })
      local function sessionUpdated(snapshot)
        connected, armed = snapshot.connected == true, snapshot.isArmed == true
        local protocol = connected and escStatus.familyName(snapshot.escSignature) or nil
        local availability = escStatus.availability(connected, snapshot.escSignature, snapshot.escStatusWord)
        if protocol ~= lastProtocol or availability ~= lastAvailability then
          local text = AVAILABILITY[availability]
          availabilityField:value(protocol and protocol .. ": " .. text or text)
          lastProtocol, lastAvailability = protocol, availability
        end
        local canSetup = canOpenTelemetry()
        if canSetup ~= setupEnabled then setupButton:enable(canSetup); setupEnabled = canSetup end
      end
      sessionUpdated({})
      local sessionHandler = bus.subscribe("session.update", sessionUpdated)
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
      bindPreview(escStatusPanel, "esc_status")
      bindPreview(lostPanel, "governor_lost")
      bindPreview(linkPanel, "rf_link")
      bindPreview(statusPanel, "governor_status")
      bus.publish("activelook.control", {previewMode = "low_fuel"})
      updateEnabled()
      return function()
        bus.unsubscribe("session.update", sessionHandler)
        availabilityField, setupButton = nil, nil
      end
    end)
end
return {open = open}
