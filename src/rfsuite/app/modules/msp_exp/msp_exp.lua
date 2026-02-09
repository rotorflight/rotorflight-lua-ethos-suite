--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local fields = {}
local total_bytes = rfsuite.preferences.developer.mspexpbytes
local fieldMap = {}

local int8_dirty = false
local uint8_dirty = false
local enableWakeup = false

local function uint8_to_int8(value)
    if type(value) ~= "number" then error("uint8_to_int8: value is not a number (got " .. tostring(value) .. ")") end
    if value < 0 or value > 255 then error("Value out of uint8 range") end
    if value > 127 then
        return value - 256
    else
        return value
    end
end

local function int8_to_uint8(value) return value & 0xFF end

local function buildFieldMap()
    fieldMap = {}
    for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields or {}) do
        if not fieldMap[field.label] then fieldMap[field.label] = {} end
        table.insert(fieldMap[field.label], field)
    end
end

local function safeFieldValue(field)
    if field.value == nil then return 0 end
    return field.value
end

local function update_int8()
    if not uint8_dirty then return end
    uint8_dirty = false

    for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields or {}) do if field.isINT8 then for _, match in ipairs(fieldMap[field.label] or {}) do if match.isUINT8 then field.value = uint8_to_int8(safeFieldValue(match)) end end end end
end

local function update_uint8()
    if not int8_dirty then return end
    int8_dirty = false

    for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields or {}) do if field.isUINT8 then for _, match in ipairs(fieldMap[field.label] or {}) do if match.isINT8 then field.value = int8_to_uint8(safeFieldValue(match)) end end end end
end

local function generateMSPAPI(numLabels)

    if numLabels > 16 then numLabels = 16 end

    local apidata = {api = {'EXPERIMENTAL'}, formdata = {labels = {}, fields = {}}}

    for i = 1, numLabels do
        table.insert(apidata.formdata.labels, {t = tostring(i), inline_size = 17, label = i})

        table.insert(apidata.formdata.fields, {t = "UINT8", isUINT8 = true, label = i, inline = 2, mspapi = 1, apikey = "exp_uint" .. i, min = 0, max = 255, onChange = function() uint8_dirty = true end})

        table.insert(apidata.formdata.fields, {t = "INT8", isINT8 = true, label = i, inline = 1, mspapi = 1, apikey = "exp_int" .. i, min = -128, max = 127, onChange = function() int8_dirty = true end})
    end

    return apidata
end

local apidata = generateMSPAPI(rfsuite.preferences.developer.mspexpbytes)

local function periodicSync()
    update_int8()
    update_uint8()
end

local function postLoad()

    fieldMap = {}
    int8_dirty = false
    uint8_dirty = true
    enableWakeup = false

    if rfsuite.tasks.msp.api.apidata.receivedBytesCount['EXPERIMENTAL'] == 0 then
        rfsuite.app.triggers.closeProgressLoader = true
        rfsuite.app.ui.disableAllFields()
        rfsuite.app.ui.disableAllNavigationFields()
        rfsuite.app.ui.enableNavigationField('menu')
        return
    end

    if total_bytes ~= rfsuite.tasks.msp.api.apidata.receivedBytesCount['EXPERIMENTAL'] then

        rfsuite.preferences.developer.mspexpbytes = rfsuite.tasks.msp.api.apidata.receivedBytesCount['EXPERIMENTAL']
        rfsuite.app.triggers.reloadFull = true
    end

    buildFieldMap()

    uint8_dirty = true

    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function wakeup()
    if not enableWakeup or not rfsuite.app.Page or not rfsuite.app.Page.apidata.formdata.fields then return end
    periodicSync()
end

local function preUnload() enableWakeup = false end

return {apidata = apidata, title = "Experimental", navButtons = {menu = true, save = true, reload = true, help = true}, eepromWrite = true, postLoad = postLoad, wakeup = wakeup, preUnload = preUnload, API = {}}
