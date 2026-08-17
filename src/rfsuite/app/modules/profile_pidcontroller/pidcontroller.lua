--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local labels = {}
local fields = {}

local activateWakeup = false

local apidata = {
    api = {
        {id = 1, name = "PID_PROFILE", enableDeltaCache = false, rebuildOnWrite = true},
    },    
    formdata = {
        labels = {
            {t = "Inflight Error Decay", label = 2, inline_size = 13.6},
            {t = "Error limit", label = 4, inline_size = 8.15},
            {t = "HSI Offset limit", label = 5, inline_size = 8.15},
            {t = "I-term relax", label = 6, inline_size = 40.15},
            {t = "Cut-off point", label = 15, inline_size = 8.15}
        },
        fields = {
            {t = "Ground Error Decay", mspapi = 1, apikey = "error_decay_time_ground"}, {t = "Time", inline = 2, label = 2, mspapi = 1, apikey = "error_decay_time_cyclic"}, {t = "Limit", inline = 1, label = 2, mspapi = 1, apikey = "error_decay_limit_cyclic"},
            {t = "R", inline = 3, label = 4, mspapi = 1, apikey = "error_limit_0"}, {t = "P", inline = 2, label = 4, mspapi = 1, apikey = "error_limit_1"}, {t = "Y", inline = 1, label = 4, mspapi = 1, apikey = "error_limit_2"}, {t = "R", inline = 3, label = 5, mspapi = 1, apikey = "offset_limit_0"},
            {t = "P", inline = 2, label = 5, mspapi = 1, apikey = "offset_limit_1"}, {t = "Error rotation", mspapi = 1, apikey = "error_rotation", type = 1, apiversionlte = {12, 0, 8}}, {t = "", inline = 1, label = 6, mspapi = 1, apikey = "iterm_relax_type", type = 1}, {t = "R", inline = 3, label = 15, mspapi = 1, apikey = "iterm_relax_cutoff_0"},
            {t = "P", inline = 2, label = 15, mspapi = 1, apikey = "iterm_relax_cutoff_1"}, {t = "Y", inline = 1, label = 15, mspapi = 1, apikey = "iterm_relax_cutoff_2"}
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

return {apidata = apidata, title = "PID Controller", refreshOnProfileChange = true, reboot = false, eepromWrite = true, labels = labels, fields = fields, postLoad = postLoad, wakeup = wakeup, API = {}}
