local PageFiles = {}


-- ESC pages.
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.omp.basic)@", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.omp.advanced)@", script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.omp.governor)@", script = "esc_governor.lua", image = "other.png"}

return PageFiles
