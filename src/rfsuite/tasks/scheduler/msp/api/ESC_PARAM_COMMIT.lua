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

local API_NAME = "ESC_PARAM_COMMIT"
local MSP_API_CMD_WRITE = 0x300E
local ESC_ID_COMBINED = 255

local function validateWrite()
    local armed = rfsuite.utils and rfsuite.utils.resolveArmedState and rfsuite.utils.resolveArmedState()
    if armed then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC_PARAM_COMMIT blocked while armed", "info")
        end
        if rfsuite.utils and rfsuite.utils.signalArmedWriteBlocked then
            rfsuite.utils.signalArmedWriteBlocked()
        end
        return false, "armed_blocked"
    end
    return true
end

local function buildWritePayload(_, _, _, _, escId)
    local targetEscId = tonumber(escId)
    if targetEscId == nil then
        targetEscId = ESC_ID_COMBINED
    end

    targetEscId = math.floor(targetEscId)
    if targetEscId < 0 then targetEscId = 0 end
    if targetEscId > 255 then targetEscId = 255 end

    return {targetEscId}
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = MSP_API_CMD_WRITE,
    minApiVersion = {12, 0, 10},
    buildWritePayload = buildWritePayload,
    validateWrite = validateWrite,
    simulatorResponseWrite = {},
    writeUuidFallback = true,
    initialRebuildOnWrite = false
})
