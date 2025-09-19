local toolName = "@i18n(app.modules.esc_tools.mfg.yge.name)@"
local moduleName = "RF2YGE"

local mspHeaderBytes = 2

local escType = {
    [848] = "YGE 35 LVT BEC",
    [1616] = "YGE 65 LVT BEC",
    [2128] = "YGE 85 LVT BEC",
    [2384] = "YGE 95 LVT BEC",
    [4944] = "YGE 135 LVT BEC",
    [2304] = "YGE 90 HVT Opto",
    [4608] = "YGE 120 HVT Opto",
    [5712] = "YGE 165 HVT",
    [8272] = "YGE 205 HVT",
    [8273] = "YGE 205 HVT BEC",
    [4177] = "YGE Aureus 105",
    [4179] = "YGE Aureus 105v2",
    [5025] = "YGE Aureus 135",
    [5027] = "YGE Aureus 135v2",
    [5457] = "YGE Saphir 155",
    [5459] = "YGE Saphir 155v2",
    [4689] = "YGE Saphir 125",
    [4928] = "YGE Opto 135",
    [9552] = "YGE Opto 255",
    [16464] = "YGE Opto 405"
}

local escFlags = {spinDirection = 0, f3cAuto = 1, keepMah = 2, bec12v = 3}

function getEscTypeLabel(values)
    local idx = (values[mspHeaderBytes + 24] * 256) + values[mspHeaderBytes + 23]
    return escType[idx] or "YGE ESC (" .. idx .. ")"
end

local function getUInt(page, vals)
    local v = 0
    for idx = 1, #vals do
        local raw_val = page[vals[idx] + mspHeaderBytes] or 0
        raw_val = raw_val * (256 ^ (idx - 1))
        v = v + raw_val
    end
    return v
end

local function getEscModel(buffer)
    return getEscTypeLabel(buffer)
end

local function getEscVersion(buffer)
    return getUInt(buffer, {29, 30, 31, 32})
end

local function getEscFirmware(buffer)
    return string.format("%.5f", getUInt(buffer, {25, 26, 27, 28}) / 100000)
end

return {
    mspapi = "ESC_PARAMETERS_YGE",
    toolName = toolName,
    image = "yge.png",
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
}

