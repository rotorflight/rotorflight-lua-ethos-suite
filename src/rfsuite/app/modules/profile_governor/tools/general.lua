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
local apidata

local function getApiEntryName(entry)
    if type(entry) == "table" then return entry.name end
    return entry
end

local function getGovernorFlags()
    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
    if not values then return nil end

    local apiName = getApiEntryName(apidata and apidata.api and apidata.api[1]) or "GOVERNOR_PROFILE"
    local governorProfile = values[apiName] or values["GOVERNOR_PROFILE"]
    if governorProfile and governorProfile.governor_flags ~= nil then
        return tonumber(governorProfile.governor_flags) or governorProfile.governor_flags
    end
    return nil
end

-- Constant bit order, and a reused decode buffer. decodeGovernorFlags runs on
-- every wakeup tick; it previously built an 11-table bitmap plus a result table
-- each time. The buffer never escapes the calling tick.
local GOVERNOR_FLAG_FIELDS = {
    "fc_throttle_curve", "tx_precomp_curve", "fallback_precomp", "voltage_comp", "pid_spoolup",
    "hs_adjustment", "dyn_min_throttle", "autorotation", "suspend", "bypass"
}
local decodedFlagsBuf = {}

local function decodeGovernorFlags(flags)
    for bitIndex = 1, #GOVERNOR_FLAG_FIELDS do
        decodedFlagsBuf[GOVERNOR_FLAG_FIELDS[bitIndex]] = (flags & (1 << (bitIndex - 1))) ~= 0
    end
    return decodedFlagsBuf
end

-- app.formFields[i] is a bare {} when a field fails its enablefunction (see
-- ui.lua: `valid` folds in enablefunction(), and the else branch stores {}).
-- Every field this page toggles is gated on governorMode >= 2, so on an FC in
-- governor mode 0 or 1 the unguarded :enable() below raised
-- "attempt to call a nil value (method 'enable')" on every wakeup tick.
local function setFieldEnabled(idx, enabled)
    local f = rfsuite.app.formFields[idx]
    if f and f.enable then f:enable(enabled) end
end

apidata = {
    api = {
        {id = 1, name = "GOVERNOR_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
    },    
    formdata = {
        labels = {
            {t = "Gains", label = 1, inline_size = 8.15}, 
            {t = "Precomp", label = 2, inline_size = 8.15}, 
        },
        fields = {
            {t = "Full headspeed", mspapi = 1, apikey = "governor_headspeed", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "Min throttle", mspapi = 1, apikey = "governor_min_throttle", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "Max throttle", mspapi = 1, apikey = "governor_max_throttle", enablefunction = function() return (rfsuite.session.governorMode >= 1) end}, {t = "Thr. Fallback drop", mspapi = 1, apikey = "governor_fallback_drop", enablefunction = function() return (rfsuite.session.governorMode >= 1) end},
            {t = "PID master gain", mspapi = 1, apikey = "governor_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "P", inline = 4, label = 1, mspapi = 1, apikey = "governor_p_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "I", inline = 3, label = 1, mspapi = 1, apikey = "governor_i_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "D", inline = 2, label = 1, mspapi = 1, apikey = "governor_d_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "FF", inline = 1, label = 1, mspapi = 1, apikey = "governor_f_gain", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "Yaw", inline = 3, label = 2, mspapi = 1, apikey = "governor_yaw_weight", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
            {t = "Cyc", inline = 2, label = 2, mspapi = 1, apikey = "governor_cyclic_weight", enablefunction = function() return (rfsuite.session.governorMode >= 2) end}, {t = "Col", inline = 1, label = 2, mspapi = 1, apikey = "governor_collective_weight", enablefunction = function() return (rfsuite.session.governorMode >= 2) end},
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

        local flags = getGovernorFlags()
        if flags == nil then return end
        local decodedFlags = decodeGovernorFlags(flags)

        local enabled = not decodedFlags["tx_precomp_curve"]
        setFieldEnabled(FIELD_F_GAIN, enabled)
        setFieldEnabled(FIELD_YAW_WEIGHT, enabled)
        setFieldEnabled(FIELD_CYCLIC_WEIGHT, enabled)
        setFieldEnabled(FIELD_COLLECTIVE_WEIGHT, enabled)

    end

end

local function event(widget, category, value, x, y)
    return navHandlers.event(widget, category, value)
end

local function onNavMenu()
    return navHandlers.onNavMenu()
end

return {apidata = apidata, title = "Governor", reboot = false, event = event, onNavMenu = onNavMenu, refreshOnProfileChange = true, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
