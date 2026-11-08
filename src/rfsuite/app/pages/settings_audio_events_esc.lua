-- Settings -> Audio -> Events -> ESC temperature.
--
-- Two fields: whether to call out an over-temperature ESC, and the threshold
-- in degrees. Both panels that used to hold this (the alert toggle and its
-- threshold) are on one page now, and the threshold is greyed until the alert
-- is on -- same rule the monolithic page had, kept so a pilot who turns the
-- alert off cannot leave a stale threshold looking configured.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/pages/settings_audio_events_common.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.esc_temperature)@"

-- The threshold is stored in Celsius (the flight controller's ESC temperature is compared
-- with it as it is). On a radio set to Fahrenheit it is shown and typed in Fahrenheit,
-- the way the ActiveLook ESC limit is (#2662).
local function celsiusToFahrenheit(celsius) return celsius * 1.8 + 32 end
local function fahrenheitToCelsius(fahrenheit) return (fahrenheit - 32) / 1.8 end

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    local fields = ctx.fields
    local fahrenheit = ctx.temperatureUnit() == 1

    local function updateFields()
      ctx.setEnabled(fields.escTempThreshold, ctx.get("temp_esc") == true)
      ctx.setEnabled(fields.escTempRepeats, ctx.get("temp_esc") == true)
      ctx.setEnabled(fields.escTempHaptic, ctx.get("temp_esc") == true)
    end

    fields.tempEsc = ctx.addBool("@i18n(app.modules.settings.esc_temperature)@", "temp_esc", updateFields)
    fields.escTempThreshold = ctx.addNumber("@i18n(app.modules.settings.esc_threshold)@", "escalertvalue", {
      min = fahrenheit and 140 or 60,
      max = fahrenheit and 572 or 300,
      default = 90,
      suffix = fahrenheit and "°F" or "°C",
      toShown = fahrenheit and celsiusToFahrenheit or nil,
      toStored = fahrenheit and fahrenheitToCelsius or nil,
    })
    fields.escTempRepeats = ctx.addNumber("@i18n(app.modules.settings.alert_max_repeats)@", "temp_esc_repeats",
      {min = 0, max = 10, default = 0, suffix = "x"})
    fields.escTempHaptic = ctx.addBool("@i18n(app.modules.settings.alert_vibrate)@", "temp_esc_haptic")

    updateFields()
  end)
end

return {open = open}