local toolName = "Scorpion"
moduleName = "RF2SCORP"

local mspHeaderBytes = 2

function getUInt(page, vals)
    if page.values == nil then return 0 end
    local v = 0
    for idx = 1, #vals do
        local raw_val = page.value[vals[idx] + mspHeaderBytes] or 0
        raw_val = raw_val << (idx - 1) * 8
        v = (v | raw_val) << 0
    end
    return v
end

local function getEscModel(buffer)
    local tt = {}
    for i = 1, 32 do
        local v = buffer[i + mspHeaderBytes]
        if v == 0 then break end
        if v ~= nil then table.insert(tt, string.char(v)) end
    end
    return table.concat(tt)
end

local function getEscVersion(buffer)
    return getUInt(buffer, {59, 60})
end

local function getEscFirmware(buffer)
    return string.format("%08X", getUInt(buffer, {55, 56, 57, 58}))
end

return {
    toolName = toolName,
    powerCycle = true,
    mspSignature = 0x53,
    mspHeaderBytes = mspHeaderBytes,
    mspBytes = 84,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
    simulatorResponse = {83, 128, 84, 114, 105, 98, 117, 110, 117, 115, 32, 69, 83, 67, 45, 54, 83, 45, 56, 48, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 3, 0, 3, 0, 1, 0, 3, 0, 136, 19, 22, 3, 16, 39, 64, 31, 136, 19, 0, 0, 1, 0, 7, 2, 0, 6, 63, 0, 160, 15, 64, 31, 208, 7, 100, 0, 0, 0, 200, 0, 0, 0, 1, 0, 0, 0, 200, 250, 0, 0}
}

