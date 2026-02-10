--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false
local session = rfsuite.session

local apidata = {
    api = {
        [1] = 'GOVERNOR_CONFIG'
    },
    formdata = {
        labels = {},
        fields = {
            { t = "@i18n(app.modules.governor.mode)@",                  mspapi = 1, apikey = "gov_mode",                  postEdit = function(self) self.setGovernorMode(self) end, type = 1 },
            { t = "@i18n(app.modules.governor.handover_throttle)@",    mspapi = 1, apikey = "gov_handover_throttle" },
            { t = "@i18n(app.modules.governor.startup_time)@",          mspapi = 1, apikey = "gov_startup_time" },
            { t = "@i18n(app.modules.governor.spoolup_time)@",         mspapi = 1, apikey = "gov_spoolup_time" },
            { t = "@i18n(app.modules.governor.spoolup_min_throttle)@", mspapi = 1, apikey = "gov_spoolup_min_throttle", apiversion = 12.08 },
            { t = "@i18n(app.modules.governor.tracking_time)@",        mspapi = 1, apikey = "gov_tracking_time" },
            { t = "@i18n(app.modules.governor.recovery_time)@",        mspapi = 1, apikey = "gov_recovery_time" }
        }
    }
}

local function disableFields() for i, _ in ipairs(rfsuite.app.formFields) do if type(rfsuite.app.formFields[i]) == "userdata" then if i ~= 1 and rfsuite.app.formFields[i] then rfsuite.app.formFields[i]:enable(false) end end end end

local function enableFields() for i, _ in ipairs(rfsuite.app.formFields) do if type(rfsuite.app.formFields[i]) == "userdata" then if i ~= 1 and rfsuite.app.formFields[i] then rfsuite.app.formFields[i]:enable(true) end end end end

local function setGovernorMode(self)
    local currentIndex = math.floor(rfsuite.app.Page.apidata.formdata.fields[1].value)
    session.governorMode = currentIndex
    rfsuite.utils.log("Governor mode set to: " .. currentIndex, "info")
    if currentIndex == 0 then
        disableFields()
    else
        enableFields()
    end
end

local function postLoad(self)
    enableWakeup = true
end

local function postSave(self)

    if session.governorMode ~= rfsuite.app.Page.apidata.formdata.fields[1].value then
        session.governorMode = rfsuite.app.Page.apidata.formdata.fields[1].value
        rfsuite.utils.log("Governor mode: " .. session.governorMode, "info")
    end
    return payload
end

local function wakeup(self)
    if not enableWakeup then return end


    if session.governorMode == nil then
        if tasks and tasks.msp and tasks.msp.helpers then
            tasks.msp.helpers.governorMode(function(governorMode)
                utils.log("Received governor mode: " .. tostring(governorMode), "info")
            end)
        end
    else 
        setGovernorMode(self)
        rfsuite.app.triggers.closeProgressLoader = true
    end    

end


return {apidata = apidata, reboot = true, eepromWrite = true, labels = labels, setGovernorMode = setGovernorMode, fields = fields, postLoad = postLoad, postSave = postSave, wakeup = wakeup}
