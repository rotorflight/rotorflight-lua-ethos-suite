--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local MAX_NAME_LENGTH = 16

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

return factory.create({
    name = "NAME",
    readCmd = 10,
    writeCmd = 11,
    minBytes = 0,
    simulatorResponseRead = {80, 105, 108, 111, 116},
    parseRead = parseRead,
    buildWritePayload = buildWritePayload
})
