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

local API_NAME = "MODE_RANGES_EXTRA"

local function buildSimulatorResponse()
    local response = {20, 1, 0, 0}
    for _ = 1, 19 do
        response[#response + 1] = 0
        response[#response + 1] = 0
        response[#response + 1] = 0
    end
    return response
end

local SIM_RESPONSE = buildSimulatorResponse()

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    local parsed = {}
    local extras = {}

    buf.offset = 1
    local count = helper.readU8(buf) or 0
    for _ = 1, count do
        local modeId = helper.readU8(buf)
        local modeLogic = helper.readU8(buf)
        local linkedTo = helper.readU8(buf)
        if modeId == nil or modeLogic == nil or linkedTo == nil then break end
        extras[#extras + 1] = {id = modeId, modeLogic = modeLogic, linkedTo = linkedTo}
    end

    parsed.mode_ranges_extra = extras
    return {parsed = parsed, buffer = buf, receivedBytesCount = #buf}
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 238,
    minBytes = 0,
    fields = {},
    simulatorResponseRead = SIM_RESPONSE,
    parseRead = parseRead
})
