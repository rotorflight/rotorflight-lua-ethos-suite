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
    local u0 = helper.readU32(buf)
    local u1 = helper.readU32(buf)
    local u2 = helper.readU32(buf)
    if u0 == nil or u1 == nil or u2 == nil then
        return nil, "parse_failed"
    end

    return {
        parsed = {
            U_ID_0 = u0,
            U_ID_1 = u1,
            U_ID_2 = u2
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

return factory.create({
    name = "UID",
    readCmd = 160,
    minBytes = 12,
    simulatorResponseRead = {43, 0, 34, 0, 9, 81, 51, 52, 52, 56, 53, 49},
    parseRead = parseRead
})
