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

-- What the low-voltage callout speaks once it fires (issue #2309). Values are
-- stored as numbers because the store holds scalars; 0 keeps the alert-only
-- tone the suite had before this option existed.
local VOLTAGE_CALLOUT_CHOICES = {
  {"@i18n(app.modules.settings.voltage_callout_none)@", 0},
  {"@i18n(app.modules.settings.voltage_callout_pack)@", 1},
  {"@i18n(app.modules.settings.voltage_callout_cell)@", 2},
}

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    local fields = ctx.fields

    local function updateFields()
      local voltageOn = ctx.get("voltage") == true
      ctx.setEnabled(fields.voltageCallout, voltageOn)
      ctx.setEnabled(fields.voltageHold, voltageOn)
      ctx.setEnabled(fields.voltageRepeat, voltageOn)
      ctx.setEnabled(fields.becVoltageThreshold, ctx.get("bec_voltage") == true)
      ctx.setEnabled(fields.rxVoltageThreshold, ctx.get("rx_voltage") == true)
    end

    fields.voltage = ctx.addBool("@i18n(app.modules.settings.low_voltage_alert)@", "voltage", updateFields)
    fields.voltageCallout = ctx.addChoice("@i18n(app.modules.settings.voltage_callout)@",
      "voltage_callout", VOLTAGE_CALLOUT_CHOICES, {default = 0})
    fields.voltageHold = ctx.addNumber("@i18n(app.modules.settings.voltage_hold)@", "voltage_hold",
      {min = 0, max = 100, default = 2.0, scale = 10, decimals = 1, suffix = "s"})
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