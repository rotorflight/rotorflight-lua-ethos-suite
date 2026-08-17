--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false

local apidata = {
    api = {
        {id = 1, name = "PID_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
    },  
    formdata = {
        labels = {
            { t = "Collective Pitch Compensation", t2 = "Col. Pitch Compensation", label = 1, inline_size = 40.15 },
            { t = "Cyclic Cross coupling", label = 2, inline_size = 40.15 },
            { t = "", label = 3, inline_size = 40.15 },
            { t = "", label = 4, inline_size = 40.15 }
        },
        fields = {
            { t = "", inline = 1, label = 1, mspapi = 1, apikey = "pitch_collective_ff_gain" },
            { t = "Gain", inline = 1, label = 2, mspapi = 1, apikey = "cyclic_cross_coupling_gain" },
            { t = "Ratio", inline = 1, label = 3, mspapi = 1, apikey = "cyclic_cross_coupling_ratio" },
            { t = "Cutoff", inline = 1, label = 4, mspapi = 1, apikey = "cyclic_cross_coupling_cutoff" }
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

return {apidata = apidata, title = "Main Rotor", refreshOnProfileChange = true, reboot = false, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, API = {}}
