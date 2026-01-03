--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local enableWakeup = false
local triggerSave = false

local FIELDS = {
    AILERON_DIRECTION = 1,
    ELEVATOR_DIRECTION = 2,
    COLLECTIVE_DIRECTION = 3,
    YAW_DIRECTION = 4,
}

local apidata

if rfsuite.utils.apiVersionCompare(">", "12.08") then
    apidata = {
        api = {
            [1] = 'MIXER_INPUT_INDEXED_ROLL',
            [2] = 'MIXER_INPUT_INDEXED_PITCH',
            [3] = 'MIXER_INPUT_INDEXED_COLLECTIVE',
            [4] = 'MIXER_INPUT_INDEXED_YAW',
        },
        formdata = {
            labels = {
            },
            fields = {
                [FIELDS.AILERON_DIRECTION]     = {t = "@i18n(app.modules.mixer.aileron_direction)@",             mspapi = 1, apikey="rate_stabilized_roll", type = 1},
                [FIELDS.ELEVATOR_DIRECTION]    = {t = "@i18n(app.modules.mixer.elevator_direction)@",            mspapi = 2, apikey="rate_stabilized_pitch", type = 1},
                [FIELDS.COLLECTIVE_DIRECTION]  = {t = "@i18n(app.modules.mixer.collective_direction)@",          mspapi = 3, apikey="rate_stabilized_collective", type = 1},            
                [FIELDS.YAW_DIRECTION]         = {t = "@i18n(app.modules.mixer.yaw_direction)@",                 mspapi = 4, apikey="rate_stabilized_yaw", type = 1},
            }
        }
    }
else
    apidata = {
        api = {
            [1] = 'MIXER_INPUT',
        },
        formdata = {
            labels = {
            },
            fields = {
                [FIELDS.AILERON_DIRECTION]     = {t = "@i18n(app.modules.mixer.aileron_direction)@",             mspapi = 1, apikey="rate_stabilized_roll", type = 1},
                [FIELDS.ELEVATOR_DIRECTION]    = {t = "@i18n(app.modules.mixer.elevator_direction)@",            mspapi = 1, apikey="rate_stabilized_pitch", type = 1},
                [FIELDS.COLLECTIVE_DIRECTION]  = {t = "@i18n(app.modules.mixer.collective_direction)@",          mspapi = 1, apikey="rate_stabilized_collective", type = 1},            
                [FIELDS.YAW_DIRECTION]         = {t = "@i18n(app.modules.mixer.yaw_direction)@",                 mspapi = 1, apikey="rate_stabilized_yaw", type = 1},
            }
        }
    }
end

local function saveMixerInputs()
    local app   = rfsuite.app
    local tasks = rfsuite.tasks
    local log   = rfsuite.utils.log

    local useIndexed = rfsuite.utils.apiVersionCompare(">", "12.08")

    app.Page.apidata.apiState.isProcessing = true

    if useIndexed then
        -- Indexed plan: each axis is its own API + its own field names
        local plan = {
            {
                label="roll",
                api="MIXER_INPUT_INDEXED_ROLL",
                formField=FIELDS.AILERON_DIRECTION,
                rateKey="rate_stabilized_roll",
                minKey ="min_stabilized_roll",
                maxKey ="max_stabilized_roll",
            },
            {
                label="pitch",
                api="MIXER_INPUT_INDEXED_PITCH",
                formField=FIELDS.ELEVATOR_DIRECTION,
                rateKey="rate_stabilized_pitch",
                minKey ="min_stabilized_pitch",
                maxKey ="max_stabilized_pitch",
            },
            {
                label="yaw",
                api="MIXER_INPUT_INDEXED_YAW",
                formField=FIELDS.YAW_DIRECTION,
                rateKey="rate_stabilized_yaw",
                minKey ="min_stabilized_yaw",
                maxKey ="max_stabilized_yaw",
            },
            {
                label="collective",
                api="MIXER_INPUT_INDEXED_COLLECTIVE",
                formField=FIELDS.COLLECTIVE_DIRECTION,
                rateKey="rate_stabilized_collective",
                minKey ="min_stabilized_collective",
                maxKey ="max_stabilized_collective",
            },
        }

        for _, item in ipairs(plan) do
            local field = app.Page.apidata.formdata.fields[item.formField]
            if not field then
                log("saveMixerInputs(indexed): missing field for " .. item.label, "error")
                app.triggers.saveFailed = true
                break
            end

            local rateVal = tonumber(field.value)
            if rateVal == nil then
                log("saveMixerInputs(indexed): invalid rate for " .. item.label, "error")
                app.triggers.saveFailed = true
                break
            end

            -- read current min/max from the *same* indexed API's parsed data
            local stored = tasks.msp.api.apidata.values[item.api]
            local parsed = stored and (stored.parsed or stored) or nil
            if not parsed then
                log("saveMixerInputs(indexed): no parsed data for " .. item.api, "error")
                app.triggers.saveFailed = true
                break
            end

            local API = tasks.msp.api.load(item.api)
            if not API then
                log("saveMixerInputs(indexed): failed to load " .. item.api, "error")
                app.triggers.saveFailed = true
                break
            end

            -- Populate payload (indexed API write structure expects these keys)
            API.setValue(item.rateKey, rateVal)
            API.setValue(item.minKey,  tonumber(parsed[item.minKey]) or 0)
            API.setValue(item.maxKey,  tonumber(parsed[item.maxKey]) or 0)

            -- Ensure unique queue identity (prevents overwrite/coalescing)
            API.setUUID(item.api .. ":" .. tostring(os.clock()))

            API.setErrorHandler(function(self, buf)
                app.triggers.saveFailed = true
            end)

            API.write()
        end
        app.Page.apidata.apiState.isProcessing = false
        return
    end

    -- Legacy path: single MIXER_INPUT api with index/rate/min/max
    local stored = tasks.msp.api.apidata.values["MIXER_INPUT"]
    local parsed = stored and (stored.parsed or stored) or nil
    if not parsed then
        log("saveMixerInputs(legacy): no parsed MIXER_INPUT data", "error")
        app.triggers.saveFailed = true
        return
    end

    local plan = {
        { label="roll",       index=1, formField=FIELDS.AILERON_DIRECTION,    minKey="min_stabilized_roll",       maxKey="max_stabilized_roll" },
        { label="pitch",      index=2, formField=FIELDS.ELEVATOR_DIRECTION,   minKey="min_stabilized_pitch",      maxKey="max_stabilized_pitch" },
        { label="yaw",        index=3, formField=FIELDS.YAW_DIRECTION,        minKey="min_stabilized_yaw",        maxKey="max_stabilized_yaw" },
        { label="collective", index=4, formField=FIELDS.COLLECTIVE_DIRECTION, minKey="min_stabilized_collective", maxKey="max_stabilized_collective" },
    }

    for _, item in ipairs(plan) do
        local field = app.Page.apidata.formdata.fields[item.formField]
        if not field then
            log("saveMixerInputs(legacy): missing field for " .. item.label, "error")
            app.triggers.saveFailed = true
            break
        end

        local rateVal = tonumber(field.value)
        if rateVal == nil then
            log("saveMixerInputs(legacy): invalid rate for " .. item.label, "error")
            app.triggers.saveFailed = true
            break
        end

        local API = tasks.msp.api.load("MIXER_INPUT")
        if not API then
            log("saveMixerInputs(legacy): failed to load MIXER_INPUT API", "error")
            app.triggers.saveFailed = true
            break
        end

        API.setValue("index", item.index)
        API.setValue("rate",  rateVal)
        API.setValue("min",   tonumber(parsed[item.minKey]) or 0)
        API.setValue("max",   tonumber(parsed[item.maxKey]) or 0)

        API.setUUID("MIXER_INPUT:" .. item.index .. ":" .. tostring(os.clock()))

        API.setErrorHandler(function(self, buf)
            app.triggers.saveFailed = true
        end)

        API.write()
    end
    app.Page.apidata.apiState.isProcessing = false
end



local function saveToEeprom()
    local mspEepromWrite = {
        command = 250, 
        simulatorResponse = {}, 
        processReply = function() rfsuite.utils.log("EEPROM write command sent","info") end
    }
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
end


local function onSaveMenuProgress()
    rfsuite.app.ui.progressDisplay("@i18n(app.modules.sbusout.saving)@", "@i18n(app.modules.sbusout.saving_data)@")
    saveMixerInputs()
    saveToEeprom()
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end


local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end


local function wakeup()
    if not enableWakeup then return end

    if triggerSave then
        onSaveMenuProgress()
        triggerSave = false
    end


end

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function onSaveMenu()
    form.openDialog({
    width = nil,
    title = "@i18n(app.msg_save_settings)@",
    message = ("@i18n(app.msg_save_current_page)@" ),
    buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()
                triggerSave = true
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    },
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT
})

    rfsuite.app.triggers.triggerSave = false
end


return {wakeup = wakeup, apidata = apidata, eepromWrite = true, postLoad = postLoad, reboot = false, API = {}, onNavMenu=onNavMenu, onSaveMenu = onSaveMenu}
