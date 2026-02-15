--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_motors/tools/escmfg/" .. folder .. "/init.lua"))()
local simulatorResponse = ESC.simulatorResponse


local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.throttle_protocol)@",     mspapi = 1, apikey = "throttle_protocol",     type = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.telemetry_protocol)@",    mspapi = 1, apikey = "telemetry_protocol",    type = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.led_color)@",             mspapi = 1, apikey = "led_color_index",        type = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_temp_sensor)@",     mspapi = 1, apikey = "motor_temp_sensor",      type = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_temp)@",            mspapi = 1, apikey = "motor_temp"},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.battery_capacity)@",      mspapi = 1, apikey = "battery_capacity"}
        }
    }
}

if rfsuite.session.escDetails and rfsuite.session.escDetails.model then

    local TEST_150A = false

    if string.find(rfsuite.session.escDetails.model, "FLYROTOR 150A") or TEST_150A == true then

        if apidata and apidata.formdata and apidata.formdata.fields then
            table.remove(apidata.formdata.fields, 1)
            table.remove(apidata.formdata.fields, 1)
            table.remove(apidata.formdata.fields, 1)
            table.remove(apidata.formdata.fields, 1)
            table.remove(apidata.formdata.fields, 1)
        end
    end

end

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    postLoad = postLoad,
    simulatorResponse = simulatorResponse,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.other)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
