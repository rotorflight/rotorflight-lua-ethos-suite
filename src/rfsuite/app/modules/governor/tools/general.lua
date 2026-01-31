--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --
 
local rfsuite = require("rfsuite")

local enableWakeup = false
local formFields = rfsuite.app.formFields

local FIELDS = {
    ["GOVERNOR_MODE"] = 1,
    ["GOVERNOR_THROTTLE_TYPE"] = 2,
    ["GOVERNOR_IDLE_THROTTLE"] = 3,
    ["GOVERNOR_AUTO_THROTTLE"] = 4,
    ["GOV_HANDOVER_THROTTLE"] = 5,
    ["GOV_THROTTLE_HOLD_TIMEOUT"] = 6,
    ["GOV_AUTO_TIMEOUT"] = 7,
}

local apidata = {
    api = {[1] = 'GOVERNOR_CONFIG'},
    formdata = {
        labels = {},
        fields = {
            [FIELDS["GOVERNOR_MODE"]] = {t = "@i18n(app.modules.governor.mode)@", mspapi = 1, apikey = "gov_mode", xpostEdit = function(self) self.setGovernorMode(self) end, type = 1}, 
            [FIELDS["GOVERNOR_THROTTLE_TYPE"]] = {t = "@i18n(app.modules.governor.throttle_type)@", mspapi = 1, apikey = "gov_throttle_type", type = 1}, 
            [FIELDS["GOVERNOR_IDLE_THROTTLE"]] = {t = "@i18n(app.modules.profile_governor.idle_throttle)@", mspapi = 1, apikey = "governor_idle_throttle", xenablefunction = function() return (rfsuite.session.governorMode >= 1) end,}, 
            [FIELDS["GOVERNOR_AUTO_THROTTLE"]] = {t = "@i18n(app.modules.profile_governor.auto_throttle)@", mspapi = 1, apikey = "governor_auto_throttle", xenablefunction = function() return (rfsuite.session.governorMode >= 1) end},
            [FIELDS["GOV_HANDOVER_THROTTLE"]] = {t = "@i18n(app.modules.governor.handover_throttle)@", mspapi = 1, apikey = "gov_handover_throttle"}, 
            [FIELDS["GOV_THROTTLE_HOLD_TIMEOUT"]] = {t = "@i18n(app.modules.governor.throttle_hold_timeout)@", mspapi = 1, apikey = "gov_throttle_hold_timeout"},
            [FIELDS["GOV_AUTO_TIMEOUT"]] = {t = "@i18n(app.modules.governor.auto_timeout)@", mspapi = 1, apikey = "gov_autorotation_timeout"},
        }
    }
}


local function postLoad(self)
    --setGovernorMode(self)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function postSave(self)

    if rfsuite.session.governorMode ~= rfsuite.app.Page.apidata.formdata.fields[1].value then
        rfsuite.session.governorMode = rfsuite.app.Page.apidata.formdata.fields[1].value
        rfsuite.utils.log("Governor mode: " .. rfsuite.session.governorMode, "info")
    end
    return payload
end


local function wakeup()
    if not enableWakeup then return false end

    -- we are compromised if we don't have governor mode known
    if rfsuite.session.governorMode == nil then
        rfsuite.app.ui.openMainMenu()
        return
    end


    local governorMode = math.floor(rfsuite.app.Page.apidata.formdata.fields[FIELDS["GOVERNOR_MODE"]].value)

    if governorMode == 0 then   -- OFF
        formFields[FIELDS["GOVERNOR_THROTTLE_TYPE"]]:enable(false)
        formFields[FIELDS["GOVERNOR_IDLE_THROTTLE"]]:enable(false)
        formFields[FIELDS["GOVERNOR_AUTO_THROTTLE"]]:enable(false)
        formFields[FIELDS["GOV_HANDOVER_THROTTLE"]]:enable(false)
        formFields[FIELDS["GOV_THROTTLE_HOLD_TIMEOUT"]]:enable(false)
        formFields[FIELDS["GOV_AUTO_TIMEOUT"]]:enable(false)
    elseif governorMode == 1 then -- LIMIT
        formFields[FIELDS["GOVERNOR_THROTTLE_TYPE"]]:enable(true)
        formFields[FIELDS["GOVERNOR_IDLE_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOVERNOR_AUTO_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOV_HANDOVER_THROTTLE"]]:enable(false)
        formFields[FIELDS["GOV_THROTTLE_HOLD_TIMEOUT"]]:enable(false)    
        formFields[FIELDS["GOV_AUTO_TIMEOUT"]]:enable(false)
    elseif governorMode == 2 then -- DIRECT
        formFields[FIELDS["GOVERNOR_THROTTLE_TYPE"]]:enable(true)       --- add in auto timeout
        formFields[FIELDS["GOVERNOR_IDLE_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOVERNOR_AUTO_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOV_HANDOVER_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOV_THROTTLE_HOLD_TIMEOUT"]]:enable(true)    
        formFields[FIELDS["GOV_AUTO_TIMEOUT"]]:enable(true)
    elseif governorMode == 3 then -- ELECTRIC
        formFields[FIELDS["GOVERNOR_THROTTLE_TYPE"]]:enable(true)       --- add in auto timeout
        formFields[FIELDS["GOVERNOR_IDLE_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOVERNOR_AUTO_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOV_HANDOVER_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOV_THROTTLE_HOLD_TIMEOUT"]]:enable(true)   
        formFields[FIELDS["GOV_AUTO_TIMEOUT"]]:enable(true) 
    elseif governorMode == 4 then -- NITRO
        formFields[FIELDS["GOVERNOR_THROTTLE_TYPE"]]:enable(true)       --- add in auto timeout
        formFields[FIELDS["GOVERNOR_IDLE_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOVERNOR_AUTO_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOV_HANDOVER_THROTTLE"]]:enable(true)
        formFields[FIELDS["GOV_THROTTLE_HOLD_TIMEOUT"]]:enable(true)    
        formFields[FIELDS["GOV_AUTO_TIMEOUT"]]:enable(true)
    end


end

local function event(widget, category, value, x, y)
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pidx, title, "governor/governor.lua")
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(pidx, title, "governor/governor.lua")
    return true
end

return {apidata = apidata, reboot = true, eepromWrite = true, setGovernorMode = setGovernorMode, postLoad = postLoad, postSave = postSave, onNavMenu = onNavMenu, event = event, wakeup = wakeup}
