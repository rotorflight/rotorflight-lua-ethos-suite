--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "SET_MODE_RANGE"

local function buildWritePayload(payloadData)
    local payload = payloadData.payload
    if type(payload) ~= "table" then return nil end
    return payload
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = 35,
    buildWritePayload = buildWritePayload,
    simulatorResponseWrite = {},
    writeUuidFallback = true
})
