local MSP_API = "ESC_PARAMETERS_FLYROTOR"
local toolName = "FLYROTOR"
moduleName = "FLRTR"


function getUInt(page, vals)
    local v = 0
    for idx = 1, #vals do
        local raw_val = page[vals[idx]] or 0
        raw_val = raw_val << ((idx - 1) * 8)
        v = v | raw_val
    end
    return v
end

function getPageValue(page, index)
    return page[index]
end

-- required by framework
local function getEscModel(self)

    -- buffer is the whole msp payload
    -- looks like prob have to extract

    local hw = "1." .. getPageValue(self, 20) .. '/' .. getPageValue(self, 14) .. "." .. getPageValue(self, 15) .. "." .. getPageValue(self, 16)

    return "FLYROTOR " .. string.format(self[5]) .. "A " .. hw .. " "

end

-- required by framework
local function getEscVersion(self)

    -- buffer is the whole msp payload
    -- looks like prob have to extract
    -- DATA[3-10]: Serial number. Example: 7771BED8DE25A9EA 

    -- return string.format("%.5f", getUInt(buffer, {mspHeaderBytes + 18}) / 100000)

    local sn = string.format("%08X", getUInt(self, {9, 8, 7, 6})) .. string.format("%08X", getUInt(self, {13, 12, 11, 9}))
    return sn

end

-- required by framework
local function getEscFirmware(self)

    local version = getPageValue(self, 15) .. "." .. getPageValue(self, 16) .. "." .. getPageValue(self, 17)

    return version

end

return {
    mspapi=MSP_API,    
    toolName = toolName,
    image = "flrtr.png",
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
}
