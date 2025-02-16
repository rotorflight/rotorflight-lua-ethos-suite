local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Geo correction", apikey = "swash_geo_correction"}

labels[#labels + 1] = {t = "", label = "line2", inline_size = 40.15}
fields[#fields + 1] = {t = "Total pitch limit", apikey = "swash_pitch_limit"}

if rfsuite.session.apiVersion >= 12.08 then
    labels[#labels + 1] = {t = "Collective Tilt Correction", inline_size = 35, label = "coltilt1", type = 1}
fields[#fields + 1] = {t = "Positive", inline = 1, label = "coltilt1", apikey = "collective_tilt_correction_pos"}

    labels[#labels + 1] = {t = "                           ", inline_size = 35, label = "coltilt2", type = 1}
fields[#fields + 1] = {t = "Negative", inline = 1, label = "coltilt2", apikey = "collective_tilt_correction_neg"}
end

labels[#labels + 1] = {t = "", label = "line3", inline_size = 40.15}
fields[#fields + 1] = {t = "Phase angle", apikey = "swash_phase"}

labels[#labels + 1] = {t = "", label = "line4", inline_size = 40.15}
fields[#fields + 1] = {t = "TTA precomp", apikey = "swash_tta_precomp"}

fields[#fields + 1] = {t = "Tail Idle Thr%", apikey = "tail_motor_idle"}




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
