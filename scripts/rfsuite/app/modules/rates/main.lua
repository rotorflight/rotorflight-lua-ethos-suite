local labels = {}
local tables = {}

local activateWakeup = false
local currentProfileChecked = false

tables[0] = "app/modules/rates/ratetables/none.lua"
tables[1] = "app/modules/rates/ratetables/betaflight.lua"
tables[2] = "app/modules/rates/ratetables/raceflight.lua"
tables[3] = "app/modules/rates/ratetables/kiss.lua"
tables[4] = "app/modules/rates/ratetables/actual.lua"
tables[5] = "app/modules/rates/ratetables/quick.lua"

if rfsuite.rateProfile == nil then rfsuite.rateProfile = rfsuite.config.defaultRateProfile end

local mytable = assert(loadfile(tables[rfsuite.rateProfile]))()

local fields = mytable.fields

fields[13] = {t = "Rates Type", hidden = true, ratetype = 1, min = 0, max = 5, vals = {1}}

local function postLoad(self)
    -- if the activeRateProfile is not what we are displaying
    -- then we need to trigger a reload of the page
    local v = rfsuite.app.Page.values[1]
    if v ~= nil then rfsuite.activeRateProfile = math.floor(v) end

    if rfsuite.activeRateProfile ~= nil then
        if rfsuite.activeRateProfile ~= rfsuite.rateProfile then
            rfsuite.rateProfile = rfsuite.activeRateProfile
            rfsuite.app.triggers.reloadFull = true
            return
        end
    end

    rfsuite.app.triggers.isReady = true

    activateWakeup = true

end

local function flagRateChange(self)
    rfsuite.app.triggers.resetRates = true
end

local function openPage(idx, title, script)

    rfsuite.app.Page = assert(loadfile("app/modules/" .. script))()
    -- collectgarbage()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.lastPage = script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    longPage = false

    form.clear()

    rfsuite.app.ui.fieldHeader(title)

    local numCols = #rfsuite.app.Page.cols

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

    line = form.addLine(rfsuite.app.Page.rTableName)

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

    local c = 1
    while loc > 0 do
        local colLabel = rfsuite.app.Page.cols[loc]

        positions[loc] = posX - w
        positions_r[c] = posX - w

        lcd.font(FONT_STD)
        local tsizeW, tsizeH = lcd.getTextSize(colLabel)

        local posTxt = (positions_r[c] + w) - tsizeW

        pos = {x = posTxt, y = posY, w = w, h = h}
        form.addStaticText(line, pos, colLabel)

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

            minValue = f.min * rfsuite.utils.decimalInc(f.decimals)
            maxValue = f.max * rfsuite.utils.decimalInc(f.decimals)
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
                if rfsuite.activeRateProfile == 0 then
                    value = 0
                else
                    value = rfsuite.utils.getFieldValue(rfsuite.app.Page.fields[i])
                end
                return value
            end, function(value)
                f.value = rfsuite.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
                rfsuite.app.saveValue(i)
            end)
            if f.default ~= nil then
                local default = f.default * rfsuite.utils.decimalInc(f.decimals)
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
            if f.disable == true then rfsuite.app.formFields[i]:enable(false) end
        end
    end

end

local function wakeup()

    if activateWakeup == true and currentProfileChecked == false and rfsuite.bg.msp.mspQueue:isProcessed() then

        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.config.activeRateProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.config.activeRateProfile)
            currentProfileChecked = true
        end

    end

end

return {
    read = 111, -- msp_RC_TUNING
    write = 204, -- msp_SET_RC_TUNING
    title = "Rates",
    reboot = false,
    eepromWrite = true,
    minBytes = 25,
    labels = labels,
    fields = fields,
    refreshOnRateChange = true,
    rows = mytable.rows,
    cols = mytable.cols,
    simulatorResponse = {4, 18, 25, 32, 20, 0, 0, 18, 25, 32, 20, 0, 0, 32, 50, 45, 10, 0, 0, 56, 0, 56, 20, 0, 0},
    rTableName = mytable.rTableName,
    flagRateChange = flagRateChange,
    postLoad = postLoad,
    openPage = openPage,
    wakeup = wakeup

}
