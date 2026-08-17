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
            { t = "Gov-P",      mspapi = 1, apikey = "gov_p"          },
            { t = "Gov-I",      mspapi = 1, apikey = "gov_i"          },
            { t = "Motor Pole Pairs", mspapi = 1, apikey = "motor_pole_pairs" },
            { t = "Main Teeth", mspapi = 1, apikey = "main_teeth"    },
            { t = "Pinion Teeth", mspapi = 1, apikey = "pinion_teeth"  },
            { t = "Stick Zero", mspapi = 1, apikey = "stick_zero_us" },
            { t = "Stick Range", mspapi = 1, apikey = "stick_range_us" }
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {apidata = apidata, eepromWrite = true, reboot = false, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "Esc Programing" .. " / " .. "YGE" .. " / " .. "Other", headerLine = rfsuite.escHeaderLineText}
