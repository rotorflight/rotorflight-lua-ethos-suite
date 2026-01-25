--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false
local governorDisabledMsg = false

local FIELD_FALLBACK_PRECOMP = 1
local FIELD_PID_SPOOLUP = 2
local FIELD_VOLTAGE_COMP = 3
local FIELD_DYN_MIN_THROTTLE = 4


local apidata = {
    api = {[1] = 'GOVERNOR_PROFILE'},
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.profile_governor.fallback_precomp)@", mspapi = 1, apikey = "governor_flags->fallback_precomp", type = 1},
            {t = "@i18n(app.modules.profile_governor.pid_spoolup)@", mspapi = 1, apikey = "governor_flags->pid_spoolup", type = 1}, 
            {t = "@i18n(app.modules.profile_governor.voltage_comp)@", mspapi = 1, apikey = "governor_flags->voltage_comp", type = 1}, 
            {t = "@i18n(app.modules.profile_governor.dyn_min_throttle)@", mspapi = 1, apikey = "governor_flags->dyn_min_throttle", type = 1},
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

        -- Enable/disable fields based on firmware/session state.
        local govEnabled = (rfsuite.session.governorMode ~= nil and rfsuite.session.governorMode ~= 0)
        local adcVoltage = (rfsuite.session.batteryConfig ~= nil and rfsuite.session.batteryConfig.voltageMeterSource == 1)

        -- Navigation buttons (if present)
        if rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields['save'] then
            rfsuite.app.formNavigationFields['save']:enable(govEnabled)
        end
        if rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields['reload'] then
            rfsuite.app.formNavigationFields['reload']:enable(govEnabled)
        end

        -- If governor is disabled in firmware, lock the page and show the hint once.
        if not govEnabled then
            if not governorDisabledMsg then
                governorDisabledMsg = true
                if rfsuite.app.formLines then
                    rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("@i18n(app.modules.profile_governor.disabled_message)@")
                end
            end
            if rfsuite.app.formFields then
                rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(false)
                rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(false)
                rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(false)
                rfsuite.app.formFields[FIELD_DYN_MIN_THROTTLE]:enable(false)
            end
            return
        end

        -- Governor enabled: field availability
        if rfsuite.app.formFields then
            rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(true)
            rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(true)
            rfsuite.app.formFields[FIELD_DYN_MIN_THROTTLE]:enable(true)

            -- Voltage compensation requires an ADC voltage source.
            rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(adcVoltage)
        end
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
