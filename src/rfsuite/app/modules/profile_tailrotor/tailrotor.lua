--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false

local apidata = {
    api = {
        [1] = "PID_PROFILE",
    },
    formdata = {
        labels = {
            { t = "@i18n(app.modules.profile_tailrotor.inertia_precomp)@", label = 2, inline_size = 13.6, apiversiongte = {12, 0, 8} },
            { t = "@i18n(app.modules.profile_tailrotor.collective_impulse_ff)@", label = 3, inline_size = 13.6, apiversionlte = {12, 0, 7} },
        },
        fields = {
            { t = "@i18n(app.modules.profile_tailrotor.precomp_cutoff)@",      mspapi = 1, apikey = "yaw_precomp_cutoff" },
            { t = "@i18n(app.modules.profile_tailrotor.gain)@",                inline = 2, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_gain",     apiversiongte = {12, 0, 8} },
            { t = "@i18n(app.modules.profile_tailrotor.cutoff)@",              inline = 1, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_cutoff", apiversiongte = {12, 0, 8} },
            { t = "@i18n(app.modules.profile_tailrotor.gain)@",                inline = 2, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_gain", apiversionlte = {12, 0, 7} },
            { t = "@i18n(app.modules.profile_tailrotor.decay)@",               inline = 1, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_decay", apiversionlte = {12, 0, 7} }
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()

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
