local labels = {}
local tables = {}

local activateWakeup = false
local i18n = rfsuite.i18n.get

tables[0] = "app/modules/rates/ratetables/none.lua"
tables[1] = "app/modules/rates/ratetables/betaflight.lua"
tables[2] = "app/modules/rates/ratetables/raceflight.lua"
tables[3] = "app/modules/rates/ratetables/kiss.lua"
tables[4] = "app/modules/rates/ratetables/actual.lua"
tables[5] = "app/modules/rates/ratetables/quick.lua"

if rfsuite.session.activeRateTable == nil then 
    rfsuite.session.activeRateTable = rfsuite.config.defaultRateProfile 
end


rfsuite.utils.log("Loading Rate Table: " .. tables[rfsuite.session.activeRateTable],"debug")
local apidata = assert(rfsuite.compiler.loadfile(tables[rfsuite.session.activeRateTable]))()
local mytable = apidata.formdata



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

    rfsuite.app.Page = assert(rfsuite.compiler.loadfile("app/modules/" .. script))()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.session.lastPage = script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    longPage = false

    form.clear()

    rfsuite.app.ui.fieldHeader(title)

    rfsuite.utils.log("Merging form data from apidata","debug")
    rfsuite.app.Page.fields = rfsuite.app.Page.apidata.formdata.fields
    rfsuite.app.Page.labels = rfsuite.app.Page.apidata.formdata.labels
    rfsuite.app.Page.rows = rfsuite.app.Page.apidata.formdata.rows
    rfsuite.app.Page.cols = rfsuite.app.Page.apidata.formdata.cols

    local numCols
    if rfsuite.app.Page.cols ~= nil then
        numCols = #rfsuite.app.Page.cols
    else
        numCols = 3
    end

    -- we dont use the global due to scrollers
    local screenWidth, screenHeight = lcd.getWindowSize()

    local padding = 10
    local paddingTop = rfsuite.app.radio.linePaddingTop
    local h = rfsuite.app.radio.navbuttonHeight
    local w = ((screenWidth * 70 / 100) / numCols)
    local paddingRight = 10
    local positions = {}
    local positions_r = {}
    local pos

    --line = form.addLine(apidata.formdata.name)
    line = form.addLine("")
    pos = {x = 0, y = paddingTop, w = 200, h = h}
    rfsuite.app.formFields['col_0'] = form.addStaticText(line, pos, apidata.formdata.name)

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

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

            minValue = f.min * rfsuite.app.utils.decimalInc(f.decimals)
            maxValue = f.max * rfsuite.app.utils.decimalInc(f.decimals)
            if f.mult ~= nil then
                minValue = minValue * f.mult
                maxValue = maxValue * f.mult
            end
            if f.scale ~= nil then
                minValue = minValue / f.scale
                maxValue = maxValue / f.scale
            end            

            rfsuite.app.formFields[i] = form.addNumberField(rateRows[f.row], pos, minValue, maxValue, function()
                local value
                if rfsuite.session.activeRateProfile == 0 then
                    value = 0
                else
                    value = rfsuite.app.utils.getFieldValue(rfsuite.app.Page.fields[i])
                end
                return value
            end, function(value)
                f.value = rfsuite.app.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
            end)
            if f.default ~= nil then
                local default = f.default * rfsuite.app.utils.decimalInc(f.decimals)
                if f.mult ~= nil then default = math.floor(default * f.mult) end
                if f.scale ~= nil then default = math.floor(default / f.scale) end
                rfsuite.app.formFields[i]:default(default)
            else
                rfsuite.app.formFields[i]:default(0)
            end           
            if f.decimals ~= nil then rfsuite.app.formFields[i]:decimals(f.decimals) end
            if f.unit ~= nil then rfsuite.app.formFields[i]:suffix(f.unit) end
            if f.step ~= nil then rfsuite.app.formFields[i]:step(f.step) end
            if f.help ~= nil then
                if rfsuite.app.fieldHelpTxt[f.help]['t'] ~= nil then
                    local helpTxt = rfsuite.app.fieldHelpTxt[f.help]['t']
                    rfsuite.app.formFields[i]:help(helpTxt)
                end
            end   
            if f.disable == true then 
                rfsuite.app.formFields[i]:enable(false) 
            end  
        end
    end

end

local function wakeup()

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then       
        if rfsuite.session.activeRateProfile ~= nil then
            if rfsuite.app.formFields['title'] then
                rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeRateProfile)
            end
        end 
    end
end

local function onHelpMenu()

    local helpPath = "app/modules/rates/help.lua"
    local help = assert(rfsuite.compiler.loadfile(helpPath))()

    rfsuite.app.ui.openPageHelp(help.help["table"][rfsuite.session.activeRateTable], "rates")


end    

return {
    apidata = apidata,
    title = i18n("app.modules.rates.name"),
    reboot = false,
    eepromWrite = true,
    refreshOnRateChange = true,
    rows = mytable.rows,
    cols = mytable.cols,
    flagRateChange = flagRateChange,
    postLoad = postLoad,
    openPage = openPage,
    wakeup = wakeup,
    onHelpMenu = onHelpMenu,
    API = {},
}
