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

local API_NAME = "CURRENT_METER_CONFIG"
local MSP_API_CMD_READ = 40
local MSP_API_CMD_WRITE = 41

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"meter_count", "U8"},
    {"frame_length", "U8"},
    {"meter_id", "U8"},
    {"meter_type", "U8"},
    {"scale", "U16"},
    {"offset", "U16"}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"meter_id", "U8"},
    {"scale", "U16"},
    {"offset", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    1,    -- meter_count
    6,    -- frame_length
    0,    -- meter_id
    1,    -- meter_type
    0, 0, -- scale
    0, 0  -- offset
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
