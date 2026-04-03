--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_API = "ESC_PARAMETERS_BLUEJAY"
local toolName = "@i18n(app.modules.esc_tools.mfg.bluejay.name)@"
local ESC1_TARGET = 0
local ESC2_TARGET = 1
local BLUEJAY_MAIN_REVISION = 0

local function getPageValue(page, index)
    if type(page) ~= "table" then return nil end
    return page[index]
end

local function getMainRevision(buffer)
    return getPageValue(buffer, 3)
end

local function getLayoutRevision(buffer)
    return getPageValue(buffer, 5)
end

local function getLayoutNamePrefix(buffer)
    local byte = getPageValue(buffer, 67)
    if type(byte) ~= "number" or byte <= 0 then return nil end
    return string.char(byte)
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

local function isCompatibleEsc(buffer, api)
    if api and api.readValue then
        local mainRevision = api.readValue("main_revision")
        if mainRevision ~= nil then
            return mainRevision == BLUEJAY_MAIN_REVISION
        end
    end
    return getMainRevision(buffer) == BLUEJAY_MAIN_REVISION
end

local function supportsLedControl(buffer)
    local prefix = getLayoutNamePrefix(buffer)
    return prefix == "E" or prefix == "J" or prefix == "M" or prefix == "Q" or prefix == "U"
end

return {
    mspapi = MSP_API,
    toolName = toolName,
    isCompatibleEsc = isCompatibleEsc,
    force4WaySwitchOnEntry = true,
    esc4wayEsc1Target = ESC1_TARGET,
    esc4wayEsc2Target = ESC2_TARGET,
    mspBufferCache = true,
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
    isolatedSaveWaitEscMessage = "@i18n(app.modules.esc_tools.mfg.bluejay.waitingforesc)@",
    isolatedSaveGcCollect = true,
    isolatedSaveGcPasses = 1,
    escDetailsPollInterval = 0.6,
    escDetailsRetryInterval = 1.2,
    retrySwitchOnReadFail = true,
    readSwitchRetryCount = 3,
    readSwitchRetryDelay = 1.5,
    powerCycle = false,
    getLayoutRevision = getLayoutRevision,
    supportsLedControl = supportsLedControl,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware
}
