--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local FIELD_ORDER = {"aileron", "elevator", "rudder", "collective", "throttle", "aux1", "aux2", "aux3"}

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    buf.offset = 1
    local parsed = {}
    for i = 1, #FIELD_ORDER do
        local value = helper.readU8(buf)
        if value == nil then return nil, "parse_failed" end
        parsed[FIELD_ORDER[i]] = value
    end

    return {
        parsed = parsed,
        buffer = buf,
        receivedBytesCount = #buf
    }
end

local function buildWritePayload(payloadData, mspData, helper)
    if not helper then return nil, "msp_helper_missing" end

    local payload = {}
    for i = 1, #FIELD_ORDER do
        local key = FIELD_ORDER[i]
        local value = payloadData[key]
        if value == nil and mspData and mspData.parsed then
            value = mspData.parsed[key]
        end
        if value == nil then
            value = i - 1
        end
        helper.writeU8(payload, value)
    end

    return payload
end

return factory.create({
    name = "RX_MAP",
    readCmd = 64,
    writeCmd = 65,
    minBytes = 8,
    simulatorResponseRead = {0, 1, 2, 3, 4, 5, 6, 7},
    parseRead = parseRead,
    buildWritePayload = buildWritePayload
})
