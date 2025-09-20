local MSP_API = "ESC_PARAMETERS_XDFLY"
local toolName = "@i18n(app.modules.esc_tools.mfg.xdfly.name)@"
local moduleName = "xdfly"


local function getPageValue(page, index)
    return page[index]
end


-- required by framework
local function getEscModel(self)

    local escModelID = getPageValue(self, 4)
    local escModels = {"RESERVED", "35A", "65A", "85A", "125A", "155A", "130A", "195A", "300A"}

    if escModelID == nil then
        return "UNKNOWN"
    end

    return "XDFLY " .. escModels[escModelID] .. " "

end

-- required by framework
local function getEscVersion(self)
    return " "
end

-- required by framework
local function getEscFirmware(self)

   local version = "SW" .. (getPageValue(self, 3) >> 4) .. "." .. (getPageValue(self, 3) & 0xF)
   return version

end

-- Function to convert two bytes to a 16-bit number (little-endian)
local function to16bit(high, low)
    return low + (high * 256)
end

-- Function to convert a number to a table of binary bits (LSB first)
local function to_binary_table(value, bits)
    local binary_table = {}
    for i = 0, bits - 1 do
        table.insert(binary_table, (value >> i) & 1)  -- Store bits from LSB to MSB
    end
    return binary_table
end

-- Main function to process byte stream and extract values as a bit table
local function extract_16bit_values_as_table(byte_stream)
    if #byte_stream % 2 ~= 0 then
        error("Byte stream length must be even (multiple of 2)")
    end

    local combined_binary_table = {}
    for i = 1, #byte_stream, 2 do
        local value = to16bit(byte_stream[i + 1], byte_stream[i]) -- Swap order to handle LSB first
        local binary_table = to_binary_table(value, 16)
        for _, bit in ipairs(binary_table) do
            table.insert(combined_binary_table, bit)
        end
    end

    return combined_binary_table
end

local function getActiveFields(inputTable)
    
    if inputTable == nil then
        return {}
    end

    local length = #inputTable
    local lastFour = {}

    -- Ensure we handle cases where the table has fewer than 4 elements
    local startIndex = math.max(1, length - 3)

    for i = startIndex, length do
        table.insert(lastFour, inputTable[i])
    end

    return extract_16bit_values_as_table(lastFour)

end


return {
        mspapi=MSP_API,
        toolName = toolName, 
        image="xdfly.png", 
        powerCycle = false,
        mspBufferCache = true,      -- funny little param to allow us to cache the buffer and carry it over to the next page
        getEscModel = getEscModel,
        getEscVersion = getEscVersion, 
        getEscFirmware = getEscFirmware,
        getActiveFields = getActiveFields,
    }
