--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({showProgress = true})

local activateWakeup = false
local governorDisabledMsg = false

local FIELD_F_GAIN = 9
local FIELD_YAW_WEIGHT = 10
local FIELD_CYCLIC_WEIGHT = 11
local FIELD_COLLECTIVE_WEIGHT = 12
local function decodeGovernorFlags(flags)
    local governor_flags_bitmap = {{field = "fc_throttle_curve"}, {field = "tx_precomp_curve"}, {field = "fallback_precomp"}, {field = "voltage_comp"}, {field = "pid_spoolup"}, {field = "hs_adjustment"}, {field = "dyn_min_throttle"}, {field = "autorotation"}, {field = "suspend"}, {field = "bypass"}}

    local decoded = {}
    for bitIndex, info in ipairs(governor_flags_bitmap) do
        local mask = 2 ^ (bitIndex - 1)
        decoded[info.field] = (flags & mask) ~= 0
    end
    return decoded
end

local apidata = {
    api = {[1] = 'GOVERNOR_PROFILE'},
    formdata = {
        labels = {
            {t = "@i18n(app.modules.profile_governor.gains)@", label = 1, inline_size = 8.15}, 
            {t = "@i18n(app.modules.profile_governor.precomp)@", label = 2, inline_size = 8.15}, 
        },
        fields = {
            {t = "@i18n(app.modules.profile_governor.full_headspeed)@", mspapi = 1, apikey = "governor_headspeed", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "@i18n(app.modules.profile_governor.min_throttle)@", mspapi = 1, apikey = "governor_min_throttle", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "@i18n(app.modules.profile_governor.max_throttle)@", mspapi = 1, apikey = "governor_max_throttle", enablefunction = function() return (rfsuite.session.governorMode >= 1) end}, {t = "@i18n(app.modules.profile_governor.fallback_drop)@", mspapi = 1, apikey = "governor_fallback_drop", enablefunction = function() return (rfsuite.session.governorMode >= 1) end},
            {t = "@i18n(app.modules.profile_governor.gain)@", mspapi = 1, apikey = "governor_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "@i18n(app.modules.profile_governor.p)@", inline = 4, label = 1, mspapi = 1, apikey = "governor_p_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "@i18n(app.modules.profile_governor.i)@", inline = 3, label = 1, mspapi = 1, apikey = "governor_i_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "@i18n(app.modules.profile_governor.d)@", inline = 2, label = 1, mspapi = 1, apikey = "governor_d_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "@i18n(app.modules.profile_governor.f)@", inline = 1, label = 1, mspapi = 1, apikey = "governor_f_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "@i18n(app.modules.profile_governor.yaw)@", inline = 3, label = 2, mspapi = 1, apikey = "governor_yaw_weight", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "@i18n(app.modules.profile_governor.cyc)@", inline = 2, label = 2, mspapi = 1, apikey = "governor_cyclic_weight", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "@i18n(app.modules.profile_governor.col)@", inline = 1, label = 2, mspapi = 1, apikey = "governor_collective_weight", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()

     -- we are compromised if we don't have governor mode known
    if rfsuite.session.governorMode == nil then
        pageRuntime.openMenuContext()
        return
    end   

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeProfile = rfsuite.session and rfsuite.session.activeProfile
        if activeProfile ~= nil then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
        if rfsuite.session.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true

                rfsuite.app.formNavigationFields['save']:enable(false)

                rfsuite.app.formNavigationFields['reload']:enable(false)
    
            end
        end

        local flags = rfsuite.tasks.msp.api.apidata.values['GOVERNOR_PROFILE'].governor_flags
        local decodedFlags = decodeGovernorFlags(flags)

        if decodedFlags["tx_precomp_curve"] then
            rfsuite.app.formFields[FIELD_F_GAIN]:enable(false)
            rfsuite.app.formFields[FIELD_YAW_WEIGHT]:enable(false)
            rfsuite.app.formFields[FIELD_CYCLIC_WEIGHT]:enable(false)
            rfsuite.app.formFields[FIELD_COLLECTIVE_WEIGHT]:enable(false)

        else
            rfsuite.app.formFields[FIELD_F_GAIN]:enable(true)
            rfsuite.app.formFields[FIELD_YAW_WEIGHT]:enable(true)
            rfsuite.app.formFields[FIELD_CYCLIC_WEIGHT]:enable(true)
            rfsuite.app.formFields[FIELD_COLLECTIVE_WEIGHT]:enable(true)
        end

    end

end

local function event(widget, category, value, x, y)
    return navHandlers.event(widget, category, value)
end

local function onNavMenu()
    return navHandlers.onNavMenu()
end

return {apidata = apidata, title = "@i18n(app.modules.profile_governor.name)@", reboot = false, event = event, onNavMenu = onNavMenu, refreshOnProfileChange = true, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
