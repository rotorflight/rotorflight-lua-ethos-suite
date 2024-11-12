--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]]--
local status = {}

local arg = {...}

local compile = arg[2]

local environment = system.getVersion()

status.oldsensors = {"status.refresh", "voltage", "rpm", "current", "temp_esc", "temp_mcu", "fuel", "mah", "rssi", "fm", "govmode"}
status.isVisible = nil
status.isDARKMODE = nil
status.loopCounter = 0
status.sensors = nil
status.gfx_model = nil
status.theTIME = 0
status.sensors = {}
status.sensordisplay = {}
status.theme = {}
status.lvTimer = false
status.lvTimerStart = nil
status.lvannouncementTimer = false
status.lvannouncementTimerStart = nil
status.lvaudioannouncementCounter = 0
status.lvAudioAlertCounter = 0
status.motorWasActive = false
status.lfTimer = false
status.lfTimerStart = nil
status.lfannouncementTimer = false
status.lfannouncementTimerStart = nil
status.lfaudioannouncementCounter = 0
status.lfAudioAlertCounter = 0
status.timeralarmVibrateParam = true
status.timeralarmParam = 210
status.timerAlarmPlay = true
status.statusColorParam = true
status.rpmtime = {}
status.rpmtime.rpmTimer = false
status.rpmtime.rpmTimerStart = nil
status.rpmtime.announcementTimer = false
status.rpmtime.announcementTimerStart = nil
status.rpmtime.audioannouncementCounter = 0
status.currenttime = {}
status.currenttime.currentTimer = false
status.currenttime.currentTimerStart = nil
status.currenttime.currentannouncementTimer = false
status.currenttime.currentannouncementTimerStart = nil
status.currenttime.currentaudioannouncementCounter = 0
status.lqtime = {}
status.lqtime.lqTimer = false
status.lqtime.lqTimerStart = nil
status.lqtime.lqannouncementTimer = false
status.lqtime.lqannouncementTimerStart = nil
status.lqtime.lqaudioannouncementCounter = 0
status.fueltime = {}
status.fueltime.fuelTimer = false
status.fueltime.fuelTimerStart = nil
status.fueltime.fuelannouncementTimer = false
status.fueltime.fuelannouncementTimerStart = nil
status.fueltime.fuelaudioannouncementCounter = 0
status.esctime = {}
status.esctime.escTimer = false
status.esctime.escTimerStart = nil
status.esctime.escannouncementTimer = false
status.esctime.escannouncementTimerStart = nil
status.esctime.escaudioannouncementCounter = 0
status.mcutime = {}
status.mcutime.mcuTimer = false
status.mcutime.mcuTimerStart = nil
status.mcutime.mcuannouncementTimer = false
status.mcutime.mcuannouncementTimerStart = nil
status.mcutime.mcuaudioannouncementCounter = 0
status.timetime = {}
status.timetime.timerTimer = false
status.timetime.timerTimerStart = nil
status.timetime.timerannouncementTimer = false
status.timetime.timerannouncementTimerStart = nil
status.timetime.timeraudioannouncementCounter = 0
status.linkUP = false
status.linkUPTime = 0
status.refresh = true
status.isInConfiguration = false
status.stopTimer = true
status.startTimer = false
status.voltageIsLow = false
status.voltageIsLowAlert = false
status.voltageIsGettingLow = false
status.fuelIsLow = false
status.fuelIsGettingLow = false
status.showLOGS = false
status.readLOGS = false
status.readLOGSlast = {}
status.playGovernorCount = 0
status.playGovernorLastState = nil
status.playrpmdiff = {}
status.playrpmdiff.playRPMDiffCount = 1
status.playrpmdiff.playRPMDiffLastState = nil
status.playrpmdiff.playRPMDiffCounter = 0
status.lvStickOrder = {}
status.lvStickOrder[1] = {1, 2, 3, 4}
status.lvStickOrder[2] = {1, 2, 4, 5}
status.lvStickOrder[3] = {1, 2, 4, 6}
status.lvStickOrder[4] = {2, 3, 4, 6}
status.switchstatus = {}
status.quadBoxParam = 0
status.lowvoltagStickParam = 0
status.lowvoltagStickCutoffParam = 70
status.govmodeParam = 0
status.btypeParam = 0
status.lowvoltagStickParam = nil
status.lowvoltagStickCutoffParam = nil
status.lowvoltagStickCutoffParam = 80
status.govmodeParam = 0
status.lowfuelParam = 20
status.alertintParam = 5
status.alrthptcParam = 1
status.maxminParam = true
status.titleParam = true
status.modelImageParam = true
status.cellsParam = 6
status.lowVoltageGovernorParam = true
status.sagParam = 5
status.rpmAlertsParam = false
status.rpmAlertsPercentageParam = 100
status.governorAlertsParam = true
status.announcementVoltageSwitchParam = nil
status.announcementRPMSwitchParam = nil
status.announcementCurrentSwitchParam = nil
status.announcementFuelSwitchParam = nil
status.announcementLQSwitchParam = nil
status.announcementESCSwitchParam = nil
status.announcementMCUSwitchParam = nil
status.announcementTimerSwitchParam = nil
status.filteringParam = 1
status.lowvoltagsenseParam = 2
status.announcementIntervalParam = 30
status.lowVoltageGovernorParam = nil
status.customSensorParam1 = nil
status.customSensorParam2 = nil
status.governorUNKNOWNParam = true
status.governorDISARMEDParam = true
status.governorDISABLEDParam = true
status.governorAUTOROTParam = true
status.governorLOSTHSParam = true
status.governorTHROFFParam = true
status.governorACTIVEParam = true
status.governorRECOVERYParam = true
status.governorSPOOLUPParam = true
status.governorIDLEParam = true
status.governorOFFParam = true
status.alertonParam = 0
status.calcfuelParam = false
status.tempconvertParamESC = 1
status.tempconvertParamMCU = 1
status.idleupdelayParam = 20
status.switchIdlelowParam = nil
status.switchIdlemediumParam = nil
status.switchIdlehighParam = nil
status.switchrateslowParam = nil
status.switchratesmediumParam = nil
status.switchrateshighParam = nil
status.switchrescueonParam = nil
status.switchrescueoffParam = nil
status.switchbblonParam = nil
status.switchbbloffParam = nil
status.idleupswitchParam = nil
status.timerWASActive = false
status.govWasActive = false
status.maxMinSaved = false
status.simPreSPOOLUP = false
status.simDoSPOOLUP = false
status.simDODISARM = false
status.simDoSPOOLUPCount = 0
status.actTime = nil
status.lvStickannouncement = false
status.maxminFinals1 = nil
status.maxminFinals2 = nil
status.maxminFinals3 = nil
status.maxminFinals4 = nil
status.maxminFinals5 = nil
status.maxminFinals6 = nil
status.maxminFinals7 = nil
status.maxminFinals8 = nil
status.oldADJSOURCE = 0
status.oldADJVALUE = 0
status.adjfuncIdChanged = false
status.adjfuncValueChanged = false
status.adjJUSTUP = false
status.ADJSOURCE = nil
status.ADJVALUE = nil
status.noTelemTimer = 0
status.closeButtonX = 0
status.closeButtonY = 0
status.closeButtonW = 0
status.closeButtonH = 0
status.adjTimerStart = os.time()
status.adjJUSTUPCounter = 0
status.sensorVoltageMax = 0
status.sensorVoltageMin = 0
status.sensorFuelMin = 0
status.sensorFuelMax = 0
status.sensorRPMMin = 0
status.sensorRPMMax = 0
status.sensorCurrentMin = 0
status.sensorCurrentMax = 0
status.sensorTempMCUMin = 0
status.sensorTempMCUMax = 0
status.sensorTempESCMin = 0
status.sensorTempESCMax = 0
status.sensorRSSIMin = 0
status.sensorRSSIMax = 0
status.lastMaxMin = 0
status.wakeupSchedulerUI = os.clock()
status.voltageNoiseQ = 100
status.fuelNoiseQ = 100
status.rpmNoiseQ = 100
status.temp_mcuNoiseQ = 100
status.temp_escNoiseQ = 100
status.rssiNoiseQ = 100
status.currentNoiseQ = 100
status.layoutOptions = {
    {"TIMER", 1}, {"VOLTAGE", 2}, {"FUEL", 3}, {"CURRENT", 4}, {"MAH", 17}, {"RPM", 5}, {"LQ", 6}, {"T.ESC", 7}, {"T.MCU", 8}, {"IMAGE", 9}, {"GOVERNOR", 10}, {"IMAGE, GOVERNOR", 11},
    {"LQ, TIMER", 12}, {"T.ESC, T.MCU", 13}, {"VOLTAGE, FUEL", 14}, {"VOLTAGE, CURRENT", 15}, {"VOLTAGE, MAH", 16}, {"LQ, TIMER, T.ESC, T.MCU", 20}, {"MAX CURRENT", 21}, {"LQ, GOVERNOR", 22},
    {"CUSTOMSENSOR #1", 23}, {"CUSTOMSENSOR #2", 24}, {"CUSTOMSENSOR #1, #2", 25}
}
status.layoutBox1Param = 11 -- IMAGE, GOV
status.layoutBox2Param = 2 -- VOLTAGE
status.layoutBox3Param = 3 -- FUEL
status.layoutBox4Param = 12 -- LQ,TIMER
status.layoutBox5Param = 4 -- CURRENT
status.layoutBox6Param = 5 -- RPM
status.maxCellVoltage = 430
status.fullCellVoltage = 410
status.minCellVoltage = 330
status.warnCellVoltage = 350

local governorMap = {}
governorMap[0] = "OFF"
governorMap[1] = "IDLE"
governorMap[2] = "SPOOLUP"
governorMap[3] = "RECOVERY"
governorMap[4] = "ACTIVE"
governorMap[5] = "THR-OFF"
governorMap[6] = "LOST-HS"
governorMap[7] = "AUTOROT"
governorMap[8] = "BAILOUT"
governorMap[100] = "DISABLED"
governorMap[101] = "DISARMED"

function status.create(widget)

    status.initTime = os.clock()

    status.gfx_model = lcd.loadBitmap(model.bitmap())
    status.gfx_heli = lcd.loadBitmap("widgets/status/gfx/heli.png")
    status.gfx_close = lcd.loadBitmap("widgets/status/gfx/close.png")
    -- status.rssiSensor = status.getRssiSensor()

    if tonumber(status.sensorMakeNumber(environment.version)) < 159 then
        status.screenError("ETHOS < V1.5.9")
        return
    end

    return {
        fmsrc = 0,
        btype = 0,
        lowfuel = 20,
        alertint = 5,
        alrthptc = 1,
        maxmin = 1,
        title = 1,
        cells = 6,
        announcementswitchvltg = nil,
        govmode = 0,
        governoralerts = 0,
        rpmalerts = 0,
        rpmaltp = 2.5,
        adjfunc = 0,
        announcementswitchrpm = nil,
        announcementswitchcrnt = nil,
        announcementswitchfuel = nil,
        announcementswitchlq = nil,
        announcementswitchesc = nil,
        announcementswitchmcu = nil,
        announcementswitchtmr = nil,
        filtering = 1,
        sag = 5,
        lvsense = 2,
        announcementint = 30,
        lvgovernor = false,
        lvstickmon = 0,
        lvstickcutoff = 1,
        governorUNKNOWN = true,
        governorDISARMED = true,
        governorDISABLED = true,
        governorBAILOUT = true,
        governorAUTOROT = true,
        governorLOSTHS = true,
        governorTHROFF = true,
        governorACTIVE = true,
        governorRECOVERY = true,
        governorSPOOLUP = true,
        governorIDLE = true,
        governorOFF = true,
        alerton = 0,
        tempconvertesc = 1
    }
end

local voltageSOURCE
local rpmSOURCE
local currentSOURCE
local temp_escSOURCE
local temp_mcuSOURCE
local fuelSOURCE
local govSOURCE
local adjSOURCE
local adjVALUE
local mahSOURCE
local telemetrySOURCE
local crsfSOURCE

function status.configure(widget)
    status.isInConfiguration = true

    triggerpanel = form.addExpansionPanel("Triggers")
    triggerpanel:open(false)

    line = triggerpanel:addLine("Arm switch")
    armswitch = form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return armswitchParam
    end, function(value)
        armswitchParam = value
    end)

    line = triggerpanel:addLine("Idleup switch")
    idleupswitch = form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.idleupswitchParam
    end, function(value)
        status.idleupswitchParam = value
    end)

    line = triggerpanel:addLine("    " .. "Delay before active")
    field = form.addNumberField(line, nil, 5, 60, function()
        return status.idleupdelayParam
    end, function(value)
        status.idleupdelayParam = value
    end)
    field:default(5)
    field:suffix("s")

    timerpanel = form.addExpansionPanel("Timer configuration")
    timerpanel:open(false)

    timeTable = {
        {"Disabled", 0}, {"00:30", 30}, {"01:00", 60}, {"01:30", 90}, {"02:00", 120}, {"02:30", 150}, {"03:00", 180}, {"03:30", 210}, {"04:00", 240}, {"04:30", 270}, {"05:00", 300}, {"05:30", 330},
        {"06:00", 360}, {"06:30", 390}, {"07:00", 420}, {"07:30", 450}, {"08:00", 480}, {"08:30", 510}, {"09:00", 540}, {"09:30", 570}, {"10:00", 600}, {"10:30", 630}, {"11:00", 660}, {"11:30", 690},
        {"12:00", 720}, {"12:30", 750}, {"13:00", 780}, {"13:30", 810}, {"14:00", 840}, {"14:30", 870}, {"15:00", 900}, {"15:30", 930}, {"16:00", 960}, {"16:30", 990}, {"17:00", 1020},
        {"17:30", 1050}, {"18:00", 1080}, {"18:30", 1110}, {"19:00", 1140}, {"19:30", 1170}, {"20:00", 1200}
    }

    line = timerpanel:addLine("Play alarm at")
    form.addChoiceField(line, nil, timeTable, function()
        return status.timeralarmParam
    end, function(newValue)
        status.timeralarmParam = newValue
    end)

    line = timerpanel:addLine("Vibrate")
    form.addBooleanField(line, nil, function()
        return status.timeralarmVibrateParam
    end, function(newValue)
        status.timeralarmVibrateParam = newValue
    end)

    batterypanel = form.addExpansionPanel("Battery configuration")
    batterypanel:open(false)

    -- BATTERY CELLS
    line = batterypanel:addLine("Cells")
    field = form.addNumberField(line, nil, 1, 14, function()
        return status.cellsParam
    end, function(value)
        status.cellsParam = value
    end)
    field:default(6)

    -- BATTERY MAX
    line = batterypanel:addLine("Maximum cell voltage")
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.maxCellVoltage
    end, function(value)
        status.maxCellVoltage = value
    end)
    field:default(430)
    field:decimals(2)
    field:suffix("V")

    -- BATTERY FULL
    line = batterypanel:addLine("Minimum cell voltage")
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.minCellVoltage
    end, function(value)
        status.minCellVoltage = value
    end)
    field:default(330)
    field:decimals(2)
    field:suffix("V")

    -- BATTERY WARN
    line = batterypanel:addLine("Warning cell voltage")
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.warnCellVoltage
    end, function(value)
        status.warnCellVoltage = value
    end)
    field:default(350)
    field:decimals(2)
    field:suffix("V")

    -- LOW FUEL announcement
    line = batterypanel:addLine("Low fuel%")
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.lowfuelParam
    end, function(value)
        status.lowfuelParam = value
    end)
    field:default(20)
    field:suffix("%")

    -- ALERT ON
    line = batterypanel:addLine("Play alert on")
    form.addChoiceField(line, nil, {{"Low voltage", 0}, {"Low fuel", 1}, {"Low fuel & Low voltage", 2}, {"Disabled", 3}}, function()
        return status.alertonParam
    end, function(newValue)
        if newValue == 3 then
            plalrtint:enable(false)
            plalrthap:enable(false)
        else
            plalrtint:enable(true)
            plalrthap:enable(true)
        end
        status.alertonParam = newValue
    end)

    -- ALERT INTERVAL
    line = batterypanel:addLine("     " .. "Interval")
    plalrtint = form.addChoiceField(line, nil, {{"5S", 5}, {"10S", 10}, {"15S", 15}, {"20S", 20}, {"30S", 30}}, function()
        return status.alertintParam
    end, function(newValue)
        status.alertintParam = newValue
    end)
    if status.alertonParam == 3 then
        plalrtint:enable(false)
    else
        plalrtint:enable(true)
    end

    -- HAPTIC
    line = batterypanel:addLine("     " .. "Vibrate")
    plalrthap = form.addBooleanField(line, nil, function()
        return alrthptParam
    end, function(newValue)
        alrthptParam = newValue
    end)
    if status.alertonParam == 3 then
        plalrthap:enable(false)
    else
        plalrthap:enable(true)
    end

    switchpanel = form.addExpansionPanel("Switch announcements")
    switchpanel:open(false)

    line = switchpanel:addLine("Idle speed low")
    form.addSwitchField(line, nil, function()
        return status.switchIdlelowParam
    end, function(value)
        status.switchIdlelowParam = value
    end)

    line = switchpanel:addLine("Idle speed medium")
    form.addSwitchField(line, nil, function()
        return status.switchIdlemediumParam
    end, function(value)
        status.switchIdlemediumParam = value
    end)

    line = switchpanel:addLine("Idle speed high")
    form.addSwitchField(line, nil, function()
        return status.switchIdlehighParam
    end, function(value)
        status.switchIdlehighParam = value
    end)

    line = switchpanel:addLine("Rates low")
    form.addSwitchField(line, nil, function()
        return status.switchrateslowParam
    end, function(value)
        status.switchrateslowParam = value
    end)

    line = switchpanel:addLine("Rates medium")
    form.addSwitchField(line, nil, function()
        return status.switchratesmediumParam
    end, function(value)
        status.switchratesmediumParam = value
    end)

    line = switchpanel:addLine("Rates high")
    form.addSwitchField(line, nil, function()
        return status.switchrateshighParam
    end, function(value)
        status.switchrateshighParam = value
    end)

    line = switchpanel:addLine("Rescue on")
    form.addSwitchField(line, nil, function()
        return status.switchrescueonParam
    end, function(value)
        status.switchrescueonParam = value
    end)

    line = switchpanel:addLine("Rescue off")
    form.addSwitchField(line, nil, function()
        return status.switchrescueoffParam
    end, function(value)
        status.switchrescueoffParam = value
    end)

    line = switchpanel:addLine("BBL enabled")
    form.addSwitchField(line, nil, function()
        return status.switchbblonParam
    end, function(value)
        status.switchbblonParam = value
    end)

    line = switchpanel:addLine("BBL disabled")
    form.addSwitchField(line, nil, function()
        return status.switchbbloffParam
    end, function(value)
        status.switchbbloffParam = value
    end)

    announcementpanel = form.addExpansionPanel("Telemetry announcements")
    announcementpanel:open(false)

    -- announcement VOLTAGE READING
    line = announcementpanel:addLine("Voltage")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementVoltageSwitchParam
    end, function(value)
        status.announcementVoltageSwitchParam = value
    end)

    -- announcement RPM READING
    line = announcementpanel:addLine("RPM")
    form.addSwitchField(line, nil, function()
        return status.announcementRPMSwitchParam
    end, function(value)
        status.announcementRPMSwitchParam = value
    end)

    -- announcement CURRENT READING
    line = announcementpanel:addLine("Current")
    form.addSwitchField(line, nil, function()
        return status.announcementCurrentSwitchParam
    end, function(value)
        status.announcementCurrentSwitchParam = value
    end)

    -- announcement FUEL READING
    line = announcementpanel:addLine("Fuel")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementFuelSwitchParam
    end, function(value)
        status.announcementFuelSwitchParam = value
    end)

    -- announcement LQ READING
    line = announcementpanel:addLine("LQ")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementLQSwitchParam
    end, function(value)
        status.announcementLQSwitchParam = value
    end)

    -- announcement LQ READING
    line = announcementpanel:addLine("ESC temperature")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementESCSwitchParam
    end, function(value)
        status.announcementESCSwitchParam = value
    end)

    -- announcement MCU READING
    line = announcementpanel:addLine("MCU temperature")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementMCUSwitchParam
    end, function(value)
        status.announcementMCUSwitchParam = value
    end)

    -- announcement TIMER READING
    line = announcementpanel:addLine("Timer")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementTimerSwitchParam
    end, function(value)
        status.announcementTimerSwitchParam = value
    end)

    govalertpanel = form.addExpansionPanel("Governor announcements")
    govalertpanel:open(false)

    -- TITLE DISPLAY
    line = govalertpanel:addLine("  " .. "OFF")
    form.addBooleanField(line, nil, function()
        return status.governorOFFParam
    end, function(newValue)
        status.governorOFFParam = newValue
    end)

    -- TITLE DISPLAY
    line = govalertpanel:addLine("  " .. "IDLE")
    form.addBooleanField(line, nil, function()
        return status.governorIDLEParam
    end, function(newValue)
        status.governorIDLEParam = newValue
    end)

    -- TITLE DISPLAY
    line = govalertpanel:addLine("  " .. "SPOOLUP")
    form.addBooleanField(line, nil, function()
        return status.governorSPOOLUPParam
    end, function(newValue)
        status.governorSPOOLUPParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "RECOVERY")
    form.addBooleanField(line, nil, function()
        return status.governorRECOVERYParam
    end, function(newValue)
        status.governorRECOVERYParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "ACTIVE")
    form.addBooleanField(line, nil, function()
        return status.governorACTIVEParam
    end, function(newValue)
        status.governorACTIVEParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "THR-OFF")
    form.addBooleanField(line, nil, function()
        return status.governorTHROFFParam
    end, function(newValue)
        status.governorTHROFFParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "LOST-HS")
    form.addBooleanField(line, nil, function()
        return status.governorLOSTHSParam
    end, function(newValue)
        status.governorLOSTHSParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "AUTOROT")
    form.addBooleanField(line, nil, function()
        return status.governorAUTOROTParam
    end, function(newValue)
        status.governorAUTOROTParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "BAILOUT")
    form.addBooleanField(line, nil, function()
        return status.governorBAILOUTParam
    end, function(newValue)
        status.governorBAILOUTParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "DISABLED")
    form.addBooleanField(line, nil, function()
        return status.governorDISABLEDParam
    end, function(newValue)
        status.governorDISABLEDParam = newValue
    end)

    line = govalertpanel:addLine("  " .. "DISARMED")
    form.addBooleanField(line, nil, function()
        return status.governorDISARMEDParam
    end, function(newValue)
        status.governorDISARMEDParam = newValue
    end)

    line = govalertpanel:addLine("   " .. "UNKNOWN")
    form.addBooleanField(line, nil, function()
        return status.governorUNKNOWNParam
    end, function(newValue)
        status.governorUNKNOWNParam = newValue
    end)

    displaypanel = form.addExpansionPanel("Customise display")
    displaypanel:open(false)

    line = displaypanel:addLine("Box1")
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox1Param
    end, function(newValue)
        status.layoutBox1Param = newValue
    end)

    line = displaypanel:addLine("Box2")
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox2Param
    end, function(newValue)
        status.layoutBox2Param = newValue
    end)

    line = displaypanel:addLine("Box3")
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox3Param
    end, function(newValue)
        status.layoutBox3Param = newValue
    end)

    line = displaypanel:addLine("Box4")
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox4Param
    end, function(newValue)
        status.layoutBox4Param = newValue
    end)

    line = displaypanel:addLine("Box5")
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox5Param
    end, function(newValue)
        status.layoutBox5Param = newValue
    end)

    line = displaypanel:addLine("Box6")
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox6Param
    end, function(newValue)
        status.layoutBox6Param = newValue
    end)

    -- TITLE DISPLAY
    line = displaypanel:addLine("Display title")
    form.addBooleanField(line, nil, function()
        return status.titleParam
    end, function(newValue)
        status.titleParam = newValue
    end)

    -- MAX MIN DISPLAY
    line = displaypanel:addLine("Display max/min")
    form.addBooleanField(line, nil, function()
        return status.maxminParam
    end, function(newValue)
        status.maxminParam = newValue
    end)

    -- color mode
    line = displaypanel:addLine("Use colors to indicate status")
    form.addBooleanField(line, nil, function()
        return status.statusColorParam
    end, function(newValue)
        status.statusColorParam = newValue
    end)

    -- custom sensors
    line = form.addLine("Custom Sensors", displaypanel)

    -- custom1
    line = displaypanel:addLine("   " .. "Custom Sensor #1")
    form.addSensorField(line, nil, function()
        return status.customSensorParam1
    end, function(newValue)
        status.customSensorParam1 = newValue
    end)

    -- custom2
    line = displaypanel:addLine("   " .. "Custom Sensor #2")
    form.addSensorField(line, nil, function()
        return status.customSensorParam2
    end, function(newValue)
        status.customSensorParam2 = newValue
    end)

    advpanel = form.addExpansionPanel("Advanced")
    advpanel:open(false)

    line = advpanel:addLine("Governor")
    extgov = form.addChoiceField(line, nil, {{"RF Governor", 0}, {"External Governor", 1}}, function()
        return status.govmodeParam
    end, function(newValue)
        status.govmodeParam = newValue
    end)

    line = form.addLine("Temperature conversion", advpanel)

    line = advpanel:addLine("    " .. "ESC")
    form.addChoiceField(line, nil, {{"Disable", 1}, {"°C -> °F", 2}, {"°F -> °C", 3}}, function()
        return status.tempconvertParamESC
    end, function(newValue)
        status.tempconvertParamESC = newValue
    end)

    line = advpanel:addLine("   " .. "MCU")
    form.addChoiceField(line, nil, {{"Disable", 1}, {"°C -> °F", 2}, {"°F -> °C", 3}}, function()
        return status.tempconvertParamMCU
    end, function(newValue)
        status.tempconvertParamMCU = newValue
    end)

    line = form.addLine("Voltage", advpanel)

    -- LVannouncement DISPLAY
    line = advpanel:addLine("    " .. "Sensitivity")
    form.addChoiceField(line, nil, {{"HIGH", 1}, {"MEDIUM", 2}, {"LOW", 3}}, function()
        return status.lowvoltagsenseParam
    end, function(newValue)
        status.lowvoltagsenseParam = newValue
    end)

    line = advpanel:addLine("    " .. "Sag compensation")
    field = form.addNumberField(line, nil, 0, 10, function()
        return status.sagParam
    end, function(value)
        status.sagParam = value
    end)
    field:default(5)
    field:suffix("s")
    -- field:decimals(1)

    -- LVSTICK MONITORING
    line = advpanel:addLine("    " .. "Gimbal monitoring")
    form.addChoiceField(line, nil, {
        {"DISABLED", 0}, -- 
        {"AECR1T23 (ELRS)", 1}, -- recomended
        {"AETRC123 (FRSKY)", 2}, -- frsky
        {"AETR1C23 (FUTABA)", 3}, -- fut/hitec
        {"TAER1C23 (SPEKTRUM)", 4} -- spec
    }, function()
        return status.lowvoltagStickParam
    end, function(newValue)
        if newValue == 0 then
            fieldstckcutoff:enable(false)
        else
            fieldstckcutoff:enable(true)
        end
        status.lowvoltagStickParam = newValue
    end)

    line = advpanel:addLine("       " .. "Stick cutoff")
    fieldstckcutoff = form.addNumberField(line, nil, 65, 95, function()
        return status.lowvoltagStickCutoffParam
    end, function(value)
        status.lowvoltagStickCutoffParam = value
    end)
    fieldstckcutoff:default(80)
    fieldstckcutoff:suffix("%")
    if status.lowvoltagStickParam == 0 then
        fieldstckcutoff:enable(false)
    else
        fieldstckcutoff:enable(true)
    end

    line = form.addLine("Headspeed", advpanel)

    -- TITLE DISPLAY
    line = advpanel:addLine("   " .. "Alert on RPM difference")
    form.addBooleanField(line, nil, function()
        return status.rpmAlertsParam
    end, function(newValue)
        if newValue == false then
            rpmperfield:enable(false)
        else
            rpmperfield:enable(true)
        end

        status.rpmAlertsParam = newValue
    end)

    -- TITLE DISPLAY
    line = advpanel:addLine("   " .. "Alert if difference > than")
    rpmperfield = form.addNumberField(line, nil, 0, 200, function()
        return status.rpmAlertsPercentageParam
    end, function(value)
        status.rpmAlertsPercentageParam = value
    end)
    if status.rpmAlertsParam == false then
        rpmperfield:enable(false)
    else
        rpmperfield:enable(true)
    end
    rpmperfield:default(100)
    rpmperfield:decimals(1)
    rpmperfield:suffix("%")

    --[[
    -- FILTER
    -- MAX MIN DISPLAY
    line = advpanel:addLine("Telemetry filtering")
    form.addChoiceField(line, nil, {{"LOW", 1}, {"MEDIUM", 2}, {"HIGH", 3}}, function()
        return status.filteringParam
    end, function(newValue)
        status.filteringParam = newValue
    end)
    ]] --

    -- LVannouncement DISPLAY
    line = advpanel:addLine("Announcement interval")
    form.addChoiceField(line, nil, {
        {"5s", 5}, {"10s", 10}, {"15s", 15}, {"20s", 20}, {"25s", 25}, {"30s", 30}, {"35s", 35}, {"40s", 40}, {"45s", 45}, {"50s", 50}, {"55s", 55}, {"60s", 60}, {"No repeat", 50000}
    }, function()
        return status.announcementIntervalParam
    end, function(newValue)
        status.announcementIntervalParam = newValue
    end)

    -- calcfuel
    line = advpanel:addLine("Calculate fuel locally")
    form.addBooleanField(line, nil, function()
        return status.calcfuelParam
    end, function(newValue)
        status.calcfuelParam = newValue
    end)

    status.resetALL()

    return widget
end

function status.screenError(msg)
    local w, h = lcd.getWindowSize()
    status.isDARKMODE = lcd.darkMode()
    lcd.font(FONT_STD)
    str = msg
    tsizeW, tsizeH = lcd.getTextSize(str)

    if status.isDARKMODE then
        -- dark theme
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        -- light theme
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawText((w / 2) - tsizeW / 2, (h / 2) - tsizeH / 2, str)
    return
end

function status.resetALL()
    status.showLOGS = false
    status.sensorVoltageMax = 0
    status.sensorVoltageMin = 0
    status.sensorFuelMin = 0
    status.sensorFuelMax = 0
    status.sensorRPMMin = 0
    status.sensorRPMMax = 0
    status.sensorCurrentMin = 0
    status.sensorCurrentMax = 0
    status.sensorTempMCUMin = 0
    status.sensorTempMCUMax = 0
    status.sensorTempESCMin = 0
    status.sensorTempESCMax = 0
end

function status.noTelem()

    lcd.font(FONT_STD)
    str = "NO LINK"

    status.theme = status.getThemeInfo()
    local w, h = lcd.getWindowSize()
    boxW = math.floor(w / 2)
    boxH = 45
    tsizeW, tsizeH = lcd.getTextSize(str)

    -- draw the backgstatus.round
    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end
    lcd.drawFilledRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- draw the border
    if status.isDARKMODE then
        -- dark theme
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        -- light theme
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    if status.isDARKMODE then
        -- dark theme
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        -- light theme
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawText((w / 2) - tsizeW / 2, (h / 2) - tsizeH / 2, str)
    return
end

function status.message(msg)

    lcd.font(FONT_STD)

    status.theme = status.getThemeInfo()
    local w, h = lcd.getWindowSize()
    boxW = math.floor(w / 2)
    boxH = 45
    tsizeW, tsizeH = lcd.getTextSize(msg)

    -- draw the backgstatus.round
    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end
    lcd.drawFilledRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- draw the border
    if status.isDARKMODE then
        -- dark theme
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        -- light theme
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    if status.isDARKMODE then
        -- dark theme
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        -- light theme
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawText((w / 2) - tsizeW / 2, (h / 2) - tsizeH / 2, str)
    return
end

function status.getThemeInfo()
    environment = system.getVersion()
    local w, h = lcd.getWindowSize()

    -- this is just to force height calc to end up on whole numbers to avoid
    -- scaling issues
    h = (math.floor((h / 4)) * 4)
    w = (math.floor((w / 6)) * 6)

    -- first one is unsporrted

    if environment.board == "XES" or environment.board == "XE" or environment.board == "X20" or environment.board == "X20S" or environment.board == "X20PRO" or environment.board == "X20PROAW" or
        environment.board == "X20R" or environment.board == "X20RS" then
        ret = {
            supportedRADIO = true,
            colSpacing = 4,
            fullBoxW = 262,
            fullBoxH = h / 2,
            smallBoxSensortextOFFSET = -5,
            title_voltage = "VOLTAGE",
            title_fuel = "FUEL",
            title_mah = "MAH",
            title_rpm = "RPM",
            title_current = "CURRENT",
            title_tempMCU = "T.MCU",
            title_tempESC = "T.ESC",
            title_time = "TIMER",
            title_governor = "GOVERNOR",
            title_fm = "FLIGHT MODE",
            title_rssi = "LQ",
            fontSENSOR = FONT_XXL,
            fontSENSORSmallBox = FONT_STD,
            fontTITLE = FONT_XS,
            fontPopupTitle = FONT_S,
            widgetTitleOffset = 20,
            logsCOL1w = 60,
            logsCOL2w = 120,
            logsCOL3w = 120,
            logsCOL4w = 170,
            logsCOL5w = 110,
            logsCOL6w = 90,
            logsCOL7w = 90,
            logsHeaderOffset = 5

        }
    end

    if environment.board == "X18" or environment.board == "X18S" then
        ret = {
            supportedRADIO = true,
            colSpacing = 2,
            fullBoxW = 158,
            fullBoxH = 97,
            smallBoxSensortextOFFSET = -8,
            title_voltage = "VOLTAGE",
            title_fuel = "FUEL",
            title_mah = "MAH",
            title_rpm = "RPM",
            title_current = "CURRENT",
            title_tempMCU = "T.MCU",
            title_tempESC = "T.ESC",
            title_time = "TIMER",
            title_governor = "GOVERNOR",
            title_fm = "FLIGHT MODE",
            title_rssi = "LQ",
            fontSENSOR = FONT_XXL,
            fontSENSORSmallBox = FONT_STD,
            fontTITLE = 768,
            fontPopupTitle = FONT_S,
            widgetTitleOffset = 20,
            logsCOL1w = 50,
            logsCOL2w = 100,
            logsCOL3w = 100,
            logsCOL4w = 140,
            logsCOL5w = 0,
            logsCOL6w = 0,
            logsCOL7w = 75,
            logsHeaderOffset = 5
        }
    end

    if environment.board == "X14" or environment.board == "X14S" then
        ret = {
            supportedRADIO = true,
            colSpacing = 3,
            fullBoxW = 210,
            fullBoxH = 120,
            smallBoxSensortextOFFSET = -10,
            title_voltage = "VOLTAGE",
            title_fuel = "FUEL",
            title_mah = "MAH",
            title_rpm = "RPM",
            title_current = "CURRENT",
            title_tempMCU = "T.MCU",
            title_tempESC = "T.ESC",
            title_time = "TIMER",
            title_governor = "GOVERNOR",
            title_fm = "FLIGHT MODE",
            title_rssi = "LQ",
            fontSENSOR = FONT_XXL,
            fontSENSORSmallBox = FONT_STD,
            fontTITLE = 768,
            fontPopupTitle = FONT_S,
            widgetTitleOffset = 20,
            logsCOL1w = 70,
            logsCOL2w = 140,
            logsCOL3w = 120,
            logsCOL4w = 170,
            logsCOL5w = 0,
            logsCOL6w = 0,
            logsCOL7w = 120,
            logsHeaderOffset = 5
        }
    end

    if environment.board == "TWXLITE" or environment.board == "TWXLITES" then
        ret = {
            supportedRADIO = true,
            colSpacing = 2,
            fullBoxW = 158,
            fullBoxH = 96,
            smallBoxSensortextOFFSET = -10,
            title_voltage = "VOLTAGE",
            title_fuel = "FUEL",
            title_mah = "MAH",
            title_rpm = "RPM",
            title_current = "CURRENT",
            title_tempMCU = "T.MCU",
            title_tempESC = "T.ESC",
            title_time = "TIMER",
            title_governor = "GOVERNOR",
            title_fm = "FLIGHT MODE",
            title_rssi = "LQ",
            fontSENSOR = FONT_XXL,
            fontSENSORSmallBox = FONT_STD,
            fontTITLE = 768,
            fontPopupTitle = FONT_S,
            widgetTitleOffset = 20,
            logsCOL1w = 50,
            logsCOL2w = 100,
            logsCOL3w = 100,
            logsCOL4w = 140,
            logsCOL5w = 0,
            logsCOL6w = 0,
            logsCOL7w = 75,
            logsHeaderOffset = 5
        }
    end

    if environment.board == "X10EXPRESS" or environment.board == "X10" or environment.board == "X10S" or environment.board == "X12" or environment.board == "X12S" then
        ret = {
            supportedRADIO = true,
            colSpacing = 2,
            fullBoxW = 158,
            fullBoxH = 79,
            smallBoxSensortextOFFSET = -10,
            title_voltage = "VOLTAGE",
            title_fuel = "FUEL",
            title_mah = "MAH",
            title_rpm = "RPM",
            title_current = "CURRENT",
            title_tempMCU = "T.MCU",
            title_tempESC = "T.ESC",
            title_time = "TIMER",
            title_governor = "GOVERNOR",
            title_fm = "FLIGHT MODE",
            title_rssi = "LQ",
            fontSENSOR = FONT_XXL,
            fontSENSORSmallBox = FONT_STD,
            fontTITLE = FONT_XS,
            fontPopupTitle = FONT_S,
            widgetTitleOffset = 20,
            logsCOL1w = 50,
            logsCOL2w = 100,
            logsCOL3w = 100,
            logsCOL4w = 140,
            logsCOL5w = 0,
            logsCOL6w = 0,
            logsCOL7w = 75,
            logsHeaderOffset = 5
        }
    end

    return ret
end

function status.govColorFlag(flag)

    -- 0 = default colour
    -- 1 = red (alarm)
    -- 2 = orange (warning)
    -- 3 = green (ok)  

    if flag == "UNKNOWN" then
        return 1
    elseif flag == "DISARMED" then
        return 0
    elseif flag == "DISABLED" then
        return 0
    elseif flag == "BAILOUT" then
        return 2
    elseif flag == "AUTOROT" then
        return 2
    elseif flag == "LOST-HS" then
        return 2
    elseif flag == "THR-OFF" then
        return 2
    elseif flag == "ACTIVE" then
        return 3
    elseif flag == "RECOVERY" then
        return 2
    elseif flag == "SPOOLUP" then
        return 2
    elseif flag == "IDLE" then
        return 0
    elseif flag == "OFF" then
        return 0
    end

    return 0
end

function status.telemetryBox(x, y, w, h, title, value, unit, smallbox, alarm, minimum, maximum)

    status.isVisible = lcd.isVisible()
    status.isDARKMODE = lcd.darkMode()
    local theme = status.getThemeInfo()

    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end

    -- draw box backgstatus.round    
    lcd.drawFilledRectangle(x, y, w, h)

    -- color    
    if status.isDARKMODE then
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end

    -- draw sensor text
    if value ~= nil then

        if smallbox == nil or smallbox == false then
            lcd.font(theme.fontSENSOR)
        else
            lcd.font(theme.fontSENSORSmallBox)
        end

        str = value .. unit

        if unit == "°" then
            tsizeW, tsizeH = lcd.getTextSize(value .. ".")
        else
            tsizeW, tsizeH = lcd.getTextSize(str)
        end

        sx = (x + w / 2) - (tsizeW / 2)
        if smallbox == nil or smallbox == false then
            sy = (y + h / 2) - (tsizeH / 2)
        else
            if status.maxminParam == false and status.titleParam == false then
                sy = (y + h / 2) - (tsizeH / 2)
            else
                sy = (y + h / 2) - (tsizeH / 2) + theme.smallBoxSensortextOFFSET
            end
        end

        -- change text colour to suit alarm flag
        -- 0 = default colour
        -- 1 = red (alarm)
        -- 2 = orange (warning)
        -- 3 = green (ok)  
        if status.statusColorParam == true then
            if alarm == 1 then
                lcd.color(lcd.RGB(255, 0, 0, 1)) -- red
            elseif alarm == 2 then
                lcd.color(lcd.RGB(255, 204, 0, 1)) -- orange
            elseif alarm == 3 then
                lcd.color(lcd.RGB(0, 188, 4, 1)) -- green
            end
        else
            -- we only do red
            if alarm == 1 then
                lcd.color(lcd.RGB(255, 0, 0, 1)) -- red
            end
        end

        lcd.drawText(sx, sy, str)

        -- reset text back from red to ensure max/min stay right color 
        if alarm ~= 0 then
            if status.isDARKMODE then
                lcd.color(lcd.RGB(255, 255, 255, 1))
            else
                lcd.color(lcd.RGB(90, 90, 90))
            end
        end

    end

    if title ~= nil and status.titleParam == true then
        lcd.font(theme.fontTITLE)
        str = title
        tsizeW, tsizeH = lcd.getTextSize(str)

        sx = (x + w / 2) - (tsizeW / 2)
        sy = (y + h) - (tsizeH) - theme.colSpacing

        lcd.drawText(sx, sy, str)
    end

    if status.maxminParam == true then

        if minimum ~= nil then

            lcd.font(theme.fontTITLE)

            if tostring(minimum) ~= "-" then lastMin = minimum end

            if tostring(minimum) == "-" then
                str = minimum
            else
                str = minimum .. unit
            end

            if unit == "°" then
                tsizeW, tsizeH = lcd.getTextSize(minimum .. ".")
            else
                tsizeW, tsizeH = lcd.getTextSize(str)
            end

            sx = (x + theme.colSpacing)
            sy = (y + h) - (tsizeH) - theme.colSpacing

            lcd.drawText(sx, sy, str)
        end

        if maximum ~= nil then
            lcd.font(theme.fontTITLE)

            if tostring(maximum) == "-" then
                str = maximum
            else
                str = maximum .. unit
            end
            if unit == "°" then
                tsizeW, tsizeH = lcd.getTextSize(maximum .. ".")
            else
                tsizeW, tsizeH = lcd.getTextSize(str)
            end

            sx = (x + w) - tsizeW - theme.colSpacing
            sy = (y + h) - (tsizeH) - theme.colSpacing

            lcd.drawText(sx, sy, str)
        end

    end

end

function status.telemetryBoxMAX(x, y, w, h, title, value, unit, smallbox)

    status.isVisible = lcd.isVisible()
    status.isDARKMODE = lcd.darkMode()
    local theme = status.getThemeInfo()

    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end

    -- draw box backgstatus.round    
    lcd.drawFilledRectangle(x, y, w, h)

    -- color    
    if status.isDARKMODE then
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end

    -- draw sensor text
    if value ~= nil then

        if smallbox == nil or smallbox == false then
            lcd.font(theme.fontSENSOR)
        else
            lcd.font(theme.fontSENSORSmallBox)
        end

        str = value .. unit

        if unit == "°" then
            tsizeW, tsizeH = lcd.getTextSize(value .. ".")
        else
            tsizeW, tsizeH = lcd.getTextSize(str)
        end

        sx = (x + w / 2) - (tsizeW / 2)
        if smallbox == nil or smallbox == false then
            sy = (y + h / 2) - (tsizeH / 2)
        else
            if status.maxminParam == false and status.titleParam == false then
                sy = (y + h / 2) - (tsizeH / 2)
            else
                sy = (y + h / 2) - (tsizeH / 2) + theme.smallBoxSensortextOFFSET
            end
        end

        lcd.drawText(sx, sy, str)

    end

    if title ~= nil and status.titleParam == true then
        lcd.font(theme.fontTITLE)
        str = title
        tsizeW, tsizeH = lcd.getTextSize(str)

        sx = (x + w / 2) - (tsizeW / 2)
        sy = (y + h) - (tsizeH) - theme.colSpacing

        lcd.drawText(sx, sy, str)
    end

end

function status.logsBOX()

    if status.readLOGS == false then
        local history = status.readHistory()
        status.readLOGSlast = history
        status.readLOGS = true
    else
        history = status.readLOGSlast
    end

    local theme = status.getThemeInfo()
    local w, h = lcd.getWindowSize()
    if w < 500 then
        boxW = w
    else
        boxW = w - math.floor((w * 2) / 100)
    end
    if h < 200 then
        boxH = h - 2
    else
        boxH = h - math.floor((h * 4) / 100)
    end

    -- draw the backgstatus.round
    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40, 50))
    else
        lcd.color(lcd.RGB(240, 240, 240, 50))
    end
    lcd.drawFilledRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- draw the border
    lcd.color(lcd.RGB(248, 176, 56))
    lcd.drawRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- draw the title
    lcd.color(lcd.RGB(248, 176, 56))
    lcd.drawFilledRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH / 9)

    if status.isDARKMODE then
        -- dark theme
        lcd.color(lcd.RGB(0, 0, 0, 1))
    else
        -- light theme
        lcd.color(lcd.RGB(255, 255, 255))
    end
    str = "Log History"
    lcd.font(theme.fontPopupTitle)
    tsizeW, tsizeH = lcd.getTextSize(str)

    boxTh = boxH / 9
    boxTy = h / 2 - boxH / 2
    boxTx = w / 2 - boxW / 2
    lcd.drawText((w / 2) - tsizeW / 2, boxTy + (boxTh / 2) - tsizeH / 2, str)

    -- close button
    lcd.drawBitmap(boxTx + boxW - boxTh, boxTy, status.gfx_close, boxTh, boxTh)
    status.closeButtonX = math.floor(boxTx + boxW - boxTh)
    status.closeButtonY = math.floor(boxTy) + theme.widgetTitleOffset
    status.closeButtonW = math.floor(boxTh)
    status.closeButtonH = math.floor(boxTh)

    lcd.color(lcd.RGB(255, 255, 255))

    --[[ header column format 
        TIME VOLTAGE AMPS RPM LQ MCU ESC
    ]] --
    colW = boxW / 7

    col1x = boxTx
    col2x = boxTx + theme.logsCOL1w
    col3x = boxTx + theme.logsCOL1w + theme.logsCOL2w
    col4x = boxTx + theme.logsCOL1w + theme.logsCOL2w + theme.logsCOL3w
    col5x = boxTx + theme.logsCOL1w + theme.logsCOL2w + theme.logsCOL3w + theme.logsCOL4w
    col6x = boxTx + theme.logsCOL1w + theme.logsCOL2w + theme.logsCOL3w + theme.logsCOL4w + theme.logsCOL5w
    col7x = boxTx + theme.logsCOL1w + theme.logsCOL2w + theme.logsCOL3w + theme.logsCOL4w + theme.logsCOL5w + theme.logsCOL6w

    lcd.color(lcd.RGB(90, 90, 90))

    -- LINES
    lcd.drawLine(boxTx + boxTh / 2, boxTy + (boxTh * 2), boxTx + boxW - (boxTh / 2), boxTy + (boxTh * 2))

    lcd.drawLine(col2x, boxTy + boxTh + boxTh / 2, col2x, boxTy + boxH - (boxTh / 2))
    lcd.drawLine(col3x, boxTy + boxTh + boxTh / 2, col3x, boxTy + boxH - (boxTh / 2))
    lcd.drawLine(col4x, boxTy + boxTh + boxTh / 2, col4x, boxTy + boxH - (boxTh / 2))
    lcd.drawLine(col5x, boxTy + boxTh + boxTh / 2, col5x, boxTy + boxH - (boxTh / 2))
    lcd.drawLine(col6x, boxTy + boxTh + boxTh / 2, col6x, boxTy + boxH - (boxTh / 2))
    lcd.drawLine(col7x, boxTy + boxTh + boxTh / 2, col7x, boxTy + boxH - (boxTh / 2))

    -- HEADER text
    if status.isDARKMODE then
        -- dark theme
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        -- light theme
        lcd.color(lcd.RGB(0, 0, 0))
    end
    lcd.font(theme.fontPopupTitle)

    if theme.logsCOL1w ~= 0 then
        str = "TIME"
        tsizeW, tsizeH = lcd.getTextSize(str)
        lcd.drawText(col1x + (theme.logsCOL1w / 2) - (tsizeW / 2), theme.logsHeaderOffset + (boxTy + boxTh) + ((boxTh / 2) - (tsizeH / 2)), str)
    end

    if theme.logsCOL2w ~= 0 then
        str = "VOLTAGE"
        tsizeW, tsizeH = lcd.getTextSize(str)
        lcd.drawText((col2x) + (theme.logsCOL2w / 2) - (tsizeW / 2), theme.logsHeaderOffset + (boxTy + boxTh) + (boxTh / 2) - (tsizeH / 2), str)
    end

    if theme.logsCOL3w ~= 0 then
        str = "AMPS"
        tsizeW, tsizeH = lcd.getTextSize(str)
        lcd.drawText((col3x) + (theme.logsCOL3w / 2) - (tsizeW / 2), theme.logsHeaderOffset + (boxTy + boxTh) + (boxTh / 2) - (tsizeH / 2), str)
    end

    if theme.logsCOL4w ~= 0 then
        str = "RPM"
        tsizeW, tsizeH = lcd.getTextSize(str)
        lcd.drawText((col4x) + (theme.logsCOL4w / 2) - (tsizeW / 2), theme.logsHeaderOffset + (boxTy + boxTh) + (boxTh / 2) - (tsizeH / 2), str)
    end

    if theme.logsCOL5w ~= 0 then
        str = "LQ"
        tsizeW, tsizeH = lcd.getTextSize(str)
        lcd.drawText((col5x) + (theme.logsCOL5w / 2) - (tsizeW / 2), theme.logsHeaderOffset + (boxTy + boxTh) + (boxTh / 2) - (tsizeH / 2), str)
    end

    if theme.logsCOL6w ~= 0 then
        str = "T.MCU"
        tsizeW, tsizeH = lcd.getTextSize(str)
        lcd.drawText((col6x) + (theme.logsCOL6w / 2) - (tsizeW / 2), theme.logsHeaderOffset + (boxTy + boxTh) + (boxTh / 2) - (tsizeH / 2), str)
    end

    if theme.logsCOL7w ~= 0 then
        str = "T.ESC"
        tsizeW, tsizeH = lcd.getTextSize(str)
        lcd.drawText((col7x) + (theme.logsCOL7w / 2) - (tsizeW / 2), theme.logsHeaderOffset + (boxTy + boxTh) + (boxTh / 2) - (tsizeH / 2), str)
    end

    c = 0

    if history ~= nil then
        for index, value in ipairs(history) do
            if value ~= nil then
                if value ~= "" and value ~= nil then
                    rowH = c * boxTh

                    local rowData = status.explode(value, ",")

                    --[[ rowData is a csv string as follows
                
                        status.theTIME,status.sensorVoltageMin,status.sensorVoltageMax,status.sensorFuelMin,status.sensorFuelMax,
                        status.sensorRPMMin,status.sensorRPMMax,status.sensorCurrentMin,status.sensorCurrentMax,status.sensorRSSIMin,
                        status.sensorRSSIMax,status.sensorTempMCUMin,status.sensorTempMCUMax,status.sensorTempESCMin,status.sensorTempESCMax    
                ]] --
                    -- loop of rowData and extract each value bases on idx
                    if rowData ~= nil then

                        for idx, snsr in pairs(rowData) do

                            snsr = snsr:gsub("%s+", "")

                            if snsr ~= nil and snsr ~= "" then
                                -- time
                                if idx == 1 and theme.logsCOL1w ~= 0 then
                                    str = status.SecondsToClockAlt(snsr)
                                    tsizeW, tsizeH = lcd.getTextSize(str)
                                    lcd.drawText(col1x + (theme.logsCOL1w / 2) - (tsizeW / 2), boxTy + tsizeH / 2 + (boxTh * 2) + rowH, str)
                                end
                                -- voltagemin
                                if idx == 2 then vstr = snsr end
                                -- voltagemax
                                if idx == 3 and theme.logsCOL2w ~= 0 then
                                    str = status.round(vstr / 100, 1) .. 'v / ' .. status.round(snsr / 100, 1) .. 'v'
                                    tsizeW, tsizeH = lcd.getTextSize(str)
                                    lcd.drawText(col2x + (theme.logsCOL2w / 2) - (tsizeW / 2), boxTy + tsizeH / 2 + (boxTh * 2) + rowH, str)
                                end
                                -- fuelmin
                                if idx == 4 then local logFUELmin = snsr end
                                -- fuelmax
                                if idx == 5 then local logFUELmax = snsr end
                                -- rpmmin
                                if idx == 6 then rstr = snsr end
                                -- rpmmax
                                if idx == 7 and theme.logsCOL4w ~= 0 then
                                    str = rstr .. 'rpm / ' .. snsr .. 'rpm'
                                    tsizeW, tsizeH = lcd.getTextSize(str)
                                    lcd.drawText(col4x + (theme.logsCOL4w / 2) - (tsizeW / 2), boxTy + tsizeH / 2 + (boxTh * 2) + rowH, str)
                                end
                                -- currentmin
                                if idx == 8 then cstr = snsr end
                                -- currentmax
                                if idx == 9 and theme.logsCOL3w ~= 0 then
                                    str = math.floor(cstr / 10) .. 'A / ' .. math.floor(snsr / 10) .. 'A'
                                    tsizeW, tsizeH = lcd.getTextSize(str)
                                    lcd.drawText(col3x + (theme.logsCOL3w / 2) - (tsizeW / 2), boxTy + tsizeH / 2 + (boxTh * 2) + rowH, str)
                                end
                                -- rssimin
                                if idx == 10 then lqstr = snsr end
                                -- rssimax
                                if idx == 11 and theme.logsCOL5w ~= 0 then
                                    str = lqstr .. '% / ' .. snsr .. '%'
                                    tsizeW, tsizeH = lcd.getTextSize(str)
                                    lcd.drawText(col5x + (theme.logsCOL5w / 2) - (tsizeW / 2), boxTy + tsizeH / 2 + (boxTh * 2) + rowH, str)
                                end
                                -- mcumin
                                if idx == 12 then mcustr = snsr end
                                -- mcumax
                                if idx == 13 and theme.logsCOL6w ~= 0 then
                                    str = status.round(mcustr / 100, 0) .. '° / ' .. status.round(snsr / 100, 0) .. '°'
                                    strf = status.round(mcustr / 100, 0) .. '. / ' .. status.round(snsr / 100, 0) .. '.'
                                    tsizeW, tsizeH = lcd.getTextSize(strf)
                                    lcd.drawText(col6x + (theme.logsCOL6w / 2) - (tsizeW / 2), boxTy + tsizeH / 2 + (boxTh * 2) + rowH, str)
                                end
                                -- escmin
                                if idx == 14 then escstr = snsr end
                                -- escmax
                                if idx == 15 and theme.logsCOL7w ~= 0 then
                                    str = status.round(escstr / 100, 0) .. '° / ' .. status.round(snsr / 100, 0) .. '°'
                                    strf = status.round(escstr / 100, 0) .. '. / ' .. status.round(snsr / 100, 0) .. '.'
                                    tsizeW, tsizeH = lcd.getTextSize(strf)
                                    lcd.drawText(col7x + (theme.logsCOL7w / 2) - (tsizeW / 2), boxTy + tsizeH / 2 + (boxTh * 2) + rowH, str)
                                end
                            end
                            -- end loop of each storage line        
                        end
                        c = c + 1

                        if h < 200 then
                            if c > 5 then break end
                        else
                            if c > 7 then break end
                        end
                        -- end of each log storage slot
                    end
                end
            end
        end
    end

    -- lcd.drawText((w / 2) - tsizeW / 2, (h / 2) - tsizeH / 2, str)
    return
end

function status.telemetryBoxImage(x, y, w, h, gfx)

    status.isVisible = lcd.isVisible()
    status.isDARKMODE = lcd.darkMode()
    local theme = status.getThemeInfo()

    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end

    -- draw box backgstatus.round    
    lcd.drawFilledRectangle(x, y, w, h)

    lcd.drawBitmap(x, y, gfx, w - theme.colSpacing, h - theme.colSpacing)

end

function status.paint(widget)

    if not rfsuite.bg.active() then

        if (os.clock() - status.initTime) >= 2 then status.screenError("PLEASE ENABLE THE BACKGROUND TASK") end
        lcd.invalidate()
        return
    else

        status.isVisible = lcd.isVisible()
        status.isDARKMODE = lcd.darkMode()

        status.isInConfiguration = false

        local cellVoltage = status.warnCellVoltage / 100

        if status.sensors.voltage ~= nil then
            -- we use status.lowvoltagsenseParam is use to raise or lower sensitivity
            if status.lowvoltagsenseParam == 1 then
                zippo = 0.2
            elseif status.lowvoltagsenseParam == 2 then
                zippo = 0.1
            else
                zippo = 0
            end
            -- low
            if status.sensors.voltage / 100 < ((cellVoltage * status.cellsParam) + zippo) then
                -- only do audio alert if between a range
                if status.sensors.voltage / 100 > ((cellVoltage * status.cellsParam / 2) + zippo) then
                    status.voltageIsLowAlert = true
                else
                    status.voltageIsLowAlert = false
                end
                -- we are low.. but above determs if we play the alert
                status.voltageIsLow = true
            else
                status.voltageIsLow = false
                status.voltageIsLowAlert = false
            end

            -- getting low
            if status.sensors.voltage / 100 < (((cellVoltage + 0.2) * status.cellsParam) + zippo) then
                status.voltageIsGettingLow = true
            else
                status.voltageIsGettingLow = false
            end
        else
            status.voltageIsLow = false
            status.voltageIsGettingLow = false
        end

        -- fuel detection
        if status.sensors.voltage ~= nil and status.lowfuelParam ~= nil then
            if status.sensors.fuel < status.lowfuelParam then
                status.fuelIsLow = true
            else
                status.fuelIsLow = false
            end
        else
            status.fuelIsLow = false
        end

        -- fuel detection
        if status.sensors.voltage ~= nil and status.lowfuelParam ~= nil then

            if status.sensors.fuel < (status.lowfuelParam + (status.lowfuelParam * 20) / 100) then
                status.fuelIsGettingLow = true
            else
                status.fuelIsGettingLow = false
            end
        else
            status.fuelIsGettingLow = false
        end

        -- -----------------------------------------------------------------------------------------------
        -- write values to boxes
        -- -----------------------------------------------------------------------------------------------

        local theme = status.getThemeInfo()
        local w, h = lcd.getWindowSize()

        if status.isVisible then
            -- blank out display
            if status.isDARKMODE then
                -- dark theme
                lcd.color(lcd.RGB(16, 16, 16))
            else
                -- light theme
                lcd.color(lcd.RGB(209, 208, 208))
            end
            lcd.drawFilledRectangle(0, 0, w, h)

            -- hard error
            if theme.supportedRADIO ~= true then
                status.screenError("UNKNOWN" .. " " .. environment.board)
                return
            end

            -- widget size
            if environment.board == "V20" or environment.board == "XES" or environment.board == "X20" or environment.board == "X20S" or environment.board == "X20PRO" or environment.board == "X20PROAW" then
                if w ~= 784 and h ~= 294 then
                    status.screenError("DISPLAY SIZE INVALID")
                    return
                end
            end
            if environment.board == "X18" or environment.board == "X18S" then
                smallTEXT = true
                if w ~= 472 and h ~= 191 then
                    status.screenError("DISPLAY SIZE INVALID")
                    return
                end
            end
            if environment.board == "X14" or environment.board == "X14S" then
                if w ~= 630 and h ~= 236 then
                    status.screenError("DISPLAY SIZE INVALID")
                    return
                end
            end
            if environment.board == "TWXLITE" or environment.board == "TWXLITES" then
                if w ~= 472 and h ~= 191 then
                    status.screenError("DISPLAY SIZE INVALID")
                    return
                end
            end
            if environment.board == "X10EXPRESS" or environment.board == "X10" or environment.board == "X10S" or environment.board == "X12" or environment.board == "X12S" then
                if w ~= 472 and h ~= 158 then
                    status.screenError("DISPLAY SIZE INVALID")
                    return
                end
            end

            boxW = theme.fullBoxW - theme.colSpacing
            boxH = theme.fullBoxH - theme.colSpacing

            boxHs = theme.fullBoxH / 2 - theme.colSpacing
            boxWs = theme.fullBoxW / 2 - theme.colSpacing

            -- FUEL
            if status.sensors.fuel ~= nil then

                sensorWARN = 3
                if status.fuelIsGettingLow then sensorWARN = 2 end
                if status.fuelIsLow then sensorWARN = 1 end

                sensorVALUE = status.sensors.fuel

                if status.sensors.voltage <= 50 then sensorVALUE = 0 end

                if status.sensors.fuel < 5 then sensorVALUE = "0" end

                if status.titleParam == true then
                    sensorTITLE = "FUEL"
                else
                    sensorTITLE = ""
                end

                if status.sensorFuelMin == 0 or status.sensorFuelMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = status.sensorFuelMin
                end

                if status.sensorFuelMax == 0 or status.sensorFuelMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = status.sensorFuelMax
                end

                sensorUNIT = "%"

                local sensorTGT = 'fuel'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            end

            -- RPM
            if status.sensors.rpm ~= nil then

                sensorVALUE = status.sensors.rpm

                if status.sensors.rpm < 5 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_rpm
                else
                    sensorTITLE = ""
                end

                if status.sensorRPMMin == 0 or status.sensorRPMMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = status.sensorRPMMin
                end

                if status.sensorRPMMax == 0 or status.sensorRPMMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = status.sensorRPMMax
                end

                sensorUNIT = "rpm"
                sensorWARN = 0

                local sensorTGT = 'rpm'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            end

            -- VOLTAGE
            if status.sensors.voltage ~= nil then

                sensorWARN = 3
                if status.voltageIsGettingLow then sensorWARN = 2 end
                if status.voltageIsLow then sensorWARN = 1 end

                sensorVALUE = status.sensors.voltage / 100

                if sensorVALUE < 1 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_voltage
                else
                    sensorTITLE = ""
                end

                if status.sensorVoltageMin == 0 or status.sensorVoltageMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = status.sensorVoltageMin / 100
                end

                if status.sensorVoltageMax == 0 or status.sensorVoltageMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = status.sensorVoltageMax / 100
                end

                sensorUNIT = "v"

                local sensorTGT = 'voltage'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            end

            -- CURRENT
            if status.sensors.current ~= nil then

                sensorVALUE = status.sensors.current / 10
                if status.linkUP == false then
                    sensorVALUE = 0
                else
                    if sensorVALUE == 0 then
                        local fakeC
                        if status.sensors.rpm > 5 then
                            fakeC = 1
                        elseif status.sensors.rpm > 50 then
                            fakeC = 2
                        elseif status.sensors.rpm > 100 then
                            fakeC = 3
                        elseif status.sensors.rpm > 200 then
                            fakeC = 4
                        elseif status.sensors.rpm > 500 then
                            fakeC = 5
                        elseif status.sensors.rpm > 1000 then
                            fakeC = 6
                        else
                            if status.sensors.voltage > 0 then
                                fakeC = math.random(1, 3) / 10
                            else
                                fakeC = 0
                            end
                        end
                        sensorVALUE = fakeC
                    end
                end
                if status.sensors.voltage <= 50 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_current
                else
                    sensorTITLE = ""
                end

                if status.sensorCurrentMin == 0 or status.sensorCurrentMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = status.sensorCurrentMin / 10
                end

                if status.sensorCurrentMax == 0 or status.sensorCurrentMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = status.sensorCurrentMax / 10
                end

                sensorUNIT = "A"
                sensorWARN = 0

                local sensorTGT = 'current'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            end

            -- TEMP ESC
            if status.sensors.temp_esc ~= nil then

                sensorVALUE = status.round(status.sensors.temp_esc / 100, 0)

                if sensorVALUE < 1 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_tempESC
                else
                    sensorTITLE = ""
                end

                if status.sensorTempESCMin == 0 or status.sensorTempESCMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = status.round(status.sensorTempESCMin / 100, 0)
                end

                if status.sensorTempESCMax == 0 or status.sensorTempESCMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = status.round(status.sensorTempESCMax / 100, 0)
                end

                sensorUNIT = "°"
                sensorWARN = 0

                local sensorTGT = 'temp_esc'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            end

            -- TEMP MCU
            if status.sensors.temp_mcu ~= nil then

                sensorVALUE = status.round(status.sensors.temp_mcu / 100, 0)

                if sensorVALUE < 1 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_tempMCU
                else
                    sensorTITLE = ""
                end

                if status.sensorTempMCUMin == 0 or status.sensorTempMCUMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = status.round(status.sensorTempMCUMin / 100, 0)
                end

                if status.sensorTempMCUMax == 0 or status.sensorTempMCUMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = status.round(status.sensorTempMCUMax / 100, 0)
                end

                sensorUNIT = "°"
                sensorWARN = 0

                local sensorTGT = 'temp_mcu'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            end

            -- RSSI
            if status.sensors.rssi ~= nil and (status.quadBoxParam == 0 or status.quadBoxParam == 1) then

                sensorVALUE = status.sensors.rssi

                -- if sensorVALUE < 1 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_rssi
                else
                    sensorTITLE = ""
                end

                if status.sensorRSSIMin == 0 or status.sensorRSSIMin == nil then
                    sensorMIN = "-"
                else
                    sensorMIN = status.sensorRSSIMin
                end

                if status.sensorRSSIMax == 0 or status.sensorRSSIMax == nil then
                    sensorMAX = "-"
                else
                    sensorMAX = status.sensorRSSIMax
                end

                sensorUNIT = "dB"
                sensorWARN = 0

                local sensorTGT = 'rssi'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            end

            -- mah
            if status.sensors.mah ~= nil then

                sensorVALUE = status.sensors.mah

                if sensorVALUE < 1 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_mah
                else
                    sensorTITLE = ""
                end

                if sensorMAHMin == 0 or sensorMAHMin == nil then
                    sensorMIN = "-"
                else
                    sensorMIN = sensorMAHMin
                end

                if sensorMAHMax == 0 or sensorMAHMax == nil then
                    sensorMAX = "-"
                else
                    sensorMAX = sensorMAHMax
                end

                sensorUNIT = ""
                sensorWARN = 0

                local sensorTGT = 'mah'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT
            end

            -- TIMER
            sensorMIN = nil
            sensorMAX = nil

            if status.theTIME ~= nil or status.theTIME == 0 then
                str = status.SecondsToClock(status.theTIME)
            else
                str = "00:00:00"
            end

            if status.titleParam == true then
                sensorTITLE = theme.title_time
            else
                sensorTITLE = ""
            end

            sensorVALUE = str

            sensorUNIT = ""
            sensorWARN = 0

            local sensorTGT = 'timer'
            status.sensordisplay[sensorTGT] = {}
            status.sensordisplay[sensorTGT]['title'] = sensorTITLE
            status.sensordisplay[sensorTGT]['value'] = sensorVALUE
            status.sensordisplay[sensorTGT]['warn'] = sensorWARN
            status.sensordisplay[sensorTGT]['min'] = sensorMIN
            status.sensordisplay[sensorTGT]['max'] = sensorMAX
            status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            -- GOV MODE
            if status.govmodeParam == 0 then
                if status.sensors.govmode == nil then status.sensors.govmode = "INIT" end
                str = status.sensors.govmode
                sensorTITLE = theme.title_governor
            else
                str = status.sensors.fm
                sensorTITLE = theme.title_fm
            end
            sensorVALUE = str

            if status.titleParam ~= true then sensorTITLE = "" end

            sensorUNIT = ""
            sensorWARN = 0
            sensorMIN = nil
            sensorMAX = nil

            local sensorTGT = 'governor'
            status.sensordisplay[sensorTGT] = {}
            status.sensordisplay[sensorTGT]['title'] = sensorTITLE
            status.sensordisplay[sensorTGT]['value'] = sensorVALUE
            status.sensordisplay[sensorTGT]['warn'] = status.govColorFlag(sensorVALUE)
            status.sensordisplay[sensorTGT]['min'] = sensorMIN
            status.sensordisplay[sensorTGT]['max'] = sensorMAX
            status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            -- CUSTOM SENSOR #1

            if status.customSensorParam1 ~= nil then

                local csSensor = status.customSensorParam1
                if csSensor:value() == nil then
                    sensorVALUE = "-"
                else
                    sensorVALUE = csSensor:value()
                end

                if csSensor:name() == nil then
                    sensorTITLE = "UNKNOWN"
                else
                    sensorTITLE = string.upper(csSensor:name())
                end

                if csSensor:unit() == nil then
                    sensorUNIT = ""
                else
                    sensorUNIT = csSensor:stringUnit()
                end

                sensorMIN = "-"
                sensorMAX = "-"

                local sensorTGT = 'customsensor1'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT
            else

                local sensorTGT = 'customsensor1'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = "CUSTOM SENSOR 1"
                status.sensordisplay[sensorTGT]['value'] = "N/A"
                status.sensordisplay[sensorTGT]['warn'] = nil
                status.sensordisplay[sensorTGT]['min'] = nil
                status.sensordisplay[sensorTGT]['max'] = nil
                status.sensordisplay[sensorTGT]['unit'] = ""
            end

            -- CUSTOM SENSOR #1

            if status.customSensorParam2 ~= nil then

                local csSensor = status.customSensorParam2
                if csSensor:value() == nil then
                    sensorVALUE = "-"
                else
                    sensorVALUE = csSensor:value()
                end

                if csSensor:name() == nil then
                    sensorTITLE = "UNKNOWN"
                else
                    sensorTITLE = string.upper(csSensor:name())
                end

                if csSensor:unit() == nil then
                    sensorUNIT = ""
                else
                    sensorUNIT = csSensor:stringUnit()
                end

                sensorMIN = "-"
                sensorMAX = "-"

                local sensorTGT = 'customsensor2'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = sensorTITLE
                status.sensordisplay[sensorTGT]['value'] = sensorVALUE
                status.sensordisplay[sensorTGT]['warn'] = sensorWARN
                status.sensordisplay[sensorTGT]['min'] = sensorMIN
                status.sensordisplay[sensorTGT]['max'] = sensorMAX
                status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            else

                local sensorTGT = 'customsensor2'
                status.sensordisplay[sensorTGT] = {}
                status.sensordisplay[sensorTGT]['title'] = "CUSTOM SENSOR 2"
                status.sensordisplay[sensorTGT]['value'] = "N/A"
                status.sensordisplay[sensorTGT]['warn'] = nil
                status.sensordisplay[sensorTGT]['min'] = nil
                status.sensordisplay[sensorTGT]['max'] = nil
                status.sensordisplay[sensorTGT]['unit'] = ""

            end

            -- loop throught 6 box and link into status.sensordisplay to choose where to put things
            local c = 1
            while c <= 6 do

                -- reset all values
                sensorVALUE = nil
                sensorUNIT = nil
                sensorMIN = nil
                sensorMAX = nil
                sensorWARN = 0
                sensorTITLE = nil
                sensorTGT = nil
                smallBOX = false

                -- column positions and tgt
                if c == 1 then
                    posX = 0
                    posY = theme.colSpacing
                    sensorTGT = status.layoutBox1Param
                end
                if c == 2 then
                    posX = 0 + theme.colSpacing + boxW
                    posY = theme.colSpacing
                    sensorTGT = status.layoutBox2Param
                end
                if c == 3 then
                    posX = 0 + theme.colSpacing + boxW + theme.colSpacing + boxW
                    posY = theme.colSpacing
                    sensorTGT = status.layoutBox3Param
                end
                if c == 4 then
                    posX = 0
                    posY = theme.colSpacing + boxH + theme.colSpacing
                    sensorTGT = status.layoutBox4Param
                end
                if c == 5 then
                    posX = 0 + theme.colSpacing + boxW
                    posY = theme.colSpacing + boxH + theme.colSpacing
                    sensorTGT = status.layoutBox5Param
                end
                if c == 6 then
                    posX = 0 + theme.colSpacing + boxW + theme.colSpacing + boxW
                    posY = theme.colSpacing + boxH + theme.colSpacing
                    sensorTGT = status.layoutBox6Param
                end

                -- remap sensorTGT
                if sensorTGT == 1 then sensorTGT = 'timer' end
                if sensorTGT == 2 then sensorTGT = 'voltage' end
                if sensorTGT == 3 then sensorTGT = 'fuel' end
                if sensorTGT == 4 then sensorTGT = 'current' end
                if sensorTGT == 17 then sensorTGT = 'mah' end
                if sensorTGT == 5 then sensorTGT = 'rpm' end
                if sensorTGT == 6 then sensorTGT = 'rssi' end
                if sensorTGT == 7 then sensorTGT = 'temp_esc' end
                if sensorTGT == 8 then sensorTGT = 'temp_mcu' end
                if sensorTGT == 9 then sensorTGT = 'image' end
                if sensorTGT == 10 then sensorTGT = 'governor' end
                if sensorTGT == 11 then sensorTGT = 'image__gov' end
                if sensorTGT == 12 then sensorTGT = 'rssi__timer' end
                if sensorTGT == 13 then sensorTGT = 'temp_esc__temp_mcu' end
                if sensorTGT == 14 then sensorTGT = 'voltage__fuel' end
                if sensorTGT == 15 then sensorTGT = 'voltage__current' end
                if sensorTGT == 16 then sensorTGT = 'voltage__mah' end
                if sensorTGT == 20 then sensorTGT = 'rssi_timer_temp_esc_temp_mcu' end
                if sensorTGT == 21 then sensorTGT = 'max_current' end
                if sensorTGT == 22 then sensorTGT = 'lq__gov' end
                if sensorTGT == 23 then sensorTGT = 'customsensor1' end
                if sensorTGT == 24 then sensorTGT = 'customsensor2' end
                if sensorTGT == 25 then sensorTGT = 'customsensor1_2' end

                -- set sensor values based on sensorTGT
                if status.sensordisplay[sensorTGT] ~= nil then
                    -- all std values.  =
                    sensorVALUE = status.sensordisplay[sensorTGT]['value']
                    sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                    sensorMIN = status.sensordisplay[sensorTGT]['min']
                    sensorMAX = status.sensordisplay[sensorTGT]['max']
                    sensorWARN = status.sensordisplay[sensorTGT]['warn']
                    sensorTITLE = status.sensordisplay[sensorTGT]['title']
                    status.telemetryBox(posX, posY, boxW, boxH, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                else

                    if sensorTGT == 'customsensor1' or sensorTGT == 'customsensor2' then

                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        sensorTITLE = status.sensordisplay[sensorTGT]['title']
                        status.telemetryBox(posX, posY, boxW, boxH, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, "", "")

                    end

                    if sensorTGT == 'customsensor1_2' then
                        -- SENSOR1 & 2
                        sensorTGT = "customsensor1"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "customsensor2"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'image' then
                        -- IMAGE
                        if status.gfx_model ~= nil then
                            status.telemetryBoxImage(posX, posY, boxW, boxH, status.gfx_model)
                        else
                            status.telemetryBoxImage(posX, posY, boxW, boxH, status.gfx_heli)
                        end
                    end

                    if sensorTGT == 'image__gov' then
                        -- IMAGE + GOVERNOR
                        if status.gfx_model ~= nil then
                            status.telemetryBoxImage(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), status.gfx_model)
                        else
                            status.telemetryBoxImage(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), status.gfx_heli)
                        end

                        sensorTGT = "governor"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'lq__gov' then
                        -- LQ + GOV
                        sensorTGT = "rssi"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "governor"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'rssi__timer' then

                        sensorTGT = "rssi"
                        if status.sensordisplay[sensorTGT] ~= nil then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            status.telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "timer"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'temp_esc__temp_mcu' then

                        sensorTGT = "temp_esc"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "temp_mcu"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'voltage__fuel' then

                        sensorTGT = "voltage"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "fuel"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'voltage__current' then

                        sensorTGT = "voltage"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "current"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'voltage__mah' then

                        sensorTGT = "voltage"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "mah"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN,
                                            sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'rssi_timer_temp_esc_temp_mcu' then

                        sensorTGT = "rssi"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY, boxW / 2 - (theme.colSpacing / 2), boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN,
                                            sensorMAX)

                        sensorTGT = "timer"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX + boxW / 2 + (theme.colSpacing / 2), posY, boxW / 2 - (theme.colSpacing / 2), boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT,
                                            smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "temp_esc"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW / 2 - (theme.colSpacing / 2), boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT,
                                            smallBOX, sensorWARN, sensorMIN, sensorMAX)

                        sensorTGT = "temp_mcu"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        smallBOX = true
                        status.telemetryBox(posX + boxW / 2 + (theme.colSpacing / 2), posY + boxH / 2 + (theme.colSpacing / 2), boxW / 2 - (theme.colSpacing / 2), boxH / 2 - (theme.colSpacing / 2),
                                            sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)

                    end

                    if sensorTGT == 'max_current' then

                        sensorTGT = "current"
                        sensorVALUE = status.sensordisplay[sensorTGT]['value']
                        sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                        sensorMIN = status.sensordisplay[sensorTGT]['min']
                        sensorMAX = status.sensordisplay[sensorTGT]['max']
                        sensorWARN = status.sensordisplay[sensorTGT]['warn']
                        sensorTITLE = status.sensordisplay[sensorTGT]['title']

                        if sensorMAX == "-" or sensorMAX == nil then sensorMAX = 0 end

                        smallBOX = false
                        status.telemetryBox(posX, posY, boxW, boxH, "MAX " .. sensorTITLE, sensorMAX, sensorUNIT, smallBOX)

                    end

                end

                c = c + 1
            end

            if status.linkUP == false and environment.simulation == false then status.noTelem() end

            if status.showLOGS ~= nil then if status.showLOGS then status.logsBOX() end end

        end
    end

end

function status.ReverseTable(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do reversedTable[itemCount + 1 - k] = v end
    return reversedTable
end

function status.getChannelValue(ich)
    local src = system.getSource({category = CATEGORY_CHANNEL, member = (ich - 1), options = 0})
    return math.floor((src:value() / 10.24) + 0.5)
end

function status.getSensors()
    if status.isInConfiguration == true then return status.sensors end

    local tv
    local voltage
    local temp_esc
    local temp_mcu
    local mah
    local mah
    local fuel
    local fm
    local rssi
    local adjSOURCE
    local adjvalue
    local current
    local currentesc1

    -- lcd.resetFocusTimeout()

    if environment.simulation == true then

        tv = math.random(2100, 2274)
        voltage = tv
        temp_esc = math.random(50, 225) * 10
        temp_mcu = math.random(50, 185) * 10
        mah = math.random(10000, 10100)
        fuel = 55
        fm = "DISABLED"
        rssi = math.random(90, 100)
        adjsource = 0
        adjvalue = 0
        current = 0

        if status.idleupswitchParam ~= nil and armswitchParam ~= nil then
            if status.idleupswitchParam:state() == true and armswitchParam:state() == true then
                current = math.random(100, 120)
                rpm = math.random(90, 100)
            else
                current = 0
                rpm = 0
            end
        end

    elseif status.linkUP == true then

        -- get sensors
        voltageSOURCE = rfsuite.bg.telemetry.getSensorSource("voltage")
        rpmSOURCE = rfsuite.bg.telemetry.getSensorSource("rpm")
        currentSOURCE = rfsuite.bg.telemetry.getSensorSource("current")
        currentSOURCEESC1 = rfsuite.bg.telemetry.getSensorSource("currentESC1")
        temp_escSOURCE = rfsuite.bg.telemetry.getSensorSource("tempESC")
        temp_mcuSOURCE = rfsuite.bg.telemetry.getSensorSource("tempMCU")
        fuelSOURCE = rfsuite.bg.telemetry.getSensorSource("fuel")
        adjSOURCE = rfsuite.bg.telemetry.getSensorSource("adjF")
        adjVALUE = rfsuite.bg.telemetry.getSensorSource("adjV")
        adjvSOURCE = rfsuite.bg.telemetry.getSensorSource("adjV")
        mahSOURCE = rfsuite.bg.telemetry.getSensorSource("capacity")
        rssiSOURCE = rfsuite.utils.getRssiSensor().sensor
        govSOURCE = rfsuite.bg.telemetry.getSensorSource("governor")

        if rfsuite.bg.telemetry.getSensorProtocol() == 'ccrsf' then

            if voltageSOURCE ~= nil then
                voltage = voltageSOURCE:value()
                if voltage ~= nil then
                    voltage = voltage * 100
                else
                    voltage = 0
                end
            else
                voltage = 0
            end

            if rpmSOURCE ~= nil then
                if rpmSOURCE:maximum() == 1000.0 then rpmSOURCE:maximum(65000) end

                rpm = rpmSOURCE:value()
                if rpm ~= nil then
                    rpm = rpm
                else
                    rpm = 0
                end
            else
                rpm = 0
            end

            if currentSOURCE ~= nil then
                if currentSOURCE:maximum() == 50.0 then currentSOURCE:maximum(400.0) end

                current = currentSOURCE:value()
                if currentSOURCEESC1 ~= nil then
                        currentesc1 = currentSOURCEESC1:value()
                else
                        currentesc1 = 0
                end
                if current ~= nil then
                    if current == 0 and currentesc1 ~= 0 then
                        current = currentesc1 * 10
                    else
                        current = current * 10
                    end    
                else
                    current = 0
                end
            else
                current = 0
            end

            if temp_escSOURCE ~= nil then
                temp_esc = temp_escSOURCE:value()
                if temp_esc ~= nil then
                    temp_esc = temp_esc * 100
                else
                    temp_esc = 0
                end
            else
                temp_esc = 0
            end

            if temp_mcuSOURCE ~= nil then
                temp_mcu = temp_mcuSOURCE:value()
                if temp_mcu ~= nil then
                    temp_mcu = (temp_mcu) * 100
                else
                    temp_mcu = 0
                end
            else
                temp_mcu = 0
            end

            if fuelSOURCE ~= nil then
                fuel = fuelSOURCE:value()
                if fuel ~= nil then
                    fuel = fuel
                else
                    fuel = 0
                end
            else
                fuel = 0
            end

            if mahSOURCE ~= nil then
                mah = mahSOURCE:value()
                if mah ~= nil then
                    mah = mah
                else
                    mah = 0
                end
            else
                mah = 0
            end

            if govSOURCE ~= nil then
                govId = govSOURCE:value()

                if governorMap[govId] == nil then
                    govmode = "UNKNOWN"
                else
                    govmode = governorMap[govId]
                end

            else
                govmode = ""
            end
            if system.getSource({category = CATEGORY_FLIGHT, member = FLIGHT_CURRENT_MODE}):stringValue() then
                fm = system.getSource({category = CATEGORY_FLIGHT, member = FLIGHT_CURRENT_MODE}):stringValue()
            else
                fm = ""
            end

            if rssiSOURCE ~= nil then
                rssi = rssiSOURCE:value()

                if rssi ~= nil then
                    rssi = rssi
                else
                    rssi = 0
                end
            else
                rssi = 0
            end

            if adjSOURCE ~= nil then
                adjfunc = adjSOURCE:value()
                if adjfunc ~= nil then
                    adjfunc = adjfunc
                else
                    adjfunc = 0
                end
            else
                adjfunc = 0
            end

            if adjVALUE ~= nil then
                adjvalue = adjVALUE:value()
                if adjvalue ~= nil then
                    adjvalue = adjvalue
                else
                    adjvalue = 0
                end
            else
                adjvalue = 0
            end

        elseif rfsuite.bg.telemetry.getSensorProtocol() == 'lcrsf' then

            if voltageSOURCE ~= nil then
                voltage = voltageSOURCE:value()
                if voltage ~= nil then
                    voltage = voltage * 100
                else
                    voltage = 0
                end
            else
                voltage = 0
            end

            if rpmSOURCE ~= nil then
                if rpmSOURCE:maximum() == 1000.0 then rpmSOURCE:maximum(65000) end

                rpm = rpmSOURCE:value()
                if rpm ~= nil then
                    rpm = rpm
                else
                    rpm = 0
                end
            else
                rpm = 0
            end

            if currentSOURCE ~= nil then
                if currentSOURCE:maximum() == 50.0 then currentSOURCE:maximum(400.0) end

                current = currentSOURCE:value()
                if current ~= nil then
                    current = current * 10
                else
                    current = 0
                end
            else
                current = 0
            end

            if temp_escSOURCE ~= nil then
                temp_esc = temp_escSOURCE:value()
                if temp_esc ~= nil then
                    temp_esc = temp_esc * 100
                else
                    temp_esc = 0
                end
            else
                temp_esc = 0
            end

            if temp_mcuSOURCE ~= nil then
                temp_mcu = temp_mcuSOURCE:value()
                if temp_mcu ~= nil then
                    temp_mcu = (temp_mcu) * 100
                else
                    temp_mcu = 0
                end
            else
                temp_mcu = 0
            end

            if fuelSOURCE ~= nil then
                fuel = fuelSOURCE:value()
                if fuel ~= nil then
                    fuel = fuel
                else
                    fuel = 0
                end
            else
                fuel = 0
            end

            if mahSOURCE ~= nil then
                mah = mahSOURCE:value()
                if mah ~= nil then
                    mah = mah
                else
                    mah = 0
                end
            else
                mah = 0
            end

            if govSOURCE ~= nil then govmode = govSOURCE:stringValue() end
            if system.getSource({category = CATEGORY_FLIGHT, member = FLIGHT_CURRENT_MODE}):stringValue() then
                fm = system.getSource({category = CATEGORY_FLIGHT, member = FLIGHT_CURRENT_MODE}):stringValue()
            else
                fm = ""
            end

            if rssiSOURCE ~= nil then
                rssi = rssiSOURCE:value()
                if rssi ~= nil then
                    rssi = rssi
                else
                    rssi = 0
                end
            else
                rssi = 0
            end

            -- note.
            -- need to modify firmware to allow this to work for crsf correctly
            adjsource = 0
            adjvalue = 0

        elseif rfsuite.bg.telemetry.getSensorProtocol() == 'sport' then

            if voltageSOURCE ~= nil then
                voltage = voltageSOURCE:value()
                if voltage ~= nil then
                    voltage = voltage * 100
                else
                    voltage = 0
                end
            else
                voltage = 0
            end

            if rpmSOURCE ~= nil then
                rpm = rpmSOURCE:value()
                if rpm ~= nil then
                    rpm = rpm
                else
                    rpm = 0
                end
            else
                rpm = 0
            end

            if currentSOURCE ~= nil then
                current = currentSOURCE:value()
                if currentSOURCEESC1 ~= nil then
                        currentesc1 = currentSOURCEESC1:value()
                else
                        currentesc1 = 0
                end
                if current ~= nil then
                    if current == 0 and currentesc1 ~= 0 then
                        current = currentesc1 * 10
                    else
                        current = current * 10
                    end  
                else
                    current = 0
                end
            else
                current = 0
            end

            if temp_escSOURCE ~= nil then
                temp_esc = temp_escSOURCE:value()
                if temp_esc ~= nil then
                    temp_esc = temp_esc * 100
                else
                    temp_esc = 0
                end
            else
                temp_esc = 0
            end

            if temp_mcuSOURCE ~= nil then
                temp_mcu = temp_mcuSOURCE:value()
                if temp_mcu ~= nil then
                    temp_mcu = temp_mcu * 100
                else
                    temp_mcu = 0
                end
            else
                temp_mcu = 0
            end

            if fuelSOURCE ~= nil then
                fuel = fuelSOURCE:value()
                if fuel ~= nil then
                    fuel = status.round(fuel, 0)
                else
                    fuel = 0
                end
            else
                fuel = 0
            end

            if mahSOURCE ~= nil then
                mah = mahSOURCE:value()
                if mah ~= nil then
                    mah = mah
                else
                    mah = 0
                end
            else
                mah = 0
            end

            if rssiSOURCE ~= nil then
                rssi = rssiSOURCE:value()
                if rssi ~= nil then
                    rssi = rssi
                else
                    rssi = 0
                end
            else
                rssi = 0
            end

            if govSOURCE ~= nil then
                govId = govSOURCE:value()

                if governorMap[govId] == nil then
                    govmode = "UNKNOWN"
                else
                    govmode = governorMap[govId]
                end

            else
                govmode = ""
            end
            if system.getSource({category = CATEGORY_FLIGHT, member = FLIGHT_CURRENT_MODE}):stringValue() then
                fm = system.getSource({category = CATEGORY_FLIGHT, member = FLIGHT_CURRENT_MODE}):stringValue()
            else
                fm = ""
            end

            if adjSOURCE ~= nil then adjsource = adjSOURCE:value() end

            if adjVALUE ~= nil then adjvalue = adjVALUE:value() end

        end

    else
        -- we have no link.  do something
        -- print("NO LINK")
        -- keep looking for new sensor

        voltage = 0
        rpm = 0
        current = 0
        temp_esc = 0
        temp_mcu = 0
        fuel = 0
        mah = 0
        govmode = "-"
        fm = "-"
        rssi = 0
        adjsource = 0
        adjvalue = 0

        voltageSOURCE = nil
        rpmSOURCE = nil
        currentSOURCE = nil
        temp_escSOURCE = nil
        temp_mcuSOURCE = nil
        fuelSOURCE = nil
        govSOURCE = nil
        adjSOURCE = nil
        adjVALUE = nil
        mahSOURCE = nil
        telemetrySOURCE = nil
        crsfSOURCE = nil

    end

    -- calc fuel percentage if needed
    if status.calcfuelParam == true then

        local maxCellVoltage = status.maxCellVoltage / 100
        local minCellVoltage = status.minCellVoltage / 100

        local maxVoltage = maxCellVoltage * status.cellsParam
        local minVoltage = minCellVoltage * status.cellsParam

        local cv = voltage / 100
        local maxv = maxCellVoltage * status.cellsParam
        local minv = minCellVoltage * status.cellsParam

        local batteryPercentage = ((cv - minv) / (maxv - minv)) * 100

        fuel = status.round(batteryPercentage, 0)

        if fuel > 100 then fuel = 100 end

    end

    if voltage == nil then voltage = 0 end
    if math.floor(voltage) <= 5 then fuel = 0 end

    -- convert from C to F
    -- Divide by 5, then multiply by 9, then add 32
    if status.tempconvertParamMCU == 2 then
        temp_mcu = ((temp_mcu / 5) * 9) + 32
        temp_mcu = status.round(temp_mcu, 0)
    end
    -- convert from F to C
    -- Deduct 32, then multiply by 5, then divide by 9
    if status.tempconvertParamMCU == 3 then
        temp_mcu = ((temp_mcu - 32) * 5) / 9
        temp_mcu = status.round(temp_mcu, 0)
    end

    -- convert from C to F
    -- Divide by 5, then multiply by 9, then add 32
    if status.tempconvertParamESC == 2 then
        temp_esc = ((temp_esc / 5) * 9) + 32
        temp_esc = status.round(temp_esc, 0)
    end
    -- convert from F to C
    -- Deduct 32, then multiply by 5, then divide by 9
    if status.tempconvertParamESC == 3 then
        temp_esc = ((temp_esc - 32) * 5) / 9
        temp_esc = status.round(temp_esc, 0)
    end

    -- set flag to status.refresh screen or not

    if voltage == nil then voltage = 0 end
    voltage = status.round(voltage, 0)

    if rpm == nil then rpm = 0 end
    rpm = status.round(rpm, 0)

    if temp_mcu == nil then temp_mcu = 0 end
    temp_mcu = status.round(temp_mcu, 0)

    if temp_esc == nil then temp_esc = 0 end
    temp_esc = status.round(temp_esc, 0)

    if current == nil then current = 0 end
    current = status.round(current, 0)

    if rssi == nil then rssi = 0 end
    rssi = status.round(rssi, 0)

    -- do / dont do voltage based on stick position
    if status.lowvoltagStickParam == nil then status.lowvoltagStickParam = 0 end
    if status.lowvoltagStickCutoffParam == nil then status.lowvoltagStickCutoffParam = 80 end

    if (status.lowvoltagStickParam ~= 0) then
        status.lvStickannouncement = false
        for i, v in ipairs(status.lvStickOrder[status.lowvoltagStickParam]) do
            if status.lvStickannouncement == false then -- we skip more if any stick has resulted in announcement
                if math.abs(status.getChannelValue(v)) >= status.lowvoltagStickCutoffParam then status.lvStickannouncement = true end
            end
        end
    end

    -- intercept governor for non rf governor helis
    if armswitchParam ~= nil or status.idleupswitchParam ~= nil then
        if status.govmodeParam == 1 then
            if armswitchParam:state() == true then
                govmode = "ARMED"
                fm = "ARMED"
            else
                govmode = "DISARMED"
                fm = "DISARMED"
            end

            if armswitchParam:state() == true then
                if status.idleupswitchParam:state() == true then
                    govmode = "ACTIVE"
                    fm = "ACTIVE"
                else
                    govmode = "THR-OFF"
                    fm = "THR-OFF"
                end

            end
        end

    end

    if status.sensors.voltage ~= voltage then status.refresh = true end
    if status.sensors.rpm ~= rpm then status.refresh = true end
    if status.sensors.current ~= current then status.refresh = true end
    if status.sensors.temp_esc ~= temp_esc then status.refresh = true end
    if status.sensors.temp_mcu ~= temp_mcu then status.refresh = true end
    if status.sensors.govmode ~= govmode then status.refresh = true end
    if status.sensors.fuel ~= fuel then status.refresh = true end
    if status.sensors.mah ~= mah then status.refresh = true end
    if status.sensors.rssi ~= rssi then status.refresh = true end
    if status.sensors.fm ~= CURRENT_FLIGHT_MODE then status.refresh = true end

    ret = {
        fm = fm,
        govmode = govmode,
        voltage = voltage,
        rpm = rpm,
        current = current,
        temp_esc = temp_esc,
        temp_mcu = temp_mcu,
        fuel = fuel,
        mah = mah,
        rssi = rssi,
        adjsource = adjsource,
        adjvalue = adjvalue
    }
    status.sensors = ret

    return ret
end

function status.sensorsMAXMIN(sensors)

    if status.linkUP == true and status.theTIME ~= nil and status.idleupdelayParam ~= nil then

        -- hold back - to early to get a reading
        if status.theTIME <= status.idleupdelayParam then
            status.sensorVoltageMin = 0
            status.sensorVoltageMax = 0
            status.sensorFuelMin = 0
            status.sensorFuelMax = 0
            status.sensorRPMMin = 0
            status.sensorRPMMax = 0
            status.sensorCurrentMin = 0
            status.sensorCurrentMax = 0
            status.sensorRSSIMin = 0
            status.sensorRSSIMax = 0
            status.sensorTempESCMin = 0
            status.sensorTempMCUMax = 0
        end

        -- prob put in a screen/audio alert for initialising
        if status.theTIME >= 1 and status.theTIME < status.idleupdelayParam then end

        if status.theTIME >= status.idleupdelayParam then

            local idleupdelayOFFSET = 2

            -- record initial parameters for max/min
            if status.theTIME >= status.idleupdelayParam and status.theTIME <= (status.idleupdelayParam + idleupdelayOFFSET) then
                status.sensorVoltageMin = sensors.voltage
                status.sensorVoltageMax = sensors.voltage
                status.sensorFuelMin = sensors.fuel
                status.sensorFuelMax = sensors.fuel
                status.sensorRPMMin = sensors.rpm
                status.sensorRPMMax = sensors.rpm
                if sensors.current == 0 then
                    status.sensorCurrentMin = 1
                else
                    status.sensorCurrentMin = sensors.current
                end
                status.sensorCurrentMax = sensors.current

                status.sensorRSSIMin = sensors.rssi
                status.sensorRSSIMax = sensors.rssi
                status.sensorTempESCMin = sensors.temp_esc
                status.sensorTempESCMax = sensors.temp_esc
                status.sensorTempMCUMin = sensors.temp_mcu
                status.sensorTempMCUMax = sensors.temp_mcu

                motorNearlyActive = 0
            end

            if status.theTIME >= (status.idleupdelayParam + idleupdelayOFFSET) and status.idleupswitchParam:state() == true then

                if sensors.voltage < status.sensorVoltageMin then status.sensorVoltageMin = sensors.voltage end
                if sensors.voltage > status.sensorVoltageMax then status.sensorVoltageMax = sensors.voltage end

                if sensors.fuel < status.sensorFuelMin then status.sensorFuelMin = sensors.fuel end
                if sensors.fuel > status.sensorFuelMax then status.sensorFuelMax = sensors.fuel end

                if sensors.rpm < status.sensorRPMMin then status.sensorRPMMin = sensors.rpm end
                if sensors.rpm > status.sensorRPMMax then status.sensorRPMMax = sensors.rpm end
                if sensors.current < status.sensorCurrentMin then
                    status.sensorCurrentMin = sensors.current
                    if status.sensorCurrentMin == 0 then status.sensorCurrentMin = 1 end
                end
                if sensors.current > status.sensorCurrentMax then status.sensorCurrentMax = sensors.current end
                if sensors.rssi < status.sensorRSSIMin then status.sensorRSSIMin = sensors.rssi end
                if sensors.rssi > status.sensorRSSIMax then status.sensorRSSIMax = sensors.rssi end
                if sensors.temp_esc < status.sensorTempESCMin then status.sensorTempESCMin = sensors.temp_esc end
                if sensors.temp_esc > status.sensorTempESCMax then status.sensorTempESCMax = sensors.temp_esc end

                status.motorWasActive = true
            end

        end

        -- store the last values
        if status.motorWasActive and status.idleupswitchParam:state() == false then

            status.motorWasActive = false

            local maxminFinals = status.readHistory()

            if status.sensorCurrentMin == 0 then
                status.sensorCurrentMinAlt = 1
            else
                status.sensorCurrentMinAlt = status.sensorCurrentMin
            end
            if status.sensorCurrentMax == 0 then
                status.sensorCurrentMaxAlt = 1
            else
                status.sensorCurrentMaxAlt = status.sensorCurrentMax
            end

            local maxminRow = status.theTIME .. "," .. status.sensorVoltageMin .. "," .. status.sensorVoltageMax .. "," .. status.sensorFuelMin .. "," .. status.sensorFuelMax .. "," ..
                                  status.sensorRPMMin .. "," .. status.sensorRPMMax .. "," .. status.sensorCurrentMin .. "," .. status.sensorCurrentMax .. "," .. status.sensorRSSIMin .. "," ..
                                  status.sensorRSSIMax .. "," .. status.sensorTempMCUMin .. "," .. status.sensorTempMCUMax .. "," .. status.sensorTempESCMin .. "," .. status.sensorTempESCMax

            -- print("Last data: ".. maxminRow )

            table.insert(maxminFinals, 1, maxminRow)
            if tablelength(maxminFinals) >= 9 then table.remove(maxminFinals, 9) end

            name = string.gsub(model.name(), "%s+", "_")
            name = string.gsub(name, "%W", "_")

            local file = "widgets/status/logs/" .. name .. ".log"

            local f = io.open(file, 'w')
            f:write("")
            io.close(f)

            -- print("Writing history to: " .. file)

            local f = io.open(file, 'a')
            for k, v in ipairs(maxminFinals) do
                if v ~= nil then
                    v = v:gsub("%s+", "")
                    -- if v ~= "" then
                    -- print(v)
                    f:write(v .. "\n")
                    -- end
                end
            end
            io.close(f)

            status.readLOGS = false

        end

    else
        status.sensorVoltageMax = 0
        status.sensorVoltageMin = 0
        status.sensorFuelMin = 0
        status.sensorFuelMax = 0
        status.sensorRPMMin = 0
        status.sensorRPMMax = 0
        status.sensorCurrentMin = 0
        status.sensorCurrentMax = 0
        status.sensorTempESCMin = 0
        status.sensorTempESCMax = 0
    end

end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function print_r(arr, indentLevel)
    local str = ""
    local indentStr = "#"

    if (indentLevel == nil) then
        print(print_r(arr, 0))
        return
    end

    for i = 0, indentLevel do indentStr = indentStr .. "\t" end

    for index, value in ipairs(arr) do
        if type(value) == "table" then
            str = str .. indentStr .. index .. ": \n" .. print_r(value, (indentLevel + 1))
        else
            str = str .. indentStr .. index .. ": " .. value .. "\n"
        end
    end
    return str
end

function status.sensorMakeNumber(x)
    if x == nil or x == "" then x = 0 end

    x = string.gsub(x, "%D+", "")
    x = tonumber(x)
    if x == nil or x == "" then x = 0 end

    return x
end

function status.round(number, precision)
    local fmtStr = string.format("%%0.%sf", precision)
    number = string.format(fmtStr, number)
    number = tonumber(number)
    return number
end

function status.SecondsToClock(seconds)
    local seconds = tonumber(seconds)

    if seconds <= 0 then
        return "00:00:00"
    else
        hours = string.format("%02.f", math.floor(seconds / 3600))
        mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
        secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))
        return hours .. ":" .. mins .. ":" .. secs
    end
end

function status.SecondsToClockAlt(seconds)
    local seconds = tonumber(seconds)

    if seconds <= 0 then
        return "00:00"
    else
        hours = string.format("%02.f", math.floor(seconds / 3600))
        mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
        secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))
        return mins .. ":" .. secs
    end
end

function status.SecondsFromTime(seconds)
    local seconds = tonumber(seconds)

    if seconds <= 0 then
        return "0"
    else
        hours = string.format("%02.f", math.floor(seconds / 3600))
        mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
        secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))
        return tonumber(secs)
    end
end

function status.spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a, b)
            return order(t, a, b)
        end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then return keys[i], t[keys[i]] end
    end
end

function status.explode(inputstr, sep)
    if sep == nil then sep = "%s" end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do table.insert(t, str) end
    return t
end

function status.ReadLine(f, line)
    local i = 1 -- line counter
    for l in f:lines() do -- lines iterator, "l" returns the line
        if i == line then return l end -- we found this line, return it
        i = i + 1 -- counting lines
    end
    return "" -- Doesn't have that line
end

function status.readHistory()

    local history = {}
    -- print("Reading history")

    name = string.gsub(model.name(), "%s+", "_")
    name = string.gsub(name, "%W", "_")

    file = "widgets/status/logs/" .. name .. ".log"
    local f = io.open(file, "rb")

    if f ~= nil then
        -- file exists
        local rData
        c = 0
        tc = 1
        while c <= 10 do
            if c == 0 then
                rData = io.read(f, "l")
            else
                rData = io.read(f, "L")
            end
            if rData ~= "" or rData ~= nil then
                history[tc] = rData
                tc = tc + 1
            end
            c = c + 1
        end
        io.close(f)

    else
        return history
    end

    return history

end

function status.read()
    status.govmodeParam = storage.read("mem1")
    status.btypeParam = storage.read("mem2")
    status.lowfuelParam = storage.read("mem3")
    status.alertintParam = storage.read("mem4")
    alrthptParam = storage.read("mem5")
    status.maxminParam = storage.read("mem6")
    status.titleParam = storage.read("mem7")
    status.cellsParam = storage.read("mem8")
    status.announcementVoltageSwitchParam = storage.read("mem9")
    status.govmodeParam = storage.read("mem10")
    status.rpmAlertsParam = storage.read("mem11")
    status.rpmAlertsPercentageParam = storage.read("mem12")
    status.adjFunctionParam = storage.read("mem13") -- spare
    status.announcementRPMSwitchParam = storage.read("mem14")
    status.announcementCurrentSwitchParam = storage.read("mem15")
    status.announcementFuelSwitchParam = storage.read("mem16")
    status.announcementLQSwitchParam = storage.read("mem17")
    status.announcementESCSwitchParam = storage.read("mem18")
    status.announcementMCUSwitchParam = storage.read("mem19")
    status.announcementTimerSwitchParam = storage.read("mem20")
    status.filteringParam = storage.read("mem21")
    status.sagParam = storage.read("mem22")
    status.lowvoltagsenseParam = storage.read("mem23")
    status.announcementIntervalParam = storage.read("mem24")
    status.lowVoltageGovernorParam = storage.read("mem25")
    status.lowvoltagStickParam = storage.read("mem26")
    status.quadBoxParam = storage.read("mem27")
    status.lowvoltagStickCutoffParam = storage.read("mem28")
    status.governorUNKNOWNParam = storage.read("mem29")
    status.governorDISARMEDParam = storage.read("mem30")
    status.governorDISABLEDParam = storage.read("mem31")
    status.governorBAILOUTParam = storage.read("mem32")
    status.governorAUTOROTParam = storage.read("mem33")
    status.governorLOSTHSParam = storage.read("mem34")
    status.governorTHROFFParam = storage.read("mem35")
    status.governorACTIVEParam = storage.read("mem36")
    status.governorRECOVERYParam = storage.read("mem37")
    status.governorSPOOLUPParam = storage.read("mem38")
    status.governorIDLEParam = storage.read("mem39")
    status.governorOFFParam = storage.read("mem40")
    status.alertonParam = storage.read("mem41")
    status.calcfuelParam = storage.read("mem42")
    status.tempconvertParamESC = storage.read("mem43")
    status.tempconvertParamMCU = storage.read("mem44")
    status.idleupswitchParam = storage.read("mem45")
    armswitchParam = storage.read("mem46")
    status.idleupdelayParam = storage.read("mem47")
    status.switchIdlelowParam = storage.read("mem48")
    status.switchIdlemediumParam = storage.read("mem49")
    status.switchIdlehighParam = storage.read("mem50")
    status.switchrateslowParam = storage.read("mem51")
    status.switchratesmediumParam = storage.read("mem52")
    status.switchrateshighParam = storage.read("mem53")
    status.switchrescueonParam = storage.read("mem54")
    status.switchrescueoffParam = storage.read("mem55")
    status.switchbblonParam = storage.read("mem56")
    status.switchbbloffParam = storage.read("mem57")
    status.layoutBox1Param = storage.read("mem58")
    status.layoutBox2Param = storage.read("mem59")
    status.layoutBox3Param = storage.read("mem60")
    status.layoutBox4Param = storage.read("mem61")
    status.layoutBox5Param = storage.read("mem62")
    status.layoutBox6Param = storage.read("mem63")
    status.timeralarmVibrateParam = storage.read("mem64")
    status.timeralarmParam = storage.read("mem65")
    status.statusColorParam = storage.read("mem66")
    status.maxCellVoltage = storage.read("mem67")
    status.fullCellVoltage = storage.read("mem68")
    status.minCellVoltage = storage.read("mem69")
    status.warnCellVoltage = storage.read("mem79")
    status.customSensorParam1 = storage.read("mem80")
    status.customSensorParam2 = storage.read("mem81")

    if status.statusColorParam == nil then status.statusColorParam = 2 end

    if status.alertonParam == nil then status.alertonParam = 2 end

    if status.maxCellVoltage == nil then status.maxCellVoltage = 430 end
    if status.fullCellVoltage == nil then status.fullCellVoltage = 410 end
    if status.minCellVoltage == nil then status.minCellVoltage = 330 end
    if status.warnCellVoltage == nil then status.warnCellVoltage = 350 end

    if status.layoutBox1Param == nil then status.layoutBox1Param = 11 end
    if status.layoutBox2Param == nil then status.layoutBox2Param = 2 end
    if status.layoutBox3Param == nil then status.layoutBox3Param = 3 end
    if status.layoutBox4Param == nil then status.layoutBox4Param = 12 end
    if status.layoutBox5Param == nil then status.layoutBox5Param = 4 end
    if status.layoutBox6Param == nil then status.layoutBox6Param = 5 end

    status.resetALL()

end

function status.write()
    storage.write("mem1", status.govmodeParam)
    storage.write("mem2", status.btypeParam)
    storage.write("mem3", status.lowfuelParam)
    storage.write("mem4", status.alertintParam)
    storage.write("mem5", alrthptParam)
    storage.write("mem6", status.maxminParam)
    storage.write("mem7", status.titleParam)
    storage.write("mem8", status.cellsParam)
    storage.write("mem9", status.announcementVoltageSwitchParam)
    storage.write("mem10", status.govmodeParam)
    storage.write("mem11", status.rpmAlertsParam)
    storage.write("mem12", status.rpmAlertsPercentageParam)
    storage.write("mem13", status.adjFunctionParam) -- spare
    storage.write("mem14", status.announcementRPMSwitchParam)
    storage.write("mem15", status.announcementCurrentSwitchParam)
    storage.write("mem16", status.announcementFuelSwitchParam)
    storage.write("mem17", status.announcementLQSwitchParam)
    storage.write("mem18", status.announcementESCSwitchParam)
    storage.write("mem19", status.announcementMCUSwitchParam)
    storage.write("mem20", status.announcementTimerSwitchParam)
    storage.write("mem21", status.filteringParam)
    storage.write("mem22", status.sagParam)
    storage.write("mem23", status.lowvoltagsenseParam)
    storage.write("mem24", status.announcementIntervalParam)
    storage.write("mem25", status.lowVoltageGovernorParam)
    storage.write("mem26", status.lowvoltagStickParam)
    storage.write("mem27", status.quadBoxParam)
    storage.write("mem28", status.lowvoltagStickCutoffParam)
    storage.write("mem29", status.governorUNKNOWNParam)
    storage.write("mem30", status.governorDISARMEDParam)
    storage.write("mem31", status.governorDISABLEDParam)
    storage.write("mem32", status.governorBAILOUTParam)
    storage.write("mem33", status.governorAUTOROTParam)
    storage.write("mem34", status.governorLOSTHSParam)
    storage.write("mem35", status.governorTHROFFParam)
    storage.write("mem36", status.governorACTIVEParam)
    storage.write("mem37", status.governorRECOVERYParam)
    storage.write("mem38", status.governorSPOOLUPParam)
    storage.write("mem39", status.governorIDLEParam)
    storage.write("mem40", status.governorOFFParam)
    storage.write("mem41", status.alertonParam)
    storage.write("mem42", status.calcfuelParam)
    storage.write("mem43", status.tempconvertParamESC)
    storage.write("mem44", status.tempconvertParamMCU)
    storage.write("mem45", status.idleupswitchParam)
    storage.write("mem46", armswitchParam)
    storage.write("mem47", status.idleupdelayParam)
    storage.write("mem48", status.switchIdlelowParam)
    storage.write("mem49", status.switchIdlemediumParam)
    storage.write("mem50", status.switchIdlehighParam)
    storage.write("mem51", status.switchrateslowParam)
    storage.write("mem52", status.switchratesmediumParam)
    storage.write("mem53", status.switchrateshighParam)
    storage.write("mem54", status.switchrescueonParam)
    storage.write("mem55", status.switchrescueoffParam)
    storage.write("mem56", status.switchbblonParam)
    storage.write("mem57", status.switchbbloffParam)
    storage.write("mem58", status.layoutBox1Param)
    storage.write("mem59", status.layoutBox2Param)
    storage.write("mem60", status.layoutBox3Param)
    storage.write("mem61", status.layoutBox4Param)
    storage.write("mem62", status.layoutBox5Param)
    storage.write("mem63", status.layoutBox6Param)
    storage.write("mem64", status.timeralarmVibrateParam)
    storage.write("mem65", status.timeralarmParam)
    storage.write("mem66", status.statusColorParam)
    storage.write("mem67", status.maxCellVoltage)
    storage.write("mem68", status.fullCellVoltage)
    storage.write("mem69", status.minCellVoltage)
    storage.write("mem79", status.warnCellVoltage)
    storage.write("mem80", status.customSensorParam1)
    storage.write("mem81", status.customSensorParam1)

end

function status.playCurrent(widget)
    if status.announcementCurrentSwitchParam ~= nil then
        if status.announcementCurrentSwitchParam:state() then
            status.currenttime.currentannouncementTimer = true
            currentDoneFirst = false
        else
            status.currenttime.currentannouncementTimer = false
            currentDoneFirst = true
        end

        if status.isInConfiguration == false then
            if status.sensors.current ~= nil then
                if status.currenttime.currentannouncementTimer == true then
                    -- start timer
                    if status.currenttime.currentannouncementTimerStart == nil and currentDoneFirst == false then
                        status.currenttime.currentannouncementTimerStart = os.time()
                        status.currenttime.currentaudioannouncementCounter = os.clock()
                        -- print ("Play Current Alert (first)")
                        system.playNumber(status.sensors.current / 10, UNIT_AMPERE, 2)
                        currentDoneFirst = true
                    end
                else
                    status.currenttime.currentannouncementTimerStart = nil
                end

                if status.currenttime.currentannouncementTimerStart ~= nil then
                    if currentDoneFirst == false then
                        if ((tonumber(os.clock()) - tonumber(status.currenttime.currentaudioannouncementCounter)) >= status.announcementIntervalParam) then
                            -- print ("Play Current Alert (repeat)")
                            status.currenttime.currentaudioannouncementCounter = os.clock()
                            system.playNumber(status.sensors.current / 10, UNIT_AMPERE, 2)
                        end
                    end
                else
                    -- stop timer
                    status.currenttime.currentannouncementTimerStart = nil
                end
            end
        end
    end
end

function status.playLQ(widget)
    if status.announcementLQSwitchParam ~= nil then
        if status.announcementLQSwitchParam:state() then
            status.lqtime.lqannouncementTimer = true
            lqDoneFirst = false
        else
            status.lqtime.lqannouncementTimer = false
            lqDoneFirst = true
        end

        if status.isInConfiguration == false then
            if status.sensors.rssi ~= nil then
                if status.lqtime.lqannouncementTimer == true then
                    -- start timer
                    if status.lqtime.lqannouncementTimerStart == nil and lqDoneFirst == false then
                        status.lqtime.lqannouncementTimerStart = os.time()
                        status.lqtime.lqaudioannouncementCounter = os.clock()
                        -- print ("Play LQ Alert (first)")
                        rfsuite.utils.playFile("status","alerts/lq.wav")
                        system.playNumber(status.sensors.rssi, UNIT_PERCENT, 2)
                        lqDoneFirst = true
                    end
                else
                    status.lqtime.lqannouncementTimerStart = nil
                end

                if status.lqtime.lqannouncementTimerStart ~= nil then
                    if lqDoneFirst == false then
                        if ((tonumber(os.clock()) - tonumber(status.lqtime.lqaudioannouncementCounter)) >= status.announcementIntervalParam) then
                            status.lqtime.lqaudioannouncementCounter = os.clock()
                            -- print ("Play LQ Alert (repeat)")
                            rfsuite.utils.playFile("status","alerts/lq.wav")
                            system.playNumber(status.sensors.rssi, UNIT_PERCENT, 2)
                        end
                    end
                else
                    -- stop timer
                    status.lqtime.lqannouncementTimerStart = nil
                end
            end
        end
    end
end

function status.playMCU(widget)
    if status.announcementMCUSwitchParam ~= nil then
        if status.announcementMCUSwitchParam:state() then
            status.mcutime.mcuannouncementTimer = true
            mcuDoneFirst = false
        else
            status.mcutime.mcuannouncementTimer = false
            mcuDoneFirst = true
        end

        if status.isInConfiguration == false then
            if status.sensors.temp_mcu ~= nil then
                if status.mcutime.mcuannouncementTimer == true then
                    -- start timer
                    if status.mcutime.mcuannouncementTimerStart == nil and mcuDoneFirst == false then
                        status.mcutime.mcuannouncementTimerStart = os.time()
                        status.mcutime.mcuaudioannouncementCounter = os.clock()
                        -- print ("Playing MCU (first)")
                        rfsuite.utils.playFile("status","alerts/mcu.wav")
                        system.playNumber(status.sensors.temp_mcu / 100, UNIT_DEGREE, 2)
                        mcuDoneFirst = true
                    end
                else
                    status.mcutime.mcuannouncementTimerStart = nil
                end

                if status.mcutime.mcuannouncementTimerStart ~= nil then
                    if mcuDoneFirst == false then
                        if ((tonumber(os.clock()) - tonumber(status.mcutime.mcuaudioannouncementCounter)) >= status.announcementIntervalParam) then
                            status.mcutime.mcuaudioannouncementCounter = os.clock()
                            -- print ("Playing MCU (repeat)")
                            rfsuite.utils.playFile("status","alerts/mcu.wav")
                            system.playNumber(status.sensors.temp_mcu / 100, UNIT_DEGREE, 2)
                        end
                    end
                else
                    -- stop timer
                    status.mcutime.mcuannouncementTimerStart = nil
                end
            end
        end
    end
end

function status.playESC(widget)
    if status.announcementESCSwitchParam ~= nil then
        if status.announcementESCSwitchParam:state() then
            status.esctime.escannouncementTimer = true
            escDoneFirst = false
        else
            status.esctime.escannouncementTimer = false
            escDoneFirst = true
        end

        if status.isInConfiguration == false then
            if status.sensors.temp_esc ~= nil then
                if status.esctime.escannouncementTimer == true then
                    -- start timer
                    if status.esctime.escannouncementTimerStart == nil and escDoneFirst == false then
                        status.esctime.escannouncementTimerStart = os.time()
                        status.esctime.escaudioannouncementCounter = os.clock()
                        -- print ("Playing ESC (first)")
                        rfsuite.utils.playFile("status","alerts/esc.wav")
                        system.playNumber(status.sensors.temp_esc / 100, UNIT_DEGREE, 2)
                        escDoneFirst = true
                    end
                else
                    status.esctime.escannouncementTimerStart = nil
                end

                if status.esctime.escannouncementTimerStart ~= nil then
                    if escDoneFirst == false then
                        if ((tonumber(os.clock()) - tonumber(status.esctime.escaudioannouncementCounter)) >= status.announcementIntervalParam) then
                            status.esctime.escaudioannouncementCounter = os.clock()
                            -- print ("Playing ESC (repeat)")
                            rfsuite.utils.playFile("status","alerts/esc.wav")
                            system.playNumber(status.sensors.temp_esc / 100, UNIT_DEGREE, 2)
                        end
                    end
                else
                    -- stop timer
                    status.esctime.escannouncementTimerStart = nil
                end
            end
        end
    end
end

function status.playTIMERALARM(widget)
    if status.theTIME ~= nil and status.timeralarmParam ~= nil and status.timeralarmParam ~= 0 then

        -- reset timer Delay
        if status.theTIME > status.timeralarmParam + 2 then status.timerAlarmPlay = true end
        -- trigger first timer
        if status.timerAlarmPlay == true then
            if status.theTIME >= status.timeralarmParam and status.theTIME <= status.timeralarmParam + 1 then

                rfsuite.utils.playFileCommon("alarm.wav")

                hours = string.format("%02.f", math.floor(status.theTIME / 3600))
                mins = string.format("%02.f", math.floor(status.theTIME / 60 - (hours * 60)))
                secs = string.format("%02.f", math.floor(status.theTIME - hours * 3600 - mins * 60))

                rfsuite.utils.playFile("status","alerts/timer.wav")
                if mins ~= "00" then system.playNumber(mins, UNIT_MINUTE, 2) end
                system.playNumber(secs, UNIT_SECOND, 2)

                if status.timeralarmVibrateParam == true then system.playHaptic("- - -") end

                status.timerAlarmPlay = false
            end
        end

    end
end

function status.playTIMER(widget)
    if status.announcementTimerSwitchParam ~= nil then

        if status.announcementTimerSwitchParam:state() then
            status.timetime.timerannouncementTimer = true
            timerDoneFirst = false
        else
            status.timetime.timerannouncementTimer = false
            timerDoneFirst = true
        end

        if status.isInConfiguration == false then

            if status.theTIME == nil then
                alertTIME = 0
            else
                alertTIME = status.theTIME
            end

            if alertTIME ~= nil then

                hours = string.format("%02.f", math.floor(alertTIME / 3600))
                mins = string.format("%02.f", math.floor(alertTIME / 60 - (hours * 60)))
                secs = string.format("%02.f", math.floor(alertTIME - hours * 3600 - mins * 60))

                if status.timetime.timerannouncementTimer == true then
                    -- start timer
                    if status.timetime.timerannouncementTimerStart == nil and timerDoneFirst == false then
                        status.timetime.timerannouncementTimerStart = os.time()
                        status.timetime.timeraudioannouncementCounter = os.clock()
                        -- print ("Playing TIMER (first)" .. alertTIME)

                        if mins ~= "00" then system.playNumber(mins, UNIT_MINUTE, 2) end
                        system.playNumber(secs, UNIT_SECOND, 2)

                        timerDoneFirst = true
                    end
                else
                    status.timetime.timerannouncementTimerStart = nil
                end

                if status.timetime.timerannouncementTimerStart ~= nil then
                    if timerDoneFirst == false then
                        if ((tonumber(os.clock()) - tonumber(status.timetime.timeraudioannouncementCounter)) >= status.announcementIntervalParam) then
                            status.timetime.timeraudioannouncementCounter = os.clock()
                            -- print ("Playing TIMER (repeat)" .. alertTIME)
                            if mins ~= "00" then system.playNumber(mins, UNIT_MINUTE, 2) end
                            system.playNumber(secs, UNIT_SECOND, 2)
                        end
                    end
                else
                    -- stop timer
                    status.timetime.timerannouncementTimerStart = nil
                end
            end
        end
    end
end

function status.playFuel(widget)
    if status.announcementFuelSwitchParam ~= nil then
        if status.announcementFuelSwitchParam:state() then
            status.fueltime.fuelannouncementTimer = true
            fuelDoneFirst = false
        else
            status.fueltime.fuelannouncementTimer = false
            fuelDoneFirst = true
        end

        if status.isInConfiguration == false then
            if status.sensors.fuel ~= nil then
                if status.fueltime.fuelannouncementTimer == true then
                    -- start timer
                    if status.fueltime.fuelannouncementTimerStart == nil and fuelDoneFirst == false then
                        status.fueltime.fuelannouncementTimerStart = os.time()
                        status.fueltime.fuelaudioannouncementCounter = os.clock()
                        -- print("Play fuel alert (first)")
                        rfsuite.utils.playFile("status","alerts/fuel.wav")
                        system.playNumber(status.sensors.fuel, UNIT_PERCENT, 2)
                        fuelDoneFirst = true
                    end
                else
                    status.fueltime.fuelannouncementTimerStart = nil
                end

                if status.fueltime.fuelannouncementTimerStart ~= nil then
                    if fuelDoneFirst == false then
                        if ((tonumber(os.clock()) - tonumber(status.fueltime.fuelaudioannouncementCounter)) >= status.announcementIntervalParam) then
                            status.fueltime.fuelaudioannouncementCounter = os.clock()
                            -- print("Play fuel alert (repeat)")
                            rfsuite.utils.playFile("status","alerts/fuel.wav")
                            system.playNumber(status.sensors.fuel, UNIT_PERCENT, 2)

                        end
                    end
                else
                    -- stop timer
                    status.fueltime.fuelannouncementTimerStart = nil
                end
            end
        end
    end
end

function status.playRPM(widget)
    if status.announcementRPMSwitchParam ~= nil then
        if status.announcementRPMSwitchParam:state() then
            status.rpmtime.announcementTimer = true
            rpmDoneFirst = false
        else
            status.rpmtime.announcementTimer = false
            rpmDoneFirst = true
        end

        if status.isInConfiguration == false then
            if status.sensors.rpm ~= nil then
                if status.rpmtime.announcementTimer == true then
                    -- start timer
                    if status.rpmtime.announcementTimerStart == nil and rpmDoneFirst == false then
                        status.rpmtime.announcementTimerStart = os.time()
                        status.rpmtime.audioannouncementCounter = os.clock()
                        -- print("Play rpm alert (first)")
                        system.playNumber(status.sensors.rpm, UNIT_RPM, 2)
                        rpmDoneFirst = true
                    end
                else
                    status.rpmtime.announcementTimerStart = nil
                end

                if status.rpmtime.announcementTimerStart ~= nil then
                    if rpmDoneFirst == false then
                        if ((tonumber(os.clock()) - tonumber(status.rpmtime.audioannouncementCounter)) >= status.announcementIntervalParam) then
                            -- print("Play rpm alert (repeat)")
                            status.rpmtime.audioannouncementCounter = os.clock()
                            system.playNumber(status.sensors.rpm, UNIT_RPM, 2)
                        end
                    end
                else
                    -- stop timer
                    status.rpmtime.announcementTimerStart = nil
                end
            end
        end
    end
end

function status.playVoltage(widget)
    if status.announcementVoltageSwitchParam ~= nil then
        if status.announcementVoltageSwitchParam:state() then
            status.lvannouncementTimer = true
            voltageDoneFirst = false
        else
            status.lvannouncementTimer = false
            voltageDoneFirst = true
        end

        if status.isInConfiguration == false then
            if status.sensors.voltage ~= nil then
                if status.lvannouncementTimer == true then
                    -- start timer
                    if status.lvannouncementTimerStart == nil and voltageDoneFirst == false then
                        status.lvannouncementTimerStart = os.time()
                        status.lvaudioannouncementCounter = os.clock()
                        -- print("Play voltage alert (first)")                       
                        system.playNumber(status.sensors.voltage / 100, 2, 2)
                        voltageDoneFirst = true
                    end
                else
                    status.lvannouncementTimerStart = nil
                end

                if status.lvannouncementTimerStart ~= nil then
                    if voltageDoneFirst == false then
                        if status.lvaudioannouncementCounter ~= nil and status.announcementIntervalParam ~= nil then
                            if ((tonumber(os.clock()) - tonumber(status.lvaudioannouncementCounter)) >= status.announcementIntervalParam) then
                                status.lvaudioannouncementCounter = os.clock()
                                -- print("Play voltage alert (repeat)")                             
                                system.playNumber(status.sensors.voltage / 100, 2, 2)
                            end
                        end
                    end
                else
                    -- stop timer
                    status.lvannouncementTimerStart = nil
                end
            end
        end
    end
end

function status.event(widget, category, value, x, y)

    -- print("Event received:", category, value, x, y)

    if closingLOGS then
        if category == EVT_TOUCH and (value == 16640 or value == 16641) then
            closingLOGS = false
            -- collectgarbage()
            return true
        end

    end

    if status.showLOGS then
        if value == 35 then status.showLOGS = false end

        if category == EVT_TOUCH and (value == 16640 or value == 16641) then
            if (x >= (status.closeButtonX) and (x <= (status.closeButtonX + status.closeButtonW))) and (y >= (status.closeButtonY) and (y <= (status.closeButtonY + status.closeButtonH))) then
                status.showLOGS = false
                closingLOGS = true
            end
            return true
        else
            if category == EVT_TOUCH then return true end
        end

    end

end

function status.playGovernor()
    if status.governorAlertsParam == true then
        if status.playGovernorLastState == nil then status.playGovernorLastState = status.sensors.govmode end

        if status.sensors.govmode ~= status.playGovernorLastState then
            status.playGovernorCount = 0
            status.playGovernorLastState = status.sensors.govmode
        end

        if status.playGovernorCount == 0 then
            -- print("Governor: " .. status.sensors.govmode)
            status.playGovernorCount = 1

            if status.sensors.govmode == "UNKNOWN" and status.governorUNKNOWNParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/unknown.wav")
            end
            if status.sensors.govmode == "DISARMED" and status.governorDISARMEDParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/disarmed.wav")
            end
            if status.sensors.govmode == "DISABLED" and status.governorDISABLEDParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/disabled.wav")
            end
            if status.sensors.govmode == "BAILOUT" and status.governorBAILOUTParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/bailout.wav")
            end
            if status.sensors.govmode == "AUTOROT" and status.governorAUTOROTParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/autorot.wav")
            end
            if status.sensors.govmode == "LOST-HS" and status.governorLOSTHSParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/lost-hs.wav")
            end
            if status.sensors.govmode == "THR-OFF" and status.governorTHROFFParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/thr-off.wav")
            end
            if status.sensors.govmode == "ACTIVE" and status.governorACTIVEParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/active.wav")
            end
            if status.sensors.govmode == "RECOVERY" and status.governorRECOVERYParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/recovery.wav")
            end
            if status.sensors.govmode == "SPOOLUP" and status.governorSPOOLUPParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/spoolup.wav")
            end
            if status.sensors.govmode == "IDLE" and status.governorIDLEParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/idle.wav")
            end
            if status.sensors.govmode == "OFF" and status.governorOFFParam == true then
                if status.govmodeParam == 0 then rfsuite.utils.playFile("status","events/governor.wav") end
                rfsuite.utils.playFile("status","events/off.wav")
            end

        end

    end
end

function status.playRPMDiff()
    if status.rpmAlertsParam == true then

        if status.sensors.govmode == "ACTIVE" or status.sensors.govmode == "LOST-HS" or status.sensors.govmode == "BAILOUT" or status.sensors.govmode == "RECOVERY" then

            if status.playrpmdiff.playRPMDiffLastState == nil then status.playrpmdiff.playRPMDiffLastState = status.sensors.rpm end

            -- we take a reading every 5 second
            if (tonumber(os.clock()) - tonumber(status.playrpmdiff.playRPMDiffCounter)) >= 5 then
                status.playrpmdiff.playRPMDiffCounter = os.clock()
                status.playrpmdiff.playRPMDiffLastState = status.sensors.rpm
            end

            -- check if current state withing % of last state
            local percentageDiff = 0
            if status.sensors.rpm > status.playrpmdiff.playRPMDiffLastState then
                percentageDiff = math.abs(100 - (status.sensors.rpm / status.playrpmdiff.playRPMDiffLastState * 100))
            elseif status.playrpmdiff.playRPMDiffLastState < status.sensors.rpm then
                percentage = math.abs(100 - (status.playrpmdiff.playRPMDiffLastState / status.sensors.rpm * 100))
            else
                percentageDiff = 0
            end

            if percentageDiff > status.rpmAlertsPercentageParam / 10 then status.playrpmdiff.playRPMDiffCount = 0 end

            if status.playrpmdiff.playRPMDiffCount == 0 then
                -- print("RPM Difference: " .. percentageDiff)
                status.playrpmdiff.playRPMDiffCount = 1
                system.playNumber(status.sensors.rpm, UNIT_RPM, 2)
            end
        end
    end
end

-- MAIN WAKEUP FUNCTION. THIS SIMPLY FARMS OUT AT DIFFERING SCHEDULES TO SUB FUNCTIONS
function status.wakeup(widget)

    local schedulerUI
    if lcd.isVisible() then
        schedulerUI = 0.25
    else
        schedulerUI = 1
    end

    -- keep cpu load down by running UI at reduced interval
    local now = os.clock()
    if (now - status.wakeupSchedulerUI) >= schedulerUI then
        status.wakeupSchedulerUI = now
        status.wakeupUI()
        -- collectgarbage()
    end

end

function status.wakeupUI(widget)

    if not rfsuite.bg.active() then
        voltageSOURCE = nil
        rpmSOURCE = nil
        currentSOURCE = nil
        temp_escSOURCE = nil
        temp_mcuSOURCE = nil
        fuelSOURCE = nil
        adjSOURCE = nil
        adjVALUE = nil
        adjvSOURCE = nil
        mahSOURCE = nil
        rssiSOURCE = nil
        govSOURCE = nil
        lcd.invalidate()
        status.linkUPTime = nil
        return
    else

        status.refresh = false

        status.linkUP = rfsuite.bg.telemetry.active()
        status.sensors = status.getSensors()

        if status.refresh == true then
            status.sensorsMAXMIN(status.sensors)
            lcd.invalidate()
        end

        if status.linkUP == false then status.linkUPTime = os.clock() end

        if status.linkUP == true then

            if status.linkUPTime ~= nil and ((tonumber(os.clock()) - tonumber(status.linkUPTime)) >= 5) then
                -- voltage alerts
                status.playVoltage(widget)
                -- governor callouts
                status.playGovernor(widget)
                -- rpm diff
                status.playRPMDiff(widget)
                -- rpm
                status.playRPM(widget)
                -- current
                status.playCurrent(widget)
                -- fuel
                status.playFuel(widget)
                -- lq
                status.playLQ(widget)
                -- esc
                status.playESC(widget)
                -- mcu
                status.playMCU(widget)
                -- timer
                status.playTIMER(widget)
                -- timer alarm
                status.playTIMERALARM(widget)

                if status.linkUPTime == nil then status.linkUPTime = 0 end

                if ((tonumber(os.clock()) - tonumber(status.linkUPTime)) >= 10) then

                    -- IDLE
                    if status.switchIdlelowParam ~= nil and status.switchIdlelowParam:state() == true then
                        if status.switchstatus.idlelow == nil or status.switchstatus.idlelow == false then
                            rfsuite.utils.playFile("status","switches/idle-l.wav")
                            status.switchstatus.idlelow = true
                            status.switchstatus.idlemedium = false
                            status.switchstatus.idlehigh = false
                        end
                    else
                        status.switchstatus.idlelow = false
                    end
                    if status.switchIdlemediumParam ~= nil and status.switchIdlemediumParam:state() == true then
                        if status.switchstatus.idlemedium == nil or status.switchstatus.idlemedium == false then
                            rfsuite.utils.playFile("status","switches/idle-m.wav")
                            status.switchstatus.idlelow = false
                            status.switchstatus.idlemedium = true
                            status.switchstatus.idlehigh = false
                        end
                    else
                        status.switchstatus.idlemedium = false
                    end
                    if status.switchIdlehighParam ~= nil and status.switchIdlehighParam:state() == true then
                        if status.switchstatus.idlehigh == nil or status.switchstatus.idlehigh == false then
                            rfsuite.utils.playFile("status","switches/idle-h.wav")
                            status.switchstatus.idlelow = false
                            status.switchstatus.idlemedium = false
                            status.switchstatus.idlehigh = true
                        end
                    else
                        status.switchstatus.idlehigh = false
                    end

                    -- RATES
                    if status.switchrateslowParam ~= nil and status.switchrateslowParam:state() == true then
                        if status.switchstatus.rateslow == nil or status.switchstatus.rateslow == false then
                            rfsuite.utils.playFile("status","switches/rates-l.wav")
                            status.switchstatus.rateslow = true
                            status.switchstatus.ratesmedium = false
                            status.switchstatus.rateshigh = false
                        end
                    else
                        status.switchstatus.rateslow = false
                    end
                    if status.switchratesmediumParam ~= nil and status.switchratesmediumParam:state() == true then
                        if status.switchstatus.ratesmedium == nil or status.switchstatus.ratesmedium == false then
                            rfsuite.utils.playFile("status","switches/rates-m.wav")
                            status.switchstatus.rateslow = false
                            status.switchstatus.ratesmedium = true
                            status.switchstatus.rateshigh = false
                        end
                    else
                        status.switchstatus.ratesmedium = false
                    end
                    if status.switchrateshighParam ~= nil and status.switchrateshighParam:state() == true then
                        if status.switchstatus.rateshigh == nil or status.switchstatus.rateshigh == false then
                            rfsuite.utils.playFile("status","switches/rates-h.wav")
                            status.switchstatus.rateslow = false
                            status.switchstatus.ratesmedium = false
                            status.switchstatus.rateshigh = true
                        end
                    else
                        status.switchstatus.rateshigh = false
                    end

                    -- RESCUE
                    if status.switchrescueonParam ~= nil and status.switchrescueonParam:state() == true then
                        if status.switchstatus.rescueon == nil or status.switchstatus.rescueon == false then
                            rfsuite.utils.playFile("status","switches/rescue-on.wav")
                            status.switchstatus.rescueon = true
                            status.switchstatus.rescueoff = false
                        end
                    else
                        status.switchstatus.rescueon = false
                    end
                    if status.switchrescueoffParam ~= nil and status.switchrescueoffParam:state() == true then
                        if status.switchstatus.rescueoff == nil or status.switchstatus.rescueoff == false then
                            rfsuite.utils.playFile("status","switches/rescue-off.wav")
                            status.switchstatus.rescueon = false
                            status.switchstatus.rescueoff = true
                        end
                    else
                        status.switchstatus.rescueoff = false
                    end

                    -- BBL
                    if status.switchbblonParam ~= nil and status.switchbblonParam:state() == true then
                        if status.switchstatus.bblon == nil or status.switchstatus.bblon == false then
                            rfsuite.utils.playFile("status","switches/bbl-on.wav")
                            status.switchstatus.bblon = true
                            status.switchstatus.bbloff = false
                        end
                    else
                        status.switchstatus.bblon = false
                    end
                    if status.switchbbloffParam ~= nil and status.switchbbloffParam:state() == true then
                        if status.switchstatus.bbloff == nil or status.switchstatus.bbloff == false then
                            rfsuite.utils.playFile("status","switches/bbl-off.wav")
                            status.switchstatus.bblon = false
                            status.switchstatus.bbloff = true
                        end
                    else
                        status.switchstatus.bbloff = false
                    end

                end

                ---
                -- TIME
                if status.linkUP == true then
                    if armswitchParam ~= nil then
                        if armswitchParam:state() == false then
                            status.stopTimer = true
                            stopTIME = os.clock()
                            timerNearlyActive = 1
                            status.theTIME = 0
                        end
                    end

                    if status.idleupswitchParam ~= nil then
                        if status.idleupswitchParam:state() then
                            if timerNearlyActive == 1 then
                                timerNearlyActive = 0
                                startTIME = os.clock()
                            end
                            if startTIME ~= nil then status.theTIME = os.clock() - startTIME end
                        end
                    end

                end

                -- LOW FUEL ALERTS
                -- big conditional to announcement status.lfTimer if needed
                if status.linkUP == true then
                    if status.idleupswitchParam ~= nil then
                        if status.idleupswitchParam:state() then

                            if (status.sensors.fuel <= status.lowfuelParam and status.alertonParam == 1) then
                                status.lfTimer = true
                            elseif (status.sensors.fuel <= status.lowfuelParam and status.alertonParam == 2) then
                                status.lfTimer = true
                            else
                                status.lfTimer = false
                            end
                        else
                            status.lfTimer = false
                        end
                    else
                        status.lfTimer = false
                    end
                else
                    status.lfTimer = false
                end

                if status.lfTimer == true then
                    -- start timer
                    if status.lfTimerStart == nil then status.lfTimerStart = os.time() end
                else
                    status.lfTimerStart = nil
                end

                if status.lfTimerStart ~= nil then
                    -- only announcement if we have been on for 5 seconds or more
                    if (tonumber(os.clock()) - tonumber(status.lfAudioAlertCounter)) >= status.alertintParam then
                        status.lfAudioAlertCounter = os.clock()

                        if status.sensors.fuel >= 10 then
                            rfsuite.utils.playFile("status","alerts/lowfuel.wav")

                            -- system.playNumber(status.sensors.voltage / 100, 2, 2)
                            if alrthptParam == true then system.playHaptic("- . -") end
                        end
                    end
                else
                    -- stop timer
                    status.lfTimerStart = nil
                end

                -- LOW VOLTAGE ALERTS
                -- big conditional to announcement status.lvTimer if needed
                if status.linkUP == true then

                    if status.idleupswitchParam ~= nil then
                        if status.idleupswitchParam:state() then
                            if (status.voltageIsLow and status.alertonParam == 0) then
                                status.lvTimer = true
                            elseif (status.voltageIsLow and status.alertonParam == 2) then
                                status.lvTimer = true
                            else
                                status.lvTimer = false
                            end
                        else
                            status.lvTimer = false
                        end
                    else
                        status.lvTimer = false
                    end
                else
                    status.lvTimer = false
                end

                if status.lvTimer == true then
                    -- start timer
                    if status.lvTimerStart == nil then status.lvTimerStart = os.time() end
                else
                    status.lvTimerStart = nil
                end

                if status.lvTimerStart ~= nil then
                    if (os.time() - status.lvTimerStart >= status.sagParam) then
                        -- only announcement if we have been on for 5 seconds or more
                        if (tonumber(os.clock()) - tonumber(status.lvAudioAlertCounter)) >= status.alertintParam then
                            status.lvAudioAlertCounter = os.clock()

                            if status.lvStickannouncement == false and status.voltageIsLowAlert == true then -- do not play if sticks at high end points
                                rfsuite.utils.playFile("status","alerts/lowvoltage.wav")
                                -- system.playNumber(status.sensors.voltage / 100, 2, 2)
                                if alrthptParam == true then system.playHaptic("- . -") end
                            else
                                -- print("Alarm supressed due to stick positions")
                            end

                        end
                    end
                else
                    -- stop timer
                    status.lvTimerStart = nil
                end
                ---

            else
                status.adjJUSTUP = true
            end
        end

    end
    return
end

function status.viewLogs()
    status.showLOGS = true
end

function status.menu(widget)

    return {
        {
            "View logs", function()
                status.viewLogs()
            end
        }
    }

end

return status
