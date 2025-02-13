local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Max Cell Voltage", apikey="vbatmaxcellvoltage"}
fields[#fields + 1] = {t = "Full Cell Voltage", apikey="vbatfullcellvoltage"}
fields[#fields + 1] = {t = "Warn Cell Voltage", apikey="vbatwarningcellvoltage"}
fields[#fields + 1] = {t = "Min Cell Voltage", apikey="vbatmincellvoltage"}
fields[#fields + 1] = {t = "Battery Capacity", apikey="batteryCapacity"}
fields[#fields + 1] = {t = "Cell Count", apikey="batteryCellCount"}

-- Below are other fields on the same msp call.
-- voltage meter source (val 4)
-- current meter source (val 5)
-- lvc perventage source (val 14)
-- consumption warning percentage (vale 15)

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

return {
    mspapi = "BATTERY_CONFIG",
    eepromWrite = true,
    reboot = false,
    title = "Battery",
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    API = {},
}
