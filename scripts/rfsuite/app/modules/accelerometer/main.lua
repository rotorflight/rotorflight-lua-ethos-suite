local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Roll", help = "accelerometerTrim", min = -300, max = 300, default = 0, unit = "°", vals = {3, 4}}
fields[#fields + 1] = {t = "Pitch", help = "accelerometerTrim", min = -300, max = 300, default = 0, unit = "°", vals = {1, 2}}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

return {
    read = 240, -- msp_ACC_TRIM
    write = 239, -- msp_SET_ACC_TRIM
    eepromWrite = true,
    simulatorResponse = {0, 0, 0, 0},
    reboot = false,
    title = "Accelerometer",
    minBytes = 4,
    labels = labels,
    fields = fields,
    postLoad = postLoad
}
