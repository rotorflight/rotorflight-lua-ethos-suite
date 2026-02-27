--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    buf.offset = 1
    local flightcount = helper.readU32(buf)
    local totalflighttime = helper.readU32(buf)
    local totaldistance = helper.readU32(buf)
    local minarmedtime = helper.readS8(buf)

    if flightcount == nil or totalflighttime == nil or totaldistance == nil or minarmedtime == nil then
        return nil, "parse_failed"
    end

    return {
        parsed = {
            flightcount = flightcount,
            totalflighttime = totalflighttime,
            totaldistance = totaldistance,
            minarmedtime = minarmedtime
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

local function valueFor(payloadData, mspData, key, default)
    local value = payloadData[key]
    if value == nil and mspData and mspData.parsed then
        value = mspData.parsed[key]
    end
    if value == nil then value = default end
    return value
end

local function buildWritePayload(payloadData, mspData, helper)
    if not helper then return nil, "msp_helper_missing" end

    local payload = {}
    helper.writeU32(payload, valueFor(payloadData, mspData, "flightcount", 0))
    helper.writeU32(payload, valueFor(payloadData, mspData, "totalflighttime", 0))
    helper.writeU32(payload, valueFor(payloadData, mspData, "totaldistance", 0))
    helper.writeS8(payload, valueFor(payloadData, mspData, "minarmedtime", 0))
    return payload
end

return factory.create({
    name = "FLIGHT_STATS",
    readCmd = 14,
    writeCmd = 15,
    minBytes = 13,
    simulatorResponseRead = {123, 1, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 15},
    parseRead = parseRead,
    buildWritePayload = buildWritePayload
})
