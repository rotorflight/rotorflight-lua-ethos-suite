--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware"})

local activateWakeup = false
local CYCLIC_RING_DEFAULT = 150
local FIELD_CYCLIC_POLAR = 1
local FIELD_CYCLIC_RING_ENABLE = 2
local FIELD_CYCLIC_RING_VALUE = 3
local OFF_ON = {
    "@i18n(api.RC_TUNING.tbl_off)@",
    "@i18n(api.RC_TUNING.tbl_on)@"
}

local function getFields()
    return rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.formdata and rfsuite.app.Page.apidata.formdata.fields
end

local function getField(index)
    local fields = getFields()
    return fields and fields[index] or nil
end

local function setFormFieldEnabled(index, enabled)
    local formField = rfsuite.app and rfsuite.app.formFields and rfsuite.app.formFields[index]
    if formField and formField.enable then
        formField:enable(enabled == true)
    end
end

local function syncCyclicRingState()
    local enableField = getField(FIELD_CYCLIC_RING_ENABLE)
    local valueField = getField(FIELD_CYCLIC_RING_VALUE)
    if not (enableField and valueField) then return end

    local enabled = tonumber(valueField.value or 0) > 0
    enableField.value = enabled and 1 or 0
    setFormFieldEnabled(FIELD_CYCLIC_RING_VALUE, enabled)
end

local function handleCyclicRingToggle(_, value)
    local enableField = getField(FIELD_CYCLIC_RING_ENABLE)
    local valueField = getField(FIELD_CYCLIC_RING_VALUE)
    if not (enableField and valueField) then return end

    local nextValue = value
    if nextValue == nil then
        nextValue = enableField.value
    end

    local enabled = tonumber(nextValue or 0) == 1
    if enabled then
        if tonumber(valueField.value or 0) <= 0 then
            valueField.value = CYCLIC_RING_DEFAULT
        end
    else
        valueField.value = 0
    end

    syncCyclicRingState()
end

local apidata = {
    api = {
        {id = 1, name = "RC_TUNING"},
    },
    formdata = {
        labels = {},
        fields = {
            [FIELD_CYCLIC_POLAR] = {t = "@i18n(app.modules.rates_advanced.cyclic_polarity)@", mspapi = 1, apikey = "cyclic_polarity", type = 1, apiversiongte = {12, 0, 9}},
            [FIELD_CYCLIC_RING_ENABLE] = {t = "@i18n(app.modules.rates_advanced.cyclic_ring)@", type = 1, value = 0, table = OFF_ON, tableIdxInc = -1, apiversiongte = {12, 0, 9}, postEdit = handleCyclicRingToggle},
            [FIELD_CYCLIC_RING_VALUE] = {t = "@i18n(app.modules.rates_advanced.cyclic_ring)@ %", mspapi = 1, apikey = "cyclic_ring", apiversiongte = {12, 0, 9}, postEdit = syncCyclicRingState}
        }
    }
}

local function postLoad(self)
    syncCyclicRingState()
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeRateProfile = rfsuite.session and rfsuite.session.activeRateProfile
        if activeRateProfile ~= nil then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeRateProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
        activateWakeup = false
    end
end

return {apidata = apidata, title = "@i18n(app.modules.rates_advanced.cyclic_behaviour)@", onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, reboot = false, eepromWrite = true, refreshOnRateChange = true, postLoad = postLoad, wakeup = wakeup, API = {}}
