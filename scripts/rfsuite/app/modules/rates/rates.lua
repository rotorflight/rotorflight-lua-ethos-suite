local labels = {}
local tables = {}
local alltables = {}

local activateWakeup = false
local activeRateTable


tables[0] = "app/modules/rates/ratetables/none.lua"
tables[1] = "app/modules/rates/ratetables/betaflight.lua"
tables[2] = "app/modules/rates/ratetables/raceflight.lua"
tables[3] = "app/modules/rates/ratetables/kiss.lua"
tables[4] = "app/modules/rates/ratetables/actual.lua"
tables[5] = "app/modules/rates/ratetables/quick.lua"

-- populate alltables with the tables
for i,v in ipairs(tables) do
    alltables[i] = assert(loadfile(v))()
end

if activeRateTable == nil then 
    activeRateTable = rfsuite.preferences.defaultRateProfile 
end


local mspapi = alltables[activeRateTable]
local mytable = mspapi.formdata

local function postLoad(self)

    local v = mspapi.values[mspapi.api[1]].rates_type
    if v ~= nil then activeRateTable = math.floor(v) end

    rfsuite.utils.log("Active Rate Table: " .. activeRateTable,"info")


    rfsuite.session.activeRateTable = activeRateTable

    -- update static text fields
    local v = mspapi.values[mspapi.api[1]].rates_type
    local cols = alltables[activeRateTable].formdata.cols
    local title = alltables[activeRateTable].formdata.name

    -- title
    rfsuite.app.formFields['col_0']:value(title)

    -- columns
    for i = 1, #cols do
        local txt = rightAlignText(rfsuite.session.colWidth, cols[i])
        rfsuite.app.formFields['col_' .. tostring((#cols + 1) - i)]:value(txt)
    end

    -- update field decimals mult max etc
    for x,f in ipairs(alltables[activeRateTable].formdata.fields) do
        if f.disable == true then
            rfsuite.utils.log("Disabling field: " .. f.apikey,"debug")
            rfsuite.app.formFields[x]:enable(false)
        else
            rfsuite.app.formFields[x]:enable(true)
        end
        if f.scale ~= nil then 
            rfsuite.utils.log("Setting scale for field: " .. f.apikey .. " to " .. f.scale,"debug")
            rfsuite.app.Page.fields[x].scale = f.scale
        else
            rfsuite.app.Page.fields[x].scale = nil    
        end
        if f.mult ~= nil then 
            rfsuite.utils.log("Setting mult for field: " .. f.apikey .. " to " .. f.mult,"debug")
            rfsuite.app.Page.fields[x].mult = f.mult
        else
            rfsuite.app.Page.fields[x].mult = nil        
        end
        if f.offset ~= nil then 
            rfsuite.utils.log("Setting offset for field: " .. f.apikey.. " to " .. f.offset,"debug")
            rfsuite.app.Page.fields[x].offset = f.offset
        else
            rfsuite.app.Page.fields[x].offset = nil           
        end
        if f.decimals ~= nil then
            rfsuite.utils.log("Setting decimals for field: " .. f.apikey .. " to " .. f.decimals,"debug")
            rfsuite.app.formFields[x]:decimals(math.floor(f.decimals))
            rfsuite.app.Page.fields[x].decimals = f.decimals
        else
            rfsuite.app.formFields[x]:decimals(nil)
            rfsuite.app.Page.fields[x].decimals = nil   
        end
        if f.unit ~= nil then 
            rfsuite.utils.log("Setting unit for field: " .. f.apikey.. " to " .. f.unit,"debug")
            rfsuite.app.formFields[x]:suffix(math.floor(f.unit))
            rfsuite.app.Page.fields[x].unit = f.unit
        else
            rfsuite.app.formFields[x]:suffix("")
            rfsuite.app.Page.fields[x].unit = nil    
        end
        if f.step ~= nil then
            rfsuite.utils.log("Setting step for field: " .. f.apikey.. " to " .. f.step,"debug")
            rfsuite.app.formFields[x]:step(math.floor(f.step))
            rfsuite.app.Page.fields[x].step = f.step
        else
            rfsuite.app.formFields[x]:step(1)
            rfsuite.app.Page.fields[x].step = nil
        end
        if f.min ~= nil then
            rfsuite.utils.log("Setting min for field: " .. f.apikey .. " to " .. f.min,"debug")
            local  minValue = f.min * rfsuite.utils.decimalInc(f.decimals)
            if f.mult ~= nil then
                minValue = minValue * f.mult
            end
            if f.scale ~= nil then
                minValue = minValue / f.scale
            end
            rfsuite.app.formFields[x]:minimum(math.floor(minValue))
            rfsuite.app.Page.fields[x].min = f.min
        else
            rfsuite.app.formFields[x]:minimum(0)
            rfsuite.app.Page.fields[x].min = nil    
        end
        if f.max ~= nil then
            rfsuite.utils.log("Setting max for field: " .. f.apikey .. " to " .. f.max,"debug")
            local maxValue = f.max * rfsuite.utils.decimalInc(f.decimals)
            if f.mult ~= nil then
                maxValue = maxValue * f.mult
            end
            if f.scale ~= nil then
                maxValue = maxValue / f.scale
            end
            rfsuite.app.formFields[x]:maximum(math.floor(maxValue))
            rfsuite.app.Page.fields[x].max = f.max
        else
            rfsuite.app.formFields[x]:maximum(0)
            rfsuite.app.Page.fields[x].max = nil    
        end
        if (f.default ~= nil) then
            rfsuite.utils.log("Setting default for field: " .. f.apikey .. " to " .. f.default,"debug")
                                
            -- factor in all possible scaling
            if f.offset ~= nil then f.default = f.default + f.offset end
            local default = f.default * rfsuite.utils.decimalInc(f.decimals)
            if f.mult ~= nil then default = default * f.mult end
    
            -- if for some reason we have a .0 we need to work around an ethos peculiarity on default boxes!
            local str = tostring(default)
            if str:match("%.0$") then default = math.ceil(default) end                            
    
            if f.type ~= 1 then 
                rfsuite.app.formFields[x]:default(math.floor(default))
                rfsuite.app.Page.fields[x].default = default
            end
        else
            rfsuite.app.formFields[x]:default(nil)
            rfsuite.app.Page.fields[x].default = nil    
        end
        -- set the value
        rfsuite.utils.log("Setting value for field: " .. f.apikey .. " to " .. f.value,"debug")
        rfsuite.app.Page.fields[x].value = f.value

    end


    rfsuite.app.triggers.closeProgressLoader = true
    rfsuite.app.triggers.isReady = true
    activateWakeup = true
  
end

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

    rfsuite.app.Page = assert(loadfile("app/modules/" .. script))()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.session.lastPage = script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    longPage = false

    form.clear()

    rfsuite.app.ui.fieldHeader(title)

    -- merge in form info when using multi msp api system
    if rfsuite.utils.is_multi_mspapi() then
        rfsuite.utils.log("Merging form data from mspapi","debug")
        rfsuite.app.Page.fields = rfsuite.app.Page.mspapi.formdata.fields
        rfsuite.app.Page.labels = rfsuite.app.Page.mspapi.formdata.labels
        rfsuite.app.Page.rows = rfsuite.app.Page.mspapi.formdata.rows
        rfsuite.app.Page.cols = rfsuite.app.Page.mspapi.formdata.cols
    end


    local numCols
    if rfsuite.app.Page.cols ~= nil then
        numCols = #rfsuite.app.Page.cols
    else
        numCols = 3
    end

    -- we dont use the global due to scrollers
    local screenWidth, screenHeight = rfsuite.app.getWindowSize()

    local padding = 10
    local paddingTop = rfsuite.app.radio.linePaddingTop
    local h = rfsuite.app.radio.navbuttonHeight
    local w = ((screenWidth * 70 / 100) / numCols)
    local paddingRight = 10
    local positions = {}
    local positions_r = {}
    local pos

    --line = form.addLine(mspapi.formdata.name)
    line = form.addLine("")
    pos = {x = 0, y = paddingTop, w = 200, h = h}
    rfsuite.app.formFields['col_0'] = form.addStaticText(line, pos, mspapi.formdata.name)

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

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
    local rateRows = {}
    for ri, rv in ipairs(rfsuite.app.Page.rows) do rateRows[ri] = form.addLine(rv) end

    for i = 1, #rfsuite.app.Page.fields do
        local f = rfsuite.app.Page.fields[i]
        local l = rfsuite.app.Page.labels
        local pageIdx = i
        local currentField = i

        if f.hidden == nil or f.hidden == false then
            posX = positions[f.col]

            pos = {x = posX + padding, y = posY, w = w - padding, h = h}

 
            rfsuite.app.formFields[i] = form.addNumberField(rateRows[f.row], pos, 0, 0, function()
                local value
                if rfsuite.session.activeRateProfile == 0 then
                    value = 0
                else
                    value = rfsuite.utils.getFieldValue(rfsuite.app.Page.fields[i])
                end
                return value
            end, function(value)
                f.value = rfsuite.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
                rfsuite.app.saveValue(i)
            end)
        end
    end

end

local function wakeup()

    if activateWakeup == true and rfsuite.bg.msp.mspQueue:isProcessed() then       
        if rfsuite.session.activeRateProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeRateProfile)
        end


        ----for i,v in ipairs(rfsuite.app.Page.fields) do
        --    rfsuite.utils.print_r(v)
       -- end    

    end

end

return {
    mspapi = mspapi,
    title = "Rates",
    reboot = false,
    eepromWrite = true,
    refreshOnRateChange = true,
    rows = mytable.rows,
    cols = mytable.cols,
    flagRateChange = flagRateChange,
    postLoad = postLoad,
    openPage = openPage,
    wakeup = wakeup,
    API = {},
}
