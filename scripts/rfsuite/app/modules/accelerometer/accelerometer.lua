local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Roll", help = "accelerometerTrim", apikey="roll"}
fields[#fields + 1] = {t = "Pitch", help = "accelerometerTrim", apikey="pitch"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true

end

return {
    mspapi="ACC_TRIM",
    eepromWrite = true,
    reboot = false,
    title = "Accelerometer",
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    API = {},
}
