local labels = {}
local fields = {}

labels[#labels + 1] = {t = "Stick", label = 1, inline_size = 14.5}
fields[#fields + 1] = {t = "Center", label = 1, inline = 2, help = "radioCenter", min = 1400, max = 1600, default = 1500, unit = "us", vals = {1, 2}}
fields[#fields + 1] = {t = "Deflection", t2 = "Deflect", label = 1, inline = 1, help = "radioDeflection", min = 200, max = 700, default = 510, unit = "us", vals = {3, 4}}

labels[#labels + 1] = {t = "Throttle", label = 2, inline_size = 14.5}
fields[#fields + 1] = {
    t = "Arming",
    label = 2,
    inline = 2,
    help = "radioArmThrottle",
    min = 850,
    max = 1880,
    default = 1050,
    unit = "us",
    vals = {5, 6},
    postEdit = function(self)
        self.validateThrottleValues(self, true)
    end
}

fields[#fields + 1] = {
    t = "Min",
    label = 2,
    inline = 1,
    help = "radioMinThrottle",
    min = 860,
    max = 1890,
    default = 1100,
    unit = "us",
    vals = {7, 8},
    postEdit = function(self)
        self.validateThrottleValues(self, true)
    end
}

labels[#labels + 1] = {t = "", label = 3, inline_size = 14.5}
fields[#fields + 1] = {t = "Max", label = 3, inline = 1, help = "radioMaxThrottle", min = 1900, max = 2150, default = 1900, unit = "us", vals = {9, 10}}

labels[#labels + 1] = {t = "Deadband", label = 4, inline_size = 14.5}
fields[#fields + 1] = {t = "Cyclic", label = 4, inline = 2, help = "radioCycDeadband", min = 0, max = 100, default = 2, unit = "us", vals = {11}}
fields[#fields + 1] = {t = "Yaw", label = 4, inline = 1, help = "radioYawDeadband", min = 0, max = 100, default = 2, unit = "us", vals = {12}}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
    self.validateThrottleValues(self)
end

local function validateThrottleValues(self)
    local arm = self.fields[3].value
    local min = self.fields[4].value

    self.fields[4].min = arm + 10

    if min < (arm + 10) then
        self.fields[4].value = arm + 10
    end
end

return {
    read = 66, -- MSP_RC_CONFIG
    write = 67, -- MSP_SET_RC_CONFIG
    title = "Radio Config",
    reboot = true,
    simulatorResponse = {220, 5, 254, 1, 232, 3, 242, 3, 208, 7, 4, 4},
    eepromWrite = true,
    minBytes = 12,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    validateThrottleValues = validateThrottleValues
}
