local labels = {}
local fields = {}


labels[#labels + 1] = {t = "Gyro lowpass 1", t2 = "Lowpass 1", label = "line1", inline_size = 40.15}
fields[#fields + 1] = {t = "Filter type", label = "line1", inline = 1, apikey="gyro_lpf1_type", type=1}

labels[#labels + 1] = {t = "", label = "line2", inline_size = 40.15}
fields[#fields + 1] = {t = "Cutoff", label = "line2", inline = 1, apikey="gyro_lpf1_static_hz"}

labels[#labels + 1] = {t = "Gyro lowpass 1 dynamic", t2 = "Lowpass 1 dyn.", label = "line3", inline_size = 40.15, type = 1}
fields[#fields + 1] = {t = "Min cutoff", label = "line3", inline = 1, apikey="gyro_lpf1_dyn_min_hz"}

labels[#labels + 1] = {t = "", label = "line4", inline_size = 40.15}
fields[#fields + 1] = {t = "Max cutoff", label = "line4", inline = 1, apikey="gyro_lpf1_dyn_max_hz"}

labels[#labels + 1] = {t = "Gyro lowpass 2", t2 = "Lowpass 2", label = "line5", inline_size = 40.15}
fields[#fields + 1] = {t = "Filter type", label = "line5", inline = 1, apikey="gyro_lpf2_type", type=1}

labels[#labels + 1] = {t = "", label = "line6", inline_size = 40.15}
fields[#fields + 1] = {t = "Cutoff", label = "line6", inline = 1, apikey="gyro_lpf2_static_hz"}

labels[#labels + 1] = {t = "Gyro notch 1", t2 = "Notch 1", label = "line7", inline_size = 13.6}
fields[#fields + 1] = {t = "Center", label = "line7", inline = 2, apikey="gyro_soft_notch_hz_1"}
fields[#fields + 1] = {t = "Cutoff", label = "line7", inline = 1, apikey="gyro_soft_notch_cutoff_1"}

labels[#labels + 1] = {t = "Gyro notch 2", t2 = "Notch 2", label = "line9", inline_size = 13.6}
fields[#fields + 1] = {t = "Center", label = "line9", inline = 2, apikey="gyro_soft_notch_hz_2"}
fields[#fields + 1] = {t = "Cutoff", label = "line9", inline = 1, apikey="gyro_soft_notch_cutoff_2"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

return {
    mspapi = "FILTER_CONFIG",
    eepromWrite = true,
    reboot = true,
    title = "Filters",
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    API = {},
}
