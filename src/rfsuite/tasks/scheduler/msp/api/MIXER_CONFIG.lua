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

local API_NAME = "MIXER_CONFIG"
local MSP_API_CMD_READ = 42
local MSP_API_CMD_WRITE = 43
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "main_rotor_dir", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, table = {"@i18n(api.MIXER_CONFIG.tbl_cw)@", "@i18n(api.MIXER_CONFIG.tbl_ccw)@"}, tableIdxInc = -1},
    { field = "tail_rotor_mode", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, table = {"@i18n(api.MIXER_CONFIG.tbl_tail_variable_pitch)@", "@i18n(api.MIXER_CONFIG.tbl_tail_motororized_tail)@", "@i18n(api.MIXER_CONFIG.tbl_tail_bidirectional)@"}, tableIdxInc = -1},
    { field = "tail_motor_idle", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, default = 0, unit = "%", min = 0, max = 250, decimals = 1, scale = 10},
    { field = "tail_center_trim", type = "S16", apiVersion = {12, 0, 6}, simResponse = {165, 1}, unit = "%", default = 0, min = -500, max = 500, decimals = 1, scale = 10, mult = 0.239923224568138},
    { field = "swash_type", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, table = {"None", "Direct", "CPPM 120", "CPPM 135", "CPPM 140", "FPM 90 L", "FPM 90 V"}, tableIdxInc = -1},
    { field = "swash_ring", type = "U8", apiVersion = {12, 0, 6}, simResponse = {2}},
    { field = "swash_phase", type = "S16", apiVersion = {12, 0, 6}, simResponse = {100, 0}, unit = "°", default = 0, min = -1800, max = 1800, decimals = 1, scale = 10},
    { field = "swash_pitch_limit", type = "U16", apiVersion = {12, 0, 6}, simResponse = {131, 6}, unit = "°", default = 0, min = 0, max = 360, decimals = 1, step = 1, mult = 0.01200192},
    { field = "swash_trim_0", type = "S16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, unit = "%", default = 0, min = -1000, max = 1000, decimals = 1, scale = 10},
    { field = "swash_trim_1", type = "S16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, unit = "%", default = 0, min = -1000, max = 1000, decimals = 1, scale = 10},
    { field = "swash_trim_2", type = "S16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, unit = "%", default = 0, min = -1000, max = 1000, decimals = 1, scale = 10},
    { field = "swash_tta_precomp", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, default = 0, min = 0, max = 250},
    { field = "swash_geo_correction", type = "S8", apiVersion = {12, 0, 7}, simResponse = {10}, unit = "%",default = 0, min = -250, max = 250, decimals = 1, scale = 5, step = 2},
    { field = "collective_tilt_correction_pos", type = "S8", apiVersion = {12, 0, 8}, simResponse = {3}, unit = "°", default = 0, min = -100, max = 100},
    { field = "collective_tilt_correction_neg", type = "S8", apiVersion = {12, 0, 8}, simResponse = {11}, unit = "°", default = 10, min = -100, max = 100},
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
