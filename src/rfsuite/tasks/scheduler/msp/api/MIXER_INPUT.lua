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

local API_NAME = "MIXER_INPUT"
local MSP_API_CMD_READ = 170
local MSP_API_CMD_WRITE = 171
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {

    -- 0: MIXER_IN_NONE
    { field = "rate_none", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 0, 0 } },
    { field = "min_none",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 0, 0 } },
    { field = "max_none",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 0, 0 } },

    -- 1: MIXER_IN_STABILIZED_ROLL
    { field = "rate_stabilized_roll", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 }, tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_roll",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_stabilized_roll",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 2: MIXER_IN_STABILIZED_PITCH
    { field = "rate_stabilized_pitch", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } , tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_pitch",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_stabilized_pitch",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 3: MIXER_IN_STABILIZED_YAW
    { field = "rate_stabilized_yaw", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } , tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_yaw",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_stabilized_yaw",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 4: MIXER_IN_STABILIZED_COLLECTIVE
    { field = "rate_stabilized_collective", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } , tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_collective",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_stabilized_collective",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 5: MIXER_IN_STABILIZED_THROTTLE
    { field = "rate_stabilized_throttle", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_stabilized_throttle",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_stabilized_throttle",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 6: MIXER_IN_RC_COMMAND_ROLL
    { field = "rate_rc_command_roll", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_command_roll",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_command_roll",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 7: MIXER_IN_RC_COMMAND_PITCH
    { field = "rate_rc_command_pitch", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_command_pitch",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_command_pitch",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 8: MIXER_IN_RC_COMMAND_YAW
    { field = "rate_rc_command_yaw", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_command_yaw",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_command_yaw",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 9: MIXER_IN_RC_COMMAND_COLLECTIVE
    { field = "rate_rc_command_collective", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_command_collective",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_command_collective",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 10: MIXER_IN_RC_COMMAND_THROTTLE
    { field = "rate_rc_command_throttle", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_command_throttle",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_command_throttle",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 11: MIXER_IN_RC_CHANNEL_ROLL
    { field = "rate_rc_channel_roll", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_roll",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_roll",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 12: MIXER_IN_RC_CHANNEL_PITCH
    { field = "rate_rc_channel_pitch", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_pitch",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_pitch",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 13: MIXER_IN_RC_CHANNEL_YAW
    { field = "rate_rc_channel_yaw", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_yaw",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_yaw",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 14: MIXER_IN_RC_CHANNEL_COLLECTIVE
    { field = "rate_rc_channel_collective", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_collective",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_collective",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 15: MIXER_IN_RC_CHANNEL_THROTTLE
    { field = "rate_rc_channel_throttle", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_throttle",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_throttle",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 16–18: AUX
    { field = "rate_rc_channel_aux1", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_aux1",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_aux1",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_aux2", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_aux2",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_aux2",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_aux3", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_aux3",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_aux3",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    -- 19–28: RC channels 9–18
    { field = "rate_rc_channel_9",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_9",   type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_9",   type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_10", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_10",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_10",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_11", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_11",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_11",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_12", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_12",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_12",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_13", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_13",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_13",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_14", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_14",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_14",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_15", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_15",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_15",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_16", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_16",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_16",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_17", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_17",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_17",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_18", type = "U16", apiVersion = {12, 0, 6}, simResponse = { 250, 0 } },
    { field = "min_rc_channel_18",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 30, 251 } },
    { field = "max_rc_channel_18",  type = "U16", apiVersion = {12, 0, 6}, simResponse = { 226, 4 } },
}

-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    -- mixer input index
    { field = "index", type = "U8" },

    -- mixer input values
    { field = "rate",  type = "U16" },
    { field = "min",   type = "U16" },
    { field = "max",   type = "U16" },
}
-- LuaFormatter on

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
