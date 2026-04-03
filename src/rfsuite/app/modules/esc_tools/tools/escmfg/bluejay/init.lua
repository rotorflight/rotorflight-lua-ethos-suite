--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_API = "ESC_PARAMETERS_BLUEJAY"
local toolName = "Bluejay"
local ESC1_TARGET = 0
local ESC2_TARGET = 1
local BLUEJAY_MAIN_REVISION = 0

local function getPageValue(page, index)
    return page[index]
end

local function getEscFamily(buffer)
    local major = getPageValue(buffer, 3)
    if major == BLUEJAY_MAIN_REVISION then
        return toolName
    end
    return toolName
end

local function getEscModel(buffer)
    return  getEscFamily(buffer)
end

local function getEscVersion(buffer)
    local layoutRevision = getPageValue(buffer, 5)
    if layoutRevision ~= nil then
        return "Revision " .. tostring(layoutRevision)
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
    esc4wayEsc1Target = ESC1_TARGET,
    esc4wayEsc2Target = ESC2_TARGET,
    flushFirstReadAfterSwitch = true,
    preSwitchTarget = 100,
    preSwitchWriteCount = 1,
    preSwitchDelay = 0.8,
    initialConnectTimeout = 18.0,
    switchWriteCount = 1,
    switchReadDelay = 5.0,
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
    readSwitchRetryDelay = 1.5,
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware
}
