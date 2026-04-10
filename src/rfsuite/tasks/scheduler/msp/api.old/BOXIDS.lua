--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "BOXIDS"
local SIMULATOR_RESPONSE = {0, 1, 2, 53, 27, 36, 45, 13, 52, 19, 20, 26, 31, 51, 55, 56, 57}

local function parseRead(buf)
    local helper = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspHelper
    if not helper then return nil, "msp_helper_missing" end

    local parsed = {}
    local ids = {}
    buf.offset = 1

    while true do
        local id = helper.readU8(buf)
        if id == nil then break end
        ids[#ids + 1] = id
    end

    parsed.box_ids = ids
    return {parsed = parsed, buffer = buf}
end

return factory.create({
    name = API_NAME,
    readCmd = 119,
    minBytes = 0,
    simulatorResponseRead = SIMULATOR_RESPONSE,
    parseRead = parseRead,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
