--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false
local governorDisabledMsg = false

local FIELD_TX_PRECOMP_CURVE = 1
local FIELD_HS_ADJUSTMENT = 2
local FIELD_FALLBACK_PRECOMP = 3
local FIELD_PID_SPOOLUP = 4
local FIELD_VOLTAGE_COMP = 5
local FIELD_DYN_MIN_THROTTLE = 6
local FIELD_AUTOROTATION = 7
local FIELD_SUSPEND = 8
local FIELD_BYPASS = 9

local apidata = {
    api = {[1] = 'GOVERNOR_PROFILE'},
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.profile_governor.tx_precomp_curve)@", mspapi = 1, apikey = "governor_flags->tx_precomp_curve", type = 4}, {t = "@i18n(app.modules.profile_governor.hs_adjustment)@", mspapi = 1, apikey = "governor_flags->hs_adjustment", type = 4},
            {t = "@i18n(app.modules.profile_governor.fallback_precomp)@", mspapi = 1, apikey = "governor_flags->fallback_precomp", type = 4}, {t = "@i18n(app.modules.profile_governor.pid_spoolup)@", mspapi = 1, apikey = "governor_flags->pid_spoolup", type = 4},
            {t = "@i18n(app.modules.profile_governor.voltage_comp)@", mspapi = 1, apikey = "governor_flags->voltage_comp", type = 4}, {t = "@i18n(app.modules.profile_governor.dyn_min_throttle)@", mspapi = 1, apikey = "governor_flags->dyn_min_throttle", type = 4},
            {t = "@i18n(app.modules.profile_governor.autorotation)@", mspapi = 1, apikey = "governor_flags->autorotation", type = 4}, {t = "@i18n(app.modules.profile_governor.suspend)@", mspapi = 1, apikey = "governor_flags->suspend", type = 4},
            {t = "@i18n(app.modules.profile_governor.bypass)@", mspapi = 1, apikey = "governor_flags->bypass", type = 4}

        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then

        if rfsuite.session.activeProfile ~= nil then rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " / " .. "@i18n(app.modules.governor.menu_flags)@" .. " #" .. rfsuite.session.activeProfile) end

        if rfsuite.session.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true
                rfsuite.app.formNavigationFields['save']:enable(false)
                rfsuite.app.formNavigationFields['reload']:enable(false)
                rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("@i18n(app.modules.profile_governor.disabled_message)@")
            end
        end

        local bypass = (rfsuite.app.Page.apidata.formdata.fields[FIELD_BYPASS].value == 1)
        local txPrecomp = (rfsuite.app.Page.apidata.formdata.fields[FIELD_TX_PRECOMP_CURVE].value == 1)
        local pidSpoolup = (rfsuite.app.Page.apidata.formdata.fields[FIELD_PID_SPOOLUP].value == 1)
        local adcVoltage = (rfsuite.session.batteryConfig.voltageMeterSource == 1)

        if bypass then
            rfsuite.app.formFields[FIELD_TX_PRECOMP_CURVE]:enable(false)
            rfsuite.app.formFields[FIELD_HS_ADJUSTMENT]:enable(false)
            rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(false)
            rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(false)
            rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(false)
            rfsuite.app.formFields[FIELD_DYN_MIN_THROTTLE]:enable(false)
            rfsuite.app.formFields[FIELD_AUTOROTATION]:enable(false)
            rfsuite.app.formFields[FIELD_SUSPEND]:enable(false)
            return
        end

        rfsuite.app.formFields[FIELD_TX_PRECOMP_CURVE]:enable(true)
        rfsuite.app.formFields[FIELD_HS_ADJUSTMENT]:enable(true)
        rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(true)
        rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(true)
        rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(true)
        rfsuite.app.formFields[FIELD_DYN_MIN_THROTTLE]:enable(true)
        rfsuite.app.formFields[FIELD_AUTOROTATION]:enable(true)
        rfsuite.app.formFields[FIELD_SUSPEND]:enable(true)

        rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(adcVoltage)

        if txPrecomp then
            rfsuite.app.formFields[FIELD_HS_ADJUSTMENT]:enable(false)
            rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(false)
            rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(false)
        end

        if (not txPrecomp) and pidSpoolup then rfsuite.app.formFields[FIELD_TX_PRECOMP_CURVE]:enable(false) end
    end
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pidx, title, "profile_governor/governor.lua")
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(pidx, title, "profile_governor/governor.lua")
    return true
end

return {apidata = apidata, title = "@i18n(app.modules.profile_governor.name)@", reboot = false, event = event, onNavMenu = onNavMenu, refreshOnProfileChange = true, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
