--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "ADJUSTMENT_RANGES"
local ADJUSTMENT_RANGE_BYTES = 14
local ADJUSTMENT_RANGE_MAX = 42

local function parseRead(buf)
    local helper = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspHelper
    if not helper then return nil, "msp_helper_missing" end

    local parsed = {}
    local ranges = {}
    local byteCount = #buf or 0

    local slotCount = math.floor(byteCount / ADJUSTMENT_RANGE_BYTES)
    if slotCount > ADJUSTMENT_RANGE_MAX then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ADJUSTMENT_RANGES slot count clamped from " .. tostring(slotCount) .. " to " .. tostring(ADJUSTMENT_RANGE_MAX), "info")
        end
        slotCount = ADJUSTMENT_RANGE_MAX
    end

    if (byteCount % ADJUSTMENT_RANGE_BYTES) ~= 0 and rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log("ADJUSTMENT_RANGES payload not aligned: " .. tostring(byteCount) .. " bytes", "debug")
    end

    buf.offset = 1
    for _ = 1, slotCount do
        local adjFunction = helper.readU8(buf)
        if adjFunction == nil then break end

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
            break
        end

        ranges[#ranges + 1] = {
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
    end

    parsed.adjustment_ranges = ranges
    return {parsed = parsed, buffer = buf}
end

return factory.create({
    name = API_NAME,
    readCmd = 52,
    minBytes = 0,
    simulatorResponseRead = {},
    parseRead = parseRead,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
