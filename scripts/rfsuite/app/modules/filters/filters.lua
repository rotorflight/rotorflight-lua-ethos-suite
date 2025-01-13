local labels = {}
local fields = {}

local gyroFilterType = {[0] = "NONE", "1ST", "2ND"}

labels[#labels + 1] = {t = "Gyro lowpass 1", t2 = "Lowpass 1", label = "line1", inline_size = 40.15}
fields[#fields + 1] = {t = "Filter type", label = "line1", inline = 1, min = 0, max = #gyroFilterType, vals = {2}, table = gyroFilterType}

labels[#labels + 1] = {t = "", label = "line2", inline_size = 40.15}
fields[#fields + 1] = {t = "Cutoff", help = "gyroLowpassFilterCutoff", label = "line2", inline = 1, min = 0, max = 4000, unit = "Hz", default = 100, vals = {3, 4}}

labels[#labels + 1] = {t = "Gyro lowpass 1 dynamic", t2 = "Lowpass 1 dyn.", label = "line3", inline_size = 40.15, type = 1}
fields[#fields + 1] = {t = "Min cutoff", help = "gyroLowpassFilterDynamicCutoff", label = "line3", inline = 1, min = 0, max = 1000, unit = "Hz", vals = {16, 17}}

labels[#labels + 1] = {t = "", label = "line4", inline_size = 40.15}
fields[#fields + 1] = {t = "Max cutoff", help = "gyroLowpassFilterDynamicCutoff", label = "line4", inline = 1, min = 0, max = 1000, unit = "Hz", vals = {18, 19}}

labels[#labels + 1] = {t = "Gyro lowpass 2", t2 = "Lowpass 2", label = "line5", inline_size = 40.15}
fields[#fields + 1] = {t = "Filter type", label = "line5", inline = 1, min = 0, max = #gyroFilterType, vals = {5}, table = gyroFilterType}

labels[#labels + 1] = {t = "", label = "line6", inline_size = 40.15}
fields[#fields + 1] = {t = "Cutoff", help = "gyroLowpassFilterCutoff", label = "line6", inline = 1, min = 0, max = 4000, unit = "Hz", vals = {6, 7}}

labels[#labels + 1] = {t = "Gyro notch 1", t2 = "Notch 1", label = "line7", inline_size = 13.6}
fields[#fields + 1] = {t = "Center", help = "gyroLowpassFilterCenter", label = "line7", inline = 2, min = 0, max = 4000, unit = "Hz", vals = {8, 9}}
fields[#fields + 1] = {t = "Cutoff", help = "gyroLowpassFilterCutoff", label = "line7", inline = 1, min = 0, max = 4000, unit = "Hz", vals = {10, 11}}

labels[#labels + 1] = {t = "Gyro notch 2", t2 = "Notch 2", label = "line9", inline_size = 13.6}
fields[#fields + 1] = {t = "Center", help = "gyroLowpassFilterCenter", label = "line9", inline = 2, min = 0, max = 4000, unit = "Hz", vals = {12, 13}}
fields[#fields + 1] = {t = "Cutoff", help = "gyroLowpassFilterCutoff", label = "line9", inline = 1, min = 0, max = 4000, unit = "Hz", vals = {14, 15}}

labels[#labels + 1] = {t = "Dynamic Notch Filters", t2 = "Dyn. Notch Filters", label = "line11", inline_size = 13.6}
fields[#fields + 1] = {t = "Count", help = "gyroDynamicNotchCount", label = "line11", inline = 2, min = 0, max = 8, default = 4, vals = {20}}
fields[#fields + 1] = {t = "Q", help = "gyroDynamicNotchQ", label = "line11", inline = 1, min = 10, max = 100, default = 200, vals = {21}, decimals = 1, scale = 10}

labels[#labels + 1] = {t = "", label = "line12", inline_size = 13.6}
fields[#fields + 1] = {t = "Min", help = "gyroDynamicNotchMinHz", label = "line12", inline = 2, min = 10, max = 200, default = 25, unit = "Hz", vals = {22, 23}}
fields[#fields + 1] = {t = "Max", help = "gyroDynamicNotchMaxHz", label = "line12", inline = 1, min = 100, max = 500, default = 245, unit = "Hz", vals = {24, 25}}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

return {
    read = 92, -- msp_FILTER_CONFIG
    write = 93, -- msp_SET_FILTER_CONFIG
    eepromWrite = true,
    reboot = true,
    title = "Filters",
    minBytes = 25,
    simulatorResponse = {0, 1, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 25, 25, 0, 245, 0},
    labels = labels,
    fields = fields,
    postLoad = postLoad
}
