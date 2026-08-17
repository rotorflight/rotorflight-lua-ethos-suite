--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()
local hw5Profile = assert(loadfile("app/modules/esc_tools/tools/escmfg/hw5/profile.lua"))()

local folder = "hw5"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_HW5"
    },
    formdata = {
        labels = {
            {t = "ESC",    label = "esc1",    inline_size = 40.6},
            {t = "",                                              label = "esc2",    inline_size = 40.6},
            {t = "",                                              label = "esc3",    inline_size = 40.6},
            {t = "Limits",  label = "limits1", inline_size = 40.6},
            {t = "",                                              label = "limits2", inline_size = 40.6},
            {t = "",                                              label = "limits3", inline_size = 40.6}
        },
        fields = {
            {t = "Flight Mode",    inline = 1, label = "esc1",    type = 1, mspapi = 1, apikey = "flight_mode"},
            {t = "Rotation",        inline = 1, label = "esc2",    type = 1, mspapi = 1, apikey = "rotation"},
            {t = "BEC Voltage",     inline = 1, label = "esc3",    type = 1, mspapi = 1, apikey = "bec_voltage"},
            {t = "LiPo Cell Count", inline = 1, label = "limits1", type = 1, mspapi = 1, apikey = "lipo_cell_count"},
            {t = "Volt Cutoff Type", inline = 1, label = "limits2", type = 1, mspapi = 1, apikey = "volt_cutoff_type"},
            {t = "Cutoff Voltage",  inline = 1, label = "limits3", type = 1, mspapi = 1, apikey = "cutoff_voltage"}
        }
    }
}

hw5Profile.configurePage(apidata, "basic")

local function postLoad()
    hw5Profile.postLoad("basic")
    rfsuite.app.triggers.closeProgressLoader = true
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {apidata = apidata, eepromWrite = true, reboot = false, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "Esc Programing" .. " / " .. "Hobbywing V5" .. " / " .. "Basic", headerLine = rfsuite.escHeaderLineText}
