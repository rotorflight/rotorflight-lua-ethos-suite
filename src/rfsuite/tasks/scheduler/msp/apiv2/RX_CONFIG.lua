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

local API_NAME = "RX_CONFIG"
local MSP_API_CMD_READ = 44
local MSP_API_CMD_WRITE = 45

-- Tuple layout:
--   field, type, api major, api minor, api revision, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"serialrx_provider", "U8", 12, 0, 6},
    {"serialrx_inverted", "U8", 12, 0, 6},
    {"halfDuplex", "U8", 12, 0, 6},
    {"rx_pulse_min", "U16", 12, 0, 6, nil, nil, nil, "us"},
    {"rx_pulse_max", "U16", 12, 0, 6, nil, nil, nil, "us"},
    {"rx_spi_protocol", "U8", 12, 0, 6},
    {"rx_spi_id", "U32", 12, 0, 6},
    {"rx_spi_rf_channel_count", "U8", 12, 0, 6},
    {"pinSwap", "U8", 12, 0, 6}
}

local SIM_RESPONSE = core.simResponse({
    0,             -- serialrx_provider
    0,             -- serialrx_inverted
    0,             -- halfDuplex
    107, 3,        -- rx_pulse_min
    77, 8,         -- rx_pulse_max
    0,             -- rx_spi_protocol
    0, 0, 0, 0,    -- rx_spi_id
    0,             -- rx_spi_rf_channel_count
    0              -- pinSwap
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
