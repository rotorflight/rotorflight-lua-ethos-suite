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

local API_NAME = "BOXIDS"
local SIM_RESPONSE = {0, 1, 2, 53, 27, 36, 45, 13, 52, 19, 20, 26, 31, 51, 55, 56, 57}

local function parseRead(buf, helper)
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
    return {parsed = parsed, buffer = buf, receivedBytesCount = #buf}
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 119,
    minBytes = 0,
    fields = {},
    simulatorResponseRead = SIM_RESPONSE,
    parseRead = parseRead
})
