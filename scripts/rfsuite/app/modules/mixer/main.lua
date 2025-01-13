local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Geo correction", help = "mixerCollectiveGeoCorrection", min = -125, max = 125, vals = {19}, decimals = 1, scale = 5, step = 2}

labels[#labels + 1] = {t = "", label = "line2", inline_size = 40.15}
fields[#fields + 1] = {t = "Total pitch limit", help = "mixerTotalPitchLimit", min = 0, max = 3000, vals = {10, 11}, decimals = 1, scale = 83.33333333333333, step = 1}

labels[#labels + 1] = {t = "", label = "line3", inline_size = 40.15}
fields[#fields + 1] = {t = "Phase angle", help = "mixerSwashPhase", min = -1800, max = 1800, vals = {8, 9}, decimals = 1, scale = 10}

labels[#labels + 1] = {t = "", label = "line4", inline_size = 40.15}
fields[#fields + 1] = {t = "TTA precomp", help = "mixerTTAPrecomp", min = 0, max = 250, vals = {18}}

fields[#fields + 1] = {t = "Tail Idle Thr%", help = "mixerTailMotorIdle", min = 0, max = 250, vals = {3}, decimals = 1, scale = 10, unit = "%"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

return {
    read = 42, -- msp_MIXER_CONFIG
    write = 43, -- msp_SET_MIXER_CONFIG
    eepromWrite = true,
    reboot = false,
    title = "Mixer",
    simulatorResponse = {0, 0, 0, 0, 0, 2, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    minBytes = 19,
    labels = labels,
    fields = fields,
    postLoad = postLoad
}
