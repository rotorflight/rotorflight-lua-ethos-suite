local fields = {}
local labels = {}

local enableWakeup = false

local w, h = rfsuite.utils.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

local data = nil

local displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 100, h = rfsuite.app.radio.navbuttonHeight}

local invalidSensors = rfsuite.tasks.telemetry.validateSensors()

local repairSensors = false

function sortSensorListByName(sensorList)
    table.sort(sensorList, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return sensorList
end

local sensorList = sortSensorListByName(rfsuite.tasks.telemetry.listSensors())

local function openPage(pidx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(rfsuite.i18n.get("app.modules.validate_sensors.name"))

    rfsuite.session.formLineCnt = 0
    local posText = {x = x - 5 - buttonW - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 200, h = rfsuite.app.radio.navbuttonHeight}
    for i, v in ipairs(sensorList) do

        rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(v.name)
        rfsuite.app.formFields[v.key] = form.addStaticText(rfsuite.app.formLines[rfsuite.session.formLineCnt], posText, "-")

    end

end

function sensorKeyExists(searchKey, sensorTable)
    for _, sensor in pairs(sensorTable) do if sensor['key'] == searchKey then return true end end
    return false
end

local function postLoad(self)
    rfsuite.utils.log("postLoad","debug")
end

local function postRead(self)
    rfsuite.utils.log("postRead","debug")
end

-- Function to check if sensor exists in telemetry slots
function checkIfSensorExists(value, data)
    for key, v in pairs(data) do
        if string.match(key, "^telem_sensor_slot_%d+$") and v == value then
            return true
        end
    end
    return false
end


local function wakeup()

    -- prevent wakeup running until after initialised
    if enableWakeup == false then return end

    -- check for updates
    invalidSensors = rfsuite.tasks.telemetry.validateSensors()

    for i, v in ipairs(sensorList) do
        if sensorKeyExists(v.key, invalidSensors) then
            if v.mandatory == true then
                rfsuite.app.formFields[v.key]:value(rfsuite.i18n.get("app.modules.validate_sensors.invalid"))
                rfsuite.app.formFields[v.key]:color(ORANGE)
            else
                rfsuite.app.formFields[v.key]:value(rfsuite.i18n.get("app.modules.validate_sensors.invalid"))
                rfsuite.app.formFields[v.key]:color(RED)
            end
        else
            rfsuite.app.formFields[v.key]:value(rfsuite.i18n.get("app.modules.validate_sensors.ok"))
            rfsuite.app.formFields[v.key]:color(GREEN)
        end
    end

  -- run process to repair all sensors
  if repairSensors == true then

    if data == nil then
        API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setUUID("550e8400-e29b-41d4-a716-446655440000")
        API.setCompleteHandler(function(self, buf)
            data = API.data().parsed
        end)
        API.read()
    end

    -- we now have the valid msp data stream
    if data ~= nil then
        local sensorList = rfsuite.tasks.telemetry.listSensors()

        -- extract list of sensors we require
        local requiredSensors = {}
        for _, v in pairs(sensorList) do
            local name = v['name']
            local sensor_id = v['set_telemetry_sensors']
            if sensor_id ~= nil then
                if not checkIfSensorExists(sensor_id, data) then
                    requiredSensors[sensor_id] = true
                end
            end    
        end

        for i,v in pairs(data) do
            print(i,v)
        end    
        repairSensors = false
    end    


end  




end

local function onToolMenu(self)

    local buttons = {{
        label = rfsuite.i18n.get("app.btn_ok"),
        action = function()

            -- we push this to the background task to do its job
            repairSensors = true
            writePayload = nil
            return true
        end
    }, {
        label = rfsuite.i18n.get("app.btn_cancel"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title =  rfsuite.i18n.get("app.modules.validate_sensors.name"),
        message = rfsuite.i18n.get("app.modules.validate_sensors.msg_repair"),
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end


return {
    reboot = false,
    eepromWrite = false,
    minBytes = 0,
    wakeup = wakeup,
    refreshswitch = false,
    simulatorResponse = {},
    postLoad = postLoad,
    postRead = postRead,
    openPage = openPage,
    onToolMenu = onToolMenu,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = true,
        help = true
    },
    API = {},
}
