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

local API_NAME = "VTXTABLE_BAND"
local OPTIONAL = false

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"band", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_length", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_1", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_2", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_3", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_4", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_5", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_6", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_7", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"name_8", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"band_letter", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"is_factory_band", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"channel_count", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_1", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_2", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_3", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_4", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_5", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_6", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_7", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"freq_8", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"band", "U8"},
    {"name_length", "U8"},
    {"name_1", "U8"},
    {"name_2", "U8"},
    {"name_3", "U8"},
    {"name_4", "U8"},
    {"name_5", "U8"},
    {"name_6", "U8"},
    {"name_7", "U8"},
    {"name_8", "U8"},
    {"band_letter", "U8"},
    {"is_factory_band", "U8"},
    {"channel_count", "U8"},
    {"freq_1", "U16"},
    {"freq_2", "U16"},
    {"freq_3", "U16"},
    {"freq_4", "U16"},
    {"freq_5", "U16"},
    {"freq_6", "U16"},
    {"freq_7", "U16"},
    {"freq_8", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    1, -- band
    8, -- name_length
    65, -- name_1
    66, -- name_2
    67, -- name_3
    68, -- name_4
    69, -- name_5
    70, -- name_6
    71, -- name_7
    72, -- name_8
    65, -- band_letter
    1, -- is_factory_band
    8, -- channel_count
    100, 22, -- freq_1
    120, 22, -- freq_2
    140, 22, -- freq_3
    160, 22, -- freq_4
    180, 22, -- freq_5
    200, 22, -- freq_6
    220, 22, -- freq_7
    240, 22  -- freq_8
})

local function buildReadPayload(payloadData, _, _, _, band)
    local readBand = tonumber(band)
    if readBand == nil then
        readBand = tonumber(payloadData.band)
    end
    if readBand == nil then
        readBand = 1
    end

    return {readBand}
end

return core.createConfigAPI({
    name = API_NAME,
    readCmd = 137,
    writeCmd = 227,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    buildReadPayload = buildReadPayload,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
