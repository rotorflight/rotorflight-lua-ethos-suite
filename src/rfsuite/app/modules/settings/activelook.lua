--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local config = {}

local function openPage(opts)
    local pageIdx = opts.idx
    local title = opts.title
    local script = opts.script

    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx = pageIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.settings.name)@" .. " / ActiveLook")
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    config = {}
    local saved = rfsuite.preferences.activelook or {}
    for k, v in pairs(saved) do config[k] = v end

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Offset X")
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt],
        nil,
        0,
        10,
        function() return tonumber(config.offset_x) or 0 end,
        function(newValue) config.offset_x = tonumber(newValue) or 0 end,
        1
    )
    if rfsuite.app.formFields[formFieldCount] and type(rfsuite.app.formFields[formFieldCount].suffix) == "function" then
        rfsuite.app.formFields[formFieldCount]:suffix("px")
    end

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Offset Y")
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt],
        nil,
        0,
        10,
        function() return tonumber(config.offset_y) or 0 end,
        function(newValue) config.offset_y = tonumber(newValue) or 0 end,
        1
    )
    if rfsuite.app.formFields[formFieldCount] and type(rfsuite.app.formFields[formFieldCount].suffix) == "function" then
        rfsuite.app.formFields[formFieldCount]:suffix("px")
    end

    for _, field in ipairs(rfsuite.app.formFields) do
        if field and field.enable then field:enable(true) end
    end
    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()
    local function doSave()
        local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))

        rfsuite.preferences.activelook = rfsuite.preferences.activelook or {}
        local oldOffsetX = tonumber(rfsuite.preferences.activelook.offset_x) or 0
        local oldOffsetY = tonumber(rfsuite.preferences.activelook.offset_y) or 0
        local newOffsetX = tonumber(config.offset_x) or 0
        local newOffsetY = tonumber(config.offset_y) or 0
        for key, value in pairs(config) do rfsuite.preferences.activelook[key] = value end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)

        if oldOffsetX ~= newOffsetX or oldOffsetY ~= newOffsetY then
            rfsuite.session = rfsuite.session or {}
            rfsuite.session.activelookReset = true
        end

        rfsuite.app.triggers.closeSave = true
        return true
    end

    local confirm = rfsuite.preferences.general and rfsuite.preferences.general.save_confirm
    if confirm == false or confirm == "false" then
        doSave()
        return true
    end

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                doSave()
                return true
            end
        },
        {
            label = "@i18n(app.modules.profile_select.cancel)@",
            action = function() return true end
        }
    }

    form.openDialog({
        width = nil,
        title = "@i18n(app.modules.profile_select.save_settings)@",
        message = "@i18n(app.modules.profile_select.save_prompt_local)@",
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {
    event = event,
    openPage = openPage,
    onNavMenu = onNavMenu,
    onSaveMenu = onSaveMenu,
    navButtons = {menu = true, save = true, reload = false, tool = false, help = false},
    API = {}
}
