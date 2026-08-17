--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local labels = {}
local fields = {}

fields[#fields + 1] = {t = "Profile Type", value = 0, min = 0, max = 1, table = {[0] = "PID", "Rate"}}
fields[#fields + 1] = {t = "Source Profile", value = 0, min = 0, max = 5, tableIdxInc = -1, table = {"1", "2", "3", "4", "5", "6"}}
fields[#fields + 1] = {t = "Dest. Profile", value = 0, min = 0, max = 5, tableIdxInc = -1, table = {"1", "2", "3", "4", "5", "6"}}

local doSave = false

local function queueCopyProfile(payload, uuid)
    local msp = rfsuite.tasks and rfsuite.tasks.msp
    local bus = rfsuite.bus
    local actions = msp and msp.genericActions
    local contextId = bus and bus.createContext and bus.createContext({}, rfsuite.app and rfsuite.app.lastScript)
    local API = msp and msp.api and msp.api.loadPage("COPY_PROFILE")
    if not API then return false, "api_unavailable" end

    API.setUUID(uuid)
    API.setValue("profile_type", payload[1])
    API.setValue("dest_profile", payload[2])
    API.setValue("source_profile", payload[3])
    if contextId and actions and actions.actions and API.setBusActions then
        API.setBusActions(actions.actions.appCloseProgress, nil, contextId, true)
    end

    local ok, reason = API.write()
    if not ok and contextId and bus and bus.releaseContext then
        bus.releaseContext(contextId)
    end
    return ok, reason
end

local function onSaveMenu()

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        doSave = true
        return
    end    

    local buttons = {
        {
            label = "          OK           ",
            action = function()

                doSave = true

                return true
            end
        }, {label = "CANCEL", action = function() return true end}
    }
    local theTitle = "Save settings"
    local theMsg
    if rfsuite.app.Page.extraMsgOnSave then
        theMsg = "Save current page to flight controller?" .. "\n\n" .. rfsuite.app.Page.extraMsgOnSave
    else
        theMsg = "Save current page to flight controller?"
    end

    form.openDialog({width = nil, title = theTitle, message = theMsg, buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
end

local function getDestinationPidProfile(self)
    local destPidProfile
    if (self.currentPidProfile < self.maxPidProfiles - 1) then
        destPidProfile = self.currentPidProfile + 1
    else
        destPidProfile = self.currentPidProfile - 1
    end
    return destPidProfile
end

local function openPage(opts)

    local idx = opts.idx
    local title = opts.title
    local script = opts.script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false

    local app = rfsuite.app
    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    form.clear()
    rfsuite.session.lastPage = script

    local pageTitle = rfsuite.app.Page.pageTitle or title
    rfsuite.app.ui.fieldHeader(pageTitle)

    if rfsuite.app.Page.headerLine then
        local headerLine = form.addLine("")
        form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, rfsuite.app.Page.headerLine)
    end

    rfsuite.app.formLineCnt = 0

    if fields then
        for i, field in ipairs(fields) do
            local label = labels
            local valid = (field.apiversion == nil or rfsuite.utils.apiVersionCompare(">=", field.apiversion)) and
                (field.apiversionlt == nil or rfsuite.utils.apiVersionCompare("<", field.apiversionlt)) and
                (field.apiversiongt == nil or rfsuite.utils.apiVersionCompare(">", field.apiversiongt)) and
                (field.apiversionlte == nil or rfsuite.utils.apiVersionCompare("<=", field.apiversionlte)) and
                (field.apiversiongte == nil or rfsuite.utils.apiVersionCompare(">=", field.apiversiongte)) and
                (field.enablefunction == nil or field.enablefunction())

            if field.hidden ~= true and valid then
                rfsuite.app.ui.fieldLabel(field, i, label)
                if field.type == 0 then
                    rfsuite.app.ui.fieldStaticText(i,fields)
                elseif field.table or field.type == 1 then
                    rfsuite.app.ui.fieldChoice(i,fields)
                elseif field.type == 2 then
                    rfsuite.app.ui.fieldNumber(i,fields)
                elseif field.type == 3 then
                    rfsuite.app.ui.fieldText(i,fields)
                else
                    rfsuite.app.ui.fieldNumber(i,fields)
                end
            else
                rfsuite.app.formFields[i] = {}
            end
        end
    end

    rfsuite.app.triggers.closeProgressLoader = true
end

local function wakeup()
    if doSave == true then
        rfsuite.app.ui.progressDisplaySave()
        rfsuite.app.triggers.isSavingFake = true

        local payload = {}
        payload[1] = fields[1].value
        payload[2] = fields[3].value
        payload[3] = fields[2].value

        if payload[2] == payload[3] then
            rfsuite.utils.log("Source and destination profiles are the same. No need to copy.", "info")
            rfsuite.app.triggers.closeSaveFake = true
            rfsuite.app.triggers.isSaving = false
            doSave = false
            return
        end

        local ok, reason = queueCopyProfile(payload, string.format("copyprofiles.%d.%d.%d", payload[1], payload[2], payload[3]))
        if not ok then
            rfsuite.utils.log("Copy profiles enqueue rejected: " .. tostring(reason), "info")
            rfsuite.app.triggers.closeSaveFake = true
            rfsuite.app.triggers.isSaving = false
        end

        doSave = false
    end
end

return {reboot = false, eepromWrite = true, title = "Copy", openPage = openPage, wakeup = wakeup, onSaveMenu = onSaveMenu, labels = labels, fields = fields, getDestinationPidProfile = getDestinationPidProfile, API = {}, navButtons = {menu = true, save = true, reload = false, tool = false, help = true}}
