--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "ACC_CALIBRATION"

local function buildWritePayload()
    return {}
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = 205,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = true
})
