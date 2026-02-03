--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local toolName = "@i18n(app.modules.esc_tools.mfg.hw5.name)@"
local mspHeaderBytes = 2

-- Known HW hash → string mapping (CRC32 of hardware_version string)
local HW_NAME = {
    [0x2D518FDF] = "HW1104_V100456NB",
    [0x753D361E] = "HW1106_V100456NB",
    [0xFBB231FD] = "HW1106_V200456NB",
    [0x37183163] = "HW1106_V300456NB",
    [0x684AC53B] = "HW1109_V200456NB",
    [0xD0CE0E10] = "HW1112_V200456NB",
    [0x9FCFD633] = "HW1113_V100456NB",
    [0x1140D1D0] = "HW1113_V200456NB",
    [0x32615694] = "HW1118_V200456NB",
    [0xF3EF8954] = "HW1119_V200456NB",
    [0xB03DBD02] = "HW1121_V100456NB",
    [0xCB708387] = "HW1128_V100456NB",
}


local function getText(buffer, st, en)
    local tt = {}
    for i = st, en do
        local v = buffer[i]
        if v == 0 then break end
        tt[#tt + 1] = string.char(v)
    end
    return table.concat(tt)
end

local function getTextU32(buffer, st)
    local s = getText(buffer, st, st + 3)
    local b1, b2, b3, b4 = s:byte(1, 4)
    b1, b2, b3, b4 = b1 or 0, b2 or 0, b3 or 0, b4 or 0
    return (b1) | (b2 << 8) | (b3 << 16) | (b4 << 24)
end

local function u32hex(v)
    return string.format("0x%08X", v & 0xFFFFFFFF)
end

-- getText() wrappers for compact (>= 12.09) fields
local function getTextHex(buffer, st, en)
    local s = getText(buffer, st, en)
    local tt = {}
    for i = 1, #s do
        tt[#tt + 1] = string.format("%02X", s:byte(i))
    end
    return table.concat(tt)
end

-- Firmware packed as 8.8.8.8: maj.min.pat.build (build may be 0)
-- Input bytes are little-endian U32.
local function getTextFwPacked(buffer, st, en)
    local s = getText(buffer, st, en)
    local b1, b2, b3, b4 = s:byte(1, 4)
    b1, b2, b3, b4 = b1 or 0, b2 or 0, b3 or 0, b4 or 0
    local v = (b1) | (b2 << 8) | (b3 << 16) | (b4 << 24)
    local maj = (v >> 24) & 0xFF
    local min = (v >> 16) & 0xFF
    local pat = (v >> 8)  & 0xFF
    local bld = (v >> 0)  & 0xFF

    if bld ~= 0 then
        return string.format("%d.%d.%d.%d", maj, min, pat, bld)
    end
    return string.format("%d.%d.%d", maj, min, pat)
end

local function getTextU32Hex(buffer, st, en)
    local h = getTextHex(buffer, st, en)
    if h == "" then h = "00000000" end
    return "0x" .. h
end

local function getEscModel(buffer)
    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
        -- compact payload (no MSP header in buffer)
        local hw_u32 = getTextU32(buffer, 5)
        local hwName = HW_NAME[hw_u32]
        if hwName then return hwName end
        return "HW " .. u32hex(hw_u32)
    end
    return getText(buffer, 51, 67)
end

local function getEscVersion(buffer)
    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
        -- com_version u32 at 13..16
        local com_u32 = getTextU32(buffer, 13)
        return "COM " .. u32hex(com_u32)
    end
    return getText(buffer, 19, 34)
end

local function getEscFirmware(buffer)
    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
        -- firmware packed u32 at 9..12
        return getTextFwPacked(buffer, 9, 12)
    end
    return getText(buffer, 3, 18)
end

return {mspapi = "ESC_PARAMETERS_HW5", toolName = toolName, image = "hobbywing.png", powerCycle = false, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware, mspHeaderBytes = mspHeaderBytes}
