--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "REBOOT"

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    {field = "rebootMode", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}}
}
-- LuaFormatter on

local function buildWritePayload(payloadData, _, _, state)
    return core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, state.rebuildOnWrite == true)
end

local function validateWrite()
    local session = rfsuite.session
    local tasks = rfsuite.tasks
    local armflags = tasks and tasks.telemetry and tasks.telemetry.getSensor and tasks.telemetry.getSensor("armflags")
    local armedByFlags = (armflags == 1 or armflags == 3)
    if (session and session.isArmed) or armedByFlags then
        if rfsuite and rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("REBOOT API blocked while armed", "info")
        end
        return false, "armed_blocked"
    end
    return true
end

return factory.create({
    name = API_NAME,
    writeCmd = 68,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    buildWritePayload = buildWritePayload,
    validateWrite = validateWrite,
    writeUuidFallback = true,
    initialRebuildOnWrite = false
})
