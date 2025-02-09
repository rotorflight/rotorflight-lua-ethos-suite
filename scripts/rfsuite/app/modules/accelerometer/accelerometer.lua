local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Roll", help = "accelerometerTrim", xmin = -300, max = 300, default = 0, unit = "°", apikey="roll"}
fields[#fields + 1] = {t = "Pitch", help = "accelerometerTrim", xmin = -300, max = 300, default = 0, unit = "°", apikey="pitch"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true

    rfsuite.utils.print_r(self.API.data())

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
