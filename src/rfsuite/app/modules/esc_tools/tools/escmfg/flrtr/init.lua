--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MSP_API = "ESC_PARAMETERS_FLYROTOR"
local MSP_API_VERSION = {12, 0, 7}

local toolName = "@i18n(app.modules.esc_tools.mfg.flrtr.name)@"

local function getByte(page, index, default)
    if type(page) ~= "table" then return default end
    local v = tonumber(page[index])
    if v == nil then return default end
    v = math.floor(v)
    if v < 0 or v > 255 then return default end
    return v
end

local function getUInt(page, vals)
    local v = 0
    for idx = 1, #vals do
        local raw_val = getByte(page, vals[idx], 0)
        raw_val = raw_val << ((idx - 1) * 8)
        v = v | raw_val
    end
    return v
end

local function getPageValue(page, index, default) return getByte(page, index, default) end

local function getEscModel(self)

    local hw = "1." .. getPageValue(self, 20, 0) .. '/' .. getPageValue(self, 14, 0) .. "." .. getPageValue(self, 15, 0) .. "." .. getPageValue(self, 16, 0)
    local result = (getPageValue(self, 4, 0) * 256) + getPageValue(self, 5, 0)

    return "FLYROTOR " .. tostring(result) .. "A " .. hw .. " "
end

local function getEscVersion(self)

    local sn = string.format("%08X", getUInt(self, {9, 8, 7, 6})) .. string.format("%08X", getUInt(self, {13, 12, 11, 9}))

    return sn
end

local function getEscFirmware(self)
    local version = getPageValue(self, 17, 0) .. "." .. getPageValue(self, 18, 0) .. "." .. getPageValue(self, 19, 0)

    return version
end

return {mspapi = MSP_API, apiversion = MSP_API_VERSION, toolName = toolName, image = "flrtr.png", powerCycle = false, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware}
