--[[
 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local version = rfsuite.version().version
local ethosVersion = rfsuite.config.environment.major .. "." .. rfsuite.config.environment.minor .. "." .. rfsuite.config.environment.revision
local apiVersion = rfsuite.session.apiVersion
local fcVersion = rfsuite.session.fcVersion 
local rfVersion = rfsuite.session.rfVersion
local mspTransport = (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol and rfsuite.tasks.msp.protocol.mspProtocol) or "-"
local closeProgressLoader = true
local simulation

local i18n = rfsuite.i18n.get

local supportedMspVersion = ""
for i, v in ipairs(rfsuite.config.supportedMspApiVersion) do
    if i == 1 then
        supportedMspVersion = v
    else
        supportedMspVersion = supportedMspVersion .. "," .. v
    end
end

if system.getVersion().simulation == true then
    simulation = "ON"
else
    simulation = "OFF"
end

local displayType = 0
local disableType = false
local displayPos
local w, h = lcd.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 300, h = rfsuite.app.radio.navbuttonHeight}


local apidata = {
    api = {
        [1] = nil,
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = i18n("app.modules.info.version"), value = version, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.info.ethos_version"), value = ethosVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.info.rf_version"), value = rfVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.info.fc_version"), value = fcVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.info.msp_version"), value = apiVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.info.msp_transport"), value = string.upper(mspTransport), type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.info.supported_versions"), value = supportedMspVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.info.simulation"), value = simulation, type = displayType, disable = disableType, position = displayPos}
        }
    }
}

local function wakeup()
    if closeProgressLoader == false then
        rfsuite.app.triggers.closeProgressLoader = true
        closeProgressLoader = true
    end    
end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            i18n("app.modules.diagnostics.name"),
            "diagnostics/diagnostics.lua"
        )
        return true
    end
end


local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil,nil,true)
    rfsuite.app.ui.openPage(
        pageIdx,
        i18n("app.modules.diagnostics.name"),
        "diagnostics/diagnostics.lua"
    )
end

return {
    apidata = apidata,
    reboot = false,
    eepromWrite = false,
    minBytes = 0,
    wakeup = wakeup,
    refreshswitch = false,
    simulatorResponse = {},
    onNavMenu = onNavMenu,
    event = event,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = false,
        help = false
    },
    API = {},
}
