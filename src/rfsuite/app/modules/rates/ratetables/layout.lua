--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local layout = {}

local RATE_ROWS = {
    standard = {
        "@i18n(app.modules.rates.roll)@",
        "@i18n(app.modules.rates.pitch)@",
        "@i18n(app.modules.rates.yaw)@",
        "@i18n(app.modules.rates.collective)@"
    },
    polar = {
        "@i18n(app.modules.rates.cyclic)@",
        "@i18n(app.modules.rates.yaw)@",
        "@i18n(app.modules.rates.collective)@"
    }
}

local function copyArray(values)
    local copied = {}
    for i = 1, #values do
        copied[i] = values[i]
    end
    return copied
end

local function resolvePolarEnabled()
    local pending = rfsuite.session and rfsuite.session.pendingPolarRateLayout
    if pending ~= nil then
        return pending == true
    end

    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
    local rcTuning = values and values.RC_TUNING
    if rcTuning and rcTuning.cyclic_polarity ~= nil then
        return tonumber(rcTuning.cyclic_polarity) == 1
    end

    local fields = rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.formdata and rfsuite.app.Page.apidata.formdata.fields
    if fields then
        for i = 1, #fields do
            local field = fields[i]
            if field and field.apikey == "cyclic_polarity" then
                return tonumber(field.value or 0) == 1
            end
        end
    end

    local session = rfsuite.session
    local activeRateProfile = session and session.activeRateProfile
    local cached = session and session.rateProfilePolarState
    if activeRateProfile ~= nil and cached and cached[activeRateProfile] ~= nil then
        return cached[activeRateProfile] == true
    end

    return false
end

function layout.apply(apidata)
    if not (rfsuite.session and rfsuite.session.applyPolarRateLayout == true) then
        return apidata
    end

    local formdata = apidata and apidata.formdata
    if not formdata then return apidata end

    local polarEnabled = resolvePolarEnabled()
    formdata.rows = copyArray(polarEnabled and RATE_ROWS.polar or RATE_ROWS.standard)
    formdata._polarEnabled = polarEnabled

    local fields = formdata.fields
    if not fields then return apidata end

    for i = 1, #fields do
        local field = fields[i]
        local axis = field and field.apikey and tonumber(field.apikey:match("_(%d+)$"))
        if axis then
            if polarEnabled then
                field.hidden = (axis == 1)
                if axis > 1 then
                    field.row = axis - 1
                end
            else
                field.hidden = false
                field.row = axis
            end
        end
    end

    return apidata
end

return layout
