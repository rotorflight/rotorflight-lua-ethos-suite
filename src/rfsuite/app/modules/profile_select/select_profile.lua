--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local wakeupScheduler = os.clock()
local triggerSave = false
local triggerSaveCounter = false
local triggerMSPWrite = false
local STATUS_API = "STATUS"
local PID_FIELD_INDEX = 1
local RATE_FIELD_INDEX = 2

local apidata = {api = {[1] = "STATUS"}, formdata = {labels = {}, fields = {{t = "@i18n(app.modules.profile_select.pid_profile)@", type = 1, mspapi = 1, apikey = "current_pid_profile_index"}, {t = "@i18n(app.modules.profile_select.rate_profile)@", type = 1, mspapi = 1, apikey = "current_control_rate_profile_index"}}}}

local function clearArray(values)
    if type(values) ~= "table" then return end
    for i = #values, 1, -1 do
        values[i] = nil
    end
end

local function getProfileFields()
    local page = rfsuite.app and rfsuite.app.Page
    local formdata = page and page.apidata and page.apidata.formdata
    return formdata and formdata.fields or nil
end

local function getStatusValues()
    local tasks = rfsuite.tasks
    local apidata = tasks and tasks.msp and tasks.msp.api and tasks.msp.api.apidata
    return apidata and apidata.values and apidata.values[STATUS_API] or nil
end

local function resolveProfileCount(status, countKey, currentKey)
    local count = tonumber(status and status[countKey])
    if count then count = math.floor(count) end

    if count == nil or count < 1 then
        local current = tonumber(status and status[currentKey])
        if current then count = math.floor(current) + 1 end
    end

    if count == nil or count < 1 then return nil end
    return count
end

local function rebuildProfileTable(field, count)
    if type(field) ~= "table" then return nil end

    local options = field.table
    if type(options) ~= "table" then
        options = {}
        field.table = options
    else
        clearArray(options)
    end

    for i = 1, count do
        options[i] = tostring(i)
    end

    field.tableIdxInc = -1

    local currentValue = tonumber(field.value)
    if currentValue == nil or currentValue < 0 then
        field.value = 0
    elseif currentValue >= count then
        field.value = count - 1
    end

    return options
end

local function updateChoiceField(fieldIndex, options)
    local formFields = rfsuite.app and rfsuite.app.formFields
    local formField = formFields and formFields[fieldIndex]
    if not formField then return end

    if options and formField.values then
        local convertPageValueTable = rfsuite.app and rfsuite.app.utils and rfsuite.app.utils.convertPageValueTable
        if convertPageValueTable then
            formField:values(convertPageValueTable(options, -1))
        end
    end

    if formField.enable then
        formField:enable(options ~= nil)
    end
end

local function refreshProfileChoices()
    local fields = getProfileFields()
    local status = getStatusValues()
    if type(fields) ~= "table" or type(status) ~= "table" then return end

    local pidOptions = rebuildProfileTable(
        fields[PID_FIELD_INDEX],
        resolveProfileCount(status, "pid_profile_count", "current_pid_profile_index")
    )
    local rateOptions = rebuildProfileTable(
        fields[RATE_FIELD_INDEX],
        resolveProfileCount(status, "control_rate_profile_count", "current_control_rate_profile_index")
    )

    updateChoiceField(PID_FIELD_INDEX, pidOptions)
    updateChoiceField(RATE_FIELD_INDEX, rateOptions)
end

local function postLoad(self)
    refreshProfileChoices()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function postRead(self)
    refreshProfileChoices()
end

local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function setPidProfile(profileIndex)
    local message = {command = 210, payload = {profileIndex}, simulatorResponse = {}}
    return queueDirect(message, string.format("profile.pid.%d", profileIndex))
end

local function setRateProfile(profileIndex)
    profileIndex = profileIndex + 128
    local message = {command = 210, payload = {profileIndex}, simulatorResponse = {}}
    return queueDirect(message, string.format("profile.rate.%d", profileIndex))
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

return {apidata = apidata, reboot = false, eepromWrite = false, wakeup = wakeup, onSaveMenu = onSaveMenu, refreshOnProfileChange = true, postLoad = postLoad, postRead = postRead, navButtons = {menu = true, save = true, reload = false, tool = false, help = true}, API = {}}
