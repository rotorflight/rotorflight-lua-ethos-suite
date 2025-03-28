
local activateWakeup = false
local extraMsgOnSave = nil
local resetRates = false
local doFullReload = false

if rfsuite.session.activeRateTable == nil then 
    rfsuite.session.activeRateTable = rfsuite.preferences.defaultRateProfile 
end

--[[
local mspapi = {
    api = {
        [1] = 'RC_TUNING',
    },
    formdata = {
        labels = {
            {t = rfsuite.i18n.get("app.modules.rates_advanced.roll_dynamics"),       label = 1, inline_size = 12.1},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.pitch_dynamics"),      label = 2, inline_size = 12.1},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.yaw_dynamics"),        label = 3, inline_size = 12.1},
            {t = "",        label = 3.5, inline_size = 12.1},
            --{t = "",        label = 3.6, inline_size = 14.8},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.collective_dynamics"), label = 4, inline_size = 12.1},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.roll_boost"), label = 5, inline_size = 12.1},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.pitch_boost"), label = 6, inline_size = 12.1},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.yaw_boost"), label = 7, inline_size = 12.1},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.collective_boost"), label = 8, inline_size = 12.1},
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.rates_advanced.rates_type"),        mspapi = 1, apikey = "rates_type", type = 1, ratetype = 1, postEdit = function(self) self.flagRateChange(self, true) end},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.response_time"),     inline = 2, label = 1, mspapi = 1, apikey = "response_time_1"},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.accel_limit"),       inline = 1, label = 1, mspapi = 1, apikey = "accel_limit_1"},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.response_time"),     inline = 2, label = 2, mspapi = 1, apikey = "response_time_2"},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.accel_limit"),       inline = 1, label = 2, mspapi = 1, apikey = "accel_limit_2"},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.response_time"),     inline = 2, label = 3, mspapi = 1, apikey = "response_time_3"},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.accel_limit"),       inline = 1, label = 3, mspapi = 1, apikey = "accel_limit_3"},

            {t = rfsuite.i18n.get("app.modules.rates_advanced.yaw_dynamic_ceiling_gain"),     inline = 3, label = 3.5, mspapi = 1, apikey = "yaw_dynamic_ceiling_gain", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.yaw_dynamic_deadband_gain"),     inline = 2, label = 3.5, mspapi = 1, apikey = "yaw_dynamic_deadband_gain", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.yaw_dynamic_deadband_filter"),     inline = 1, label = 3.5, mspapi = 1, apikey = "yaw_dynamic_deadband_filter", apiversiongte = 12.08},


            {t = rfsuite.i18n.get("app.modules.rates_advanced.response_time"),     inline = 2, label = 4, mspapi = 1, apikey = "response_time_4"},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.accel_limit"),       inline = 1, label = 4, mspapi = 1, apikey = "accel_limit_4"},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.gain"),       inline = 2, label = 5, mspapi = 1, apikey = "setpoint_boost_gain_1", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.cutoff"),     inline = 1, label = 5, mspapi = 1, apikey = "setpoint_boost_cutoff_1", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.gain"),       inline = 2, label = 6, mspapi = 1, apikey = "setpoint_boost_gain_2",apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.cutoff"),     inline = 1, label = 6, mspapi = 1, apikey = "setpoint_boost_cutoff_2", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.gain"),       inline = 2, label = 7, mspapi = 1, apikey = "setpoint_boost_gain_3", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.cutoff"),     inline = 1, label = 7, mspapi = 1, apikey = "setpoint_boost_cutoff_3", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.gain"),       inline = 2, label = 8, mspapi = 1, apikey = "setpoint_boost_gain_4", apiversiongte = 12.08},
            {t = rfsuite.i18n.get("app.modules.rates_advanced.cutoff"),     inline = 1, label = 8, mspapi = 1, apikey = "setpoint_boost_cutoff_4", apiversiongte = 12.08},

        }
    }                 
}
    ]]--
   

local mspapi = {
    api = {
        [1] = 'RC_TUNING',
    },
    formdata = {
        name = "Dynamics",
        labels = {
        },
        rows = {
            "Response Time",
            "Accelerometer Limit",
            "Setpoint Boost Gain",
            "Setpoint Boost Cutoff",
            "Dyn. Ceiling Gain",
            "Dyn. Deadband. Gain",
            "Dyn. Deadband. Filter",
            rfsuite.i18n.get("app.modules.rates_advanced.rates_type")
        },
        cols = {
            "Roll",
            "Pitch",
            "Yaw",
            "Col"
        },
        fields = {
            -- response time
            {row = 1, col = 1, mspapi = 1, apikey = "response_time_1"},
            {row = 1, col = 2, mspapi = 1, apikey = "response_time_2"},
            {row = 1, col = 3, mspapi = 1, apikey = "response_time_3"},
            {row = 1, col = 4, mspapi = 1, apikey = "response_time_4"},

            {row = 2, col = 1, mspapi = 1, apikey = "accel_limit_1"},
            {row = 2, col = 2, mspapi = 1, apikey = "accel_limit_2"},
            {row = 2, col = 3, mspapi = 1, apikey = "accel_limit_3"},
            {row = 2, col = 4, mspapi = 1, apikey = "accel_limit_4"},

            {row = 3, col = 1, mspapi = 1, apikey = "setpoint_boost_gain_1", apiversiongte = 12.08},
            {row = 3, col = 2, mspapi = 1, apikey = "setpoint_boost_gain_2", apiversiongte = 12.08},
            {row = 3, col = 3, mspapi = 1, apikey = "setpoint_boost_gain_3", apiversiongte = 12.08},
            {row = 3, col = 4, mspapi = 1, apikey = "setpoint_boost_gain_4", apiversiongte = 12.08},
            
            {row = 4, col = 1, mspapi = 1, apikey = "setpoint_boost_cutoff_1", apiversiongte = 12.08},
            {row = 4, col = 2, mspapi = 1, apikey = "setpoint_boost_cutoff_2", apiversiongte = 12.08},
            {row = 4, col = 3, mspapi = 1, apikey = "setpoint_boost_cutoff_3", apiversiongte = 12.08},
            {row = 4, col = 4, mspapi = 1, apikey = "setpoint_boost_cutoff_4", apiversiongte = 12.08},

            {row = 5, col = 3, mspapi = 1, apikey = "yaw_dynamic_ceiling_gain", apiversiongte = 12.08},
            {row = 6, col = 3, mspapi = 1, apikey = "yaw_dynamic_deadband_gain", apiversiongte = 12.08},
            {row = 7, col = 3, mspapi = 1, apikey = "yaw_dynamic_deadband_filter", apiversiongte = 12.08},

            {mspapi = 1, apikey = "rates_type", type = 1, ratetype = 1, postEdit = function(self) self.flagRateChange(self, true) end},

        }
    }                 
}

function rightAlignText(width, text)
    local textWidth, _ = lcd.getTextSize(text)  -- Get the text width
    local padding = width - textWidth  -- Calculate how much padding is needed
    
    if padding > 0 then
        return string.rep(" ", math.floor(padding / lcd.getTextSize(" "))) .. text
    else
        return text  -- No padding needed if text is already wider than width
    end
end


local function openPage(idx, title, script)

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false

    rfsuite.app.Page = assert(loadfile("app/modules/" .. script))()
    -- collectgarbage()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.session.lastPage = script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    longPage = false

    form.clear()

    rfsuite.app.ui.fieldHeader(title)
    local numCols
    if rfsuite.app.Page.cols ~= nil then
        numCols = #rfsuite.app.Page.cols
    else
        numCols = 4
    end
    local screenWidth = rfsuite.session.lcdWidth - 10
    local padding = 10
    local paddingTop = rfsuite.app.radio.linePaddingTop
    local h = rfsuite.app.radio.navbuttonHeight
    local w = ((screenWidth * 60 / 100) / numCols)
    local paddingRight = 20
    local positions = {}
    local positions_r = {}
    local pos

    line = form.addLine("")

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop


    rfsuite.utils.log("Merging form data from mspapi","debug")
    rfsuite.app.Page.fields = rfsuite.app.Page.mspapi.formdata.fields
    rfsuite.app.Page.labels = rfsuite.app.Page.mspapi.formdata.labels
    rfsuite.app.Page.rows = rfsuite.app.Page.mspapi.formdata.rows
    rfsuite.app.Page.cols = rfsuite.app.Page.mspapi.formdata.cols

    rfsuite.session.colWidth = w - paddingRight

    local c = 1
    while loc > 0 do
        local colLabel = rfsuite.app.Page.cols[loc]

        positions[loc] = posX - w
        positions_r[c] = posX - w

        lcd.font(FONT_STD)
        --local tsizeW, tsizeH = lcd.getTextSize(colLabel)
        colLabel = rightAlignText(rfsuite.session.colWidth, colLabel)

        local posTxt = positions_r[c] + paddingRight 

        pos = {x = posTxt, y = posY, w = w, h = h}
        rfsuite.app.formFields['col_'..tostring(c)] = form.addStaticText(line, pos, colLabel)

        posX = math.floor(posX - w)

        loc = loc - 1
        c = c + 1
    end

    -- display each row
    local fieldRows = {}
    for ri, rv in ipairs(rfsuite.app.Page.rows) do fieldRows[ri] = form.addLine(rv) end

    for i = 1, #rfsuite.app.Page.fields do
        local f = rfsuite.app.Page.fields[i]
        if f.row and f.col then
            local l = rfsuite.app.Page.labels
            local pageIdx = i
            local currentField = i

            posX = positions[f.col]

            pos = {x = posX + padding, y = posY, w = w - padding, h = h}

            rfsuite.app.formFields[i] = form.addNumberField(fieldRows[f.row], pos, 0, 0, function()
                if rfsuite.app.Page.fields == nil or rfsuite.app.Page.fields[i] == nil then
                    ui.disableAllFields()
                    ui.disableAllNavigationFields()
                    ui.enableNavigationField('menu')
                    return nil
                end
                return rfsuite.app.utils.getFieldValue(rfsuite.app.Page.fields[i])
            end, function(value)
                if f.postEdit then f.postEdit(rfsuite.app.Page) end
                if f.onChange then f.onChange(rfsuite.app.Page) end
        
                f.value = rfsuite.app.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
            end)
        end
    end
    
end

local function preSave(self)
    if resetRates == true then
        rfsuite.utils.log("Resetting rates to defaults","info")

        -- selected id
        local table_id = rfsuite.app.Page.fields[1].value

        -- load the respective rate table
        local tables = {}
        tables[0] = "app/modules/rates/ratetables/none.lua"
        tables[1] = "app/modules/rates/ratetables/betaflight.lua"
        tables[2] = "app/modules/rates/ratetables/raceflight.lua"
        tables[3] = "app/modules/rates/ratetables/kiss.lua"
        tables[4] = "app/modules/rates/ratetables/actual.lua"
        tables[5] = "app/modules/rates/ratetables/quick.lua"
        
        local mytable = assert(loadfile(tables[table_id]))()

        rfsuite.utils.log("Using defaults from table " .. tables[table_id], "info")

        -- pull all the values to the fields table as not created because not rendered!
        for _, y in pairs(mytable.formdata.fields) do
            if y.default then
                local found = false
        

                -- Check if an entry with the same apikey exists
                for i, v in ipairs(rfsuite.app.Page.fields) do
                    if v.apikey == y.apikey then
                        -- Update existing entry
                        rfsuite.app.Page.fields[i] = y
                        found = true
                        break
                    end
                end
        
                -- If no match was found, insert as a new entry and set value to default
                if not found then
                    table.insert(rfsuite.app.Page.fields, y)
                end
            end
        end

        -- save all the values
        for i,v in ipairs(rfsuite.app.Page.fields) do

                if v.apikey == "rates_type" then
                    v.value = table_id
                else 

                    local default = v.default or 0
                    default = default * rfsuite.app.utils.decimalInc(v.decimals)
                    if v.mult ~= nil then default = math.floor(default * (v.mult)) end
                    if v.scale ~= nil then default = math.floor(default / v.scale) end
                    
                    rfsuite.utils.log("Saving default value for " .. v.apikey .. " as " .. default, "debug")
                    rfsuite.app.utils.saveFieldValue(v, default)
                end    
        end    
            
    end
 
end    

local function postLoad(self)

    local v = mspapi.values[mspapi.api[1]].rates_type
    
    rfsuite.utils.log("Active Rate Table: " .. rfsuite.session.activeRateTable,"info")

    if v ~= rfsuite.session.activeRateTable then
        rfsuite.utils.log("Switching Rate Table: " .. v,"info")
        rfsuite.app.triggers.reloadFull = true
        rfsuite.session.activeRateTable = v           
        return
    end 


    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup and rfsuite.tasks.msp.mspQueue:isProcessed() then
        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.session.activeRateProfile then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeRateProfile)
        end

        -- reload the page
        if doFullReload == true then
            rfsuite.utils.log("Reloading full after rate type change","info")
            rfsuite.app.triggers.reload = true
            doFullReload = false
        end    
    end
end

-- enable and disable fields if rate type changes
local function flagRateChange(self)

    if math.floor(rfsuite.app.Page.fields[1].value) == math.floor(rfsuite.session.activeRateTable) then
        self.extraMsgOnSave = nil
        rfsuite.app.ui.enableAllFields()
        resetRates = false
    else
        self.extraMsgOnSave = rfsuite.i18n.get("app.modules.rates_advanced.msg_reset_to_defaults")
        resetRates = true
        rfsuite.app.ui.disableAllFields()
        rfsuite.app.formFields[1]:enable(true)
    end
end

local function postEepromWrite(self)
        -- trigger full reload after writting eeprom - needed as we are changing the rate type
        if resetRates == true then
            doFullReload = true
        end
        
end

return {
    mspapi = mspapi,
    title = rfsuite.i18n.get("app.modules.rates_advanced.name"),
    reboot = false,
    openPage = openPage,
    eepromWrite = true,
    refreshOnRateChange = true,
    rTableName = rTableName,
    flagRateChange = flagRateChange,
    postLoad = postLoad,
    wakeup = wakeup,
    preSave = preSave,
    postEepromWrite = postEepromWrite,
    extraMsgOnSave = extraMsgOnSave,
    API = {},
}
