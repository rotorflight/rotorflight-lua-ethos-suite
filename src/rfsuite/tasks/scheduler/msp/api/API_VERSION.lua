--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local function splitVersionStringToNumbers(versionString)
    if not versionString then return nil end

    local parts = {0}
    for num in versionString:gmatch("%d+") do table.insert(parts, tonumber(num)) end
    return parts
end

local API_NAME = "API_VERSION"
local SIM_RESPONSE = splitVersionStringToNumbers(
    rfsuite.config.supportedMspApiVersion[rfsuite.preferences.developer.apiversion]
)

-- Flat field spec:
--   field name, type
local FIELD_SPEC = {
    "version_command", "U8",
    "version_major", "U8",
    "version_minor", "U8"
}

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 1,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    methods = {
        readVersion = function(state)
            local parsed = state.mspData and state.mspData.parsed
            if not parsed then return nil end
            return parsed.version_major + (parsed.version_minor / 100)
        end
    }
})
