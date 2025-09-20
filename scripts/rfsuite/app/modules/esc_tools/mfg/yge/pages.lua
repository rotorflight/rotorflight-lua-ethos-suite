local PageFiles = {}

-- ESC pages.
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.yge.basic)@", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.yge.advanced)@", script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.yge.other)@", script = "esc_other.lua", image = "other.png"}
-- PageFiles[#PageFiles + 1] = { title = "ESC Debug", script = "esc_debug.lua" }
-- PageFiles[#PageFiles + 1] = { title = "ESC Debug Frame", script = "esc_debug2.lua" }

return PageFiles
