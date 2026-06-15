--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local wakeupScheduler = os.clock()
local triggerSave = false
local triggerSaveCounter = false
local triggerMSPWrite = false

local MAX_PROFILE_COUNT = 6
local PROFILE_LABELS = {"1", "2", "3", "4", "5", "6"}
local profileChoiceTables = {}

local apidata = {api = {[1] = "STATUS"}, formdata = {labels = {}, fields = {{t = "@i18n(app.modules.profile_select.pid_profile)@", value = 0, min = 0, max = 5, tableIdxInc = -1, table = PROFILE_LABELS, type = 1, mspapi = 1, apikey = "current_pid_profile_index"}, {t = "@i18n(app.modules.profile_select.rate_profile)@", value = 0, min = 0, max = 5, tableIdxInc = -1, table = PROFILE_LABELS, type = 1, mspapi = 1, apikey = "current_control_rate_profile_index"}}}}

local function profileChoiceTable(count)
    count = tonumber(count) or MAX_PROFILE_COUNT
    if count < 1 then count = 1 end
    if count > MAX_PROFILE_COUNT then count = MAX_PROFILE_COUNT end

    local choices = profileChoiceTables[count]
    if not choices then
        choices = {}
        for i = 1, count do
            choices[i] = PROFILE_LABELS[i]
        end
        profileChoiceTables[count] = choices
    end
    return choices
end

local function configureProfileChoice(fieldIndex, count)
    local fields = apidata.formdata.fields
    local field = fields and fields[fieldIndex]
    if not field then return end

    local choices = profileChoiceTable(count)
    field.table = choices
    field.tableIdxInc = -1
    field.min = 0
    field.max = #choices - 1

    if field.value == nil or field.value < field.min or field.value > field.max then
        field.value = field.min
    end

    local formField = rfsuite.app and rfsuite.app.formFields and rfsuite.app.formFields[fieldIndex]
    if formField and formField.values then
        formField:values(rfsuite.app.utils.convertPageValueTable(choices, field.tableIdxInc))
    end
end

local function setProfileFieldValue(fieldIndex, activeValue, statusValue, count)
    local fields = apidata.formdata.fields
    local field = fields and fields[fieldIndex]
    if not field then return end

    count = tonumber(count) or MAX_PROFILE_COUNT
    if count < 1 then count = 1 end
    if count > MAX_PROFILE_COUNT then count = MAX_PROFILE_COUNT end

    local active = tonumber(activeValue)
    if active and active >= 1 and active <= count then
        field.value = active - 1
        return
    end

    local status = tonumber(statusValue)
    if status and status >= 0 and status < count then
        field.value = status
    end
end

local function postLoad(self)
    local status = rfsuite.tasks.msp.api.apidata.values and rfsuite.tasks.msp.api.apidata.values.STATUS
    configureProfileChoice(1, status and status.pid_profile_count)
    configureProfileChoice(2, status and status.control_rate_profile_count)

    if rfsuite.app and rfsuite.app.utils then
        rfsuite.app.utils.getCurrentProfile()
        rfsuite.app.utils.getCurrentRateProfile()
    end

    local session = rfsuite.session
    setProfileFieldValue(1, session and session.activeProfile, status and status.current_pid_profile_index, status and status.pid_profile_count)
    setProfileFieldValue(2, session and session.activeRateProfile, status and status.current_control_rate_profile_index, status and status.control_rate_profile_count)

    rfsuite.app.triggers.closeProgressLoader = true
end

local function postRead(self) end

local function setPidProfile(profileIndex)
    profileIndex = tonumber(profileIndex) or 0
    local API = rfsuite.tasks.msp.api.loadPage("SELECT_PROFILE")
    if not API then return false, "api_unavailable" end
    API.setUUID(string.format("profile.pid.%d", profileIndex))
    API.setValue("profile", profileIndex)
    return API.write()
end

local function setRateProfile(profileIndex)
    profileIndex = tonumber(profileIndex) or 0
    profileIndex = profileIndex + 128
    local API = rfsuite.tasks.msp.api.loadPage("SELECT_PROFILE")
    if not API then return false, "api_unavailable" end
    API.setUUID(string.format("profile.rate.%d", profileIndex))
    API.setValue("profile", profileIndex)
    return API.write()
end

local function onSaveMenu()

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        triggerSave = true
        return
    end      

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                triggerSave = true
                return true
            end
        }, {
            label = "@i18n(app.modules.profile_select.cancel)@",
            action = function()
                triggerSave = false
                return true
            end
        }
    }

    form.openDialog({width = nil, title = "@i18n(app.modules.profile_select.save_settings)@", message = "@i18n(app.modules.profile_select.save_prompt)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

    triggerSave = false

end

local function wakeup()

    if triggerSave == true then
        rfsuite.app.ui.progressDisplaySave()
        triggerSaveCounter = true
        triggerMSPWrite = true
        triggerSave = false
    end

    if triggerMSPWrite == true then
        triggerMSPWrite = false

        local profileIndex = rfsuite.app.Page.apidata.formdata.fields[1].value
        local rateIndex = rfsuite.app.Page.apidata.formdata.fields[2].value
        local okRate, reasonRate = setRateProfile(rateIndex)
        if not okRate then
            rfsuite.utils.log("Rate profile enqueue rejected: " .. tostring(reasonRate), "info")
            rfsuite.app.triggers.closeSaveFake = true
            rfsuite.app.triggers.isSaving = false
            return
        end

        local okPid, reasonPid = setPidProfile(profileIndex)
        if not okPid then
            rfsuite.utils.log("PID profile enqueue rejected: " .. tostring(reasonPid), "info")
            rfsuite.app.triggers.closeSaveFake = true
            rfsuite.app.triggers.isSaving = false
        end
    end

end

return {apidata = apidata, reboot = false, eepromWrite = false, wakeup = wakeup, onSaveMenu = onSaveMenu, refreshOnProfileChange = true, postLoad = postLoad, navButtons = {menu = true, save = true, reload = false, tool = false, help = true}, API = {}}
