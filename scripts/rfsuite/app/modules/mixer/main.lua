local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Geo correction", help = "mixerCollectiveGeoCorrection", min = -125, max = 125, decimals = 1, scale = 5, step = 2, apikey="swash_geo_correction"}

labels[#labels + 1] = {t = "", label = "line2", inline_size = 40.15}
fields[#fields + 1] = {t = "Total pitch limit", help = "mixerTotalPitchLimit", min = 0, max = 3000, decimals = 1, scale = 83.33333333333333, step = 1, apikey="swash_pitch_limit"}

labels[#labels + 1] = {t = "", label = "line3", inline_size = 40.15}
fields[#fields + 1] = {t = "Phase angle", help = "mixerSwashPhase", min = -1800, max = 1800, decimals = 1, scale = 10, apikey="swash_phase"}

labels[#labels + 1] = {t = "", label = "line4", inline_size = 40.15}
fields[#fields + 1] = {t = "TTA precomp", help = "mixerTTAPrecomp", min = 0, max = 250, apikey="swash_tta_precomp"}

fields[#fields + 1] = {t = "Tail Idle Thr%", help = "mixerTailMotorIdle", min = 0, max = 250, decimals = 1, scale = 10, unit = "%", apikey="tail_motor_idle"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

return {
    mspapi = "MIXER_CONFIG",
    eepromWrite = true,
    reboot = false,
    title = "Mixer",
    labels = labels,
    fields = fields,
    postLoad = postLoad
}
