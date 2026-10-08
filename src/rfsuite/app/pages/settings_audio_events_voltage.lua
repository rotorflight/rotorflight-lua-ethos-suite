-- Settings -> Audio -> Events -> Voltage.
--
-- One category of app/pages/settings_audio_events.lua as it stood before
-- issue #2308: the pack voltage alert with its repeat interval, plus the BEC
-- and RX alerts with their thresholds. The three used to sit in two expansion
-- panels on the one long form; they share a page here because they are all
-- "this rail has dropped below X" and each threshold belongs to the toggle
-- above it.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/pages/settings_audio_events_common.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.voltage)@"

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    local fields = ctx.fields

    local function updateFields()
      ctx.setEnabled(fields.voltageRepeat, ctx.get("voltage") == true)
      ctx.setEnabled(fields.becVoltageThreshold, ctx.get("bec_voltage") == true)
      ctx.setEnabled(fields.rxVoltageThreshold, ctx.get("rx_voltage") == true)
    end

    fields.voltage = ctx.addBool("@i18n(app.modules.settings.low_voltage_alert)@", "voltage", updateFields)
    fields.voltageRepeat = ctx.addNumber("@i18n(app.modules.settings.alert_repeat_interval)@", "voltage_repeat_interval",
      {min = 5, max = 120, default = 10, suffix = "s"})

    fields.becVoltage = ctx.addBool("@i18n(app.modules.settings.bec_voltage_alert)@", "bec_voltage", updateFields)
    fields.becVoltageThreshold = ctx.addNumber("@i18n(app.modules.settings.bec_voltage_threshold)@", "becalertvalue",
      {min = 30, max = 150, default = 6.5, scale = 10, decimals = 1, suffix = "V"})

    fields.rxVoltage = ctx.addBool("@i18n(app.modules.settings.rx_voltage_alert)@", "rx_voltage", updateFields)
    fields.rxVoltageThreshold = ctx.addNumber("@i18n(app.modules.settings.rx_voltage_threshold)@", "rxalertvalue",
      {min = 30, max = 150, default = 7.4, scale = 10, decimals = 1, suffix = "V"})

    -- Runs once here and again on every toggle change, so the thresholds are
    -- greyed from the first frame rather than after the pilot touches the
    -- alert above them.
    updateFields()
  end)
end

return {open = open}