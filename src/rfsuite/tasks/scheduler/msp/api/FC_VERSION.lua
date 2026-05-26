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

local string_format = string.format

-- Flat field spec:
--   field name, type
local FIELD_SPEC = {
    "version_major", "U8",
    "version_minor", "U8",
    "version_patch", "U8"
}

return core.createReadOnlyAPI({
    name = "FC_VERSION",
    readCmd = 3,
    fields = FIELD_SPEC,
    simulatorResponseRead = {4, 5, 1},
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
