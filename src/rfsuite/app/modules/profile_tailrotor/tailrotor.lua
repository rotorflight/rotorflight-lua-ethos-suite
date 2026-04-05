--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false
local governorModeRequested = false
local lastTtaEnabled = nil

local FIELDS = {
    YAW_CW_STOP_GAIN = 1,
    YAW_CCW_STOP_GAIN = 2,
    YAW_PRECOMP_CUTOFF = 3,
    YAW_CYCLIC_FF_GAIN = 4,
    YAW_COLLECTIVE_FF_GAIN = 5,
    YAW_INERTIA_PRECOMP_GAIN = 6,
    YAW_INERTIA_PRECOMP_CUTOFF = 7,
    YAW_COLLECTIVE_DYNAMIC_GAIN = 8,
    YAW_COLLECTIVE_DYNAMIC_DECAY = 9,
    GOVERNOR_TTA_GAIN = 10,
    GOVERNOR_TTA_LIMIT = 11
}

local function setTtaEnabled(enabled)
    if lastTtaEnabled == enabled then return end
    lastTtaEnabled = enabled

    local formFields = rfsuite.app and rfsuite.app.formFields
    if not formFields then return end

    local gainField = formFields[FIELDS.GOVERNOR_TTA_GAIN]
    local limitField = formFields[FIELDS.GOVERNOR_TTA_LIMIT]

    if gainField and gainField.enable then gainField:enable(enabled) end
    if limitField and limitField.enable then limitField:enable(enabled) end
end

local apidata = {
    api = {
        {id = 1, name = "PID_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
        {id = 2, name = "GOVERNOR_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
    },  
    formdata = {
        labels = {
            { t = "@i18n(app.modules.profile_tailrotor.yaw_stop_gain)@", label = 1, inline_size = 13.6 },
            { t = "@i18n(app.modules.profile_tailrotor.inertia_precomp)@", label = 2, inline_size = 13.6, apiversiongte = {12, 0, 8} },
            { t = "@i18n(app.modules.profile_tailrotor.collective_impulse_ff)@", label = 3, inline_size = 13.6, apiversionlte = {12, 0, 7} },
            { t = "@i18n(app.modules.profile_governor.tail_torque_assist)@", label = 4, inline_size = 13.6, apiversiongte = {12, 0, 9} },
        },
        fields = {
            [FIELDS.YAW_CW_STOP_GAIN] = { t = "@i18n(app.modules.profile_tailrotor.cw)@", inline = 2, label = 1, mspapi = 1, apikey = "yaw_cw_stop_gain" },
            [FIELDS.YAW_CCW_STOP_GAIN] = { t = "@i18n(app.modules.profile_tailrotor.ccw)@", inline = 1, label = 1, mspapi = 1, apikey = "yaw_ccw_stop_gain" },
            [FIELDS.YAW_PRECOMP_CUTOFF] = { t = "@i18n(app.modules.profile_tailrotor.precomp_cutoff)@", mspapi = 1, apikey = "yaw_precomp_cutoff" },
            [FIELDS.YAW_CYCLIC_FF_GAIN] = { t = "@i18n(app.modules.profile_tailrotor.cyclic_ff_gain)@", mspapi = 1, apikey = "yaw_cyclic_ff_gain" },
            [FIELDS.YAW_COLLECTIVE_FF_GAIN] = { t = "@i18n(app.modules.profile_tailrotor.collective_ff_gain)@", mspapi = 1, apikey = "yaw_collective_ff_gain" },
            [FIELDS.YAW_INERTIA_PRECOMP_GAIN] = { t = "@i18n(app.modules.profile_tailrotor.gain)@", inline = 2, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_gain", apiversiongte = {12, 0, 8} },
            [FIELDS.YAW_INERTIA_PRECOMP_CUTOFF] = { t = "@i18n(app.modules.profile_tailrotor.cutoff)@", inline = 1, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_cutoff", apiversiongte = {12, 0, 8} },
            [FIELDS.YAW_COLLECTIVE_DYNAMIC_GAIN] = { t = "@i18n(app.modules.profile_tailrotor.gain)@", inline = 2, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_gain", apiversionlte = {12, 0, 7} },
            [FIELDS.YAW_COLLECTIVE_DYNAMIC_DECAY] = { t = "@i18n(app.modules.profile_tailrotor.decay)@", inline = 1, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_decay", apiversionlte = {12, 0, 7} },
            [FIELDS.GOVERNOR_TTA_GAIN] = { t = "@i18n(app.modules.profile_governor.tta_gain)@", inline = 2, label = 4, mspapi = 2, apikey = "governor_tta_gain", apiversiongte = {12, 0, 9} },
            [FIELDS.GOVERNOR_TTA_LIMIT] = { t = "@i18n(app.modules.profile_governor.tta_limit)@", inline = 1, label = 4, mspapi = 2, apikey = "governor_tta_limit", apiversiongte = {12, 0, 9} },
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
    setTtaEnabled((tonumber(rfsuite.session and rfsuite.session.governorMode) or 0) >= 1)
end

local function wakeup()
    local helpers = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers
    if rfsuite.session.governorMode == nil and helpers and helpers.governorMode and not governorModeRequested then
        governorModeRequested = true
        helpers.governorMode(function()
            activateWakeup = true
        end)
    end

    setTtaEnabled((tonumber(rfsuite.session and rfsuite.session.governorMode) or 0) >= 1)

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeProfile = rfsuite.session and rfsuite.session.activeProfile
        if activeProfile ~= nil then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
        activateWakeup = false
    end
end

return {apidata = apidata, title = "@i18n(app.modules.profile_tailrotor.name)@", refreshOnProfileChange = true, reboot = false, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
