--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local type = type
local tostring = tostring

local ACTION_APP_CLOSE_PROGRESS = "app.close_progress.reply"
local ACTION_APP_SETTINGS_SAVED_REPLY = "app.settings_saved.reply"
local ACTION_APP_SETTINGS_SAVED_ERROR = "app.settings_saved.error"
local ACTION_LOG_REPLY = "msp.log.reply"

local function appTriggers()
    local app = rfsuite.app
    return app and app.triggers or nil
end

local function closeProgress()
    local triggers = appTriggers()
    if triggers then
        triggers.closeProgressLoader = true
    end
    return true
end

local function settingsSavedReply(context)
    local app = rfsuite.app
    local triggers = app and app.triggers
    local page = context and context.page

    if triggers then
        triggers.closeSave = true
    end
    if page and page.postEepromWrite then page.postEepromWrite() end
    if page and page.reboot then
        app.ui.rebootFc(page)
    else
        app.utils.invalidatePages({preserveCurrentPage = true})
    end
    return true
end

local function settingsSavedError()
    local triggers = appTriggers()
    if triggers then
        triggers.closeSave = true
        triggers.showSaveArmedWarning = true
    end
    return true
end

local function logReply(context)
    local utils = rfsuite.utils
    if utils and utils.log and context and context.message then
        utils.log(tostring(context.message), context.level or "info")
    end
    return true
end

local function register(bus)
    if not (bus and bus.registerAction) then return false end
    bus.registerAction(ACTION_APP_CLOSE_PROGRESS, closeProgress)
    bus.registerAction(ACTION_APP_SETTINGS_SAVED_REPLY, settingsSavedReply)
    bus.registerAction(ACTION_APP_SETTINGS_SAVED_ERROR, settingsSavedError)
    bus.registerAction(ACTION_LOG_REPLY, logReply)
    return true
end

return {
    register = register,
    actions = {
        appCloseProgress = ACTION_APP_CLOSE_PROGRESS,
        appSettingsSavedReply = ACTION_APP_SETTINGS_SAVED_REPLY,
        appSettingsSavedError = ACTION_APP_SETTINGS_SAVED_ERROR,
        logReply = ACTION_LOG_REPLY
    }
}
