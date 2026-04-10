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

local API_NAME = "GET_ADJUSTMENT_FUNCTION_IDS"
local ADJUSTMENT_RANGE_MAX = 42
local SIM_RESPONSE = {
    1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
}

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    local parsed = {}
    local functions = {}
    buf.offset = 1

    for i = 1, ADJUSTMENT_RANGE_MAX do
        local fn = helper.readU8(buf)
        if fn == nil then break end
        functions[i] = fn
    end

    parsed.adjustment_function_ids = functions
    return {parsed = parsed, buffer = buf, receivedBytesCount = #buf}
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 167,
    minBytes = 0,
    fields = {},
    simulatorResponseRead = SIM_RESPONSE,
    parseRead = parseRead
})
