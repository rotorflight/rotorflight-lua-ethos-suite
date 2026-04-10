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

local API_NAME = "MODE_RANGES"

local function buildSimulatorResponse()
    local response = {1, 0, 216, 40, 0, 0, 80, 120}
    for _ = 1, 18 do
        response[#response + 1] = 0
        response[#response + 1] = 0
        response[#response + 1] = 136
        response[#response + 1] = 136
    end
    return response
end

local SIM_RESPONSE = buildSimulatorResponse()

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    local parsed = {}
    local ranges = {}

    buf.offset = 1
    while true do
        local modeId = helper.readU8(buf)
        if modeId == nil then break end

        local auxChannelIndex = helper.readU8(buf)
        local startStep = helper.readS8(buf)
        local endStep = helper.readS8(buf)
        if auxChannelIndex == nil or startStep == nil or endStep == nil then break end

        ranges[#ranges + 1] = {
            id = modeId,
            auxChannelIndex = auxChannelIndex,
            range = {
                start = 1500 + (startStep * 5),
                ["end"] = 1500 + (endStep * 5)
            }
        }
    end

    parsed.mode_ranges = ranges
    return {parsed = parsed, buffer = buf, receivedBytesCount = #buf}
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 34,
    minBytes = 0,
    fields = {},
    simulatorResponseRead = SIM_RESPONSE,
    parseRead = parseRead
})
