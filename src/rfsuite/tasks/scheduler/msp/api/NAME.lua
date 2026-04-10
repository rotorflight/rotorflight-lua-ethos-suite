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

local MAX_NAME_LENGTH = 16

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"name", "U8"}
}

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    local name = ""
    buf.offset = 1
    while #name < MAX_NAME_LENGTH do
        local ch = helper.readU8(buf)
        if ch == nil or ch == 0 then break end
        name = name .. string.char(ch)
    end

    return {
        parsed = {name = name},
        buffer = buf,
        receivedBytesCount = #buf
    }
end

local function buildWritePayload(payloadData, mspData)
    local nameValue = payloadData.name
    if nameValue == nil and mspData and mspData.parsed then
        nameValue = mspData.parsed.name
    end
    if nameValue == nil then nameValue = "" end
    if type(nameValue) ~= "string" then nameValue = tostring(nameValue) end

    local payload = {}
    local length = math.min(#nameValue, MAX_NAME_LENGTH)
    for i = 1, length do
        payload[#payload + 1] = string.byte(nameValue, i)
    end
    return payload
end

local SIM_RESPONSE = core.simResponse({
    80,  -- P
    105, -- i
    108, -- l
    111, -- o
    116  -- t
})

return core.createConfigAPI({
    name = "NAME",
    readCmd = 10,
    writeCmd = 11,
    minApiVersion = {12, 0, 6},
    fields = FIELD_SPEC,
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    simulatorResponseRead = SIM_RESPONSE
})
