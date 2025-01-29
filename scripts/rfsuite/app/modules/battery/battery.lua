local labels = {}
local fields = {}



fields[#fields + 1] = {t = "Max Cell Voltage", help = "maxCellVoltage", min = 0, decimals=2, scale=100, max = 500, unit = "V", default = 4.3, vals = {8,9}}
fields[#fields + 1] = {t = "Full Cell Voltage", help = "fullCellVoltage", min = 0, decimals=2, scale=100, max = 500, unit = "V", default = 4.1, vals = {10,11}}
fields[#fields + 1] = {t = "Warn Cell Voltage", help = "warnCellVoltage", min = 0, decimals=2, scale=100, max = 500, unit = "V", default = 3.5, vals = {12,13}}
fields[#fields + 1] = {t = "Min Cell Voltage", help = "minCellVoltage", min = 0, decimals=2, scale=100, max = 500, unit = "V", default = 3.3, vals = {6,7}}
fields[#fields + 1] = {t = "Battery Capacity", help = "batteryCapacity", min = 0, max = 20000, step=50, unit = "mAh", default = 0, vals = {1, 2}}
fields[#fields + 1] = {t = "Cell Count", help = "cellCount", min = 0, max = 24, unit = nil, default = 6, vals = {3}}





-- Below are other fields on the same msp call.
-- voltage meter source (val 4)
-- current meter source (val 5)
-- lvc perventage source (val 14)
-- consumption warning percentage (vale 15)


local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

return {
    read = 32, -- MSP_BATTERY_CONFIG
    write = 33, -- MSP_SET_BATTERY_CONFIG
    eepromWrite = true,
    reboot = false,
    title = "Battery",
    minBytes = 15,
    simulatorResponse = {138, 2, 3, 1, 1, 74, 1, 174, 1, 154, 1, 94, 1, 100, 10},
    labels = labels,
    fields = fields,
    postLoad = postLoad
}
