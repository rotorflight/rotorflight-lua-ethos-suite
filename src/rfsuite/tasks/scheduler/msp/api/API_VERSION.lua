--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "API_VERSION"
local MSP_API_SIMULATOR_RESPONSE = rfsuite.utils.splitVersionStringToNumbers(
    rfsuite.config.supportedMspApiVersion[rfsuite.preferences.developer.apiversion]
)

local MSP_API_STRUCTURE_READ = {
    {field = "version_command", type = "U8"},
    {field = "version_major",   type = "U8"},
    {field = "version_minor",   type = "U8"}
}

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    buf.offset = 1
    local version_command = helper.readU8(buf)
    local version_major = helper.readU8(buf)
    local version_minor = helper.readU8(buf)
    if version_command == nil or version_major == nil or version_minor == nil then
        return nil, "parse_failed"
    end

    return {
        parsed = {
            version_command = version_command,
            version_major = version_major,
            version_minor = version_minor
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

return factory.create({
    name = API_NAME,
    readCmd = 1,
    minBytes = 3,
    readStructure = MSP_API_STRUCTURE_READ,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE,
    parseRead = parseRead,
    methods = {
        readVersion = function(state)
            local parsed = state.mspData and state.mspData.parsed
            if not parsed then return nil end
            return parsed.version_major + (parsed.version_minor / 100)
        end
    }
})
