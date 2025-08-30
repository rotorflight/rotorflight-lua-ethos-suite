
local activateWakeup = false
local extraMsgOnSave = nil
local resetRates = false
local doFullReload = false
local i18n = rfsuite.i18n.get

if rfsuite.session.activeRateTable == nil then 
    rfsuite.session.activeRateTable = rfsuite.config.defaultRateProfile 
end

local rows
if rfsuite.utils.apiVersionCompare(">=", "12.08") then
    print("here")
    rows = {
        i18n("app.modules.rates_advanced.response_time"),
        i18n("app.modules.rates_advanced.acc_limit"),
        i18n("app.modules.rates_advanced.setpoint_boost_gain"),
        i18n("app.modules.rates_advanced.setpoint_boost_cutoff"),
        i18n("app.modules.rates_advanced.dyn_ceiling_gain"),
        i18n("app.modules.rates_advanced.dyn_deadband_gain"),
        i18n("app.modules.rates_advanced.dyn_deadband_filter"),
    }
else
    rows = {
        i18n("app.modules.rates_advanced.response_time"),
        i18n("app.modules.rates_advanced.acc_limit"),
    }
end

   
local apidata = {
    api = {
        [1] = 'RC_TUNING',
    },
    formdata = {
        name = i18n("app.modules.rates_advanced.dynamics"),
        labels = {
        },
        rows = rows,
        cols = {
            i18n("app.modules.rates_advanced.roll"),
            i18n("app.modules.rates_advanced.pitch"),
            i18n("app.modules.rates_advanced.yaw"),
            i18n("app.modules.rates_advanced.col")
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

    rfsuite.app.Page = assert(rfsuite.compiler.loadfile("app/modules/" .. script))()
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
    local screenWidth = rfsuite.app.lcdWidth - 10
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
    rfsuite.app.Page.fields = rfsuite.app.Page.apidata.formdata.fields
    rfsuite.app.Page.labels = rfsuite.app.Page.apidata.formdata.labels
    rfsuite.app.Page.rows = rfsuite.app.Page.apidata.formdata.rows
    rfsuite.app.Page.cols = rfsuite.app.Page.apidata.formdata.cols

    rfsuite.session.colWidth = w - paddingRight

    local c = 1
    while loc > 0 do
        local colLabel = rfsuite.app.Page.cols[loc]

        positions[loc] = posX - w
        positions_r[c] = posX - w

        lcd.font(FONT_M)
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

        local valid =
            (f.apiversion    == nil or rfsuite.utils.apiVersionCompare(">=", f.apiversion))    and
            (f.apiversionlt  == nil or rfsuite.utils.apiVersionCompare("<",  f.apiversionlt))  and
            (f.apiversiongt  == nil or rfsuite.utils.apiVersionCompare(">",  f.apiversiongt))  and
            (f.apiversionlte == nil or rfsuite.utils.apiVersionCompare("<=", f.apiversionlte)) and
            (f.apiversiongte == nil or rfsuite.utils.apiVersionCompare(">=", f.apiversiongte)) and
            (f.enablefunction == nil or f.enablefunction())

        
        if f.row and f.col and valid then
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



local function postLoad(self)

    local v = apidata.values[apidata.api[1]].rates_type
    
    rfsuite.utils.log("Active Rate Table: " .. rfsuite.session.activeRateTable,"debug")

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

local function onToolMenu()
        
end



return {
    apidata = apidata,
    title = i18n("app.modules.rates_advanced.name"),
    reboot = false,
    openPage = openPage,
    eepromWrite = true,
    refreshOnRateChange = true,
    rTableName = rTableName,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
    onToolMenu = onToolMenu,
    navButtons = {
        menu = true,
        save = true,
        reload = true,
        tool = false,
        help = true
    },
}
