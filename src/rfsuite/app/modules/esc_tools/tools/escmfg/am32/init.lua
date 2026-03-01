--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_API = "ESC_PARAMETERS_AM32"
local MSP_API_VERSION = {12, 0, 9}

local toolName = "AM32"
local moduleName = "am32"

local function getPageValue(page, index) return page[index] end

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

-- required by framework
local function getEscModel(self)

    -- we dont have a name for the am32, so we just return the tool name as the model
    return "AM32 "

end


-- required by framework
local function getEscVersion(self)
    return " "
end

-- required by framework
local function getEscFirmware(self)

   local version = "SW" .. getPageValue(self, 6) .. "." .. getPageValue(self, 7)
   return version

end

return {
    mspapi="ESC_PARAMETERS_AM32",
    toolName = toolName,
    image = "am32.jpg",
    esc4way = true,
    force4WaySwitchOnEntry = true,
    preSwitchTarget = 100,
    preSwitchWriteCount = 1,
    preSwitchDelay = 0.8,
    switchWriteCount = 1,
    switchReadDelay = 3.0,
    escDetailsPollInterval = 0.6,
    escDetailsRetryInterval = 1.2,
    retrySwitchOnReadFail = true,
    readSwitchRetryCount = 3,
    readSwitchRetryDelay = 0.25,
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
    mspHeaderBytes = mspHeaderBytes,
    apiversion = MSP_API_VERSION
}
