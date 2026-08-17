--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false
local governorDisabledMsg = false

local FIELDS = {
    FULL_HEADSPEED = 1,
    MIN_THROTTLE = 2,
    MAX_THROTTLE = 3,
    GAIN = 4,
    P_GAIN = 5,
    I_GAIN = 6,
    D_GAIN = 7,
    F_GAIN = 8,
    YAW_WEIGHT = 9,
    CYCLIC_WEIGHT = 10,
    COLLECTIVE_WEIGHT = 11,
    TTA_GAIN = 12,
    TTA_LIMIT = 13
}

local apidata = {
    api = {
        {id = 1, name = "GOVERNOR_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
    },    
    formdata = {
        labels = {
            {t = "Gains", label = 1, inline_size = 8.15},
            {t = "Precomp", label = 2, inline_size = 8.15},
            {t = "Tail Torque Assist", label = 3}
        },
        fields = {
            [FIELDS.FULL_HEADSPEED] = {t = "Full headspeed", mspapi = 1, apikey = "governor_headspeed"},
            [FIELDS.MIN_THROTTLE] = {t = "Min throttle", mspapi = 1, apikey = "governor_min_throttle"},
            [FIELDS.MAX_THROTTLE] = {t = "Max throttle", mspapi = 1, apikey = "governor_max_throttle"},
            [FIELDS.GAIN] = {t = "PID master gain", mspapi = 1, apikey = "governor_gain"},
            [FIELDS.P_GAIN] = {t = "P", inline = 4, label = 1, mspapi = 1, apikey = "governor_p_gain"},
            [FIELDS.I_GAIN] = {t = "I", inline = 3, label = 1, mspapi = 1, apikey = "governor_i_gain"},
            [FIELDS.D_GAIN] = {t = "D", inline = 2, label = 1, mspapi = 1, apikey = "governor_d_gain"},
            [FIELDS.F_GAIN] = {t = "FF", inline = 1, label = 1, mspapi = 1, apikey = "governor_f_gain"},
            [FIELDS.YAW_WEIGHT] = {t = "Yaw", inline = 3, label = 2, mspapi = 1, apikey = "governor_yaw_ff_weight"},
            [FIELDS.CYCLIC_WEIGHT] = {t = "Cyc", inline = 2, label = 2, mspapi = 1, apikey = "governor_cyclic_ff_weight"},
            [FIELDS.COLLECTIVE_WEIGHT] = {t = "Col", inline = 1, label = 2, mspapi = 1, apikey = "governor_collective_ff_weight"},
            [FIELDS.TTA_GAIN] = {t = "Gain", inline = 2, label = 3, mspapi = 1, apikey = "governor_tta_gain"},
            [FIELDS.TTA_LIMIT] = {t = "Limit", inline = 1, label = 3, mspapi = 1, apikey = "governor_tta_limit"}
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true

    for id in pairs(FIELDS) do
        local field = rfsuite.app.formFields[FIELDS[id]]
        if field and field.enable then field:enable(false) end
    end
end

local function wakeup()

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeProfile = rfsuite.session and rfsuite.session.activeProfile
        if activeProfile ~= nil then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
        local mode = rfsuite.session.governorMode
        if mode == nil then return end

        local enableLevel1 = (mode >= 1)
        local enableLevel2 = (mode >= 2)

        local function setEnabled(id, enabled)
            local field = rfsuite.app.formFields[id]
            if field and field.enable then field:enable(enabled) end
        end

        setEnabled(FIELDS.FULL_HEADSPEED, enableLevel2)
        setEnabled(FIELDS.MIN_THROTTLE, enableLevel2)
        setEnabled(FIELDS.MAX_THROTTLE, enableLevel1)
        setEnabled(FIELDS.GAIN, enableLevel2)
        setEnabled(FIELDS.P_GAIN, enableLevel2)
        setEnabled(FIELDS.I_GAIN, enableLevel2)
        setEnabled(FIELDS.D_GAIN, enableLevel2)
        setEnabled(FIELDS.F_GAIN, enableLevel2)
        setEnabled(FIELDS.YAW_WEIGHT, enableLevel2)
        setEnabled(FIELDS.CYCLIC_WEIGHT, enableLevel2)
        setEnabled(FIELDS.COLLECTIVE_WEIGHT, enableLevel2)
        setEnabled(FIELDS.TTA_GAIN, enableLevel2)
        setEnabled(FIELDS.TTA_LIMIT, enableLevel2)

        if rfsuite.session.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true

                rfsuite.app.formNavigationFields['save']:enable(false)

                rfsuite.app.formNavigationFields['reload']:enable(false)

            end
        end

    end

end

return {apidata = apidata, title = "Governor", reboot = false, refreshOnProfileChange = true, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
