-- Settings -> Audio -> Events -> FC status.
--
-- The four callouts that follow a decoded System Status / System Config word
-- from the flight controller rather than a value crossing a threshold: gyro
-- overflow, GPS not responding, blackbox full, and the control-limit warning.
--
-- They keep the panel of their own that PR #2488 gave them in the monolithic
-- page, now as a page of their own. Two reasons not to fold them into
-- State callouts: #2488 drew the boundary deliberately, and these are the only
-- events on this screen that need a live FC (MSP API 12.10+) -- which is the
-- one thing a pilot needs to be able to see at a glance rather than infer from
-- a list.
--
-- The settings themselves are lib/system_alerts.lua's rules, reached through
-- tasks/audio_events.lua's announceSystemAlerts(); this page only switches which
-- rules speak.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/pages/settings_audio_events_common.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.status_alerts)@"

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    local fields = ctx.fields

    -- status_saturation ships off (DEFAULTS.events.status_saturation = false,
    -- "control limit" can be chatty in 3D flight) while the other three ship on.
    -- Nothing here gates another field, so there are no enable rules.
    fields.statusGyro = ctx.addBool("@i18n(app.modules.settings.status_gyro)@", "status_gyro")
    fields.statusGps = ctx.addBool("@i18n(app.modules.settings.status_gps)@", "status_gps")
    fields.statusBlackbox = ctx.addBool("@i18n(app.modules.settings.status_blackbox)@", "status_blackbox")
    fields.statusSaturation = ctx.addBool("@i18n(app.modules.settings.status_saturation)@", "status_saturation")
  end)
end

return {open = open}