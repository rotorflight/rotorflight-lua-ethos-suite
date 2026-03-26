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
                {t = "@i18n(app.modules.radio_config.stick)@",           label = 1, inline_size = 16},
                {t = "@i18n(app.modules.radio_config.throttle)@",        label = 2, inline_size = 16},
                {t = "@i18n(app.modules.radio_config.deadband)@",        label = 4, inline_size = 16}
            },
            fields = {
                {t = "@i18n(app.modules.radio_config.center)@",          label = 1, inline = 2, mspapi = 1, apikey = "rc_center"},
                {t = "@i18n(app.modules.radio_config.deflection)@",      label = 1, inline = 1, mspapi = 1, apikey = "rc_deflection"},
                {t = "@i18n(app.modules.radio_config.cyclic)@",          label = 4, inline = 2, mspapi = 1, apikey = "rc_deadband"},
                {t = "@i18n(app.modules.radio_config.yaw_deadband)@",    label = 4, inline = 1, mspapi = 1, apikey = "rc_yaw_deadband"},                
                {t = "@i18n(app.modules.radio_config.min_throttle)@",    label = 2, inline = 2, mspapi = 1, apikey = "rc_min_throttle"},
                {t = "@i18n(app.modules.radio_config.max_throttle)@",    label = 2, inline = 1, mspapi = 1, apikey = "rc_max_throttle"}
            }
        }
    }

else

    apidata = {
        api = {[1] = "RC_CONFIG"},
        formdata = {
            labels = {
                {t = "@i18n(app.modules.radio_config.stick)@",           label = 1, inline_size = 16},
                {t = "@i18n(app.modules.radio_config.throttle)@",        label = 2, inline_size = 16},
                {t = "",                                                   label = 3, inline_size = 16},
                {t = "@i18n(app.modules.radio_config.deadband)@",        label = 4, inline_size = 16}
            },
            fields = {
                {t = "@i18n(app.modules.radio_config.center)@",          label = 1, inline = 2, mspapi = 1, apikey = "rc_center"},
                {t = "@i18n(app.modules.radio_config.deflection)@",      label = 1, inline = 1, mspapi = 1, apikey = "rc_deflection"},
                {t = "@i18n(app.modules.radio_config.arming)@",          label = 2, inline = 2, mspapi = 1, apikey = "rc_arm_throttle"},
                {t = "@i18n(app.modules.radio_config.min_throttle)@",    label = 2, inline = 1, mspapi = 1, apikey = "rc_min_throttle"},
                {t = "@i18n(app.modules.radio_config.max_throttle)@",    label = 3, inline = 1, mspapi = 1, apikey = "rc_max_throttle"},
                {t = "@i18n(app.modules.radio_config.cyclic)@",          label = 4, inline = 2, mspapi = 1, apikey = "rc_deadband"},
                {t = "@i18n(app.modules.radio_config.yaw_deadband)@",    label = 4, inline = 1, mspapi = 1, apikey = "rc_yaw_deadband"}
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
