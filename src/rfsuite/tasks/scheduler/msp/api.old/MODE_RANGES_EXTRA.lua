--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

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

local SIMULATOR_RESPONSE = buildSimulatorResponse()

local function parseRead(buf)
    local helper = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspHelper
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
    return {parsed = parsed, buffer = buf}
end

return factory.create({
    name = API_NAME,
    readCmd = 238,
    minBytes = 0,
    simulatorResponseRead = SIMULATOR_RESPONSE,
    parseRead = parseRead,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
