local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local modePage = requireModule("app/pages/settings_activelook_mode.lua")
return modePage.create("preflight", "@i18n(app.modules.settings.activelook_preflight)@")
