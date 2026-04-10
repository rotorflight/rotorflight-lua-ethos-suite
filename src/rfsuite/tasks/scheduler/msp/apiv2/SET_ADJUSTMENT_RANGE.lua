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

local API_NAME = "SET_ADJUSTMENT_RANGE"

local function buildWritePayload(payloadData)
    local payload = payloadData.payload
    if type(payload) ~= "table" then return nil end
    return payload
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = 53,
    buildWritePayload = buildWritePayload,
    simulatorResponseWrite = {},
    writeUuidFallback = true
})
