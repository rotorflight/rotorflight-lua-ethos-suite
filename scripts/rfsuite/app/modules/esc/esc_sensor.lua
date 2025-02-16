local labels = {}
local fields = {}


--fields[#fields + 1] = {t = "Protocol", apikey = "protocol", type=1}
--fields[#fields + 1] = {t = "Half Duplex", apikey = "half_duplex", type=1}
--fields[#fields + 1] = {t = "Update HZ", apikey = "update_hz"}
--fields[#fields + 1] = {t = "Current Offset", apikey = "current_offset"}
--fields[#fields + 1] = {t = "HW4 Current Offset", apikey = "hw4_current_offset"}
--fields[#fields + 1] = {t = "HW4 Current Gain", apikey = "hw4_current_gain"}
--fields[#fields + 1] = {t = "HW4 Voltage Gain", apikey = "hw4_voltage_gain"}
--fields[#fields + 1] = {t = "Pin Swap", apikey = "pin_swap", type=1}
fields[#fields + 1] = {t = "Current Correction Factor", apikey = "current_correction_factor"}
fields[#fields + 1] = {t = "Consumption Correction Factor", apikey = "consumption_correction_factor"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "esc/esc.lua")
end

return {
    mspapi = "ESC_SENSOR_CONFIG",
    eepromWrite = true,
    reboot = false,
    title = "Mixer",
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    onNavMenu = onNavMenu,
    API = {},
}
