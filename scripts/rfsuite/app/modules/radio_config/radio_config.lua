local labels = {}
local fields = {}

labels[#labels + 1] = {t = "Stick", label = 1, inline_size = 14.5}
fields[#fields + 1] = {t = "Center", label = 1, inline = 2, apikey = "rc_center"}
fields[#fields + 1] = {t = "Deflection", t2 = "Deflect", label = 1, inline = 1, apikey = "rc_deflection"}

labels[#labels + 1] = {t = "Throttle", label = 2, inline_size = 14.5}
fields[#fields + 1] = {t = "Arming", label = 2, inline = 2, apikey = "rc_arm_throttle"}
fields[#fields + 1] = {t = "Min", label = 2, inline = 1, apikey = "rc_min_throttle"}

labels[#labels + 1] = {t = "", label = 3, inline_size = 14.5}
fields[#fields + 1] = {t = "Max", label = 3, inline = 1, apikey = "rc_max_throttle"}

labels[#labels + 1] = {t = "Deadband", label = 4, inline_size = 14.5}
fields[#fields + 1] = {t = "Cyclic", label = 4, inline = 2, apikey = "rc_deadband"}
fields[#fields + 1] = {t = "Yaw", label = 4, inline = 1, apikey = "rc_yaw_deadband"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
    self.validateThrottleValues(self)
end

local function validateThrottleValues(self)
    local arm = self.fields[3].value
    local min = self.fields[4].value

    self.fields[4].min = arm + 10

    if min < (arm + 10) then self.fields[4].value = arm + 10 end
end

return {
    mspapi="RC_CONFIG",
    title = "Radio Config",
    reboot = true,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    validateThrottleValues = validateThrottleValues,
    API = {},
}
