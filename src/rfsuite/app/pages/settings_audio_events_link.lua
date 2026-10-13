-- Settings -> Audio -> Events -> Link.
--
-- One field: the pair of announcements for the flight controller link going and
-- coming back. The behaviour it switches lives in tasks/audio_events.lua's
-- announceTelemetryLost() and announceTelemetryRecovered() (issue #2311), and it
-- is one switch rather than two because the recovery is gated on the loss: it
-- sounds only for a loss that was announced.
--
-- It is a page of its own rather than a row on State callouts because it is the
-- one event whose announcement depends on the state the model was in *before*
-- the event -- armed at the moment the link went -- and because #2308's split
-- asked for one coherent screen per category, not for a tile whose only content
-- is two toggles.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/pages/settings_audio_events_common.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.link)@"

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    ctx.fields.telemetryLost = ctx.addBool("@i18n(app.modules.settings.telemetry_lost)@", "telemetry_lost")
  end)
end

return {open = open}
