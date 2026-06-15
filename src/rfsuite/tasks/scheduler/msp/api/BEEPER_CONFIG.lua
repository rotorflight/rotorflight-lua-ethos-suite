--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "BEEPER_CONFIG"
local MSP_API_CMD_READ = 184
local MSP_API_CMD_WRITE = 185

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"beeper_off_flags", "U32"},
    {"dshotBeaconTone", "U8"},
    {"dshotBeaconOffFlags", "U32", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false}
}

local SIM_RESPONSE = core.simResponse({
    0, 0, 0, 0, -- beeper_off_flags
    1,          -- dshotBeaconTone
    0, 0, 0, 0  -- dshotBeaconOffFlags
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
