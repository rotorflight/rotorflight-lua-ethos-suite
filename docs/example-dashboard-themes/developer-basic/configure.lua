local activateWakeup = false

-- temp var to hold config while editing
local config = {}

local function configure()
    rfsuite.utils.log("configure dashboard theme","info")
    activateWakeup = true

    config.setting1 = rfsuite.widgets.dashboard.getPreference("setting1") or 0
    
    -- add form field
    local line = form.addLine("Setting 1")
    local minValue = 0
    local maxValue = 100
    local myField = form.addNumberField(line, nil, minValue, maxValue, 
                                        function() 
                                            return config.setting1
                                        end, 
                                        function(newValue) 
                                            config.setting1 = newValue
                                        end)


end

-- called when the save button is pressed
local function write()
    -- write config to preferences file
    for i,v in pairs(config) do
        rfsuite.widgets.dashboard.savePreference(i, v)
    end
end


local function wakeup()
    if activateWakeup == true then

    end
end    

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            rfsuite.i18n.get("app.modules.settings.dashboard"),
            "settings/tools/dashboard.lua"
        )
        return true
    end
end

return {
    event      = event,
    wakeup     = wakeup,
    configure   = configure,
    write       = write,
    save = save,
}
