local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Geo correction", help = "mixerCollectiveGeoCorrection", default = 0, min = -125, max = 125, decimals = 1, scale = 5, step = 2, apikey="swash_geo_correction"}

labels[#labels + 1] = {t = "", label = "line2", inline_size = 40.15}
fields[#fields + 1] = {t = "Total pitch limit", help = "mixerTotalPitchLimit", default = 0, min = 0, max = 3000, decimals = 1, scale = 83.33333333333333, step = 1, apikey="swash_pitch_limit"}

if rfsuite.config.apiVersion >= 12.08 then
    labels[#labels + 1] = {t = "Collective Tilt Correction", inline_size = 35, label = "coltilt1", type = 1}
    fields[#fields + 1] = {t = "Positive", help = "collectiveTiltCorrection", inline = 1, label = "coltilt1",  default = 0, min = -100, max = 100, unit = "", apikey="collective_tilt_correction_pos"}

    labels[#labels + 1] = {t = "                           ", inline_size = 35, label = "coltilt2", type = 1}
    fields[#fields + 1] = {t = "Negative", help = "collectiveTiltCorrection", inline = 1, label = "coltilt2",  default = 10, min = -100, max = 100, unit = "", apikey="collective_tilt_correction_neg"}
end

labels[#labels + 1] = {t = "", label = "line3", inline_size = 40.15}
fields[#fields + 1] = {t = "Phase angle", help = "mixerSwashPhase", default = 0, min = -1800, max = 1800, decimals = 1, scale = 10, apikey="swash_phase"}

labels[#labels + 1] = {t = "", label = "line4", inline_size = 40.15}
fields[#fields + 1] = {t = "TTA precomp", help = "mixerTTAPrecomp", default = 0, min = 0, max = 250, apikey="swash_tta_precomp"}

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
    postLoad = postLoad,
    API = {},
}
