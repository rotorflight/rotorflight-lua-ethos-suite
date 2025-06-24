local settings_model = {}
local i18n = rfsuite.i18n.get

local function sensorNameMap(sensorList)
    local nameMap = {}
    for _, sensor in ipairs(sensorList) do
        nameMap[sensor.key] = sensor.name
    end
    return nameMap
end

local function openPage(pageIdx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.settings.name") .. " / " .. i18n("app.modules.settings.sensors") 
    )
    rfsuite.session.formLineCnt = 0

    local formFieldCount = 0

    local function sortSensorListByName(sensorList)
        table.sort(sensorList, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
        return sensorList
    end

    local sensorList = sortSensorListByName(rfsuite.tasks.telemetry.listAssignableSensors())

    settings_model = rfsuite.session.modelPreferences

    for i, v in ipairs(sensorList) do
    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(v.name or "unknown")


   rfsuite.app.formFields[formFieldCount] = form.addSourceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.session and rfsuite.session.modelPreferences then
                                                                local value = settings_model.sensormap[v.key]
                                                                if value then
                                                                    local scategory, smember = value:match("([^,]+),([^,]+)")
                                                                    if scategory and smember then
                                                                        local source = system.getSource({ category = tonumber(scategory), member = tonumber(smember) }) 
                                                                        return source
                                                                    end    
                                                                end
                                                                return nil
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.session and rfsuite.session.modelPreferences then
                                                                local cat_member = newValue:category() .. "," .. newValue:member()
                                                                settings_model.sensormap[v.key] = cat_member or nil
                                                            end    
                                                        end)


    end
  
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(
        pageIdx,
        i18n("app.modules.settings.name"),
        "settings/settings.lua"
    )
end

local function onSaveMenu()
    local buttons = {
        {
            label  = i18n("app.btn_ok_long"),
            action = function()
                local msg = i18n("app.modules.profile_select.save_prompt_local")
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(settings_model) do
                    rfsuite.session.modelPreferences[key] = value
                end
                -- save model dashboard settings
                if rfsuite.session.isConnected and rfsuite.session.mcu_id and rfsuite.session.modelPreferencesFile then
                    for key, value in pairs(settings_model) do
                        print("Saving key: " .. key .. " with value: " .. tostring(value))
                        rfsuite.session.modelPreferences.sensormap[key] = value
                    end
                    rfsuite.ini.save_ini_file(
                        rfsuite.session.modelPreferencesFile,
                        rfsuite.session.modelPreferences
                    )
                    rfsuite.tasks.telemetry.reset()
                end    

                rfsuite.app.triggers.closeSave = true
                return true
            end,
        },
        {
            label  = i18n("app.modules.profile_select.cancel"),
            action = function()
                return true
            end,
        },
    }

    form.openDialog({
        width   = nil,
        title   = i18n("app.modules.profile_select.save_settings"),
        message = i18n("app.modules.profile_select.save_prompt_local"),
        buttons = buttons,
        wakeup  = function() end,
        paint   = function() end,
        options = TEXT_LEFT,
    })
end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            i18n("app.modules.settings.name"),
            "settings/settings.lua"
        )
        return true
    end
end

return {
    event      = event,
    openPage   = openPage,
    wakeup     = wakeup,
    onNavMenu  = onNavMenu,
    onSaveMenu = onSaveMenu,
    navButtons = {
        menu   = true,
        save   = true,
        reload = false,
        tool   = false,
        help   = false,
    },
    API = {},
}
