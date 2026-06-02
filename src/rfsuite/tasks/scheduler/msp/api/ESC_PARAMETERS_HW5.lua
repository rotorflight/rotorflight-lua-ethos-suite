--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local API_NAME = "ESC_PARAMETERS_HW5"
local MSP_SIGNATURE = 0xFD
local MSP_HEADER_BYTES = 2

local flightMode = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_fixedwing)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_heliext)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_heligov)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_helistore)@"}
local rotation = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_ccw)@"}
local lipoCellCount = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_autocalculate)@", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "11S", "12S", "13S", "14S"}
local cutoffType = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_softcutoff)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_hardcutoff)@"}
local cutoffVoltage = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "2.8", "2.9", "3.0", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8"}
local restartTime = {"1s", "1.5s", "2s", "2.5s", "3s"}
local responseTime = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
local startupPower = {"1", "2", "3", "4", "5", "6", "7"}
local enabledDisabled = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_enabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@"}
local brakeType = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_proportional)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_reverse)@"}

local BASE_POS = {
    esc_signature = {start = 1, size = 1},
    esc_command = {start = 2, size = 1},
    firmware_version = {start = 3, size = 16},
    hardware_version = {start = 19, size = 16},
    esc_type = {start = 35, size = 16},
    mode_name = {start = 51, size = 15}
}

local DEFAULT_ITEMS = {
    flight_mode = 1,
    lipo_cell_count = 2,
    volt_cutoff_type = 3,
    cutoff_voltage = 4,
    bec_voltage = 5,
    startup_time = 6,
    gov_p_gain = 7,
    gov_i_gain = 8,
    auto_restart = 9,
    restart_time = 10,
    brake_type = 11,
    brake_force = 12,
    timing = 13,
    rotation = 14,
    active_freewheel = 15,
    startup_power = 16
}

local OPTO_ITEMS = {
    flight_mode = 1,
    lipo_cell_count = 2,
    volt_cutoff_type = 3,
    cutoff_voltage = 4,
    startup_time = 5,
    gov_p_gain = 6,
    gov_i_gain = 7,
    auto_restart = 8,
    restart_time = 9,
    brake_type = 10,
    brake_force = 11,
    timing = 12,
    rotation = 13,
    active_freewheel = 14,
    startup_power = 15
}

local HW1128_ITEMS = {
    lipo_cell_count = 1,
    volt_cutoff_type = 2,
    cutoff_voltage = 3,
    brake_type = 5,
    brake_force = 6,
    timing = 7,
    rotation = 8,
    active_freewheel = 9,
    startup_power = 10
}

local HW1132_ITEMS = {
    lipo_cell_count = 1,
    volt_cutoff_type = 2,
    cutoff_voltage = 3,
    bec_voltage = 4,
    response_time = 5,
    timing = 6,
    rotation = 7,
    active_freewheel = 8,
    startup_power = 9
}

--[[
    Maintenance note:
    Keep this API module focused on the raw HW5 MSP payload and generic field bounds.

    Model-specific option lists and field availability are owned by the client/page layer
    in app/modules/esc_tools/tools/escmfg/hw5/profile.lua.
]] --

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"firmware_version", "U128"},
    {"hardware_version", "U128"},
    {"esc_type", "U128"},
    {"mode_name", "U120"},
    {"flight_mode", "U8", 0, #flightMode, 0, nil, nil, nil, nil, nil, flightMode, -1},
    {"lipo_cell_count", "U8", 0, #lipoCellCount, 0, nil, nil, nil, nil, nil, lipoCellCount, -1},
    {"volt_cutoff_type", "U8", 0, #cutoffType, 0, nil, nil, nil, nil, nil, cutoffType, -1},
    {"cutoff_voltage", "U8", 0, #cutoffVoltage, 3, nil, nil, nil, nil, nil, cutoffVoltage, -1},
    {"bec_voltage", "U8", 0, 70, 0},
    {"startup_time", "U8", 4, 25, 0, "s"},
    {"response_time", "U8", 0, #responseTime, 0, nil, nil, nil, nil, nil, responseTime, -1},
    {"gov_p_gain", "U8", 0, 9, 0},
    {"gov_i_gain", "U8", 0, 9, 0},
    {"auto_restart", "U8", 0, 90, 25},
    {"restart_time", "U8", 0, #restartTime, 1, nil, nil, nil, nil, nil, restartTime, -1},
    {"brake_type", "U8", 0, #brakeType, 0, nil, nil, nil, nil, nil, brakeType, -1, nil, nil, nil, nil, {76}},
    {"brake_force", "U8", 0, 100, 0},
    {"timing", "U8", 0, 30, 0},
    {"rotation", "U8", 0, #rotation, 0, nil, nil, nil, nil, nil, rotation, -1},
    {"active_freewheel", "U8", 0, #enabledDisabled, 0, nil, nil, nil, nil, nil, enabledDisabled, -1},
    {"startup_power", "U8", 0, #startupPower, 2, nil, nil, nil, nil, nil, startupPower, -1}
}

local WRITE_STRUCTURE = core.buildStructure(FIELD_SPEC)

local SIM_RESPONSE = core.simResponse({
    253, -- esc_signature
    0, -- esc_command
    32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32, -- firmware_version
    72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66, -- hardware_version
    80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32, -- esc_type
    80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32, -- mode_name
    0, -- flight_mode
    0, -- lipo_cell_count
    0, -- volt_cutoff_type
    3, -- cutoff_voltage
    0, -- bec_voltage
    11, -- startup_time
    1, -- response_time
    6, -- gov_p_gain
    5, -- gov_i_gain
    25, -- auto_restart
    1, -- restart_time
    0, -- brake_type
    0, -- brake_force
    24, -- timing
    0, -- rotation
    0, -- active_freewheel
    2 -- startup_power
})

local function readString(buf, start, length)
    local chars = {}
    for i = 0, length - 1 do
        local byte = buf[start + i] or 0
        if byte ~= 0 then
            chars[#chars + 1] = string.char(byte)
        end
    end
    return table.concat(chars)
end

local function readBytesAsUInt(buf, start, length)
    local value = 0
    for i = length - 1, 0, -1 do
        value = value * 256 + (buf[start + i] or 0)
    end
    return value
end

local function copyPositionMap()
    local positionmap = {}
    for name, pos in pairs(BASE_POS) do
        positionmap[name] = {start = pos.start, size = pos.size}
    end
    return positionmap
end

local function hasToken(text, token)
    return type(text) == "string" and text:upper():find(token, 1, true) ~= nil
end

local function selectItemLayout(hardware, escType)
    if hasToken(escType, "OPTO") then
        return OPTO_ITEMS
    end
    if hasToken(hardware, "HW1128") then
        return HW1128_ITEMS
    end
    if hasToken(hardware, "HW1132") then
        return HW1132_ITEMS
    end
    return DEFAULT_ITEMS
end

local function parseRead(buf)
    local hardware = readString(buf, BASE_POS.hardware_version.start, BASE_POS.hardware_version.size)
    local escType = readString(buf, BASE_POS.esc_type.start, BASE_POS.esc_type.size)
    local itemLayout = selectItemLayout(hardware, escType)
    local positionmap = copyPositionMap()
    local parsed = {}

    for name, pos in pairs(BASE_POS) do
        parsed[name] = readBytesAsUInt(buf, pos.start, pos.size)
    end

    for name, itemIndex in pairs(itemLayout) do
        local pos = BASE_POS.mode_name.start + BASE_POS.mode_name.size + itemIndex - 1
        parsed[name] = buf[pos] or 0
        positionmap[name] = {start = pos, size = 1}
    end

    return {
        parsed = parsed,
        buffer = buf,
        positionmap = positionmap,
        receivedBytesCount = #buf,
        other = {
            hardware_version_text = hardware,
            esc_type_text = escType
        }
    }
end

local function getEditableFields()
    local editableFields = {}
    local app = rfsuite.app
    local page = app and app.Page
    local fields = page and page.apidata and page.apidata.formdata and page.apidata.formdata.fields
    local formFields = app and app.formFields

    if type(fields) ~= "table" or type(formFields) ~= "table" then
        return editableFields
    end

    for idx in pairs(formFields) do
        local pageField = fields[idx]
        local apikey = pageField and pageField.apikey
        if apikey then
            editableFields[apikey:match("([^%-]+)%-%>") or apikey] = true
        end
    end

    return editableFields
end

local function buildWritePayload(payloadData, mspData)
    local apidata = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata
    local receivedBytes = (mspData and mspData.buffer) or (apidata and apidata.receivedBytes and apidata.receivedBytes[API_NAME])
    local receivedBytesCount = (mspData and mspData.receivedBytesCount) or (apidata and apidata.receivedBytesCount and apidata.receivedBytesCount[API_NAME])

    if not receivedBytes or not receivedBytesCount then
        return core.buildFullPayload(API_NAME, payloadData, WRITE_STRUCTURE)
    end

    local hardware = readString(receivedBytes, BASE_POS.hardware_version.start, BASE_POS.hardware_version.size)
    local escType = readString(receivedBytes, BASE_POS.esc_type.start, BASE_POS.esc_type.size)
    local itemLayout = selectItemLayout(hardware, escType)
    local editableFields = getEditableFields()
    local byteStream = {}

    for i = 1, receivedBytesCount do
        byteStream[i] = receivedBytes[i] or 0
    end

    for name, itemIndex in pairs(itemLayout) do
        if editableFields[name] then
            local pos = BASE_POS.mode_name.start + BASE_POS.mode_name.size + itemIndex - 1
            if pos <= receivedBytesCount then
                byteStream[pos] = math.floor((payloadData[name] or 0) + 0.5)
            end
        end
    end

    return byteStream
end

return core.createConfigAPI({
    name = API_NAME,
    minApiVersion = {12, 0, 7},
    readCmd = 217,
    writeCmd = 218,
    fields = FIELD_SPEC,
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = false,
    readCompleteOnErrorReplyAttempt = 2,
    exports = {
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = SIM_RESPONSE
    }
})
