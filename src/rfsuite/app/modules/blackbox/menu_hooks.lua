--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local mspHelper = rfsuite.tasks.msp.mspHelper

local prevConnectedState = nil
local initTime = os.clock()
local prereqRequested = false
local prereqReady = false
local featureConfigReady = false
local blackboxConfigReady = false
local dataflashStatusReady = false
local sdcardStatusReady = false
local blackboxSupported = false
local blackboxFocused = false
local featureBitmap = 0
local blackboxConfigParsed = {}
local media = {
    dataflashSupported = true,
    sdcardSupported = true
}

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = type(v) == "table" and copyTable(v) or v end
    return dst
end

local function setButtonsEnabled(enabled)
    if not rfsuite.app.formFields then return end
    for i, f in pairs(rfsuite.app.formFields) do
        if type(i) == "number" and f and f.enable then f:enable(enabled) end
    end
end

local function updateMenuAvailability()
    local connected = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
    local canOpen = prereqReady and connected and blackboxSupported

    setButtonsEnabled(canOpen)

    if canOpen and not blackboxFocused then
        blackboxFocused = true
        local idx = tonumber(rfsuite.preferences.menulastselected["blackbox"]) or 1
        local btn = rfsuite.app.formFields and rfsuite.app.formFields[idx] or nil
        if btn and btn.focus then btn:focus() end
    end
end

local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function onPrereqDone()
    prereqReady = featureConfigReady and blackboxConfigReady and dataflashStatusReady and sdcardStatusReady
    if prereqReady then
        rfsuite.session.blackbox = {
            feature = {enabledFeatures = featureBitmap},
            config = copyTable(blackboxConfigParsed or {}),
            media = copyTable(media),
            ready = blackboxSupported
        }
        updateMenuAvailability()
        rfsuite.app.triggers.closeProgressLoader = true
    end
end

local function requestBlackboxPrereqs()
    if prereqRequested then return end
    prereqRequested = true
    prereqReady = false
    featureConfigReady = false
    blackboxConfigReady = false
    dataflashStatusReady = false
    sdcardStatusReady = false
    blackboxSupported = false
    featureBitmap = 0
    blackboxConfigParsed = {}
    media = {
        dataflashSupported = true,
        sdcardSupported = true
    }
    blackboxFocused = false

    local FAPI = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
    FAPI.setUUID("blackbox-menu-feature")
    FAPI.setCompleteHandler(function()
        local d = FAPI.data()
        local parsed = d and d.parsed or nil
        featureBitmap = tonumber(parsed and parsed.enabledFeatures or 0) or 0
        featureConfigReady = true
        onPrereqDone()
    end)
    FAPI.setErrorHandler(function()
        featureConfigReady = true
        onPrereqDone()
    end)
    FAPI.read()

    local BAPI = rfsuite.tasks.msp.api.load("BLACKBOX_CONFIG")
    BAPI.setUUID("blackbox-menu-config")
    BAPI.setCompleteHandler(function()
        local d = BAPI.data()
        local parsed = d and d.parsed or nil
        blackboxConfigParsed = copyTable(parsed or {})
        blackboxSupported = tonumber(parsed and parsed.blackbox_supported or 0) == 1
        blackboxConfigReady = true
        onPrereqDone()
    end)
    BAPI.setErrorHandler(function()
        blackboxConfigParsed = {}
        blackboxSupported = false
        blackboxConfigReady = true
        onPrereqDone()
    end)
    BAPI.read()

    local dataflashMessage = {
        command = 70,
        processReply = function(self, buf)
            if buf then
                local flags = tonumber(mspHelper.readU8(buf) or 0) or 0
                media.dataflashSupported = (flags & 2) ~= 0
            end
            dataflashStatusReady = true
            onPrereqDone()
        end,
        errorHandler = function()
            dataflashStatusReady = true
            onPrereqDone()
        end,
        simulatorResponse = {3, 235, 3, 0, 0, 0, 0, 214, 7, 0, 0, 0, 0}
    }
    if not queueDirect(dataflashMessage, "blackbox-menu-dataflash") then
        dataflashStatusReady = true
    end

    local sdcardMessage = {
        command = 79,
        processReply = function(self, buf)
            if buf then
                local flags = tonumber(mspHelper.readU8(buf) or 0) or 0
                media.sdcardSupported = (flags & 0x01) ~= 0
            end
            sdcardStatusReady = true
            onPrereqDone()
        end,
        errorHandler = function()
            sdcardStatusReady = true
            onPrereqDone()
        end,
        simulatorResponse = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    }
    if not queueDirect(sdcardMessage, "blackbox-menu-sdcard") then
        sdcardStatusReady = true
    end

    onPrereqDone()
end

return {
    onOpenPost = function()
        prereqRequested = false
        setButtonsEnabled(false)
        requestBlackboxPrereqs()
    end,
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end

        if not prereqRequested then requestBlackboxPrereqs() end
        updateMenuAvailability()

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
        if currState ~= prevConnectedState then
            if not currState and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["menu"] then
                rfsuite.app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
