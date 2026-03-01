--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false

local apidata = {
    api = {
        {id = 1, name = "PID_TUNING", enableDeltaCache = false, rebuildOnWrite = true},
    },
    formdata = {
        labels = {},
        rows = {
            "@i18n(app.modules.pids.roll)@",
            "@i18n(app.modules.pids.pitch)@",
            "@i18n(app.modules.pids.yaw)@"
        },
        cols = {
            "@i18n(app.modules.pids.p)@",
            "@i18n(app.modules.pids.i)@",
            "@i18n(app.modules.pids.d)@",
            "@i18n(app.modules.pids.f)@",
            "@i18n(app.modules.pids.o)@",
            "@i18n(app.modules.pids.b)@"
        },
        fields = {
            {row = 1, col = 1, mspapi = 1, apikey = "pid_0_P"},
            {row = 2, col = 1, mspapi = 1, apikey = "pid_1_P"},
            {row = 3, col = 1, mspapi = 1, apikey = "pid_2_P"},
            {row = 1, col = 2, mspapi = 1, apikey = "pid_0_I"},
            {row = 2, col = 2, mspapi = 1, apikey = "pid_1_I"},
            {row = 3, col = 2, mspapi = 1, apikey = "pid_2_I"},
            {row = 1, col = 3, mspapi = 1, apikey = "pid_0_D"},
            {row = 2, col = 3, mspapi = 1, apikey = "pid_1_D"},
            {row = 3, col = 3, mspapi = 1, apikey = "pid_2_D"},
            {row = 1, col = 4, mspapi = 1, apikey = "pid_0_F"},
            {row = 2, col = 4, mspapi = 1, apikey = "pid_1_F"},
            {row = 3, col = 4, mspapi = 1, apikey = "pid_2_F"},
            {row = 1, col = 5, mspapi = 1, apikey = "pid_0_O"},
            {row = 2, col = 5, mspapi = 1, apikey = "pid_1_O"},
            {row = 1, col = 6, mspapi = 1, apikey = "pid_0_B"},
            {row = 2, col = 6, mspapi = 1, apikey = "pid_1_B"},
            {row = 3, col = 6, mspapi = 1, apikey = "pid_2_B"}
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function openPage(opts)

    local idx = opts.idx
    local title = opts.title
    local script = opts.script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false

    local relativeScript = script
    if type(relativeScript) == "string" and relativeScript:sub(1, 12) == "app/modules/" then
        relativeScript = relativeScript:sub(13)
    end

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = relativeScript or script
    rfsuite.session.lastPage = relativeScript or script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.ui.fieldHeader(title)
    local numCols
    if rfsuite.app.Page.apidata.formdata.cols ~= nil then
        numCols = #rfsuite.app.Page.apidata.formdata.cols
    else
        numCols = 6
    end
    local screenWidth = rfsuite.app.lcdWidth - 10
    local padding = 10
    local paddingTop = rfsuite.app.radio.linePaddingTop
    local h = rfsuite.app.radio.navbuttonHeight
    local w = ((screenWidth * 70 / 100) / numCols)
    local paddingRight = 20
    local positions = {}
    local pos

    local line = form.addLine("")

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

    while loc > 0 do
        local colLabel = rfsuite.app.Page.apidata.formdata.cols[loc]
        pos = {x = posX, y = posY, w = w, h = h}
        form.addStaticText(line, pos, colLabel)
        positions[loc] = posX - w + paddingRight
        posX = math.floor(posX - w)
        loc = loc - 1
    end

    local fields = rfsuite.app.Page.apidata.formdata.fields
    local pidRows = {}
    for ri, rv in ipairs(rfsuite.app.Page.apidata.formdata.rows) do pidRows[ri] = form.addLine(rv) end

    for i = 1, #fields do
        local f = fields[i]
        posX = positions[f.col]

        pos = {x = posX + padding, y = posY, w = w - padding, h = h}

        rfsuite.app.formFields[i] = form.addNumberField(pidRows[f.row], pos, 0, 0, function()
            if not fields or not fields[i] then
                if rfsuite.app.ui then
                    rfsuite.app.ui.disableAllFields()
                    rfsuite.app.ui.disableAllNavigationFields()
                    rfsuite.app.ui.enableNavigationField('menu')
                end
                return nil
            end
            return rfsuite.app.utils.getFieldValue(fields[i])
        end, function(value)
            if not fields or not fields[i] then return end
            rfsuite.app.ui.markPageDirty()
            if f.postEdit then f.postEdit(rfsuite.app.Page) end
            if f.onChange then f.onChange(rfsuite.app.Page) end

            f.value = rfsuite.app.utils.saveFieldValue(fields[i], value)
        end)
    end

    rfsuite.app.ui.setPageDirty(false)
end

local function canSave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    if pref == false or pref == "false" then return true end
    return rfsuite.app.pageDirty == true
end

local function wakeup()
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        if rfsuite.session.activeProfile ~= nil then
            local titleField = rfsuite.app.formFields['title']
            if titleField then
                rfsuite.app.ui.setHeaderTitle(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
            end
        end
    end
end

return {apidata = apidata, title = "@i18n(app.modules.pids.name)@", reboot = false, eepromWrite = true, refreshOnProfileChange = true, postLoad = postLoad, openPage = openPage, wakeup = wakeup, canSave = canSave, API = {}}
