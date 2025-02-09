local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Max Cell Voltage", help = "maxCellVoltage", min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 4.3, apikey="vbatmaxcellvoltage"}
fields[#fields + 1] = {t = "Full Cell Voltage", help = "fullCellVoltage", min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 4.1, apikey="vbatfullcellvoltage"}
fields[#fields + 1] = {t = "Warn Cell Voltage", help = "warnCellVoltage", min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 3.5, apikey="vbatwarningcellvoltage"}
fields[#fields + 1] = {t = "Min Cell Voltage", help = "minCellVoltage", min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 3.3, apikey="vbatmincellvoltage"}
fields[#fields + 1] = {t = "Battery Capacity", help = "batteryCapacity", min = 0, max = 20000, step = 50, unit = "mAh", default = 0, apikey="batteryCapacity"}
fields[#fields + 1] = {t = "Cell Count", help = "cellCount", min = 0, max = 24, unit = nil, default = 6, apikey="batteryCellCount"}

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
