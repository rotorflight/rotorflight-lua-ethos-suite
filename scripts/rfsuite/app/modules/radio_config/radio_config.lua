local mspapi = {
    api = {
        [1] = "RC_CONFIG",
    },
    formdata = {
        labels = {
            { t = "Stick",    label = 1, inline_size = 14.5 },
            { t = "Throttle", label = 2, inline_size = 14.5 },
            { t = "",         label = 3, inline_size = 14.5 },
            { t = "Deadband", label = 4, inline_size = 14.5 }
        },
        fields = {
            { t = "Center",     label = 1, inline = 2, mspapi = 1, apikey = "rc_center"       },
            { t = "Deflection", t2 = "Deflect", label = 1, inline = 1, mspapi = 1, apikey = "rc_deflection"   },
            { t = "Arming",     label = 2, inline = 2, mspapi = 1, apikey = "rc_arm_throttle" },
            { t = "Min",        label = 2, inline = 1, mspapi = 1, apikey = "rc_min_throttle" },
            { t = "Max",        label = 3, inline = 1, mspapi = 1, apikey = "rc_max_throttle" },
            { t = "Cyclic",     label = 4, inline = 2, mspapi = 1, apikey = "rc_deadband"     },
            { t = "Yaw",        label = 4, inline = 1, mspapi = 1, apikey = "rc_yaw_deadband" }
        }
    }                 
}


local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    self.validateThrottleValues(self)
end

local function validateThrottleValues(self)
    local arm = self.fields[3].value
    local min = self.fields[4].value

    self.fields[4].min = arm + 10

    if min < (arm + 10) then self.fields[4].value = arm + 10 end
end

return {
    mspapi=mspapi,
    title = "Radio Config",
    reboot = true,
    eepromWrite = true,
    postLoad = postLoad,
    validateThrottleValues = validateThrottleValues,
    API = {},
}
