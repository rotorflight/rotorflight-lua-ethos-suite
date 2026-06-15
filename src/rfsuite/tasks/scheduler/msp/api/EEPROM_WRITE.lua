--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "EEPROM_WRITE"

local function validateWrite()
    local armed = rfsuite.utils and rfsuite.utils.resolveArmedState and rfsuite.utils.resolveArmedState()
    if armed then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("EEPROM_WRITE API blocked while armed", "info")
        end
        if rfsuite.utils and rfsuite.utils.signalArmedWriteBlocked then
            rfsuite.utils.signalArmedWriteBlocked()
        end
        return false, "armed_blocked"
    end
    return true
end

local function buildWritePayload()
    return {}
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = 250,
    buildWritePayload = buildWritePayload,
    validateWrite = validateWrite,
    writeUuidFallback = true,
    initialRebuildOnWrite = true
})
