local labels = {}
local fields = {}

labels[#labels + 1] = {t = "RC Control", label = "line1", inline_size = 40.15}
fields[#fields + 1] = {t = "Center", label = "line1", help = "radioCenter", inline = 1, min = 1400, max = 1600, unit = "us", default = 1500, vals = {1, 2}}

labels[#labels + 1] = {t = "", label = "line2", inline_size = 40.15}
fields[#fields + 1] = {t = "Deflection", label = "line2", help = "radioDeflection", inline = 1, min = 200, max = 700, unit = "us", default = 510, vals = {3, 4}}

labels[#labels + 1] = {t = "Throttle", label = "line3", inline_size = 40.15}
fields[#fields + 1] = {
    t = "Arming",
    label = "line3",
    help = "radioArmThrottle",
    inline = 1,
    min = 850,
    max = 1880,
    unit = "us",
    default = 1050,
    vals = {5, 6},
    postEdit = function(self)
        self.validateThrottleValues(self, true)
    end
}

labels[#labels + 1] = {t = "", label = "line4", inline_size = 40.15}
fields[#fields + 1] = {
    t = "Min",
    label = "line4",
    help = "radioMinThrottle",
    inline = 1,
    min = 860,
    max = 1890,
    unit = "us",
    default = 1100,
    vals = {7, 8},
    postEdit = function(self)
        self.validateThrottleValues(self, true)
    end
}

labels[#labels + 1] = {t = "", label = "line5", inline_size = 40.15}
fields[#fields + 1] = {t = "Max", label = "line5", help = "radioMaxThrottle", inline = 1, min = 1900, max = 2150, unit = "us", default = 1900, vals = {9, 10}}

labels[#labels + 1] = {t = "Deadband", label = "line6", inline_size = 40.15}
fields[#fields + 1] = {t = "Cyclic", label = "line6", help = "radioCycDeadband", inline = 1, min = 0, max = 100, unit = "us", default = 2, vals = {11}}

labels[#labels + 1] = {t = "", label = "line7", inline_size = 40.15}
fields[#fields + 1] = {t = "Yaw", label = "line7", help = "radioYawDeadband", inline = 1, min = 0, max = 100, unit = "us", default = 2, vals = {12}}

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
    simulatorResponse = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    eepromWrite = true,
    minBytes = 12,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    validateThrottleValues = validateThrottleValues
}
