-- Settings -> Audio -> Events -> Model announcement.
--
-- One field: play SD:/audio/<model name>.wav once per connect, if the pilot
-- has recorded one. The behaviour it switches lives in
-- tasks/audio_events.lua's announceCraftName().
--
-- It gets a page of its own rather than joining State callouts because it is
-- the only event on the whole Settings -> Audio -> Events screen whose meaning
-- is not obvious from its label, and burying one such toggle in a list of
-- seven is the failure #2308 was filed about.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/pages/settings_audio_events_common.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.model_announcement)@"

local function open(opts)
  common.openPage(PAGE_TITLE, opts, function(ctx)
    ctx.fields.craftName = ctx.addBool("@i18n(app.modules.settings.model_announcement)@", "craft_name")
  end)
end

return {open = open}