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

local os_time = os.time

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"year", "U16"},
    {"month", "U8"},
    {"day", "U8"},
    {"hours", "U8"},
    {"minutes", "U8"},
    {"seconds", "U8"},
    {"milliseconds", "U16"}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"seconds", "U32"},
    {"milliseconds", "U16"}
}

local function buildWritePayload(payloadData, _, helper)
    if not helper then return nil end

    local payload = {}
    local seconds = payloadData.seconds
    local milliseconds = payloadData.milliseconds
    if seconds == nil then seconds = os_time() end
    if milliseconds == nil then milliseconds = 0 end

    helper.writeU32(payload, seconds)
    helper.writeU16(payload, milliseconds)
    return payload
end

local SIM_RESPONSE = core.simResponse({
    233, 7, -- year
    1,      -- month
    1,      -- day
    0,      -- hours
    0,      -- minutes
    0,      -- seconds
    0, 0    -- milliseconds
})

return core.createConfigAPI({
    name = "RTC",
    readCmd = 247,
    writeCmd = 246,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    buildWritePayload = buildWritePayload,
    simulatorResponseRead = SIM_RESPONSE
})
