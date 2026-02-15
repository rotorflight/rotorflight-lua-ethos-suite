--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local tasks = rfsuite.tasks
local mspHelper = tasks.msp.mspHelper

local enableWakeup = false
local wakeupScheduler = 0
local status = {
    dataflash = {
        ready = false,
        supported = false,
        sectors = 0,
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

local FIELD = {
    DATAFLASH = 1,
    SDCARD = 2,
    DEVICE = 3,
    MODE = 4,
    DENOM = 5,
    FIELDS = 6,
    INITIAL_ERASE_KIB = 7,
    ROLLING_ERASE = 8,
    GRACE_PERIOD = 9
}

local SDCARD_STATE = {
    NOT_PRESENT = 0,
    FATAL = 1,
    CARD_INIT = 2,
    FS_INIT = 3,
    READY = 4
}

local apidata = {
    api = {
        [1] = "BLACKBOX_CONFIG"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "Dataflash", value = "-", type = 0, disable = true},
            {t = "SD Card", value = "-", type = 0, disable = true},
            {t = "Device", mspapi = 1, apikey = "device", type = 1, table = {"Disabled", "Onboard Flash", "SD Card", "Serial Port"}},
            {t = "Mode", mspapi = 1, apikey = "mode", type = 1, table = {"Off", "Normal", "Armed", "Switch"}},
            {t = "Rate Denominator", mspapi = 1, apikey = "denom", min = 1, max = 65535},
            {t = "Fields Bitmask", mspapi = 1, apikey = "fields", min = 0, max = 4294967295},
            {t = "Initial Erase Free (KiB)", mspapi = 1, apikey = "initialEraseFreeSpaceKiB", min = 0, max = 65535},
            {t = "Rolling Erase", mspapi = 1, apikey = "rollingErase", type = 1, table = {"Off", "On"}},
            {t = "Grace Period", mspapi = 1, apikey = "gracePeriod", min = 0, max = 255}
        }
    }
}

local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return tasks.msp.mspQueue:add(message)
end

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
    if not status.dataflash.supported then return "Not supported" end
    if status.eraseInProgress or not status.dataflash.ready then return "Erasing / busy..." end
    local total = status.dataflash.totalSize or 0
    local used = status.dataflash.usedSize or 0
    return string.format("Used %s / %s", formatSize(used), formatSize(total))
end

local function formatSDCardStatus()
    if not status.sdcard.supported then return "Not supported" end
    local state = status.sdcard.state or SDCARD_STATE.NOT_PRESENT
    if state == SDCARD_STATE.NOT_PRESENT then return "No card" end
    if state == SDCARD_STATE.FATAL then
        return string.format("Error (code %d)", status.sdcard.filesystemLastError or 0)
    end
    if state == SDCARD_STATE.CARD_INIT then return "Initializing card..." end
    if state == SDCARD_STATE.FS_INIT then return "Initializing filesystem..." end
    if state == SDCARD_STATE.READY then
        local totalKB = status.sdcard.totalSizeKB or 0
        local freeKB = status.sdcard.freeSizeKB or 0
        local usedKB = math.max(totalKB - freeKB, 0)
        return string.format("Used %s / %s", formatSize(usedKB * 1024), formatSize(totalKB * 1024))
    end
    return string.format("Unknown state (%d)", state)
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
    local message = {
        command = 70,
        processReply = function(self, buf)
            local flags = mspHelper.readU8(buf)
            status.dataflash.ready = (flags & 1) ~= 0
            status.dataflash.supported = (flags & 2) ~= 0
            status.dataflash.sectors = mspHelper.readU32(buf)
            status.dataflash.totalSize = mspHelper.readU32(buf)
            status.dataflash.usedSize = mspHelper.readU32(buf)
        end,
        simulatorResponse = {3, 1, 0, 0, 0, 0, 4, 0, 0, 0, 3, 0, 0}
    }
    return queueDirect(message, "blackbox.dataflash")
end

local function pollSDCardSummary()
    local message = {
        command = 79,
        processReply = function(self, buf)
            local flags = mspHelper.readU8(buf)
            status.sdcard.supported = (flags & 0x01) ~= 0
            status.sdcard.state = mspHelper.readU8(buf)
            status.sdcard.filesystemLastError = mspHelper.readU8(buf)
            status.sdcard.freeSizeKB = mspHelper.readU32(buf)
            status.sdcard.totalSizeKB = mspHelper.readU32(buf)
        end,
        simulatorResponse = {1, 4, 0, 0, 80, 195, 0, 0, 160, 134, 1}
    }
    return queueDirect(message, "blackbox.sdcard")
end

local function eraseDataflash()
    local message = {
        command = 72,
        processReply = function(self, buf)
            status.eraseInProgress = true
        end,
        simulatorResponse = {}
    }
    return queueDirect(message, "blackbox.erase")
end

local function postLoad(self)
    enableWakeup = true
    wakeupScheduler = 0
    pollDataflashSummary()
    pollSDCardSummary()
    app.triggers.closeProgressLoader = true
end

local function wakeup(self)
    if not enableWakeup then return end

    local values = tasks.msp.api.apidata.values
    local cfg = values and values.BLACKBOX_CONFIG
    local blackboxSupported = cfg and tonumber(cfg.blackbox_supported or 0) == 1
    if app.formNavigationFields and app.formNavigationFields.save and app.formNavigationFields.save.enable then
        app.formNavigationFields.save:enable(blackboxSupported == true)
    end

    local device = tonumber(apidata.formdata.fields[FIELD.DEVICE].value or 0) or 0
    local mode = tonumber(apidata.formdata.fields[FIELD.MODE].value or 0) or 0

    if app.formFields[FIELD.INITIAL_ERASE_KIB] and app.formFields[FIELD.INITIAL_ERASE_KIB].enable then
        app.formFields[FIELD.INITIAL_ERASE_KIB]:enable(device == 1 and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end
    if app.formFields[FIELD.ROLLING_ERASE] and app.formFields[FIELD.ROLLING_ERASE].enable then
        app.formFields[FIELD.ROLLING_ERASE]:enable(device == 1 and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end
    if app.formFields[FIELD.GRACE_PERIOD] and app.formFields[FIELD.GRACE_PERIOD].enable then
        app.formFields[FIELD.GRACE_PERIOD]:enable(device ~= 0 and (mode == 1 or mode == 2) and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end

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

local function onToolMenu(self)
    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                status.eraseInProgress = true
                eraseDataflash()
                app.ui.progressDisplay("Blackbox", "Erasing dataflash...")
                return true
            end
        },
        {
            label = "@i18n(app.btn_cancel)@",
            action = function()
                return true
            end
        }
    }

    form.openDialog({
        width = nil,
        title = "Blackbox",
        message = "Erase onboard dataflash logs?",
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
end

return {apidata = apidata, eepromWrite = true, reboot = false, postLoad = postLoad, wakeup = wakeup, onToolMenu = onToolMenu, navButtons = {menu = true, save = true, reload = true, tool = true, help = true}, API = {}}
