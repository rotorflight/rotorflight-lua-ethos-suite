local PageFiles = {}
local i18n = rfsuite.i18n.get

-- ESC pages.
PageFiles[#PageFiles + 1] = {title = i18n("app.modules.esc_tools.mfg.hw5.basic"), script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = i18n("app.modules.esc_tools.mfg.hw5.advanced"), script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = i18n("app.modules.esc_tools.mfg.hw5.other"), script = "esc_other.lua", image = "other.png"}
-- PageFiles[#PageFiles + 1] = { title = "ESC Debug", script = "esc_debug.lua" }

return PageFiles
