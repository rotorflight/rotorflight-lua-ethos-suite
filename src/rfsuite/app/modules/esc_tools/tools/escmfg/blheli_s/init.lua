--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MSP_API = "ESC_PARAMETERS_BLHELI_S"
local toolName = "@i18n(app.modules.esc_tools.mfg.blheli_s.name)@"

local function getPageValue(page, index)
    return page[index]
end

local function getText(buffer, st, en)
    local chars = {}
    for i = st, en do
        local value = buffer[i]
        if value == nil or value == 0 then break end
        chars[#chars + 1] = string.char(value)
    end
    return table.concat(chars)
end

local function getEscModel(buffer)
    local name = getText(buffer, 99, 114)
    if name ~= "" then return name end

    local layout = getText(buffer, 67, 82)
    if layout ~= "" then return layout end

    return toolName
end

local function getEscVersion(buffer)
    local mcu = getText(buffer, 83, 98)
    if mcu ~= "" then return mcu end

    local layoutRevision = getPageValue(buffer, 5)
    if layoutRevision ~= nil then
        return "Layout " .. tostring(layoutRevision)
    end

    return " "
end

local function getEscFirmware(buffer)
    local major = getPageValue(buffer, 3)
    local minor = getPageValue(buffer, 4)
    if major == nil or minor == nil then
        return " "
    end

    return "FW" .. tostring(major) .. "." .. tostring(minor)
end

return {
    mspapi = MSP_API,
    toolName = toolName,
    force4WaySwitchOnEntry = true,
    esc4wayEsc1Target = 0,
    esc4wayEsc2Target = 1,
    flushFirstReadAfterSwitch = true,
    preSwitchTarget = 100,
    preSwitchWriteCount = 1,
    preSwitchDelay = 0.8,
    switchWriteCount = 1,
    switchReadDelay = 4.0,
    postSaveSwitchCycle = true,
    postSaveSettleDelay = 1.0,
    postSaveResetTarget = 100,
    postSaveReturnTargetDelay = 1.0,
    postSaveRestoreSettleDelay = 0.5,
    postSaveSwitchTimeout = 4.0,
    postSaveSwitchRetryCount = 1,
    postSaveSwitchRetryDelay = 0.75,
    postSaveQueueIdleTimeout = 3.0,
    postSaveFlushRead = false,
    postSaveFlushReadDelay = 0.35,
    postSaveFlushReadRetryCount = 1,
    postSaveFlushReadRetryDelay = 0.6,
    postSaveFlushReadTimeout = 5.0,
    useIsolatedSaveDialog = true,
    isolatedSaveTimeout = 32,
    isolatedSaveProgressProcessingStep = 0.2,
    isolatedSaveProgressProcessingCap = 90,
    isolatedSaveProgressIdleStep = 1,
    isolatedSaveProgressIdleCap = 97,
    isolatedSaveWaitEscMessage = "@i18n(app.modules.esc_tools.mfg.blheli_s.waitingforesc)@",
    isolatedSaveGcCollect = true,
    isolatedSaveGcPasses = 1,
    escDetailsPollInterval = 0.6,
    escDetailsRetryInterval = 1.2,
    retrySwitchOnReadFail = true,
    readSwitchRetryCount = 3,
    readSwitchRetryDelay = 0.25,
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware
}
