local fields
local setActiveProfile = nil
local batteryProfile = nil

-- we have profiles in mspo >= 12.08
if rfsuite.session.apiVersion < 12.08 then
    fields = {
        {t = rfsuite.i18n.get("app.modules.battery.max_cell_voltage"), mspapi = 1, apikey="vbatmaxcellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.full_cell_voltage"), mspapi = 1,  apikey="vbatfullcellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.warn_cell_voltage"), mspapi = 1,  apikey="vbatwarningcellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.min_cell_voltage"), mspapi = 1,  apikey="vbatmincellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.battery_capacity"), mspapi = 1,  apikey="batteryCapacity"},
        {t = rfsuite.i18n.get("app.modules.battery.cell_count"), mspapi = 1,  apikey="batteryCellCount"},
    }
else
    fields = {
        {t = rfsuite.i18n.get("app.modules.battery.max_cell_voltage"), mspapi = 1, apikey="vbatmaxcellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.full_cell_voltage"), mspapi = 1,  apikey="vbatfullcellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.warn_cell_voltage"), mspapi = 1,  apikey="vbatwarningcellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.min_cell_voltage"), mspapi = 1,  apikey="vbatmincellvoltage"},
        {t = rfsuite.i18n.get("app.modules.battery.capacity"), mspapi = 1,  apikey="batteryCapacity", label = 1, inline = 2},
        {t = rfsuite.i18n.get("app.modules.battery.cells"), mspapi = 1,  apikey="batteryCellCount", label = 1 , inline = 1},
        {t = rfsuite.i18n.get("app.modules.battery.capacity"), mspapi = 1,  apikey="batteryCapacity_1", label = 2, inline = 2},
        {t = rfsuite.i18n.get("app.modules.battery.cells"), mspapi = 1,  apikey="batteryCellCount_1", label = 2 , inline = 1},
        {t = rfsuite.i18n.get("app.modules.battery.capacity"), mspapi = 1,  apikey="batteryCapacity_2", label = 3, inline = 2},
        {t = rfsuite.i18n.get("app.modules.battery.cells"), mspapi = 1,  apikey="batteryCellCount_2", label = 3 , inline = 1},
        {t = rfsuite.i18n.get("app.modules.battery.capacity"), mspapi = 1,  apikey="batteryCapacity_3", label = 4, inline = 2},
        {t = rfsuite.i18n.get("app.modules.battery.cells"), mspapi = 1,  apikey="batteryCellCount_3", label = 4 , inline = 1},
        {t = rfsuite.i18n.get("app.modules.battery.capacity"), mspapi = 1,  apikey="batteryCapacity_4", label = 5, inline = 2},
        {t = rfsuite.i18n.get("app.modules.battery.cells"), mspapi = 1,  apikey="batteryCellCount_4", label = 5 , inline = 1},
        {t = rfsuite.i18n.get("app.modules.battery.capacity"), mspapi = 1,  apikey="batteryCapacity_5", label = 6, inline = 2},
        {t = rfsuite.i18n.get("app.modules.battery.cells"), mspapi = 1,  apikey="batteryCellCount_5", label = 6 , inline = 1},

    }
end

local mspapi = {
    api = {
        [1] = 'BATTERY_CONFIG',
    },
    formdata = {
        labels = {
            {t =  rfsuite.i18n.get("app.modules.battery.battery_profile") .. " #1", label = 1, inline_size = 17.45},
            {t =  rfsuite.i18n.get("app.modules.battery.battery_profile") .. " #2", label = 2, inline_size = 17.45},
            {t =  rfsuite.i18n.get("app.modules.battery.battery_profile") .. " #3", label = 3, inline_size = 17.45},
            {t =  rfsuite.i18n.get("app.modules.battery.battery_profile") .. " #4", label = 4, inline_size = 17.45},
            {t =  rfsuite.i18n.get("app.modules.battery.battery_profile") .. " #5", label = 5, inline_size = 17.45},
            {t =  rfsuite.i18n.get("app.modules.battery.battery_profile") .. " #6", label = 6, inline_size = 17.45},
        },
        fields = fields
    }                 
}

local function onToolMenu(self)

    local buttons = {
        {
            label = rfsuite.i18n.get("app.btn_cancel"),
            action = function()
                return true
            end
        },         
        {
            label = " 6 ",
            action = function()
                setActiveProfile = 5
                return true
            end
        },{
            label = " 5 ",
            action = function()
                setActiveProfile = 4
                return true
            end
        },{
            label = " 4 ",
            action = function()
                setActiveProfile = 3
                return true
            end
        },{
            label = " 3 ",
            action = function()
                setActiveProfile = 2
                return true
            end
        },{
            label = " 2 ",
            action = function()
                setActiveProfile = 1
                return true
            end
        }, {
            label = " 1 ",
            action = function()
                setActiveProfile = 0
                return true
            end
        }
    }

    local LCD_W, LCD_H = rfsuite.utils.getWindowSize()

    form.openDialog({
        width = LCD_W * 0.8,
        title = "Battery Profile",
        message = "Please set the active profile",
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })


end

local function wakeup()

    if setActiveProfile ~= nil then
        local API = rfsuite.tasks.msp.api.load("SELECT_BATTERY")
        API.setCompleteHandler(function(self, buf)
            rfsuite.utils.log("Battery Profile Set to " .. setActiveProfile,"info")
            rfsuite.app.formFields['title']:value(rfsuite.i18n.get("app.modules.battery.name") .. " #" .. setActiveProfile)
            setActiveProfile = nil

        end)
        API.setErrorHandler(function(self, buf)
            rfsuite.utils.log("Failed to set battery profile " .. setActiveProfile,"info")
            setActiveProfile = nil
        end)
        API.setUUID("123e4567-e89b-12d3-a456-426614174000")
        if setActiveProfile ~= nil then
            API.setValue("id", setActiveProfile)
            API.write()
        end
        
    end

    if rfsuite.tasks.msp.mspQueue:isProcessed() and batteryProfile == nil then
        local API = rfsuite.tasks.msp.api.load("STATUS")
        API.setCompleteHandler(function(self, buf)
            batteryProfile = API.readValue("battery_profile")
            rfsuite.utils.log("Battery Profile " .. batteryProfile,"info")
            rfsuite.app.formFields['title']:value(rfsuite.i18n.get("app.modules.battery.name") .. " #" .. batteryProfile)
        end)
        API.setUUID("123e4567-e89b-12d3-a456-426614174001")
        API.read()
    end    


end

local function getNavButtons(self)

    local navButtons

    if rfsuite.session.apiVersion < 12.08 then
        navButtons = {
            menu = true,
            save = true,
            reload = true,
            tool = false,
            help = true
        }
    else
        navButtons = {
            menu = true,
            save = true,
            reload = true,
            tool = true,
            help = true
        }   
    end

    return navButtons
end



return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    API = {},
    wakeup = wakeup,
    navButtons = getNavButtons,
    onToolMenu = onToolMenu,
}
