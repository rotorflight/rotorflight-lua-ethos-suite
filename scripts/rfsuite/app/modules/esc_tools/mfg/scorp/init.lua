local toolName = "@i18n(app.modules.esc_tools.mfg.scorp.name)@"
local moduleName = "RF2SCORP"



local function getUInt(page, vals)
    if page.values == nil then return 0 end
    local v = 0
    for idx = 1, #vals do
        local raw_val = page.value[vals[idx]] or 0
        raw_val = raw_val << (idx - 1) * 8
        v = (v | raw_val) << 0
    end
    return v
end

local function getEscModel(buffer)
    local tt = {}
    for i = 1, 32 do
        local v = buffer[i + 2]
        if v == 0 then break end
        if v ~= nil then table.insert(tt, string.char(v)) end
    end
    return table.concat(tt)
end

local function getEscVersion(buffer)
    return getUInt(buffer, {61, 62})
end

local function getEscFirmware(buffer)
    return string.format("%08X", getUInt(buffer, {55, 56, 57, 58}))
end

return {
    mspapi="ESC_PARAMETERS_SCORPION",
    toolName = toolName,
    image = "scorpion.png",
    powerCycle = true,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
}

