local fields = {}
local rows = {}
local cols = {}

local activateWakeup = false
local currentProfileChecked = false

rows = {"Roll", "Pitch", "Yaw"}
cols = {"P", "I", "D", "F", "O", "B"}

-- P
fields[1] = {help = "profilesProportional", row = 1, col = 1, apikey = "pid_0_P"}
fields[2] = {help = "profilesProportional", row = 2, col = 1, apikey = "pid_1_P"}
fields[3] = {help = "profilesProportional", row = 3, col = 1, apikey = "pid_2_P"}

-- I
fields[4] = {help = "profilesIntegral", row = 1, col = 2, apikey = "pid_0_I"}
fields[5] = {help = "profilesIntegral", row = 2, col = 2, apikey = "pid_1_I"}
fields[6] = {help = "profilesIntegral", row = 3, col = 2, apikey = "pid_2_I"}

-- D
fields[7] = {help = "profilesDerivative", row = 1, col = 3, apikey = "pid_0_D"}
fields[8] = {help = "profilesDerivative", row = 2, col = 3, apikey = "pid_1_D"}
fields[9] = {help = "profilesDerivative", row = 3, col = 3, apikey = "pid_2_D"}

-- F
fields[10] = {help = "profilesFeedforward", row = 1, col = 4, apikey = "pid_0_F"}
fields[11] = {help = "profilesFeedforward", row = 2, col = 4, apikey = "pid_1_F"}
fields[12] = {help = "profilesFeedforward", row = 3, col = 4, apikey = "pid_2_F"}

-- O
fields[13] = {help = "profilesHSI", row = 1, col = 5, apikey = "pid_0_O"}
fields[14] = {help = "profilesHSI", row = 2, col = 5, apikey = "pid_1_O"}

-- B
fields[15] = {help = "profilesBoost", row = 1, col = 6, apikey = "pid_0_B"}
fields[16] = {help = "profilesBoost", row = 2, col = 6, apikey = "pid_1_B"}
fields[17] = {help = "profilesBoost", row = 3, col = 6, apikey = "pid_2_B"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
    activateWakeup = true
end

local function openPage(idx, title, script)

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false

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
    local numCols
    if rfsuite.app.Page.cols ~= nil then
        numCols = #rfsuite.app.Page.cols
    else
        numCols = 6
    end
    local screenWidth = rfsuite.config.lcdWidth - 10
    local padding = 10
    local paddingTop = rfsuite.app.radio.linePaddingTop
    local h = rfsuite.app.radio.navbuttonHeight
    local w = ((screenWidth * 70 / 100) / numCols)
    local paddingRight = 20
    local positions = {}
    local positions_r = {}
    local pos

    line = form.addLine("")

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

    local c = 1
    while loc > 0 do
        local colLabel = rfsuite.app.Page.cols[loc]
        pos = {x = posX, y = posY, w = w, h = h}
        form.addStaticText(line, pos, colLabel)
        positions[loc] = posX - w + paddingRight
        positions_r[c] = posX - w + paddingRight
        posX = math.floor(posX - w)
        loc = loc - 1
        c = c + 1
    end

    -- display each row
    local pidRows = {}
    for ri, rv in ipairs(rfsuite.app.Page.rows) do pidRows[ri] = form.addLine(rv) end

    for i = 1, #rfsuite.app.Page.fields do
        local f = rfsuite.app.Page.fields[i]
        local l = rfsuite.app.Page.labels
        local pageIdx = i
        local currentField = i

        posX = positions[f.col]

        pos = {x = posX + padding, y = posY, w = w - padding, h = h}

        rfsuite.app.formFields[i] = form.addNumberField(pidRows[f.row], pos, 0, 0, function()
            local value = rfsuite.utils.getFieldValue(rfsuite.app.Page.fields[i])
            return value
        end, function(value)
            f.value = rfsuite.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
            rfsuite.app.saveValue(i)
        end)

        if f.help ~= nil then
            if rfsuite.app.fieldHelpTxt[f.help]['t'] ~= nil then
                local helpTxt = rfsuite.app.fieldHelpTxt[f.help]['t']
                rfsuite.app.formFields[i]:help(helpTxt)
            end
        end
    end

end

local function wakeup()

    if activateWakeup == true and currentProfileChecked == false and rfsuite.bg.msp.mspQueue:isProcessed() then

        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.config.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.config.activeProfile)
            currentProfileChecked = true
        end

    end

end

return {
    mspapi = "PID_TUNING",
    title = "PIDs",
    reboot = false,
    eepromWrite = true,
    refreshOnProfileChange = true,
    fields = fields,
    rows = rows,
    cols = cols,
    postLoad = postLoad,
    openPage = openPage,
    wakeup = wakeup,
    API = {},
}
