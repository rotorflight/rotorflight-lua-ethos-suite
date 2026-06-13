--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local common = assert(loadfile("app/modules/settings/activelook/common.lua"))()
local system = system

local config = {}

local function switchSourceFromConfig(value)
    if value == nil or value == "" then return nil end
    local scategory, smember = tostring(value):match("([^,]+),([^,]+)")
    scategory = tonumber(scategory)
    smember = tonumber(smember)
    if scategory and smember then
        return system.getSource({category = scategory, member = smember})
    end
    return nil
end

local function openPage(opts)
    local pageIdx = opts.idx
    local title = opts.title
    local script = opts.script

    common.clearPreviewMode()

    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx = pageIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.settings.name)@" .. " / ActiveLook / " .. "@i18n(app.modules.settings.activelook_settings)@")
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    config = {}
    local saved = rfsuite.preferences.activelook or {}
    for k, v in pairs(saved) do config[k] = v end
    config = common.applyDefaults(config)

    local function addLine(label)
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        local line = form.addLine(label)
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = line
        return line
    end

    local function addFieldLine(label)
        local line = addLine(label)
        formFieldCount = formFieldCount + 1
        return line, formFieldCount
    end

    local line, fieldIdx = addFieldLine("@i18n(app.modules.settings.activelook_hide_display)@")
    rfsuite.app.formFields[fieldIdx] = form.addSwitchField(line, nil, function()
        return switchSourceFromConfig(config.display_switch)
    end, function(newValue)
        if newValue then
            config.display_switch = newValue:category() .. "," .. newValue:member()
        else
            config.display_switch = ""
        end
    end)

    line, fieldIdx = addFieldLine("Offset X")
    rfsuite.app.formFields[fieldIdx] = form.addNumberField(line, nil, -20, 20, function()
        return tonumber(config.offset_x) or 0
    end, function(newValue) config.offset_x = common.clampOffset(newValue) end)
    if rfsuite.app.formFields[fieldIdx] and rfsuite.app.formFields[fieldIdx].suffix then
        rfsuite.app.formFields[fieldIdx]:suffix("px")
    end

    line, fieldIdx = addFieldLine("Offset Y")
    rfsuite.app.formFields[fieldIdx] = form.addNumberField(line, nil, -20, 20, function()
        return tonumber(config.offset_y) or 0
    end, function(newValue) config.offset_y = common.clampOffset(newValue) end)
    if rfsuite.app.formFields[fieldIdx] and rfsuite.app.formFields[fieldIdx].suffix then
        rfsuite.app.formFields[fieldIdx]:suffix("px")
    end

    for _, field in ipairs(rfsuite.app.formFields) do
        if field and field.enable then field:enable(true) end
    end
    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    common.clearPreviewMode()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()
    return common.confirmedSave(config)
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
