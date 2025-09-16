local toolName = "@i18n(app.modules.esc_tools.mfg.hw5.name)@"
local mspHeaderBytes = 2

-- rfsuite.tasks.msp.protocol.mspIntervalOveride = 0.8

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

local function getEscModel(buffer)
    return getText(buffer, 51, 67)
end

local function getEscVersion(buffer)
    return getText(buffer, 19, 34)
end

local function getEscFirmware(buffer)
    return getText(buffer, 3, 18)
end

return {
    mspapi="ESC_PARAMETERS_HW5",
    toolName = toolName,
    image = "hobbywing.png",
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
    mspHeaderBytes = mspHeaderBytes,
}

