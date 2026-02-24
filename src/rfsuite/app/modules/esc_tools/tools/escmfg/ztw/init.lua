--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MSP_API = "ESC_PARAMETERS_ZTW"
local MSP_API_VERSION = {12, 0, 9}
local toolName = "@i18n(app.modules.esc_tools.mfg.ztw.name)@"

local function getPageValue(page, index) return page[index] end

local function getEscModel(self)

    local escModelID = getPageValue(self, 4)
    local escModels = {"RESERVED", "35A", "65A", "85A", "125A", "155A", "130A", "195A", "300A"}

    if escModelID == nil then return "UNKNOWN" end

    return "ZTW " .. escModels[escModelID] .. " "

end

local function getEscVersion(self) return " " end

local function getEscFirmware(self)

    local version = "SW" .. (getPageValue(self, 3) >> 4) .. "." .. (getPageValue(self, 3) & 0xF)
    return version

end

local function to16bit(high, low) return low + (high * 256) end

local function to_binary_table(value, bits)
    local binary_table = {}
    for i = 0, bits - 1 do table.insert(binary_table, (value >> i) & 1) end
    return binary_table
end

local function extract_16bit_values_as_table(byte_stream)
    if #byte_stream % 2 ~= 0 then error("Byte stream length must be even (multiple of 2)") end

    local combined_binary_table = {}
    for i = 1, #byte_stream, 2 do
        local value = to16bit(byte_stream[i + 1], byte_stream[i])
        local binary_table = to_binary_table(value, 16)
        for _, bit in ipairs(binary_table) do table.insert(combined_binary_table, bit) end
    end

    return combined_binary_table
end

local function getActiveFields(inputTable)

    if inputTable == nil then return {} end

    local length = #inputTable
    local lastFour = {}

    local startIndex = math.max(1, length - 3)

    for i = startIndex, length do table.insert(lastFour, inputTable[i]) end

    return extract_16bit_values_as_table(lastFour)

end

return {mspapi = MSP_API, apiversion = MSP_API_VERSION, toolName = toolName, image = "ztw.png", powerCycle = false, mspBufferCache = true, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware, getActiveFields = getActiveFields}
