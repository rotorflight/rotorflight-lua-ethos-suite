--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd
local app = rfsuite.app
local tasks = rfsuite.tasks
local rfutils = rfsuite.utils

local fields = {}
local labels = {}
local wakeupScheduler = os.clock()
local rtcAPI
local statusAPI
local dataflashAPI
local eraseAPI
local lastStatusData
local lastDataflashData
local status = {}
local summary = {}
local triggerEraseDataFlash = false
local enableWakeup = false

local displayType = 0
local disableType = false
local firstRun = true

local w, h = lcd.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

local displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = app.radio.linePaddingTop, w = 200, h = app.radio.navbuttonHeight}

local function setFieldValue(idx, value)
    local field = app.formFields and app.formFields[idx] or nil
    if field and field.value then
        field:value(value)
    end
end

local function setFieldColor(idx, value)
    local field = app.formFields and app.formFields[idx] or nil
    if field and field.color then
        field:color(value)
    end
end

local apidata = {
    api = {[1] = nil},
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.fblstatus.fbl_date)@", value = "-", type = displayType, disable = disableType, position = displayPos}, {t = "@i18n(app.modules.fblstatus.fbl_time)@", value = "-", type = displayType, disable = disableType, position = displayPos}, {t = "@i18n(app.modules.fblstatus.arming_flags)@", value = "-", type = displayType, disable = disableType, position = displayPos},
            {t = "@i18n(app.modules.fblstatus.dataflash_free_space)@", value = "-", type = displayType, disable = disableType, position = displayPos}, {t = "@i18n(app.modules.fblstatus.real_time_load)@", value = "-", type = displayType, disable = disableType, position = displayPos}, {t = "@i18n(app.modules.fblstatus.cpu_load)@", value = "-", type = displayType, disable = disableType, position = displayPos}
        }
    }
}

local function ensureApis()
    local api = tasks.msp and tasks.msp.api
    if not rtcAPI then
        rtcAPI = api.loadPage("RTC")
        rtcAPI.setUUID("fbl.time")
        rtcAPI.setCompleteHandler(function()
            status.fblYear = rtcAPI.readValue("year")
            status.fblMonth = rtcAPI.readValue("month")
            status.fblDay = rtcAPI.readValue("day")
            status.fblHour = rtcAPI.readValue("hours")
            status.fblMinute = rtcAPI.readValue("minutes")
            status.fblSecond = rtcAPI.readValue("seconds")
            status.fblMillis = rtcAPI.readValue("milliseconds")
        end)
    end
    if not statusAPI then
        statusAPI = api.loadPage("STATUS")
        statusAPI.setUUID("fbl.status")
    end
    if not dataflashAPI then
        dataflashAPI = api.loadPage("DATAFLASH_SUMMARY")
        dataflashAPI.setUUID("fbl.dataflash")
    end
    if not eraseAPI then
        eraseAPI = api.loadPage("DATAFLASH_ERASE")
        eraseAPI.setUUID("fbl.erase")
    end
end

local function getFblTime()
    ensureApis()
    return rtcAPI.read()
end

local function getStatus()
    ensureApis()
    return statusAPI.read()
end

local function getDataflashSummary()
    ensureApis()
    return dataflashAPI.read()
end

local function eraseDataflash()
    ensureApis()
    local ok, reason = eraseAPI.write()
    if ok then
        summary = {}
        setFieldValue(1, "")
        setFieldValue(2, "")
        setFieldValue(3, "")
        setFieldValue(4, "")
        setFieldValue(5, "")
        setFieldValue(6, "")
    end
    return ok, reason
end

local function postLoad(self)

    ensureApis()
    getStatus()
    getDataflashSummary()
    getFblTime()
    app.triggers.isReady = true
    enableWakeup = true

    app.triggers.closeProgressLoader = true
end

local function postRead(self) rfutils.log("postRead", "debug") end

local function getFreeDataflashSpace()
    if not summary.supported then return "@i18n(app.modules.fblstatus.unsupported)@" end
    local freeSpace = summary.totalSize - summary.usedSize
    return string.format("%.1f " .. "@i18n(app.modules.fblstatus.megabyte)@", freeSpace / (1024 * 1024))
end

local function syncStatus()
    local data = statusAPI and statusAPI.data()
    if data == nil or data == lastStatusData then return end
    lastStatusData = data

    status.realTimeLoad = statusAPI.readValue("max_real_time_load")
    status.cpuLoad = statusAPI.readValue("average_cpu_load")
    status.armingDisableFlags = statusAPI.readValue("arming_disable_flags")
    status.profile = statusAPI.readValue("current_pid_profile_index")
    status.rateProfile = statusAPI.readValue("current_control_rate_profile_index")
end

local function syncDataflashSummary()
    local data = dataflashAPI and dataflashAPI.data()
    if data == nil or data == lastDataflashData then return end
    lastDataflashData = data

    local flags = tonumber(dataflashAPI.readValue("flags") or 0) or 0
    summary.ready = (flags & 1) ~= 0
    summary.supported = (flags & 2) ~= 0
    summary.sectors = dataflashAPI.readValue("sectors")
    summary.totalSize = dataflashAPI.readValue("total")
    summary.usedSize = dataflashAPI.readValue("used")
end

local function syncApiData()
    syncStatus()
    syncDataflashSummary()
end

local function wakeup()

    if enableWakeup == false then return end

    local page = app and app.Page or nil
    local pageFields = app and app.formFields or nil
    local mspQueue = tasks and tasks.msp and tasks.msp.mspQueue or nil

    if not mspQueue then
        return
    end

    syncApiData()

    if triggerEraseDataFlash == true then
        if app and app.audio then
            app.audio.playEraseFlash = true
        end
        triggerEraseDataFlash = false

        if app and app.ui then
            app.ui.progressDisplay("@i18n(app.modules.fblstatus.erasing)@", "@i18n(app.modules.fblstatus.erasing_dataflash)@")
        end
        if page and page.eraseDataflash then
            page.eraseDataflash()
        end
        if app and app.triggers then
            app.triggers.isReady = true
        end
    end

    if triggerEraseDataFlash == false then
        local now = os.clock()
        if (now - wakeupScheduler) >= 2 then
            wakeupScheduler = now
            firstRun = false
            if mspQueue:isProcessed() then

                getStatus()
                getDataflashSummary()
                getFblTime()

                if status.fblYear ~= nil and status.fblMonth ~= nil and status.fblDay ~= nil then
                    local value = string.format("%04d-%02d-%02d", status.fblYear, status.fblMonth, status.fblDay)
                    setFieldValue(1, value)
                end

                if status.fblHour ~= nil and status.fblMinute ~= nil and status.fblSecond ~= nil then
                    local value = string.format("%02d:%02d:%02d", status.fblHour, status.fblMinute, status.fblSecond)
                    setFieldValue(2, value)
                end

                if status.armingDisableFlags ~= nil then
                    local value = rfutils.armingDisableFlagsToString(status.armingDisableFlags)
                    setFieldValue(3, value)
                end

                if summary.supported == true then
                    local value = getFreeDataflashSpace()
                    setFieldValue(4, value)
                end

                if status.realTimeLoad ~= nil then
                    local value = math.floor(status.realTimeLoad / 10)
                    setFieldValue(5, tostring(value) .. "%")
                    if value >= 60 then setFieldColor(4, RED) end
                end
                if status.cpuLoad ~= nil then
                    local value = status.cpuLoad / 10
                    setFieldValue(6, tostring(value) .. "%")
                    if value >= 60 then setFieldColor(4, RED) end
                end

            end
        end
        if (now - wakeupScheduler) >= 1 and app and app.triggers then
            app.triggers.closeProgressLoader = true
        end
    end

end

local function onToolMenu(self)

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()

                triggerEraseDataFlash = true
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }
    local message
    local title

    title = "@i18n(app.modules.fblstatus.erase)@"
    message = "@i18n(app.modules.fblstatus.erase_prompt)@"

    form.openDialog({width = nil, title = title, message = message, buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

return {apidata = apidata, reboot = false, eepromWrite = false, minBytes = 0, wakeup = wakeup, refreshswitch = false, simulatorResponse = {}, postLoad = postLoad, postRead = postRead, eraseDataflash = eraseDataflash, onToolMenu = onToolMenu, onNavMenu = onNavMenu, event = event, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}, API = {}}
