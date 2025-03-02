local fields = {}
local rows = {}
local cols = {}

local total_bytes = rfsuite.preferences.mspExpBytes
local fieldMap = {}

-- Dirty flags and enable control
local int8_dirty = false
local uint8_dirty = false
local enableWakeup = false

-- Utility Functions
local function uint8_to_int8(value)
    if type(value) ~= "number" then
        error("uint8_to_int8: value is not a number (got " .. tostring(value) .. ")")
    end
    if value < 0 or value > 255 then error("Value out of uint8 range") end
    if value > 127 then
        return value - 256
    else
        return value
    end
end

local function int8_to_uint8(value)
    return value & 0xFF
end

-- Build or rebuild the field lookup map (maps label -> list of fields)
local function buildFieldMap()
    fieldMap = {}
    for _, field in ipairs(rfsuite.app.Page.fields or {}) do
        if not fieldMap[field.label] then
            fieldMap[field.label] = {}
        end
        table.insert(fieldMap[field.label], field)
    end
end

-- Safe field value getter
local function safeFieldValue(field)
    if field.value == nil then
        return 0
    end
    return field.value
end

-- Update all int8 fields from uint8 fields (with guard)
local function update_int8()
    if not uint8_dirty then
        return
    end
    uint8_dirty = false

    for _, field in ipairs(rfsuite.app.Page.fields or {}) do
        if field.isINT8 then
            for _, match in ipairs(fieldMap[field.label] or {}) do
                if match.isUINT8 then
                    field.value = uint8_to_int8(safeFieldValue(match))
                end
            end
        end
    end
end

-- Update all uint8 fields from int8 fields (with guard)
local function update_uint8()
    if not int8_dirty then
        return
    end
    int8_dirty = false

    for _, field in ipairs(rfsuite.app.Page.fields or {}) do
        if field.isUINT8 then
            for _, match in ipairs(fieldMap[field.label] or {}) do
                if match.isINT8 then
                    field.value = int8_to_uint8(safeFieldValue(match))
                end
            end
        end
    end
end

-- Generates the MSP API structure
local function generateMSPAPI(numLabels)

    -- prevent overage
    if numLabels > 16 then
        numLabels = 16
    end
        
    local mspapi = {
        api = {'EXPERIMENTAL'},
        formdata = {labels = {}, fields = {}}
    }

    for i = 1, numLabels do
        table.insert(mspapi.formdata.labels, {t = tostring(i), inline_size = 17, label = i})

        table.insert(mspapi.formdata.fields, {
            t = "UINT8", isUINT8 = true, label = i, inline = 2, mspapi = 1, apikey = "exp_uint" .. i,
            min = 0, max = 255,
            onChange = function() uint8_dirty = true end
        })

        table.insert(mspapi.formdata.fields, {
            t = "INT8", isINT8 = true, label = i, inline = 1, mspapi = 1, apikey = "exp_int" .. i,
            min = -128, max = 127,
            onChange = function() int8_dirty = true end
        })
    end

    return mspapi
end

-- Init API
local mspapi = generateMSPAPI(rfsuite.preferences.mspExpBytes)

-- Periodic updater (called each wakeup)
local function periodicSync()
    update_int8()
    update_uint8()
end

-- Full reset on page load (handles reloads gracefully)
local function postLoad()

    -- Hard reset everything to avoid stale state
    fieldMap = {}
    int8_dirty = false
    uint8_dirty = true
    enableWakeup = false

    if total_bytes ~= rfsuite.app.Page.mspapi.receivedBytesCount['EXPERIMENTAL'] then

        rfsuite.preferences.mspExpBytes = rfsuite.app.Page.mspapi.receivedBytesCount['EXPERIMENTAL']
        rfsuite.app.triggers.reloadFull = true
    end

    buildFieldMap()

    -- Force an initial sync (this primes int8 values)
    uint8_dirty = true

    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
end

-- Called periodically by framework (acts as "tick")
local function wakeup()
    if not enableWakeup or not rfsuite.app.Page or not rfsuite.app.Page.fields then
        return
    end
    periodicSync()
end

-- Optional (if your system supports cleanup on exit):
local function preUnload()
    enableWakeup = false  -- Disable to avoid running wakeup() on stale data
end

-- Return page definition
return {
    mspapi = mspapi,
    title = "Experimental",
    navButtons = {menu = true, save = true, reload = true, help = true},
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    preUnload = preUnload,  -- Optional, add only if your system supports
    API = {},
}
