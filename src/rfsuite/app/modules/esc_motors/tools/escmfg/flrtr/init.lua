--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MSP_API = "ESC_PARAMETERS_FLYROTOR"

local toolName = "@i18n(app.modules.esc_tools.mfg.flrtr.name)@"
local moduleName = "FLRTR"

local function getUInt(page, vals)
    local v = 0
    for idx = 1, #vals do
        local raw_val = page[vals[idx]] or 0
        raw_val = raw_val << ((idx - 1) * 8)
        v = v | raw_val
    end
    return v
end

local function getPageValue(page, index) return page[index] end

local function getEscModel(self)

    local hw = "1." .. getPageValue(self, 20) .. '/' .. getPageValue(self, 14) .. "." .. getPageValue(self, 15) .. "." .. getPageValue(self, 16)
    local result = self[4] * 256 + self[5]

    return "FLYROTOR " .. string.format(result) .. "A " .. hw .. " "
end

local function getEscVersion(self)

    local sn = string.format("%08X", getUInt(self, {9, 8, 7, 6})) .. string.format("%08X", getUInt(self, {13, 12, 11, 9}))

    return sn
end

local function getEscFirmware(self)
    local version = getPageValue(self, 17) .. "." .. getPageValue(self, 18) .. "." .. getPageValue(self, 19)

    return version
end

return {mspapi = MSP_API, toolName = toolName, image = "flrtr.png", powerCycle = false, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware}
