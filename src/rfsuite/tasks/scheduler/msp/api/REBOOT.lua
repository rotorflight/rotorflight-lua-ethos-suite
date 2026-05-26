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

local API_NAME = "REBOOT"

local function validateWrite()
    local armed = rfsuite.utils and rfsuite.utils.resolveArmedState and rfsuite.utils.resolveArmedState()
    if armed then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("REBOOT API blocked while armed", "info")
        end
        if rfsuite.utils and rfsuite.utils.signalArmedWriteBlocked then
            rfsuite.utils.signalArmedWriteBlocked()
        end
        return false, "armed_blocked"
    end
    return true
end

local function buildWritePayload(payloadData)
    local rebootMode = payloadData.rebootMode
    if rebootMode == nil then rebootMode = 0 end
    return {rebootMode}
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = 68,
    buildWritePayload = buildWritePayload,
    validateWrite = validateWrite,
    writeUuidFallback = true,
    initialRebuildOnWrite = false
})
