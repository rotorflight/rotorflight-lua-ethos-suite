local toolName = "XDFLY"
moduleName = "xdfly"

local mspHeaderBytes = 2

function getUInt(page, vals)
    local v = 0
    for idx = 1, #vals do
        local raw_val = page[vals[idx] + mspHeaderBytes] or 0
        raw_val = raw_val << ((idx - 1) * 8)
        v = v | raw_val
    end
    return v
end

function getPageValue(page, index)
    return page[mspHeaderBytes + index]
end


-- required by framework
local function getEscModel(self)

    local escModelID = getUInt(self, {1})
    local escModels = {"RESERVED", "35A", "65A", "85A", "125A", "155A", "130A", "195A", "300A"}


    return "XDFLY " .. escModels[escModelID] .. " "

end

-- required by framework
local function getEscVersion(self)
    -- mno version provided
    return " "

end

-- required by framework
local function getEscFirmware(self)

    local version = "SW" .. (getPageValue(self, 2) >> 4) .. "." .. (getPageValue(self, 2) & 0xF)
    return version

end

return {
        toolName = toolName, 
        image="xdfly.png", 
        powerCycle = true,
        mspBufferCache = true,  
        mspSignature = 0x73, 
        mspHeaderBytes = mspHeaderBytes, 
        mspBytes = 38,  -- was 46.  set to 38 as this is checked in init for powercyle etc., if it does not match you will not get past the power cycle check
        simulatorResponse = {115, 0, 6, 18, 0, 1, 0, 1, 0, 2, 240, 84, 0, 1, 0, 5, 0, 4, 0, 2, 0, 1, 0, 92, 0, 1, 0, 0, 0, 50, 0, 1, 0, 11, 0, 18, 0, 0},
        getEscModel = getEscModel, 
        getEscVersion = getEscVersion, 
        getEscFirmware = getEscFirmware
    }
