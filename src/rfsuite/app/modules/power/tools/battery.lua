--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local fieldIndexByApiKey = {}
local lastHighlightStateKey = nil
local lastEditingType = nil
local lastActiveType = nil

local CAPACITY_PROFILE_MIN = 0
local CAPACITY_PROFILE_MAX = 40000

local fields = {
    {t = "@i18n(telemetry.group_profiles)@", type = 0, apikey = "profilesGroupHeader", value = ""},
    {t = "    @i18n(app.modules.power.selected)@", mspapi = 2, apikey = "batteryProfile", type = 1},
    {t = "    @i18n(app.modules.power.capacity)@", mspapi = 1, apikey = "batteryCapacityActive", min = CAPACITY_PROFILE_MIN, max = CAPACITY_PROFILE_MAX, step = 10, unit = "mAh"},
    {t = "@i18n(telemetry.group_battery)@", type = 0, apikey = "batteryGroupHeader", value = ""},
    {t = "    @i18n(app.modules.power.max_cell_voltage)@", mspapi = 1, apikey = "vbatmaxcellvoltage"},
    {t = "    @i18n(app.modules.power.full_cell_voltage)@", mspapi = 1, apikey = "vbatfullcellvoltage"},
    {t = "    @i18n(app.modules.power.warn_cell_voltage)@", mspapi = 1, apikey = "vbatwarningcellvoltage"},
    {t = "    @i18n(app.modules.power.min_cell_voltage)@", mspapi = 1, apikey = "vbatmincellvoltage"},
    {t = "    @i18n(app.modules.power.cell_count)@", mspapi = 1, apikey = "batteryCellCount"},
    {t = "    @i18n(app.modules.power.consumption_warning_percentage)@", min = 15, max = 60, mspapi = 1, apikey = "consumptionWarningPercentage"}
}

local apidata = {
    api = {
        [1] = "BATTERY_CONFIG",
        [2] = "BATTERY_PROFILE"
    },
    formdata = {
        labels = {},
        fields = fields
    }
}

local function clampProfileIndex(v)
    local n = tonumber(v)
    if not n then return nil end
    n = math.floor(n)
    if n < 0 or n > 5 then return nil end
    return n
end

local function getFieldValue(self, apikey)
    local idx = fieldIndexByApiKey[apikey]
    if not idx then return nil end
    local list = self.fields or (self.apidata and self.apidata.formdata and self.apidata.formdata.fields) or {}
    local f = list[idx]
    return f and f.value or nil
end

local function setFieldValue(self, apikey, value)
    local idx = fieldIndexByApiKey[apikey]
    if not idx then return end
    local list = self.fields or (self.apidata and self.apidata.formdata and self.apidata.formdata.fields) or {}
    local f = list[idx]
    if not f then return end
    f.value = value
end

local function setFieldColorByApiKey(apikey, color)
    local idx = fieldIndexByApiKey[apikey]
    if not idx then return end
    local field = rfsuite.app.formFields and rfsuite.app.formFields[idx]
    if field and field.color then field:color(color) end
end

local function getProfileCapacity(profileIndex)
    if profileIndex == nil then return nil end
    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
    local batteryValues = values and values.BATTERY_CONFIG
    if not batteryValues then return nil end
    return tonumber(batteryValues["batteryCapacity_" .. tostring(profileIndex)])
end

local function saveProfileCapacity(profileIndex, capacity)
    if profileIndex == nil or capacity == nil then return end
    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
    local batteryValues = values and values.BATTERY_CONFIG
    if not batteryValues then return end
    local v = tonumber(capacity)
    if v < CAPACITY_PROFILE_MIN then v = CAPACITY_PROFILE_MIN end
    if v > CAPACITY_PROFILE_MAX then v = CAPACITY_PROFILE_MAX end
    local finalVal = math.floor(v + 0.5)
    batteryValues["batteryCapacity_" .. tostring(profileIndex)] = finalVal

    if rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.profiles then
        rfsuite.session.batteryConfig.profiles[profileIndex] = finalVal
    end
end

local function updateDynamicUi(self, editingType, activeType)
    local headerBase = rfsuite.app.lastTitle or "@i18n(app.modules.power.battery)@"
    local headerProfile = activeType
    if headerProfile ~= nil then
        pcall(function()
            rfsuite.app.ui.setHeaderTitle(headerBase .. " #" .. tostring(headerProfile + 1))
        end)
    else
        pcall(function()
            rfsuite.app.ui.setHeaderTitle(headerBase)
        end)
    end

    local color = (editingType ~= nil and activeType ~= nil and editingType == activeType) and GREEN or YELLOW
    setFieldColorByApiKey("batteryCapacityActive", color)
    setFieldColorByApiKey("batteryProfile", (activeType ~= nil) and GREEN or nil)
end

local function postLoad(self)
    fieldIndexByApiKey = {}
    lastHighlightStateKey = nil
    lastEditingType = nil
    lastActiveType = nil

    for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey then fieldIndexByApiKey[f.apikey] = i end
    end

    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "consumptionWarningPercentage" then
            local v = tonumber(f.value)
            if v and (v < 15 or v > 60) then f.value = 35 end
        end
    end

    local activeType = clampProfileIndex(rfsuite.session.activeBatteryType)
    local editingType = activeType
    if editingType == nil then
        editingType = clampProfileIndex(getFieldValue(self, "batteryProfile")) or 0
    end
    setFieldValue(self, "batteryProfile", editingType)
    local capacity = getProfileCapacity(editingType)
    if capacity ~= nil then setFieldValue(self, "batteryCapacityActive", capacity) end
    lastEditingType = editingType
    lastActiveType = activeType

    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function wakeup(self)
    if enableWakeup == false then return end

    local activeType = clampProfileIndex(rfsuite.session.activeBatteryType)
    local editingType = clampProfileIndex(getFieldValue(self, "batteryProfile"))
    local needsInvalidate = false

    -- If active battery changes while page is open, resync selection and value.
    if activeType ~= nil and activeType ~= lastActiveType then
        setFieldValue(self, "batteryProfile", activeType)
        local idx = fieldIndexByApiKey["batteryProfile"]
        if idx and rfsuite.app.formFields and rfsuite.app.formFields[idx] and rfsuite.app.formFields[idx].value then
            rfsuite.app.formFields[idx]:value(activeType)
            needsInvalidate = true
        end
        lastActiveType = activeType
        editingType = activeType
    elseif activeType ~= lastActiveType then
        lastActiveType = activeType
    end

    if editingType ~= nil and editingType ~= lastEditingType then
        if lastEditingType ~= nil then
            local currentCapacity = getFieldValue(self, "batteryCapacityActive")
            if currentCapacity then
                saveProfileCapacity(lastEditingType, currentCapacity)
            end
        end

        local capacity = getProfileCapacity(editingType)
        if capacity ~= nil then
            setFieldValue(self, "batteryCapacityActive", capacity)
            local idx = fieldIndexByApiKey["batteryCapacityActive"]
            if idx and rfsuite.app.formFields and rfsuite.app.formFields[idx] and rfsuite.app.formFields[idx].value then
                rfsuite.app.formFields[idx]:value(capacity)
                needsInvalidate = true
            end
        end
        lastEditingType = editingType
    end
    local stateKey = tostring(editingType) .. ":" .. tostring(activeType)
    if stateKey ~= lastHighlightStateKey then
        lastHighlightStateKey = stateKey
        updateDynamicUi(self, editingType, activeType)
        needsInvalidate = true
    end

    if needsInvalidate then
        lcd.invalidate()
    end
end

local function preSave(self)
    local editingType = clampProfileIndex(getFieldValue(self, "batteryProfile"))
    local capacityValue = tonumber(getFieldValue(self, "batteryCapacityActive"))
    if editingType == nil or capacityValue == nil then return end

    if capacityValue < CAPACITY_PROFILE_MIN then capacityValue = CAPACITY_PROFILE_MIN end
    if capacityValue > CAPACITY_PROFILE_MAX then capacityValue = CAPACITY_PROFILE_MAX end

    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
    local batteryValues = values and values.BATTERY_CONFIG
    if not batteryValues then return end

    local finalVal = math.floor(capacityValue + 0.5)
    batteryValues["batteryCapacity_" .. tostring(editingType)] = finalVal

    if rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.profiles then
        rfsuite.session.batteryConfig.profiles[editingType] = finalVal
    end
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

onNavMenu = function(self)
    pageRuntime.openMenuContext({defaultSection = "hardware"})
    return true
end

return {
    event = event,
    wakeup = wakeup,
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    API = {},
    postLoad = postLoad,
    preSave = preSave,
    onNavMenu = onNavMenu
}
