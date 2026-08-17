--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false
local RXFAIL_API_INDEX = 1
local MODE_SET = 2
local pidx, title

local channelLabels = {
    "Roll",
    "Pitch",
    "Yaw",
    "Collective",
    "Throttle",
    "AUX 1",
    "AUX 2",
    "AUX 3",
    "AUX 4",
    "AUX 5",
    "AUX 6",
    "AUX 7",
    "AUX 8",
    "AUX 9",
    "AUX 10",
    "AUX 11",
    "AUX 12",
    "AUX 13"
}

local fields = {}
local labels = {}
local modeFieldIndexByChannel = {}
local valueFieldIndexByChannel = {}

for i = 1, #channelLabels do
    labels[#labels + 1] = { t = channelLabels[i], label = i, inline_size = 16.0 }

    local valueField = {
        t = "",
        label = i,
        inline = 1,
        mspapi = RXFAIL_API_INDEX,
        apikey = "channel_" .. i .. "_value",
        min = 875,
        max = 2125,
        default = 1500,
        unit = "us"
    }
    fields[#fields + 1] = valueField
    valueFieldIndexByChannel[i] = #fields

    local modeField = {
        t = "",
        type = 1,
        label = i,
        inline = 2,
        mspapi = RXFAIL_API_INDEX,
        apikey = "channel_" .. i .. "_mode"
    }
    fields[#fields + 1] = modeField
    modeFieldIndexByChannel[i] = #fields
end

local apidata = {
    api = {
        [1] = "RXFAIL_CONFIG",
        [2] = "FAILSAFE_CONFIG"
    },
    formdata = {
        labels = labels,
        fields = fields
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function openPage(opts)
    local idx = opts.idx
    title = opts.title
    local script = opts.script

    local app = rfsuite.app

    app.lastIdx = idx
    app.lastTitle = title
    app.lastScript = script
    rfsuite.session.lastPage = script

    form.clear()
    app.ui.fieldHeader(title)
    local pageFields = app.Page.apidata.formdata.fields

    local w = app.lcdWidth
    local h = app.radio.navbuttonHeight
    local y = app.radio.linePaddingTop
    local rightPadding = 8
    local columnGap = 10
    local modeW = math.floor(w * 0.16)
    local valueW = math.floor(w * 0.15)
    local valueX = w - rightPadding - valueW
    local modeX = valueX - columnGap - modeW
    local posMode = {x = modeX, y = y, w = modeW, h = h}
    local posValue = {x = valueX, y = y, w = valueW, h = h}

    for i = 1, #channelLabels do
        local modeFieldIndex = modeFieldIndexByChannel[i]
        local valueFieldIndex = valueFieldIndexByChannel[i]
        local modeField = pageFields[modeFieldIndex]
        local valueField = pageFields[valueFieldIndex]

        local line = form.addLine(channelLabels[i])

        local tableData = modeField.table and app.utils.convertPageValueTable(modeField.table, modeField.tableIdxInc) or {}
        app.formFields[modeFieldIndex] = form.addChoiceField(
            line,
            posMode,
            tableData,
            function()
                return app.utils.getFieldValue(pageFields[modeFieldIndex])
            end,
            function(value)
                local f = pageFields[modeFieldIndex]
                f.value = app.utils.saveFieldValue(f, value)
            end
        )

        app.formFields[valueFieldIndex] = form.addNumberField(
            line,
            posValue,
            valueField.min or 0,
            valueField.max or 0,
            function()
                return app.utils.getFieldValue(pageFields[valueFieldIndex])
            end,
            function(value)
                local f = pageFields[valueFieldIndex]
                f.value = app.utils.saveFieldValue(f, value)
            end
        )

        if valueField.unit and app.formFields[valueFieldIndex].suffix then
            app.formFields[valueFieldIndex]:suffix(valueField.unit)
        end
        if app.formFields[valueFieldIndex].minimum then
            app.formFields[valueFieldIndex]:minimum(875)
        end
        if app.formFields[valueFieldIndex].maximum then
            app.formFields[valueFieldIndex]:maximum(2125)
        end
        if app.formFields[valueFieldIndex].step then
            app.formFields[valueFieldIndex]:step(5)
        end
    end
end

local function wakeup(self)
    if activateWakeup ~= true then return end
    if not rfsuite.app.formFields then return end
    if not rfsuite.app.Page or not rfsuite.app.Page.apidata or not rfsuite.app.Page.apidata.formdata then return end

    local pageFields = rfsuite.app.Page.apidata.formdata.fields

    for i = 1, #channelLabels do
        local modeFieldIndex = modeFieldIndexByChannel[i]
        local valueFieldIndex = valueFieldIndexByChannel[i]
        local modeField = pageFields and pageFields[modeFieldIndex]
        local valueWidget = rfsuite.app.formFields[valueFieldIndex]

        if modeField and valueWidget and valueWidget.enable then
            valueWidget:enable(tonumber(modeField.value) == MODE_SET)
        end
    end
end

return {apidata = apidata, title = "Failsafe", reboot = false, eepromWrite = true, openPage = openPage, postLoad = postLoad, wakeup = wakeup, API = {}}
