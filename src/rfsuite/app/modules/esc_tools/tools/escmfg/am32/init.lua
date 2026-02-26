--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_API = "ESC_PARAMETERS_AM32"
local MSP_API_VERSION = {12, 0, 9}
local mspHeaderBytes = 0

local toolName = "AM32"

local function getByte(page, index, default)
    if type(page) ~= "table" then return default end
    local v = tonumber(page[index])
    if v == nil then return default end
    v = math.floor(v)
    if v < 0 or v > 255 then return default end
    return v
end

local function getPageValue(page, index, default) return getByte(page, index, default) end

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

   local version = "SW" .. getPageValue(self, 6, 0) .. "." .. getPageValue(self, 7, 0)
   return version

end

return {
    mspapi = MSP_API,
    toolName = toolName,
    image = "am32.jpg",
    esc4way = true,
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
    mspHeaderBytes = mspHeaderBytes,
    apiversion = MSP_API_VERSION
}
