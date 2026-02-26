--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local toolName = "@i18n(app.modules.esc_tools.mfg.hw5.name)@"
local MSP_API_VERSION = {12, 0, 6}
local mspHeaderBytes = 2

local function getByte(buffer, index, default)
    if type(buffer) ~= "table" then return default end
    local v = tonumber(buffer[index])
    if v == nil then return default end
    v = math.floor(v)
    if v < 0 or v > 255 then return default end
    return v
end

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = getByte(buffer, i, nil)
        if v == nil then break end
        if v == 0 then break end
        if v < 32 or v > 126 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

local function getEscModel(buffer) return getText(buffer, 51, 67) end

local function getEscVersion(buffer) return getText(buffer, 19, 34) end

local function getEscFirmware(buffer) return getText(buffer, 3, 18) end

return {mspapi = "ESC_PARAMETERS_HW5", apiversion = MSP_API_VERSION, toolName = toolName, image = "hobbywing.png", powerCycle = false, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware, mspHeaderBytes = mspHeaderBytes}

