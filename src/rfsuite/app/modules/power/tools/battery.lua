--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local log = rfsuite.utils.log
local lastActiveBatteryType = nil

local fields = {
    {t = "@i18n(app.modules.power.max_cell_voltage)@",           mspapi = 1, apikey = "vbatmaxcellvoltage"},
    {t = "@i18n(app.modules.power.full_cell_voltage)@",          mspapi = 1, apikey = "vbatfullcellvoltage"},
    {t = "@i18n(app.modules.power.warn_cell_voltage)@",          mspapi = 1, apikey = "vbatwarningcellvoltage"},
    {t = "@i18n(app.modules.power.min_cell_voltage)@",           mspapi = 1, apikey = "vbatmincellvoltage"},
}

fields[#fields + 1] = {t = "@i18n(app.modules.power.battery_capacity)@",           mspapi = 1, apikey = "batteryCapacity", hidden = rfsuite.utils.apiVersionCompare(">=", "12.10.0")}

fields[#fields + 1] = {t = "@i18n(app.modules.power.battery_capacity)@ 0",         mspapi = 1, apikey = "batteryCapacity_0", apiVersion = {12, 10, 0}}
fields[#fields + 1] = {t = "@i18n(app.modules.power.battery_capacity)@ 1",         mspapi = 1, apikey = "batteryCapacity_1", apiVersion = {12, 10, 0}}
fields[#fields + 1] = {t = "@i18n(app.modules.power.battery_capacity)@ 2",         mspapi = 1, apikey = "batteryCapacity_2", apiVersion = {12, 10, 0}}
fields[#fields + 1] = {t = "@i18n(app.modules.power.battery_capacity)@ 3",         mspapi = 1, apikey = "batteryCapacity_3", apiVersion = {12, 10, 0}}
fields[#fields + 1] = {t = "@i18n(app.modules.power.battery_capacity)@ 4",         mspapi = 1, apikey = "batteryCapacity_4", apiVersion = {12, 10, 0}}
fields[#fields + 1] = {t = "@i18n(app.modules.power.battery_capacity)@ 5",         mspapi = 1, apikey = "batteryCapacity_5", apiVersion = {12, 10, 0}}
fields[#fields + 1] = {t = "@i18n(api.BATTERY_CONFIG.batteryType)@",               mspapi = 2, apikey = "batteryType",       apiVersion = {12, 10, 0}, postEdit = function() rfsuite.app.triggers.reload = true end}

fields[#fields + 1] = {t = "@i18n(app.modules.power.cell_count)@",                 mspapi = 1, apikey = "batteryCellCount"}
fields[#fields + 1] = {t = "@i18n(app.modules.power.consumption_warning_percentage)@", min = 15, max = 60, mspapi = 1, apikey = "consumptionWarningPercentage"}

local apidata = {
    api = {
        [1] = 'BATTERY_CONFIG',
        [2] = 'BATTERY_TYPE',
    },
    formdata = {
        labels = {},
        fields = fields
    }
}

local function postLoad(self)
    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "consumptionWarningPercentage" then
            local v = tonumber(f.value)
            if v then
                if v < 15 then
                    f.value = 35
                elseif v > 60 then
                    f.value = 35
                end
            end
        end
    end
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function wakeup(self)
    if enableWakeup == false then return end

    local active = rfsuite.session.activeBatteryType
    if active == nil then return end

    local currentLine = 0
    local lastLabel = nil
    local dirty = false

    print("Active battery type: %s", tostring(active))
    for i, f in ipairs(self.apidata.formdata.fields) do
        local valid = true
        if f.apiVersion and not rfsuite.utils.apiVersionCompare(">=", f.apiVersion) then valid = false end
        print("Processing field: %s (apikey: %s, valid: %s)", tostring(f.t), tostring(f.apikey), tostring(valid))
        if f.hidden ~= true and valid then
            if f.label and f.label ~= lastLabel then
                currentLine = currentLine + 1
                lastLabel = f.label
            end

            currentLine = currentLine + 1
            print("Checking field '%s' (apikey: %s) on line %d", tostring(f.t), tostring(f.apikey), currentLine)
            if f.apikey and f.apikey:match("batteryCapacity_%d") then
                local idx = tonumber(f.apikey:match("batteryCapacity_(%d)"))
                local lineObj = rfsuite.app.formLines[currentLine]
                if lineObj then
                    print("Updating field '%s' (apikey: %s) on line %d with active battery type %d", tostring(f.t), tostring(f.apikey), currentLine, active)
                    local suffix = (idx == active) and " *" or ""
                    local original = f.t:gsub(" %*$", ""):gsub("^%* ", "")
                    local newText = original .. suffix
                    if f.t ~= newText then
                        print("Changing field text from '%s' to '%s'", tostring(f.t), tostring(newText))
                        f.t = newText
                        pcall(function() lineObj:name(newText) end)
                        dirty = true
                    end
                end
            end
        end
    end

    if dirty and form.invalidate then form.invalidate() end
end


local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

onNavMenu = function(self)
    pageRuntime.openMenuContext({defaultSection = "hardware"})
    return true
end


return {event = event, wakeup = wakeup, apidata = apidata, eepromWrite = true, reboot = false, API = {}, postLoad = postLoad, onNavMenu = onNavMenu}
