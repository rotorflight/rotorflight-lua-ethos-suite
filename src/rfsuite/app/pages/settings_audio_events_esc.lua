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

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    local fields = ctx.fields

    local function updateFields()
      ctx.setEnabled(fields.escTempThreshold, ctx.get("temp_esc") == true)
    end

    fields.tempEsc = ctx.addBool("@i18n(app.modules.settings.esc_temperature)@", "temp_esc", updateFields)
    fields.escTempThreshold = ctx.addNumber("@i18n(app.modules.settings.esc_threshold)@", "escalertvalue",
      {min = 60, max = 300, default = 90, suffix = "deg"})

    updateFields()
  end)
end

return {open = open}