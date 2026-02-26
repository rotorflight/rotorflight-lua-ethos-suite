--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local toolName = "@i18n(app.modules.esc_tools.mfg.scorp.name)@"
local MSP_API_VERSION = {12, 0, 6}

local function getByte(page, index, default)
    if type(page) ~= "table" then return default end
    local v = tonumber(page[index])
    if v == nil then return default end
    v = math.floor(v)
    if v < 0 or v > 255 then return default end
    return v
end

local function getUInt(page, vals)
    local v = 0
    for idx = 1, #vals do
        local raw_val = getByte(page, vals[idx], 0)
        raw_val = raw_val << (idx - 1) * 8
        v = (v | raw_val) << 0
    end
    return v
end

local function getEscModel(buffer)
    local tt = {}
    for i = 1, 32 do
        local v = getByte(buffer, i + 2, nil)
        if v == nil then break end
        if v == 0 then break end
        if v >= 32 and v <= 126 then
            table.insert(tt, string.char(v))
        end
    end
    return table.concat(tt)
end

local function getEscVersion(buffer) return getUInt(buffer, {61, 62}) end

local function getEscFirmware(buffer) return string.format("%08X", getUInt(buffer, {55, 56, 57, 58})) end

return {mspapi = "ESC_PARAMETERS_SCORPION", apiversion = MSP_API_VERSION, toolName = toolName, image = "scorpion.png", powerCycle = true, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware}

