local activateWakeup = false

local apidata = {
    api = {
        [1] = 'PID_TUNING',
    },
    formdata = {
        labels = {
        },
        rows = {
            "@i18n(app.modules.pids.roll)@",
            "@i18n(app.modules.pids.pitch)@",
            "@i18n(app.modules.pids.yaw)@"
        },
        cols = {
            "@i18n(app.modules.pids.p)@",
            "@i18n(app.modules.pids.i)@",
            "@i18n(app.modules.pids.d)@",
            "@i18n(app.modules.pids.f)@",
            "@i18n(app.modules.pids.o)@",
            "@i18n(app.modules.pids.b)@"
        },
        fields = {
            -- P
            {row = 1, col = 1, mspapi = 1, apikey = "pid_0_P"},
            {row = 2, col = 1, mspapi = 1, apikey = "pid_1_P"},
            {row = 3, col = 1, mspapi = 1, apikey = "pid_2_P"},
            {row = 1, col = 2, mspapi = 1, apikey = "pid_0_I"},
            {row = 2, col = 2, mspapi = 1, apikey = "pid_1_I"},
            {row = 3, col = 2, mspapi = 1, apikey = "pid_2_I"},
            {row = 1, col = 3, mspapi = 1, apikey = "pid_0_D"},
            {row = 2, col = 3, mspapi = 1, apikey = "pid_1_D"},
            {row = 3, col = 3, mspapi = 1, apikey = "pid_2_D"},
            {row = 1, col = 4, mspapi = 1, apikey = "pid_0_F"},
            {row = 2, col = 4, mspapi = 1, apikey = "pid_1_F"},
            {row = 3, col = 4, mspapi = 1, apikey = "pid_2_F"},
            {row = 1, col = 5, mspapi = 1, apikey = "pid_0_O"},
            {row = 2, col = 5, mspapi = 1, apikey = "pid_1_O"},
            {row = 1, col = 6, mspapi = 1, apikey = "pid_0_B"},
            {row = 2, col = 6, mspapi = 1, apikey = "pid_1_B"},
            {row = 3, col = 6, mspapi = 1, apikey = "pid_2_B"}
        }
    }                 
}


local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
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

    local longPage = false

    form.clear()

    rfsuite.app.ui.fieldHeader(title)
    local numCols
    if rfsuite.app.Page.cols ~= nil then
        numCols = #rfsuite.app.Page.cols
    else
        numCols = 6
    end
    local screenWidth = rfsuite.app.lcdWidth - 10
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


    rfsuite.utils.log("Merging form data from mspapi","debug")
    rfsuite.app.Page.fields = rfsuite.app.Page.apidata.formdata.fields
    rfsuite.app.Page.labels = rfsuite.app.Page.apidata.formdata.labels
    rfsuite.app.Page.rows = rfsuite.app.Page.apidata.formdata.rows
    rfsuite.app.Page.cols = rfsuite.app.Page.apidata.formdata.cols

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

local function wakeup()

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then

        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.session.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
        end

    end

end

return {
    apidata = apidata,
    title = "@i18n(app.modules.pids.name)@",
    reboot = false,
    eepromWrite = true,
    refreshOnProfileChange = true,
    postLoad = postLoad,
    openPage = openPage,
    wakeup = wakeup,
    API = {},
}
