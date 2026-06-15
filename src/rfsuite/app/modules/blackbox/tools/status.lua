--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware"})

local app = rfsuite.app
local tasks = rfsuite.tasks

local FIELD = {
    DATAFLASH = 1,
    SDCARD = 2
}

local SDCARD_STATE = {
    NOT_PRESENT = 0,
    FATAL = 1,
    CARD_INIT = 2,
    FS_INIT = 3,
    READY = 4
}

local wakeupScheduler = 0
local dataflashAPI
local sdcardAPI
local eraseAPI
local lastDataflashData
local lastSdcardData
local status = {
    dataflash = {
        ready = false,
        supported = false,
        totalSize = 0,
        usedSize = 0
    },
    sdcard = {
        supported = false,
        state = 0,
        filesystemLastError = 0,
        freeSizeKB = 0,
        totalSizeKB = 0
    },
    eraseInProgress = false
}

local apidata = {
    api = {
        [1] = "BLACKBOX_CONFIG"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.blackbox.dataflash)@", value = "-", type = 0, disable = true, mspapi = 1, apikey = "blackbox_supported"},
            {t = "@i18n(app.modules.blackbox.sdcard)@", value = "-", type = 0, disable = true, mspapi = 1, apikey = "blackbox_supported"}
        }
    }
}

local function formatSize(bytes)
    if not bytes or bytes <= 0 then return "0 B" end
    if bytes < 1024 then return string.format("%d B", bytes) end
    local kb = bytes / 1024
    if kb < 1024 then return string.format("%.1f kB", kb) end
    local mb = kb / 1024
    if mb < 1024 then return string.format("%.1f MB", mb) end
    local gb = mb / 1024
    return string.format("%.2f GB", gb)
end

local function formatDataflashStatus()
    if not status.dataflash.supported then return "@i18n(app.modules.blackbox.not_supported)@" end
    if status.eraseInProgress or not status.dataflash.ready then return "@i18n(app.modules.blackbox.erasing_busy)@" end
    local total = status.dataflash.totalSize or 0
    local used = status.dataflash.usedSize or 0
    return string.format("@i18n(app.modules.blackbox.used_fmt)@", formatSize(used), formatSize(total))
end

local function formatSDCardStatus()
    if not status.sdcard.supported then return "@i18n(app.modules.blackbox.not_supported)@" end
    local state = status.sdcard.state or SDCARD_STATE.NOT_PRESENT
    if state == SDCARD_STATE.NOT_PRESENT then return "@i18n(app.modules.blackbox.no_card)@" end
    if state == SDCARD_STATE.FATAL then return string.format("@i18n(app.modules.blackbox.error_code_fmt)@", status.sdcard.filesystemLastError or 0) end
    if state == SDCARD_STATE.CARD_INIT then return "@i18n(app.modules.blackbox.initializing_card)@" end
    if state == SDCARD_STATE.FS_INIT then return "@i18n(app.modules.blackbox.initializing_filesystem)@" end
    if state == SDCARD_STATE.READY then
        local totalKB = status.sdcard.totalSizeKB or 0
        local freeKB = status.sdcard.freeSizeKB or 0
        local usedKB = math.max(totalKB - freeKB, 0)
        return string.format("@i18n(app.modules.blackbox.used_fmt)@", formatSize(usedKB * 1024), formatSize(totalKB * 1024))
    end
    return string.format("@i18n(app.modules.blackbox.unknown_state_fmt)@", state)
end

local function ensureApis()
    local api = tasks.msp and tasks.msp.api
    if not dataflashAPI then
        dataflashAPI = api.loadPage("DATAFLASH_SUMMARY")
        dataflashAPI.setUUID("blackbox.status.dataflash")
    end
    if not sdcardAPI then
        sdcardAPI = api.loadPage("SDCARD_SUMMARY")
        sdcardAPI.setUUID("blackbox.status.sdcard")
    end
    if not eraseAPI then
        eraseAPI = api.loadPage("DATAFLASH_ERASE")
        eraseAPI.setUUID("blackbox.status.erase")
    end
end

local function syncDataflashStatus()
    local data = dataflashAPI and dataflashAPI.data()
    if data == nil or data == lastDataflashData then return end
    lastDataflashData = data

    local parsed = data.parsed
    if not parsed then return end

    local flags = tonumber(parsed.flags or 0) or 0
    status.dataflash.ready = (flags & 1) ~= 0
    status.dataflash.supported = (flags & 2) ~= 0
    status.dataflash.totalSize = tonumber(parsed.total or 0) or 0
    status.dataflash.usedSize = tonumber(parsed.used or 0) or 0
end

local function syncSDCardStatus()
    local data = sdcardAPI and sdcardAPI.data()
    if data == nil or data == lastSdcardData then return end
    lastSdcardData = data

    local parsed = data.parsed
    if not parsed then return end

    local flags = tonumber(parsed.flags or 0) or 0
    status.sdcard.supported = (flags & 0x01) ~= 0
    status.sdcard.state = tonumber(parsed.state or 0) or 0
    status.sdcard.filesystemLastError = tonumber(parsed.filesystemLastError or 0) or 0
    status.sdcard.freeSizeKB = tonumber(parsed.freeSizeKB or 0) or 0
    status.sdcard.totalSizeKB = tonumber(parsed.totalSizeKB or 0) or 0
end

local function syncStatusFromApis()
    syncDataflashStatus()
    syncSDCardStatus()
end

local function updateStatusFields()
    if app.formFields[FIELD.DATAFLASH] and app.formFields[FIELD.DATAFLASH].value then
        app.formFields[FIELD.DATAFLASH]:value(formatDataflashStatus())
    end
    if app.formFields[FIELD.SDCARD] and app.formFields[FIELD.SDCARD].value then
        app.formFields[FIELD.SDCARD]:value(formatSDCardStatus())
    end
end

local function pollDataflashSummary()
    ensureApis()
    return dataflashAPI.read()
end

local function pollSDCardSummary()
    ensureApis()
    return sdcardAPI.read()
end

local function eraseDataflash()
    ensureApis()
    status.eraseInProgress = true
    return eraseAPI.write()
end

local function postLoad()
    ensureApis()
    wakeupScheduler = 0
    pollDataflashSummary()
    pollSDCardSummary()
    app.triggers.closeProgressLoader = true
end

local function wakeup()
    syncStatusFromApis()

    if tasks.msp.mspQueue:isProcessed() then
        local now = os.clock()
        if (now - wakeupScheduler) >= 2 then
            wakeupScheduler = now
            pollDataflashSummary()
            pollSDCardSummary()
        end
    end

    if status.eraseInProgress and status.dataflash.ready then
        status.eraseInProgress = false
        app.triggers.closeProgressLoader = true
    end

    updateStatusFields()
end

local function onToolMenu()
    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                status.eraseInProgress = true
                eraseDataflash()
                app.ui.progressDisplay("@i18n(app.modules.blackbox.name)@", "@i18n(app.modules.blackbox.erasing_dataflash)@")
                return true
            end
        },
        {
            label = "@i18n(app.btn_cancel)@",
            action = function() return true end
        }
    }

    form.openDialog({
        width = nil,
        title = "@i18n(app.modules.blackbox.name)@",
        message = "@i18n(app.modules.blackbox.erase_prompt)@",
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
end

return {apidata = apidata, eepromWrite = false, reboot = false, postLoad = postLoad, wakeup = wakeup, onToolMenu = onToolMenu, event = navHandlers.event, onNavMenu = navHandlers.onNavMenu, API = {}, navButtons = {menu = true, save = false, reload = true, tool = true, help = true}}
