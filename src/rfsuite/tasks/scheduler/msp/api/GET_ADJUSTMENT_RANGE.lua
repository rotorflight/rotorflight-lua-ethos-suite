--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "GET_ADJUSTMENT_RANGE"

local function buildReadPayload(_, _, _, _, slotIndex)
    slotIndex = tonumber(slotIndex) or 1
    if slotIndex < 1 then slotIndex = 1 end
    return {slotIndex - 1}
end

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end
    if type(buf) ~= "table" then return nil, "missing_buffer" end

    buf.offset = 1

    local adjFunction = helper.readU8(buf)
    if adjFunction == nil then return nil, "missing_adjustment_function" end

    local enaChannel = helper.readU8(buf)
    local enaStartStep = helper.readS8(buf)
    local enaEndStep = helper.readS8(buf)
    local adjChannel = helper.readU8(buf)
    local adjRange1StartStep = helper.readS8(buf)
    local adjRange1EndStep = helper.readS8(buf)
    local adjRange2StartStep = helper.readS8(buf)
    local adjRange2EndStep = helper.readS8(buf)
    local adjMin = helper.readS16(buf)
    local adjMax = helper.readS16(buf)
    local adjStep = helper.readU8(buf)

    if enaChannel == nil or enaStartStep == nil or enaEndStep == nil or adjChannel == nil or adjRange1StartStep == nil or
        adjRange1EndStep == nil or adjRange2StartStep == nil or adjRange2EndStep == nil or adjMin == nil or adjMax == nil or adjStep == nil then
        return nil, "short_adjustment_range"
    end

    return {
        parsed = {
            adjustment_range = {
                adjFunction = adjFunction,
                enaChannel = enaChannel,
                enaRange = {
                    start = 1500 + (enaStartStep * 5),
                    ["end"] = 1500 + (enaEndStep * 5)
                },
                adjChannel = adjChannel,
                adjRange1 = {
                    start = 1500 + (adjRange1StartStep * 5),
                    ["end"] = 1500 + (adjRange1EndStep * 5)
                },
                adjRange2 = {
                    start = 1500 + (adjRange2StartStep * 5),
                    ["end"] = 1500 + (adjRange2EndStep * 5)
                },
                adjMin = adjMin,
                adjMax = adjMax,
                adjStep = adjStep
            }
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 156,
    minBytes = 14,
    fields = {},
    buildReadPayload = buildReadPayload,
    parseRead = parseRead,
    simulatorResponseRead = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, 0}
})
