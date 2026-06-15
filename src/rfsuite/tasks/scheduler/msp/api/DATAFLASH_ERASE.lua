--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "DATAFLASH_ERASE"

local function buildWritePayload()
    return {}
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = 72,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = true
})
