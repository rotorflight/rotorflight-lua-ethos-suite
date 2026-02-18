--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "yge"


local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_YGE"
    },
    formdata = {
        labels = {},
        fields = {
            { t = "@i18n(app.modules.esc_tools.mfg.yge.gov_p)@",      mspapi = 1, apikey = "gov_p"          },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.gov_i)@",      mspapi = 1, apikey = "gov_i"          },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.motor_pole_pairs)@", mspapi = 1, apikey = "motor_pole_pairs" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.main_teeth)@", mspapi = 1, apikey = "main_teeth"    },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.pinion_teeth)@", mspapi = 1, apikey = "pinion_teeth"  },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.stick_zero_us)@", mspapi = 1, apikey = "stick_zero_us" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.stick_range_us)@", mspapi = 1, apikey = "stick_range_us" }
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.yge.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.yge.other)@", headerLine = rfsuite.escHeaderLineText}
