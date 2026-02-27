--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local string_format = string.format

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    buf.offset = 1
    local major = helper.readU8(buf)
    local minor = helper.readU8(buf)
    local patch = helper.readU8(buf)
    if major == nil or minor == nil or patch == nil then
        return nil, "parse_failed"
    end

    return {
        parsed = {
            version_major = major,
            version_minor = minor,
            version_patch = patch
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

return factory.create({
    name = "FC_VERSION",
    readCmd = 3,
    minBytes = 3,
    simulatorResponseRead = {4, 5, 1},
    parseRead = parseRead,
    methods = {
        readVersion = function(state)
            local parsed = state.mspData and state.mspData.parsed
            if not parsed then return nil end
            return string_format("%d.%d.%d", parsed.version_major, parsed.version_minor, parsed.version_patch)
        end,
        readRfVersion = function(state)
            local parsed = state.mspData and state.mspData.parsed
            if not parsed then return nil end

            local major = parsed.version_major - 2
            local minor = parsed.version_minor - 3
            local patch = parsed.version_patch

            if major < 0 or minor < 0 then
                return string_format("%d.%d.%d", parsed.version_major, parsed.version_minor, patch)
            end

            return string_format("%d.%d.%d", major, minor, patch)
        end
    }
})
