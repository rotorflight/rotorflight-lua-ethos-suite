local toolName = "Hobbywing V5"
local mspHeaderBytes = 2

-- rfsuite.bg.msp.protocol.mspIntervalOveride = 0.8

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i + mspHeaderBytes]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

local function getEscModel(buffer)
    return getText(buffer, 49, 65)
end

local function getEscVersion(buffer)
    return getText(buffer, 17, 32)
end

local function getEscFirmware(buffer)
    return getText(buffer, 1, 16)
end

return {
    toolName = toolName,
    image = "hobbywing.png",
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
    mspSignature = 0xFD,
    mspHeaderBytes = mspHeaderBytes,
    mspBytes = 60,
    mspInterval = 1,
    simulatorResponse = {253, 0, 32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32, 72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66, 80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32, 80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32, 0, 0, 0, 3, 0, 11, 6, 5, 25, 1, 0, 0, 24, 0, 0, 2}
}

