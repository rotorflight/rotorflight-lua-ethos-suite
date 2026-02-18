--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false

local apidata = {
    api = {
        [1] = 'PID_PROFILE'
    },
    formdata = {
        labels = {
            { t = "@i18n(app.modules.profile_autolevel.acro_trainer)@", inline_size = 13.6, label = 1 },
            { t = "@i18n(app.modules.profile_autolevel.angle_mode)@", inline_size = 13.6, label = 2 },
            { t = "@i18n(app.modules.profile_autolevel.horizon_mode)@", inline_size = 13.6, label = 3 }
        },
        fields = {
            { t = "@i18n(app.modules.profile_autolevel.gain)@", inline = 2, label = 1, mspapi = 1, apikey = "trainer_gain" },
            { t = "@i18n(app.modules.profile_autolevel.max)@", inline = 1, label = 1, mspapi = 1, apikey = "trainer_angle_limit" },
            { t = "@i18n(app.modules.profile_autolevel.gain)@", inline = 2, label = 2, mspapi = 1, apikey = "angle_level_strength" },
            { t = "@i18n(app.modules.profile_autolevel.max)@", inline = 1, label = 2, mspapi = 1, apikey = "angle_level_limit" },
            { t = "@i18n(app.modules.profile_autolevel.gain)@", inline = 2, label = 3, mspapi = 1, apikey = "horizon_level_strength" }
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeProfile = rfsuite.session and rfsuite.session.activeProfile
        if activeProfile ~= nil then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
        activateWakeup = false
    end
end

return {apidata = apidata, title = "@i18n(app.modules.profile_autolevel.name)@", refreshOnProfileChange = true, reboot = false, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
