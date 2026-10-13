-- Settings -> Audio -> Events -> Fuel.
--
-- The SmartFuel callout block: the master toggle, the callout cadence, how
-- often a standing low value repeats, and the haptic counterpart. Four
-- fields, and the three below the toggle are all gated by it.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/pages/settings_audio_events_common.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.fuel)@"

local FUEL_CHOICES = {
  {"@i18n(app.modules.settings.fuel_callout_default)@", 0},
  {"@i18n(app.modules.settings.fuel_callout_5)@", 5},
  {"@i18n(app.modules.settings.fuel_callout_10)@", 10},
  {"@i18n(app.modules.settings.fuel_callout_20)@", 20},
  {"@i18n(app.modules.settings.fuel_callout_25)@", 25},
  {"@i18n(app.modules.settings.fuel_callout_50)@", 50},
}

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    local fields = ctx.fields

    local function updateFields()
      local enabled = ctx.get("smartfuel") == true
      ctx.setEnabled(fields.smartfuelcallout, enabled)
      ctx.setEnabled(fields.smartfuelrepeats, enabled)
      ctx.setEnabled(fields.smartfuelhaptic, enabled)
    end

    fields.smartfuel = ctx.addBool("@i18n(app.modules.settings.fuel)@", "smartfuel", updateFields)
    fields.smartfuelcallout = ctx.addChoice("@i18n(app.modules.settings.fuel_callout_percent)@",
      "smartfuelcallout", FUEL_CHOICES, {default = 10})
    fields.smartfuelrepeats = ctx.addNumber("@i18n(app.modules.settings.fuel_repeats_below)@", "smartfuelrepeats",
      {min = 1, max = 10, default = 1, suffix = "x"})
    fields.smartfuelhaptic = ctx.addBool("@i18n(app.modules.settings.fuel_haptic_below)@", "smartfuelhaptic")

    updateFields()
  end)
end

return {open = open}