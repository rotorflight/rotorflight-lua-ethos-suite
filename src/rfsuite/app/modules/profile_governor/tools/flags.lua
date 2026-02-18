--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({showProgress = true})

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

local function setNavEnabled(id, enabled)
    local navFields = rfsuite.app and rfsuite.app.formNavigationFields
    local nav = navFields and navFields[id]
    if nav and nav.enable then nav:enable(enabled) end
end

local function setFieldEnabled(index, enabled)
    local fields = rfsuite.app and rfsuite.app.formFields
    local field = fields and fields[index]
    if field and field.enable then field:enable(enabled) end
end

local function wakeup()

    -- we are compromised if we don't have governor mode known
    if rfsuite.session.governorMode == nil then
        pageRuntime.openMenuContext()
        return
    end

    local mspQueue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if activateWakeup ~= true or not (mspQueue and mspQueue.isProcessed and mspQueue:isProcessed()) then
        return
    end

    local activeProfile = rfsuite.session and rfsuite.session.activeProfile
    if activeProfile ~= nil then
        local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
        rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
    end

    -- Enable/disable fields based on firmware/session state.
    local govEnabled = (rfsuite.session.governorMode ~= nil and rfsuite.session.governorMode ~= 0)
    local adcVoltage = (rfsuite.session.batteryConfig ~= nil and rfsuite.session.batteryConfig.voltageMeterSource == 1)

    -- Navigation buttons (if present)
    setNavEnabled("save", govEnabled)
    setNavEnabled("reload", govEnabled)

    -- If governor is disabled in firmware, lock the page.
    if not govEnabled then
        setFieldEnabled(FIELD_FALLBACK_PRECOMP, false)
        setFieldEnabled(FIELD_PID_SPOOLUP, false)
        setFieldEnabled(FIELD_VOLTAGE_COMP, false)
        setFieldEnabled(FIELD_DYN_MIN_THROTTLE, false)
        return
    end

    -- Governor enabled: field availability.
    setFieldEnabled(FIELD_FALLBACK_PRECOMP, true)
    setFieldEnabled(FIELD_PID_SPOOLUP, true)
    setFieldEnabled(FIELD_DYN_MIN_THROTTLE, true)

    -- Voltage compensation requires an ADC voltage source.
    setFieldEnabled(FIELD_VOLTAGE_COMP, adcVoltage)
end

local function event(widget, category, value, x, y)
    return navHandlers.event(widget, category, value)
end

local function onNavMenu()
    return navHandlers.onNavMenu()
end

return {apidata = apidata, title = "@i18n(app.modules.profile_governor.name)@", reboot = false, event = event, onNavMenu = onNavMenu, refreshOnProfileChange = true, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
