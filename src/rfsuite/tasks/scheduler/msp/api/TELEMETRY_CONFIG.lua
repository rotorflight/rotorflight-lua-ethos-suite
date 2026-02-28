--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "TELEMETRY_CONFIG"
local MSP_API_CMD_READ = 73
local MSP_API_CMD_WRITE = 74
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "telemetry_inverted", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telemetry_inverted)@"},
    {field = "halfDuplex", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1}, help = "@i18n(api.TELEMETRY_CONFIG.halfDuplex)@"},
    {field = "enableSensors", type = "U32", apiVersion = {12, 0, 6}, simResponse = {0, 0, 0, 0}, help = "@i18n(api.TELEMETRY_CONFIG.enableSensors)@"},
    {field = "pinSwap", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.pinSwap)@"},
    {field = "crsf_telemetry_mode", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.crsf_telemetry_mode)@"},
    {field = "crsf_telemetry_link_rate", type = "U16", apiVersion = {12, 0, 8}, simResponse = {250, 0}, help = "@i18n(api.TELEMETRY_CONFIG.crsf_telemetry_link_rate)@"},
    {field = "crsf_telemetry_link_ratio", type = "U16", apiVersion = {12, 0, 8}, simResponse = {8, 0}, help = "@i18n(api.TELEMETRY_CONFIG.crsf_telemetry_link_ratio)@"},
    {field = "telem_sensor_slot_1", type = "U8", apiVersion = {12, 0, 8}, simResponse = {3}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_1)@"},
    {field = "telem_sensor_slot_2", type = "U8", apiVersion = {12, 0, 8}, simResponse = {4}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_2)@"},
    {field = "telem_sensor_slot_3", type = "U8", apiVersion = {12, 0, 8}, simResponse = {5}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_3)@"},
    {field = "telem_sensor_slot_4", type = "U8", apiVersion = {12, 0, 8}, simResponse = {6}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_4)@"},
    {field = "telem_sensor_slot_5", type = "U8", apiVersion = {12, 0, 8}, simResponse = {8}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_5)@"},
    {field = "telem_sensor_slot_6", type = "U8", apiVersion = {12, 0, 8}, simResponse = {8}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_6)@"},
    {field = "telem_sensor_slot_7", type = "U8", apiVersion = {12, 0, 8}, simResponse = {89}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_7)@"},
    {field = "telem_sensor_slot_8", type = "U8", apiVersion = {12, 0, 8}, simResponse = {90}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_8)@"},
    {field = "telem_sensor_slot_9", type = "U8", apiVersion = {12, 0, 8}, simResponse = {91}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_9)@"},
    {field = "telem_sensor_slot_10", type = "U8", apiVersion = {12, 0, 8}, simResponse = {99}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_10)@"},
    {field = "telem_sensor_slot_11", type = "U8", apiVersion = {12, 0, 8}, simResponse = {95}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_11)@"},
    {field = "telem_sensor_slot_12", type = "U8", apiVersion = {12, 0, 8}, simResponse = {96}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_12)@"},
    {field = "telem_sensor_slot_13", type = "U8", apiVersion = {12, 0, 8}, simResponse = {60}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_13)@"},
    {field = "telem_sensor_slot_14", type = "U8", apiVersion = {12, 0, 8}, simResponse = {15}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_14)@"},
    {field = "telem_sensor_slot_15", type = "U8", apiVersion = {12, 0, 8}, simResponse = {42}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_15)@"},
    {field = "telem_sensor_slot_16", type = "U8", apiVersion = {12, 0, 8}, simResponse = {93}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_16)@"},
    {field = "telem_sensor_slot_17", type = "U8", apiVersion = {12, 0, 8}, simResponse = {50}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_17)@"},
    {field = "telem_sensor_slot_18", type = "U8", apiVersion = {12, 0, 8}, simResponse = {51}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_18)@"},
    {field = "telem_sensor_slot_19", type = "U8", apiVersion = {12, 0, 8}, simResponse = {52}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_19)@"},
    {field = "telem_sensor_slot_20", type = "U8", apiVersion = {12, 0, 8}, simResponse = {17}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_20)@"},
    {field = "telem_sensor_slot_21", type = "U8", apiVersion = {12, 0, 8}, simResponse = {18}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_21)@"},
    {field = "telem_sensor_slot_22", type = "U8", apiVersion = {12, 0, 8}, simResponse = {19}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_22)@"},
    {field = "telem_sensor_slot_23", type = "U8", apiVersion = {12, 0, 8}, simResponse = {23}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_23)@"},
    {field = "telem_sensor_slot_24", type = "U8", apiVersion = {12, 0, 8}, simResponse = {22}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_24)@"},
    {field = "telem_sensor_slot_25", type = "U8", apiVersion = {12, 0, 8}, simResponse = {36}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_25)@"},
    {field = "telem_sensor_slot_26", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_26)@"},
    {field = "telem_sensor_slot_27", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_27)@"},
    {field = "telem_sensor_slot_28", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_28)@"},
    {field = "telem_sensor_slot_29", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_29)@"},
    {field = "telem_sensor_slot_30", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_30)@"},
    {field = "telem_sensor_slot_31", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_31)@"},
    {field = "telem_sensor_slot_32", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_32)@"},
    {field = "telem_sensor_slot_33", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_33)@"},
    {field = "telem_sensor_slot_34", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_34)@"},
    {field = "telem_sensor_slot_35", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_35)@"},
    {field = "telem_sensor_slot_36", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_36)@"},
    {field = "telem_sensor_slot_37", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_37)@"},
    {field = "telem_sensor_slot_38", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_38)@"},
    {field = "telem_sensor_slot_39", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_39)@"},
    {field = "telem_sensor_slot_40", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_40)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function parseRead(buf)
    local result = nil
    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)
    if result == nil then
        return nil, "parse_failed"
    end
    return result
end

local function buildWritePayload(payloadData, _, _, state)
    local writeStructure = MSP_API_STRUCTURE_WRITE
    if writeStructure == nil then return {} end
    return core.buildWritePayload(API_NAME, payloadData, writeStructure, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minBytes = MSP_MIN_BYTES or 0,
    readStructure = MSP_API_STRUCTURE_READ,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE or {},
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = (MSP_REBUILD_ON_WRITE == true),
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
