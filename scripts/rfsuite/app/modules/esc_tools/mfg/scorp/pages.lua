local PageFiles = {}

-- ESC pages.
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.scorp.basic)@", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.scorp.limits)@", script = "esc_protection.lua", image = "limits.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.scorp.advanced)@", script = "esc_advanced.lua", image = "advanced.png"}

return PageFiles
