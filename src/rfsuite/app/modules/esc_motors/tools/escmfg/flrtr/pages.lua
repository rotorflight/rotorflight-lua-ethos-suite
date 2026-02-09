--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local PageFiles = {}

local function disablebutton(pidx, param)

    if param <= 46 and pidx == 4 then return true end

    return false
end

PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.flrtr.basic)@", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.flrtr.advanced)@", script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.flrtr.governor)@", script = "esc_governor.lua", image = "governor.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.flrtr.other)@", script = "esc_other.lua", image = "other.png", disablebutton = function(param) return disablebutton(#PageFiles, param) end, mspversion = 12.08}

return PageFiles
