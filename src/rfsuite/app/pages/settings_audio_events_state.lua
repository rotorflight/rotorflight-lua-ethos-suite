-- Settings -> Audio -> Events -> State callouts.
--
-- Everything the suite announces when a state changes rather than when a
-- value crosses a threshold: arming flags, governor state, the three profile
-- switches, and the two adjustment callouts. Seven independent booleans with
-- no dependent fields, which is why this page needs no enable rules at all.
--
-- The adjustment callouts were their own expansion panel ("Adjustment
-- callouts", two fields) in the monolithic page. They belong here rather than
-- on a page of their own: they are announced on the same kind of edge as the
-- profile switches -- a control changed -- and the issue this split came from
-- (#2308) asked for fewer, more coherent screens, not for a tile whose only
-- content is two toggles.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/pages/settings_audio_events_common.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.audio_event_state)@"

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    local fields = ctx.fields

    fields.armflags = ctx.addBool("@i18n(app.modules.settings.arming_flags)@", "armflags")
    fields.governor = ctx.addBool("@i18n(app.modules.settings.governor_state)@", "governor")
    fields.pidProfile = ctx.addBool("@i18n(app.modules.settings.pid_profile)@", "pid_profile")
    fields.rateProfile = ctx.addBool("@i18n(app.modules.settings.rate_profile)@", "rate_profile")
    fields.batteryProfile = ctx.addBool("@i18n(app.modules.settings.battery_profile_event)@", "battery_profile")
    fields.adjFunction = ctx.addBool("@i18n(app.modules.settings.adj_function)@", "adj_f")
    fields.adjValue = ctx.addBool("@i18n(app.modules.settings.adj_value)@", "adj_v")
  end)
end

return {open = open}