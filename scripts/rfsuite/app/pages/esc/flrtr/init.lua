local toolName = "FLYROTOR"
moduleName = "FLRTR"

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

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i + mspHeaderBytes]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

-- required by framework
local function getEscModel(self)

    -- buffer is the whole msp payload
    -- looks like prob have to extract

    local hw = "1." .. getPageValue(self, 18) .. '/' .. getPageValue(self, 12) .. "." .. getPageValue(self, 13) .. "." .. getPageValue(self, 14)

    return "FLYROTOR " .. string.format(self[5]) .. "A " .. hw .. " "

end

-- required by framework
local function getEscVersion(self)

    -- buffer is the whole msp payload
    -- looks like prob have to extract
    -- DATA[3-10]: Serial number. Example: 7771BED8DE25A9EA 

    -- return string.format("%.5f", getUInt(buffer, {mspHeaderBytes + 18}) / 100000)

    local sn = string.format("%08X", getUInt(self, {7, 6, 5, 4})) .. string.format("%08X", getUInt(self, {11, 10, 9, 8}))
    return sn

end

-- required by framework
local function getEscFirmware(self)

    local version = getPageValue(self, 15) .. "." .. getPageValue(self, 16) .. "." .. getPageValue(self, 17)

    return version

end

return {toolName = toolName, powerCycle = false, mspSignature = 0x73, mspHeaderBytes = mspHeaderBytes, mspBytes = 46, simulatorResponse = {115, 0, 0, 0, 150, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 2, 0, 4, 76, 7, 148, 0, 6, 30, 125, 0, 15, 0, 3, 15, 1, 20, 0, 10, 0, 0, 0, 0, 0, 0, 2, 73, 240}, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware}
