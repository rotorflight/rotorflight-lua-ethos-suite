--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false
local currentProfileChecked = false

local apidata = {
    api = {[1] = "PID_PROFILE",
           [2] = "GOVERNOR_PROFILE"},
    formdata = {
        labels = {
            {t = "@i18n(app.modules.profile_tailrotor.collective_impulse_ff)@", label = 3, inline_size = 13.6, apiversionlte = 12.07},
            {t = "@i18n(app.modules.profile_tailrotor.yaw_stop_gain)@", label = 1, inline_size = 13.6},
            {t = "@i18n(app.modules.profile_governor.tail_torque_assist)@", label = 4, inline_size = 13.6}
        },
        fields = {
            {t = "@i18n(app.modules.profile_tailrotor.cyclic_ff_gain)@", mspapi = 1, apikey = "yaw_cyclic_ff_gain"},
            {t = "@i18n(app.modules.profile_tailrotor.collective_ff_gain)@", mspapi = 1, apikey = "yaw_collective_ff_gain"},
            {t = "@i18n(app.modules.profile_tailrotor.cw)@", inline = 2, label = 1, mspapi = 1, apikey = "yaw_cw_stop_gain"},
            {t = "@i18n(app.modules.profile_tailrotor.ccw)@", inline = 1, label = 1, mspapi = 1, apikey = "yaw_ccw_stop_gain"},
            {t = "@i18n(app.modules.profile_governor.tta_gain)@", inline = 2, label = 4, mspapi = 2, apikey = "governor_tta_gain", enablefunction = function() return (rfsuite.session.governorMode and rfsuite.session.governorMode >= 2) end}, 
            {t = "@i18n(app.modules.profile_governor.tta_limit)@", inline = 1, label = 4, mspapi = 2, apikey = "governor_tta_limit", enablefunction = function() return (rfsuite.session.governorMode and rfsuite.session.governorMode >= 2) end}
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end



local function wakeup()

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        if rfsuite.session.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
            currentProfileChecked = true
        end
    end


    if rfsuite.session.governorMode == nil then
        if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
            rfsuite.tasks.msp.helpers.governorMode(function(governorMode)
                rfsuite.utils.log("Received governor mode: " .. tostring(governorMode), "info")
                rfsuite.app.triggerReloadFull = true
            end)
        end
    end    

end

return {apidata = apidata, title = "@i18n(app.modules.profile_tailrotor.name)@", refreshOnProfileChange = true, reboot = false, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
