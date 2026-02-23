--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_API = "ESC_PARAMETERS_AM32"
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

local function getHeaderOffset()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.load and rfsuite.tasks.msp.api.load(MSP_API)
    if api and api.mspHeaderBytes then
        return api.mspHeaderBytes
    end
    return 0
end

-- required by framework
local function getEscModel(self)
    return "AM32"
end


-- required by framework
local function getEscVersion(self)
    local offset = getHeaderOffset()
    local eepromVersion = getPageValue(self, offset + 2) or 0
    return "EEPROM v" .. tostring(eepromVersion)
end

local function normalizeMinor(minor)
    local value = tonumber(minor) or 0
    if value < 0 then value = 0 end
    if value > 99 then value = value % 100 end
    if value < 10 then
        return "0" .. tostring(value)
    end
    return tostring(value)
end

-- required by framework
local function getEscFirmware(self)
    local offset = getHeaderOffset()
    local major = getPageValue(self, offset + 4) or 0
    local minor = getPageValue(self, offset + 5) or 0
    local version = "SW" .. major .. "." .. normalizeMinor(minor)
    return version
end

return {
    mspapi="ESC_PARAMETERS_AM32",
    toolName = toolName,
    image = "am32.jpg",
    esc4way = true,
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
    mspHeaderBytes = mspHeaderBytes,
}
