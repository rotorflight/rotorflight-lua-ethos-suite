local labels = {}
local fields = {}


labels[#labels + 1] = {t = "Port Setup", label="port1", inline_size = 17.3}
fields[#fields + 1] = {t = "Protocol", apikey = "protocol", type=1, label="port1", inline = 2}
fields[#fields + 1] = {t = "Pin Swap", apikey = "pin_swap", type=1, label="port1", inline = 1}

labels[#labels + 1] = {t = "    ", label="port2", inline_size = 17.3}
fields[#fields + 1] = {t = "Half Duplex", apikey = "half_duplex", type=1, label="port2", inline = 2}
fields[#fields + 1] = {t = "Update HZ", apikey = "update_hz", label="port2", inline = 1}


--fields[#fields + 1] = {t = "Current Offset", apikey = "current_offset"}             -- we dont show as best kept cli
--fields[#fields + 1] = {t = "HW4 Current Offset", apikey = "hw4_current_offset"}   -- we dont show as best kept cli
--fields[#fields + 1] = {t = "HW4 Current Gain", apikey = "hw4_current_gain"}       -- we dont show as best kept cli
--fields[#fields + 1] = {t = "HW4 Voltage Gain", apikey = "hw4_voltage_gain"}         -- we dont show as best kept cli
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
