local labels = {}
local fields = {}


labels[#labels + 1] = {t = "Port Setup", label="port1", inline_size = 17.3}
fields[#fields + 1] = {t = "Protocol", apikey = "protocol", type=1, label="port1", inline = 2}
fields[#fields + 1] = {t = "Pin Swap", apikey = "pin_swap", type=1, label="port1", inline = 1}

labels[#labels + 1] = {t = "    ", label="port2", inline_size = 17.3}
fields[#fields + 1] = {t = "Half Duplex", apikey = "half_duplex", type=1, label="port2", inline = 2}
fields[#fields + 1] = {t = "Update HZ", apikey = "update_hz", label="port2", inline = 1}

if rfsuite.session.apiVersion >= 12.08 then
    fields[#fields + 1] = {t = "Current Correction Factor", apikey = "current_correction_factor"}
    fields[#fields + 1] = {t = "Consumption Correction Factor", apikey = "consumption_correction_factor"}
end

local function postLoad(self)
    
    rfsuite.app.triggers.isReady = true
end



return {
    mspapi = "ESC_SENSOR_CONFIG",
    eepromWrite = true,
    reboot = true,
    title = "Mixer",
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    API = {},
}
