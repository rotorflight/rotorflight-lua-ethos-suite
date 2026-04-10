--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicorev2) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/core.lua"))()
if msp and not msp.apicorev2 then
    msp.apicorev2 = core
end

local API_NAME = "VOLTAGE_METER_CONFIG"
local MSP_API_CMD_READ = 56
local MSP_API_CMD_WRITE = 57

-- Tuple layout:
--   field, type, api major, api minor, api revision, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"meter_count", "U8", 12, 0, 6},
    {"frame_length_1", "U8", 12, 0, 6},
    {"meter_id_1", "U8", 12, 0, 6},
    {"meter_type_1", "U8", 12, 0, 6},
    {"scale_1", "U16", 12, 0, 6},
    {"divider_1", "U16", 12, 0, 6},
    {"divmul_1", "U8", 12, 0, 6},
    {"frame_length_2", "U8", 12, 0, 6},
    {"meter_id_2", "U8", 12, 0, 6},
    {"meter_type_2", "U8", 12, 0, 6},
    {"scale_2", "U16", 12, 0, 6},
    {"divider_2", "U16", 12, 0, 6},
    {"divmul_2", "U8", 12, 0, 6},
    {"frame_length_3", "U8", 12, 0, 6},
    {"meter_id_3", "U8", 12, 0, 6},
    {"meter_type_3", "U8", 12, 0, 6},
    {"scale_3", "U16", 12, 0, 6},
    {"divider_3", "U16", 12, 0, 6},
    {"divmul_3", "U8", 12, 0, 6},
    {"frame_length_4", "U8", 12, 0, 6},
    {"meter_id_4", "U8", 12, 0, 6},
    {"meter_type_4", "U8", 12, 0, 6},
    {"scale_4", "U16", 12, 0, 6},
    {"divider_4", "U16", 12, 0, 6},
    {"divmul_4", "U8", 12, 0, 6}
}

-- Tuple layout:
--   field, type, api major, api minor, api revision, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"meter_id", "U8", 12, 0, 6},
    {"scale", "U16", 12, 0, 6},
    {"divider", "U16", 12, 0, 6},
    {"divmul", "U8", 12, 0, 6}
}

local SIM_RESPONSE = core.simResponse({
    4,       -- meter_count
    7,       -- frame_length_1
    0,       -- meter_id_1
    1,       -- meter_type_1
    0, 0,    -- scale_1
    1, 0,    -- divider_1
    1,       -- divmul_1
    7,       -- frame_length_2
    1,       -- meter_id_2
    1,       -- meter_type_2
    0, 0,    -- scale_2
    1, 0,    -- divider_2
    1,       -- divmul_2
    7,       -- frame_length_3
    2,       -- meter_id_3
    1,       -- meter_type_3
    0, 0,    -- scale_3
    1, 0,    -- divider_3
    1,       -- divmul_3
    7,       -- frame_length_4
    3,       -- meter_id_4
    1,       -- meter_type_4
    0, 0,    -- scale_4
    1, 0,    -- divider_4
    1        -- divmul_4
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
