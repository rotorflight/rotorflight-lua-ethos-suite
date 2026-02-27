--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local common = assert(loadfile("app/modules/settings/activelook/common.lua"))()
local modePage = {}

local function makePage(modeKey, modeLabel)
    local config = {}
    local previewFields = {}
    local slotFields = {}

    local function updatePreview()
        local layoutKey = config["layout_" .. modeKey]
        local line1, line2 = common.layoutPreview(layoutKey)
        if previewFields[1] and previewFields[1].value then previewFields[1]:value(line1) end
        if previewFields[2] and previewFields[2].value then previewFields[2]:value(line2) end
        -- Leave line2 blank when unused to reduce visual clutter.
    end

    local function applyLayoutToFields()
        local layoutKey = config["layout_" .. modeKey]
        local active = common.LAYOUT_ACTIVE[layoutKey] or common.LAYOUT_ACTIVE.two_top_two_bottom
        for i = 1, 4 do
            local field = slotFields[i]
            if field and field.enable then
                field:enable(active[i] == true)
            end
        end
        updatePreview()
    end

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

        rfsuite.app.ui.fieldHeader("@i18n(app.modules.settings.name)@" .. " / ActiveLook / " .. modeLabel)
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

        local layoutLine, fieldIdx = addFieldLine("Layout")
        local w = rfsuite.app.lcdWidth
        local rightPad = 8
        local gap = 6
        local fieldW = math.floor(w * 0.55)
        local fieldX = w - rightPad - fieldW
        local dropW = math.floor(fieldW * 0.5)
        local previewW = fieldW - dropW - gap
        local dropX = fieldX
        local previewX = dropX + dropW + gap
        local layoutPos = {x = dropX, y = rfsuite.app.radio.linePaddingTop, w = dropW, h = rfsuite.app.radio.navbuttonHeight}
        rfsuite.app.formFields[fieldIdx] = form.addChoiceField(layoutLine, layoutPos, common.LAYOUT_CHOICES, function()
            return common.layoutKeyToChoice(config["layout_" .. modeKey])
        end, function(newValue)
            config["layout_" .. modeKey] = common.layoutChoiceToKey(newValue)
            applyLayoutToFields()
        end)

        local previewTextW = math.max(40, math.floor(previewW * 0.6))
        local previewTextX = previewX + math.floor((previewW - previewTextW) / 2)
        local previewPos = {x = previewTextX, y = rfsuite.app.radio.linePaddingTop, w = previewTextW, h = rfsuite.app.radio.navbuttonHeight}
        previewFields[1] = form.addStaticText(layoutLine, previewPos, "")

        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        local previewLine = form.addLine("")
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = previewLine
        previewFields[2] = form.addStaticText(previewLine, previewPos, "")

        for i = 1, 4 do
            local key = modeKey .. "_" .. i
            local line, idx = addFieldLine("Slot " .. i)
            local slotPos = {x = fieldX, y = rfsuite.app.radio.linePaddingTop, w = fieldW, h = rfsuite.app.radio.navbuttonHeight}
            slotFields[i] = form.addChoiceField(line, slotPos, common.SENSOR_CHOICES, function()
                return common.keyToChoice(config[key] or common.DEFAULT_LAYOUT[modeKey][i])
            end, function(newValue) config[key] = common.choiceToKey(newValue) end)
            rfsuite.app.formFields[idx] = slotFields[i]
        end

        for _, field in ipairs(rfsuite.app.formFields) do
            if field and field.enable then field:enable(true) end
        end
        applyLayoutToFields()
        rfsuite.app.navButtons.save = true
    end

    local function onNavMenu()
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
end

function modePage.create(modeKey, modeLabel)
    return makePage(modeKey, modeLabel)
end

return modePage
