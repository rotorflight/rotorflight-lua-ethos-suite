--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apidata
local enableWakeup = false
local throttleValidated = false

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then

    apidata = {
        api = {[1] = "RC_CONFIG"},
        formdata = {
            labels = {
                {t = "Stick",           label = 1, inline_size = 16},
                {t = "Throttle",        label = 2, inline_size = 16},
                {t = "Deadband",        label = 4, inline_size = 16}
            },
            fields = {
                {t = "Center",          label = 1, inline = 2, mspapi = 1, apikey = "rc_center"},
                {t = "Deflection",      label = 1, inline = 1, mspapi = 1, apikey = "rc_deflection"},
                {t = "Cyclic",          label = 4, inline = 2, mspapi = 1, apikey = "rc_deadband"},
                {t = "Yaw",    label = 4, inline = 1, mspapi = 1, apikey = "rc_yaw_deadband"},                
                {t = "Min",    label = 2, inline = 2, mspapi = 1, apikey = "rc_min_throttle"},
                {t = "Max",    label = 2, inline = 1, mspapi = 1, apikey = "rc_max_throttle"}
            }
        }
    }

else

    apidata = {
        api = {[1] = "RC_CONFIG"},
        formdata = {
            labels = {
                {t = "Stick",           label = 1, inline_size = 16},
                {t = "Throttle",        label = 2, inline_size = 16},
                {t = "",                                                   label = 3, inline_size = 16},
                {t = "Deadband",        label = 4, inline_size = 16}
            },
            fields = {
                {t = "Center",          label = 1, inline = 2, mspapi = 1, apikey = "rc_center"},
                {t = "Deflection",      label = 1, inline = 1, mspapi = 1, apikey = "rc_deflection"},
                {t = "Arming",          label = 2, inline = 2, mspapi = 1, apikey = "rc_arm_throttle"},
                {t = "Min",    label = 2, inline = 1, mspapi = 1, apikey = "rc_min_throttle"},
                {t = "Max",    label = 3, inline = 1, mspapi = 1, apikey = "rc_max_throttle"},
                {t = "Cyclic",          label = 4, inline = 2, mspapi = 1, apikey = "rc_deadband"},
                {t = "Yaw",    label = 4, inline = 1, mspapi = 1, apikey = "rc_yaw_deadband"}
            }
        }
    }    
    
end    

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
    throttleValidated = false
    self.validateThrottleValues(self)
end

local function validateThrottleValues(self)
    local fields = self and (self.fields or (self.apidata and self.apidata.formdata and self.apidata.formdata.fields))
    if type(fields) ~= "table" then return false end

    local armField
    local minField
    for i = 1, #fields do
        local field = fields[i]
        if field and field.apikey == "rc_arm_throttle" then
            armField = field
        elseif field and field.apikey == "rc_min_throttle" then
            minField = field
        end
    end
    if not armField or not minField then return false end

    local arm = tonumber(armField.value)
    local min = tonumber(minField.value)
    if not arm or not min then return false end

    minField.min = arm + 10
    if min < (arm + 10) then minField.value = arm + 10 end
    return true
end

local function wakeup(self)
    if not enableWakeup or throttleValidated then return end
    throttleValidated = self.validateThrottleValues(self)
end

return {apidata = apidata, reboot = true, eepromWrite = true, postLoad = postLoad, validateThrottleValues = validateThrottleValues, wakeup = wakeup, API = {}}
