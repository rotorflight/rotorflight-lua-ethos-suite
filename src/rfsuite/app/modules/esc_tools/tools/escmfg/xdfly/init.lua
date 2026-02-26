--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MSP_API = "ESC_PARAMETERS_XDFLY"
local MSP_API_VERSION = {12, 0, 8}
local toolName = "@i18n(app.modules.esc_tools.mfg.xdfly.name)@"

local function getByte(page, index, default)
    if type(page) ~= "table" then return default end
    local v = tonumber(page[index])
    if v == nil then return default end
    v = math.floor(v)
    if v < 0 or v > 255 then return default end
    return v
end

local function getPageValue(page, index, default) return getByte(page, index, default) end

local function getEscModel(self)

    local escModelID = getPageValue(self, 4)
    local escModels = {"RESERVED", "35A", "65A", "85A", "125A", "155A", "130A", "195A", "300A"}

    if escModelID == nil then return "UNKNOWN" end

    local model = escModels[escModelID]
    if model == nil then
        return "XDFLY " .. tostring(escModelID) .. " "
    end

    return "XDFLY " .. model .. " "

end

local function getEscVersion(self) return " " end

local function getEscFirmware(self)

    local fw = getPageValue(self, 3, 0)
    local version = "SW" .. (fw >> 4) .. "." .. (fw & 0xF)
    return version

end

local function to16bit(high, low) return low + (high * 256) end

local function to_binary_table(value, bits)
    local binary_table = {}
    for i = 0, bits - 1 do table.insert(binary_table, (value >> i) & 1) end
    return binary_table
end

local function extract_16bit_values_as_table(byte_stream)
    if type(byte_stream) ~= "table" then return {} end
    local length = #byte_stream
    if length < 2 then return {} end
    if length % 2 ~= 0 then length = length - 1 end

    local combined_binary_table = {}
    for i = 1, length, 2 do
        local value = to16bit(getByte(byte_stream, i + 1, 0), getByte(byte_stream, i, 0))
        local binary_table = to_binary_table(value, 16)
        for _, bit in ipairs(binary_table) do table.insert(combined_binary_table, bit) end
    end

    return combined_binary_table
end

local function getActiveFields(inputTable)

    if type(inputTable) ~= "table" then return {} end

    local length = #inputTable
    local lastFour = {}

    local startIndex = math.max(1, length - 3)

    for i = startIndex, length do
        local v = getByte(inputTable, i, nil)
        if v ~= nil then table.insert(lastFour, v) end
    end

    return extract_16bit_values_as_table(lastFour)

end

return {mspapi = MSP_API, apiversion = MSP_API_VERSION, toolName = toolName, image = "xdfly.png", powerCycle = false, mspBufferCache = true, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware, getActiveFields = getActiveFields}
