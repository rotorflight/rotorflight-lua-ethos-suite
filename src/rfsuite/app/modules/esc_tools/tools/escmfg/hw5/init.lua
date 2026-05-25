--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local toolName = "@i18n(app.modules.esc_tools.mfg.hw5.name)@"
local mspHeaderBytes = 2

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

local useCompact = rfsuite.utils.apiVersionCompare(">=", {12, 0, 9})

if useCompact then
    -- Compact layout: hardware_version is at bytes 3-18 (firmware_version and esc_type removed).
    local function getEscModel(buffer) return toolName end
    local function getEscVersion(buffer) return getText(buffer, 3, 18) end
    local function getEscFirmware(buffer) return "" end
    return {mspapi = "ESC_PARAMETERS_HW5_COMPACT", toolName = toolName, escSensorProtocolId = 3, powerCycle = false, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware, mspHeaderBytes = mspHeaderBytes}
else
    -- Full layout: firmware_version[3-18], hardware_version[19-34], esc_type[35-50].
    local function getEscModel(buffer) return getText(buffer, 35, 50) end
    local function getEscVersion(buffer) return getText(buffer, 19, 34) end
    local function getEscFirmware(buffer) return getText(buffer, 3, 18) end
    return {mspapi = "ESC_PARAMETERS_HW5", toolName = toolName, escSensorProtocolId = 3, powerCycle = false, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware, mspHeaderBytes = mspHeaderBytes}
end

