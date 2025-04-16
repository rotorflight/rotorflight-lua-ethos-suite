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

]] --
local status = {}

local arg = {...}

local environment = system.getVersion()


local i18n = rfsuite.i18n

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
playGovernorCount = 0
playGovernorLastState = nil
playRPMdiff = {}
playRPMdiff.playRPMDiffCount = 1
playRPMdiff.playRPMDiffLastState = nil
playRPMdiff.playRPMDiffCounter = 0
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
status.sensorwarningParam = true
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
status.idleupdelayParam = 10
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
noTelemTimer = 0
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
status.lastBitmap = nil
status.wakeupSchedulerUI = os.clock()
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

local function buildGovernorMap()
    local map = {     
        [0] =  i18n.get("widgets.governor.OFF"),
        [1] =  i18n.get("widgets.governor.IDLE"),
        [2] =  i18n.get("widgets.governor.SPOOLUP"),
        [3] =  i18n.get("widgets.governor.RECOVERY"),
        [4] =  i18n.get("widgets.governor.ACTIVE"),
        [5] =  i18n.get("widgets.governor.THROFF"),
        [6] =  i18n.get("widgets.governor.LOSTHS"),
        [7] =  i18n.get("widgets.governor.AUTOROT"),
        [8] =  i18n.get("widgets.governor.BAILOUT"),
        [100] = i18n.get("widgets.governor.DISABLED"),
        [101] = i18n.get("widgets.governor.DISARMED")
    }

    return map
end
local governorMap = buildGovernorMap()


local function buildLayoutOptions()
    return {
        {i18n.get("widgets.status.layoutOptions.TIMER"), 1},
        {i18n.get("widgets.status.layoutOptions.VOLTAGE"), 2},
        {i18n.get("widgets.status.layoutOptions.FUEL"), 3},
        {i18n.get("widgets.status.layoutOptions.CURRENT"), 4},
        {i18n.get("widgets.status.layoutOptions.MAH"), 17},
        {i18n.get("widgets.status.layoutOptions.RPM"), 5},
        {i18n.get("widgets.status.layoutOptions.LQ"), 6},
        {i18n.get("widgets.status.layoutOptions.TESC"), 7},
        {i18n.get("widgets.status.layoutOptions.TMCU"), 8},
        {i18n.get("widgets.status.layoutOptions.IMAGE"), 9},
        {i18n.get("widgets.status.layoutOptions.GOVERNOR"), 10},
        {i18n.get("widgets.status.layoutOptions.IMAGE_GOVERNOR"), 11},
        {i18n.get("widgets.status.layoutOptions.LQ_TIMER"), 12},
        {i18n.get("widgets.status.layoutOptions.TESC_TMCU"), 13},
        {i18n.get("widgets.status.layoutOptions.VOLTAGE_FUEL"), 14},
        {i18n.get("widgets.status.layoutOptions.VOLTAGE_CURRENT"), 15},
        {i18n.get("widgets.status.layoutOptions.VOLTAGE_MAH"), 16},
        {i18n.get("widgets.status.layoutOptions.LQ_TIMER_TESC_TMCU"), 20},
        {i18n.get("widgets.status.layoutOptions.MAX_CURRENT"), 21},
        {i18n.get("widgets.status.layoutOptions.LQ_GOVERNOR"), 22},
        {i18n.get("widgets.status.layoutOptions.CRAFT_NAME"), 18},
        {i18n.get("widgets.status.layoutOptions.CUSTOMSENSOR_1"), 23},
        {i18n.get("widgets.status.layoutOptions.CUSTOMSENSOR_2"), 24},
        {i18n.get("widgets.status.layoutOptions.CUSTOMSENSOR_1_2"), 25}
    }
end

status.layoutOptions = buildLayoutOptions()


local voltageSOURCE
local rpmSOURCE
local currentSOURCE
local temp_escSOURCE
local temp_mcuSOURCE
local fuelSOURCE
local govSOURCE
local adjSOURCE
local armflagsSOURCE
local adjVALUE
local mahSOURCE
local telemetrySOURCE
local crsfSOURCE
local lastName
local lastID
local default_image

local function getThemeInfo()
    local environment = system.getVersion()
    local w, h = lcd.getWindowSize()
    local tw, th = w, h

    -- Ensure height and width are whole numbers to avoid scaling issues
    h = math.floor(h / 4) * 4
    w = math.floor(w / 6) * 6

    local defaultConfig = {
        supportedRADIO = true,
        title_voltage = i18n.get("widgets.status.title_voltage"),
        title_fuel = i18n.get("widgets.status.title_fuel"),
        title_mah = i18n.get("widgets.status.title_mah"),
        title_rpm = i18n.get("widgets.status.title_rpm"),
        title_current = i18n.get("widgets.status.title_current"),
        title_tempMCU = i18n.get("widgets.status.title_tempMCU"),
        title_tempESC = i18n.get("widgets.status.title_tempESC"),
        title_time = i18n.get("widgets.status.title_time"),
        title_governor = i18n.get("widgets.status.title_governor"),
        title_fm = i18n.get("widgets.status.title_fm"),
        title_rssi = i18n.get("widgets.status.title_rssi"),
        fontSENSOR = FONT_XXL,
        fontSENSORSmallBox = FONT_STD,
        fontPopupTitle = FONT_S,
        widgetTitleOffset = 20
    }

    local themeConfigs = {

        ["784x294"] = {colSpacing = 4, fullBoxW = 262, fullBoxH = h / 2, smallBoxSensortextOFFSET = -5, fontTITLE = FONT_XS},
        ["784x316"] = {colSpacing = 4, fullBoxW = 262, fullBoxH = h / 2, smallBoxSensortextOFFSET = -5, fontTITLE = FONT_XS}, -- no title
        ["472x191"] = {colSpacing = 2, fullBoxW = 158, fullBoxH = h / 2, smallBoxSensortextOFFSET = -8, fontTITLE = 768},
        ["472x210"] = {colSpacing = 2, fullBoxW = 158, fullBoxH = h / 2, smallBoxSensortextOFFSET = -8, fontTITLE = 768}, -- no title 
        ["630x236"] = {colSpacing = 3, fullBoxW = 210, fullBoxH = h / 2, smallBoxSensortextOFFSET = -10, fontTITLE = 768},
        ["630x258"] = {colSpacing = 3, fullBoxW = 210, fullBoxH = h / 2, smallBoxSensortextOFFSET = -10, fontTITLE = 768}, -- no title
        ["427x158"] = {colSpacing = 2, fullBoxW = 158, fullBoxH = h / 2, smallBoxSensortextOFFSET = -10, fontTITLE = FONT_XS} -- not supported anymore as X12
    }

    local configKey = string.format("%dx%d", tw, th)
    local themeConfig = themeConfigs[configKey]

    if themeConfig then
        -- Merge defaultConfig with the specific themeConfig
        for k, v in pairs(defaultConfig) do themeConfig[k] = v end
        return themeConfig
    end

    return nil -- Return nil if no matching theme configuration is found
end

local function screenError(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    -- Available font sizes in order from smallest to largest
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    -- Determine the maximum width and height with 10% padding
    local maxW, maxH = w * 0.9, h * 0.9
    local bestFont = FONT_XXS
    local bestW, bestH = 0, 0

    -- Loop through font sizes and find the largest one that fits
    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tsizeW, tsizeH = lcd.getTextSize(msg)
        
        if tsizeW <= maxW and tsizeH <= maxH then
            bestFont = font
            bestW, bestH = tsizeW, tsizeH
        else
            break  -- Stop checking larger fonts once one exceeds limits
        end
    end

    -- Set the optimal font
    lcd.font(bestFont)

    -- Set text color based on dark mode
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    -- Center the text on the screen
    local x = (w - bestW) / 2
    local y = (h - bestH) / 2
    lcd.drawText(x, y, msg)
end

local function resetALL()
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

local function missingSensors()
    lcd.font(FONT_STD)
    local str = i18n.get("widgets.status.warn_missing_sensors")

    status.theme = getThemeInfo()
    local w, h = lcd.getWindowSize()
    local boxW = math.floor(w / 2)
    local boxH = 45
    local tsizeW, tsizeH = lcd.getTextSize(str)

    -- Set background color based on theme
    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end
    lcd.drawFilledRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- Set border color based on theme
    if status.isDARKMODE then
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- Set text color based on theme and draw text
    if status.isDARKMODE then
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawText((w / 2) - tsizeW / 2, (h / 2) - tsizeH / 2, str)

    return
end

local function noTelem()
    lcd.font(FONT_STD)
    local str = rfsuite.i18n.get("no_link"):upper()

    status.theme = getThemeInfo()
    local w, h = lcd.getWindowSize()
    local boxW = math.floor(w / 2)
    local boxH = 45
    local tsizeW, tsizeH = lcd.getTextSize(str)

    -- Set background color based on theme
    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end
    lcd.drawFilledRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- Set border color based on theme
    if status.isDARKMODE then
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawRectangle(w / 2 - boxW / 2, h / 2 - boxH / 2, boxW, boxH)

    -- Set text color based on theme and draw text
    if status.isDARKMODE then
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawText((w / 2) - tsizeW / 2, (h / 2) - tsizeH / 2, str)

    return
end

local function message(msg)

    lcd.font(FONT_STD)

    status.theme = getThemeInfo()
    local w, h = lcd.getWindowSize()
    boxW = math.floor(w / 2)
    boxH = 45
    tsizeW, tsizeH = lcd.getTextSize(msg)

    -- draw the backgrfsuite.utils.round
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
    lcd.drawText((w / 2) - tsizeW / 2, (h / 2) - tsizeH / 2, msg)
    return
end

local function govColorFlag(flag)
    -- Define a table to map flags to their corresponding values

    -- 0 = default colour
    -- 1 = red (alarm)
    -- 2 = orange (warning)
    -- 3 = green (ok)  

    local flagColors = {
        [i18n.get("widgets.governor.UNKNOWN")] = 1,
        [i18n.get("widgets.governor.DISARMED")] = 0,
        [i18n.get("widgets.governor.DISABLED")] = 0,
        [i18n.get("widgets.governor.BAILOUT")] = 2,
        [i18n.get("widgets.governor.AUTOROT")] = 2,
        [i18n.get("widgets.governor.LOSTHS")] = 2,
        [i18n.get("widgets.governor.THROFF")] = 2,
        [i18n.get("widgets.governor.ACTIVE")] = 3,
        [i18n.get("widgets.governor.RECOVERY")] = 2,
        [i18n.get("widgets.governor.SPOOLUP")] = 2,
        [i18n.get("widgets.governor.IDLE")] = 0,
        [i18n.get("widgets.governor.OFF")] = 0
    }

    -- Return the corresponding value or default to 0
    return flagColors[flag] or 0
end

local function telemetryBox(x, y, w, h, title, value, unit, smallbox, alarm, minimum, maximum)
    status.isVisible = lcd.isVisible()
    status.isDARKMODE = lcd.darkMode()
    local theme = getThemeInfo()

    -- Set background color based on mode
    lcd.color(status.isDARKMODE and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.drawFilledRectangle(x, y, w, h)

    -- Set text color
    lcd.color(status.isDARKMODE and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90))

    if value ~= nil then
        -- Set font
        lcd.font((smallbox == nil or smallbox == false) and theme.fontSENSOR or theme.fontSENSORSmallBox)

        local str  = rfsuite.utils.truncateText(value .. unit,w)
        local tsizeW, tsizeH = lcd.getTextSize(unit == "°" and value .. "." or str)
        local sx = (x + w / 2) - (tsizeW / 2)
        local sy = (y + h / 2) - (tsizeH / 2)

        if smallbox and (status.maxminParam or status.titleParam) then sy = sy + theme.smallBoxSensortextOFFSET end

        -- Set text color based on alarm flag
        if status.statusColorParam then
            if alarm == 1 then
                lcd.color(lcd.RGB(255, 0, 0, 1)) -- red
            elseif alarm == 2 then
                lcd.color(lcd.RGB(255, 204, 0, 1)) -- orange
            elseif alarm == 3 then
                lcd.color(lcd.RGB(0, 188, 4, 1)) -- green
            end
        elseif alarm == 1 then
            lcd.color(lcd.RGB(255, 0, 0, 1)) -- red
        end

        lcd.drawText(sx, sy, str)

        -- Reset text color after alarm handling
        if alarm ~= 0 then lcd.color(status.isDARKMODE and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)) end
    end

    if title and status.titleParam then
        lcd.font(theme.fontTITLE)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local sx = (x + w / 2) - (tsizeW / 2)
        local sy = (y + h) - tsizeH - theme.colSpacing
        lcd.drawText(sx, sy, title)
    end

    if status.maxminParam then
        -- Draw minimum value
        if minimum ~= nil then
            lcd.font(theme.fontTITLE)
            local minStr = tostring(minimum) == "-" and minimum or minimum .. unit
            local tsizeW, tsizeH = lcd.getTextSize(unit == "°" and minimum .. "." or minStr)
            local sx = x + theme.colSpacing
            local sy = (y + h) - tsizeH - theme.colSpacing
            lcd.drawText(sx, sy, minStr)
        end

        -- Draw maximum value
        if maximum ~= nil then
            lcd.font(theme.fontTITLE)
            local maxStr = tostring(maximum) == "-" and maximum or maximum .. unit
            local tsizeW, tsizeH = lcd.getTextSize(unit == "°" and maximum .. "." or maxStr)
            local sx = (x + w) - tsizeW - theme.colSpacing
            local sy = (y + h) - tsizeH - theme.colSpacing
            lcd.drawText(sx, sy, maxStr)
        end
    end
end

local function telemetryBoxMAX(x, y, w, h, title, value, unit, smallbox)
    status.isVisible = lcd.isVisible()
    status.isDARKMODE = lcd.darkMode()
    local theme = getThemeInfo()

    -- Set background color based on dark mode
    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end

    -- Draw background rectangle
    lcd.drawFilledRectangle(x, y, w, h)

    -- Set text color based on dark mode
    if status.isDARKMODE then
        lcd.color(lcd.RGB(255, 255, 255, 1))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end

    -- Draw sensor value text if available
    if value then
        lcd.font(smallbox and theme.fontSENSORSmallBox or theme.fontSENSOR)

        local str = value .. unit
        local tsizeW, tsizeH

        if unit == "°" then
            tsizeW, tsizeH = lcd.getTextSize(value .. ".")
        else
            tsizeW, tsizeH = lcd.getTextSize(str)
        end

        local sx = x + w / 2 - tsizeW / 2
        local sy = y + h / 2 - tsizeH / 2

        if smallbox then if status.maxminParam or status.titleParam then sy = sy + theme.smallBoxSensortextOFFSET end end

        lcd.drawText(sx, sy, str)
    end

    -- Draw title text if available and enabled
    if title and status.titleParam then
        lcd.font(theme.fontTITLE)
        local str = title
        local tsizeW, tsizeH = lcd.getTextSize(str)

        local sx = x + w / 2 - tsizeW / 2
        local sy = y + h - tsizeH - theme.colSpacing

        lcd.drawText(sx, sy, str)
    end
end

local function telemetryBoxImage(x, y, w, h, gfx)
    -- Get display status and theme information
    status.isVisible = lcd.isVisible()
    status.isDARKMODE = lcd.darkMode()
    local theme = getThemeInfo()

    -- Set background color based on dark mode status
    if status.isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40)) -- Dark background
    else
        lcd.color(lcd.RGB(240, 240, 240)) -- Light background
    end

    -- Draw the background rectangle
    lcd.drawFilledRectangle(x, y, w, h)

    -- Draw the bitmap centered within the box, respecting theme spacing
    if gfx ~= nil then
        lcd.drawBitmap(x, y, gfx, w - theme.colSpacing, h - theme.colSpacing)
    else
        lcd.drawBitmap(x, y, default_image, w - theme.colSpacing, h - theme.colSpacing)
    end
end

local function getChannelValue(ich)
    local src = system.getSource({category = CATEGORY_CHANNEL, member = (ich - 1), options = 0})
    return math.floor((src:value() / 10.24) + 0.5)
end

-- Function to convert temperature
local function convert_temperature(temp, conversion_type)
    if conversion_type == 2 then
        -- Convert from C to F
        temp = ((temp / 5) * 9) + 32
    elseif conversion_type == 3 then
        -- Convert from F to C
        temp = ((temp - 32) * 5) / 9
    end
    return rfsuite.utils.round(temp, 0)
end

local function getSensors()
    if status.isInConfiguration == true then return status.sensors end

    local tv
    local voltage
    local temp_esc
    local temp_mcu
    local mah
    local fuel
    local fm
    local rssi
    local adjSOURCE
    local adjvalue
    local adjfunc
    local current
    local currentesc1

    -- lcd.resetFocusTimeout()

    if status.linkUP == true then

        -- get sensors
        voltageSOURCE = rfsuite.tasks.telemetry.getSensorSource("voltage")
        rpmSOURCE = rfsuite.tasks.telemetry.getSensorSource("rpm")
        currentSOURCE = rfsuite.tasks.telemetry.getSensorSource("current")
        temp_escSOURCE = rfsuite.tasks.telemetry.getSensorSource("temp_esc")
        temp_mcuSOURCE = rfsuite.tasks.telemetry.getSensorSource("temp_mcu")
        fuelSOURCE = rfsuite.tasks.telemetry.getSensorSource("fuel")
        adjSOURCE = rfsuite.tasks.telemetry.getSensorSource("adj_f")
        adjVALUE = rfsuite.tasks.telemetry.getSensorSource("adj_v")
        adjvSOURCE = rfsuite.tasks.telemetry.getSensorSource("adj_v")
        mahSOURCE = rfsuite.tasks.telemetry.getSensorSource("consumption")
        rssiSOURCE = rfsuite.tasks.telemetry.getSensorSource("rssi") 
        govSOURCE = rfsuite.tasks.telemetry.getSensorSource("governor")
        armflagsSOURCE = rfsuite.tasks.telemetry.getSensorSource("armflags")

        if rfsuite.tasks.telemetry.getSensorProtocol() == 'crsf' then

            if voltageSOURCE ~= nil then
                voltage = voltageSOURCE:value() or 0
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

                rpm = rpmSOURCE:value() or 0
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

                current = currentSOURCE:value() or 0
                if current ~= nil then
                    current = current * 10
                else
                    current = 0
                end
            else
                current = 0
            end

            if temp_escSOURCE ~= nil then
                temp_esc = temp_escSOURCE:value() or 0
                if temp_esc ~= nil then
                    temp_esc = temp_esc * 100
                else
                    temp_esc = 0
                end
            else
                temp_esc = 0
            end

            if temp_mcuSOURCE ~= nil then
                temp_mcu = temp_mcuSOURCE:value() or 0
                if temp_mcu ~= nil then
                    temp_mcu = (temp_mcu) * 100
                else
                    temp_mcu = 0
                end
            else
                temp_mcu = 0
            end

            if fuelSOURCE ~= nil then
                fuel = fuelSOURCE:value() or 0
                if fuel ~= nil then
                    fuel = fuel
                else
                    fuel = 0
                end
            else
                fuel = 0
            end

            if mahSOURCE ~= nil then
                mah = mahSOURCE:value() or 0
                if mah ~= nil then
                    mah = mah
                else
                    mah = 0
                end
            else
                mah = 0
            end

            if govSOURCE ~= nil then
                govId = govSOURCE:value() or 0

                if governorMap[govId] == nil then
                    govmode = "UNKNOWN"
                else
                    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.session.apiVersion > 12.07 then
                        if armflagsSOURCE and (armflagsSOURCE:value() == 0 or armflagsSOURCE:value() == 2 )then
                            govId = 101
                        end
                    end                   
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
                rssi = rssiSOURCE:value() or 0

                if rssi ~= nil then
                    rssi = rssi
                else
                    rssi = 0
                end
            else
                rssi = 0
            end

            if adjSOURCE ~= nil then
                adjfunc = adjSOURCE:value() or 0
                if adjfunc ~= nil then
                    adjfunc = adjfunc
                else
                    adjfunc = 0
                end
            else
                adjfunc = 0
            end

            if adjVALUE ~= nil then
                adjvalue = adjVALUE:value() or 0
                if adjvalue ~= nil then
                    adjvalue = adjvalue
                else
                    adjvalue = 0
                end
            else
                adjvalue = 0
            end

        elseif rfsuite.tasks.telemetry.getSensorProtocol() == 'lcrsf' then

            if voltageSOURCE ~= nil then
                voltage = voltageSOURCE:value() or 0
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

                rpm = rpmSOURCE:value() or 0
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

                current = currentSOURCE:value() or 0
                if current ~= nil then
                    current = current * 10
                else
                    current = 0
                end
            else
                current = 0
            end

            if temp_escSOURCE ~= nil then
                temp_esc = temp_escSOURCE:value() or 0
                if temp_esc ~= nil then
                    temp_esc = temp_esc * 100
                else
                    temp_esc = 0
                end
            else
                temp_esc = 0
            end

            if temp_mcuSOURCE ~= nil then
                temp_mcu = temp_mcuSOURCE:value() or 0
                if temp_mcu ~= nil then
                    temp_mcu = (temp_mcu) * 100
                else
                    temp_mcu = 0
                end
            else
                temp_mcu = 0
            end

            if fuelSOURCE ~= nil then
                fuel = fuelSOURCE:value() or 0
                if fuel ~= nil then
                    fuel = fuel
                else
                    fuel = 0
                end
            else
                fuel = 0
            end

            if mahSOURCE ~= nil then
                mah = mahSOURCE:value() or 0
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
                rssi = rssiSOURCE:value() or 0
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

        elseif rfsuite.tasks.telemetry.getSensorProtocol() == 'sport' then


            if voltageSOURCE ~= nil then
                voltage = voltageSOURCE:value() or 0
                if voltage ~= nil then
                    voltage = voltage * 100
                else
                    voltage = 0
                end
            else
                voltage = 0
            end

            if rpmSOURCE ~= nil then
                rpm = rpmSOURCE:value() or 0
                if rpm ~= nil then
                    rpm = rpm
                else
                    rpm = 0
                end
            else
                rpm = 0
            end

            if currentSOURCE ~= nil then
                current = currentSOURCE:value() or 0
                if currentSOURCEESC1 ~= nil then
                    currentesc1 = currentSOURCEESC1:value()
                    if currentesc1 == nil then currentesc1 = 0 end
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
                temp_esc = temp_escSOURCE:value() or 0
                if temp_esc ~= nil then
                    temp_esc = temp_esc * 100
                else
                    temp_esc = 0
                end
            else
                temp_esc = 0
            end

            if temp_mcuSOURCE ~= nil then
                temp_mcu = temp_mcuSOURCE:value() or 0
                if temp_mcu ~= nil then
                    temp_mcu = temp_mcu * 100
                else
                    temp_mcu = 0
                end
            else
                temp_mcu = 0
            end

            if fuelSOURCE ~= nil then
                fuel = fuelSOURCE:value() or 0
                if fuel ~= nil then
                    fuel = rfsuite.utils.round(fuel, 0)
                else
                    fuel = 0
                end
            else
                fuel = 0
            end

            if mahSOURCE ~= nil then
                mah = mahSOURCE:value() or 0
                if mah ~= nil then
                    mah = mah
                else
                    mah = 0
                end
            else
                mah = 0
            end

            if rssiSOURCE ~= nil then
                rssi = rssiSOURCE:value() or 0
                if rssi ~= nil then
                    rssi = rssi
                else
                    rssi = 0
                end
            else
                rssi = 0
            end

            if govSOURCE ~= nil then
                govId = govSOURCE:value() or 0

                if governorMap[govId] == nil then
                    govmode = "UNKNOWN"
                else
                    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.session.apiVersion > 12.07 then
                        if armflagsSOURCE and (armflagsSOURCE:value() == 0 or armflagsSOURCE:value() == 2 )then
                            govId = 101
                        end
                    end                    
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

    -- Calculate fuel percentage if needed
    if status.calcfuelParam then
        local cv = (voltage or 0) / 100
        local maxv = (status.maxCellVoltage / 100) * status.cellsParam
        local minv = (status.minCellVoltage / 100) * status.cellsParam

        local batteryPercentage = ((cv - minv) / (maxv - minv)) * 100
        fuel = math.min(rfsuite.utils.round(batteryPercentage, 0), 100)
    end

    if voltage == nil then voltage = 0 end
    if math.floor(voltage) <= 5 then fuel = 0 end

    -- Convert MCU temperature
    if status.tempconvertParamMCU == 2 or status.tempconvertParamMCU == 3 then temp_mcu = convert_temperature(temp_mcu, status.tempconvertParamMCU) end

    -- Convert ESC temperature
    if status.tempconvertParamESC == 2 or status.tempconvertParamESC == 3 then temp_esc = convert_temperature(temp_esc, status.tempconvertParamESC) end

    -- set flag to status.refresh screen or not

    if voltage == nil then voltage = 0 end
    voltage = rfsuite.utils.round(voltage, 0)

    if rpm == nil then rpm = 0 end
    rpm = rfsuite.utils.round(rpm, 0)

    if temp_mcu == nil then temp_mcu = 0 end
    temp_mcu = rfsuite.utils.round(temp_mcu, 0)

    if temp_esc == nil then temp_esc = 0 end
    temp_esc = rfsuite.utils.round(temp_esc, 0)

    if current == nil then current = 0 end
    current = rfsuite.utils.round(current, 0)

    if rssi == nil then rssi = 0 end
    rssi = rfsuite.utils.round(rssi, 0)

    if rpm == nil then rpm = 0 end
    rpm = rfsuite.utils.round(rpm, 0)

    -- Voltage based on stick position
    status.lowvoltagStickParam = status.lowvoltagStickParam or 0
    status.lowvoltagStickCutoffParam = status.lowvoltagStickCutoffParam or 80

    if status.lowvoltagStickParam ~= 0 then
        status.lvStickannouncement = false
        for _, v in ipairs(status.lvStickOrder[status.lowvoltagStickParam]) do
            if math.abs(getChannelValue(v)) >= status.lowvoltagStickCutoffParam then
                status.lvStickannouncement = true
                break -- Exit loop early once a stick triggers announcement
            end
        end
    end

    -- Intercept governor for non-RF governor helis
    local isArmed = false

    if status.linkUP then
        local armSource = rfsuite.tasks.telemetry.getSensorSource("armflags")
        if armSource then isArmed = armSource:value() end
    end

    if status.idleupswitchParam and status.govmodeParam == 1 then
        if isArmed == 1 or isArmed == 3 then
            if status.idleupswitchParam:state() then
                govmode = i18n.get("widgets.governor.ACTIVE")
                fm = i18n.get("widgets.governor.ACTIVE")
            else
                govmode = i18n.get("widgets.governor.THROFF")
                fm = i18n.get("widgets.governor.THROFF")
            end
        else
            govmode = i18n.get("widgets.governor.DISARMED")
            fm = i18n.get("widgets.governor.DISARMED")
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

    ret = {fm = fm, govmode = govmode, voltage = voltage, rpm = rpm, current = current, temp_esc = temp_esc, temp_mcu = temp_mcu, fuel = fuel, mah = mah, rssi = rssi, adjsource = adjsource, adjvalue = adjvalue}
    status.sensors = ret

    return ret
end

local function sensorsMAXMIN(sensors)
    local sensorTypes = {"Voltage", "Fuel", "RPM", "Current", "RSSI", "TempESC", "TempMCU"}

    if status.linkUP and status.theTIME and status.idleupdelayParam then

        if status.theTIME <= status.idleupdelayParam then
            for _, sensor in pairs(sensorTypes) do
                status["sensor" .. sensor .. "Min"] = 0
                status["sensor" .. sensor .. "Max"] = 0
            end
            return
        end

        if status.theTIME >= status.idleupdelayParam then
            local idleupdelayOFFSET = 2

            if status.theTIME <= (status.idleupdelayParam + idleupdelayOFFSET) then
                for _, sensor in pairs(sensorTypes) do
                    local value = sensors[sensor:lower()] or 0
                    status["sensor" .. sensor .. "Min"] = value
                    status["sensor" .. sensor .. "Max"] = value
                end

                local current = sensors.current or 0
                status.sensorCurrentMin = current > 0 and current or 1
                status.sensorCurrentMax = current

                motorNearlyActive = 0
                return
            end

            if status.theTIME > (status.idleupdelayParam + idleupdelayOFFSET) and (status.idleupswitchParam and status.idleupswitchParam:state()) then
                for _, sensor in pairs(sensorTypes) do
                    local value = sensors[sensor:lower()] or 0
                    status["sensor" .. sensor .. "Min"] = math.min(status["sensor" .. sensor .. "Min"] or math.huge, value)
                    status["sensor" .. sensor .. "Max"] = math.max(status["sensor" .. sensor .. "Max"] or -math.huge, value)
                end

                local current = sensors.current or 0
                status.sensorCurrentMin = math.min(status.sensorCurrentMin or math.huge, current > 0 and current or 1)
                status.sensorCurrentMax = math.max(status.sensorCurrentMax or -math.huge, current)

                status.motorWasActive = true
            end
        end

        if status.motorWasActive and status.idleupswitchParam and not status.idleupswitchParam:state() then
            status.motorWasActive = false

            status.sensorCurrentMinAlt = status.sensorCurrentMin > 0 and status.sensorCurrentMin or 1
            status.sensorCurrentMaxAlt = status.sensorCurrentMax > 0 and status.sensorCurrentMax or 1
        end
    else
        for _, sensor in pairs(sensorTypes) do
            status["sensor" .. sensor .. "Min"] = 0
            status["sensor" .. sensor .. "Max"] = 0
        end
    end
end

local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end


local function SecondsToClock(seconds)
    if type(seconds) ~= "number" or seconds <= 0 then return "00:00:00" end

    local hours = string.format("%02d", math.floor(seconds / 3600))
    local mins = string.format("%02d", math.floor((seconds % 3600) / 60))
    local secs = string.format("%02d", math.floor(seconds % 60))

    return hours .. ":" .. mins .. ":" .. secs
end

function status.read()
    status.govmodeParam = storage.read("mem1")
    status.btypeParam = storage.read("mem2")
    status.lowfuelParam = storage.read("mem3")
    status.alertintParam = storage.read("mem4")
    status.alrthptParam = storage.read("mem5")
    status.maxminParam = storage.read("mem6")
    status.titleParam = storage.read("mem7")
    status.cellsParam = storage.read("mem8")
    status.announcementVoltageSwitchParam = storage.read("mem9")
    status.govmodeParam = storage.read("mem10")
    status.rpmAlertsParam = storage.read("mem11")
    status.rpmAlertsPercentageParam = storage.read("mem12")
    status.sensorwarningParam = storage.read("mem13") 
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
    status.armswitchParam = storage.read("mem46")
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
    if status.quadBoxParam == nil then status.quadBoxParam = 1 end

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

    resetALL()

end

function status.write()
    storage.write("mem1", status.govmodeParam)
    storage.write("mem2", status.btypeParam)
    storage.write("mem3", status.lowfuelParam)
    storage.write("mem4", status.alertintParam)
    storage.write("mem5", status.alrthptParam)
    storage.write("mem6", status.maxminParam)
    storage.write("mem7", status.titleParam)
    storage.write("mem8", status.cellsParam)
    storage.write("mem9", status.announcementVoltageSwitchParam)
    storage.write("mem10", status.govmodeParam)
    storage.write("mem11", status.rpmAlertsParam)
    storage.write("mem12", status.rpmAlertsPercentageParam)
    storage.write("mem13", status.sensorwarningParam) 
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
    storage.write("mem81", status.customSensorParam2)

end

local function playCurrent(widget)
    if not status.announcementCurrentSwitchParam then
        return -- Exit early if the announcement switch parameter is nil
    end

    -- Update the current announcement timer and first-done flag based on switch state
    local switchState = status.announcementCurrentSwitchParam:state()
    status.currenttime.currentannouncementTimer = switchState
    local currentDoneFirst = not switchState

    if status.isInConfiguration then
        return -- Exit early if the system is in configuration mode
    end

    local currentSensorValue = status.sensors.current
    if not currentSensorValue then
        return -- Exit early if the current sensor value is nil
    end

    if status.currenttime.currentannouncementTimer then
        -- Initialize the timer for the first alert
        if not status.currenttime.currentannouncementTimerStart and not currentDoneFirst then
            status.currenttime.currentannouncementTimerStart = os.time()
            status.currenttime.currentaudioannouncementCounter = os.clock()
            system.playNumber(currentSensorValue / 10, UNIT_AMPERE, 2)
            currentDoneFirst = true
        end
    else
        -- Reset the timer when the announcement timer is off
        status.currenttime.currentannouncementTimerStart = nil
    end

    -- Handle repeated alerts
    if status.currenttime.currentannouncementTimerStart then
        local elapsed = os.clock() - (status.currenttime.currentaudioannouncementCounter or 0)
        if elapsed >= (status.announcementIntervalParam or 0) then
            status.currenttime.currentaudioannouncementCounter = os.clock()
            system.playNumber(currentSensorValue / 10, UNIT_AMPERE, 2)
        end
    else
        -- Ensure timer reset when not in use
        status.currenttime.currentannouncementTimerStart = nil
    end
end

local function playLQ(widget)
    if not status.announcementLQSwitchParam then return end

    -- Update the LQ announcement timer state based on switch param
    local isLQSwitchActive = status.announcementLQSwitchParam:state()
    status.lqtime.lqannouncementTimer = isLQSwitchActive
    lqDoneFirst = not isLQSwitchActive

    -- Exit if in configuration mode
    if status.isInConfiguration then return end

    -- Ensure sensors.rssi is valid
    if not status.sensors.rssi then return end

    -- Handle LQ announcement timer logic
    if status.lqtime.lqannouncementTimer then
        if not status.lqtime.lqannouncementTimerStart and not lqDoneFirst then
            -- Start the timer and make the initial announcement
            status.lqtime.lqannouncementTimerStart = os.time()
            status.lqtime.lqaudioannouncementCounter = os.clock()
            rfsuite.utils.playFile("status", "alerts/lq.wav")
            system.playNumber(status.sensors.rssi, UNIT_PERCENT, 2)
            lqDoneFirst = true
        elseif status.lqtime.lqannouncementTimerStart then
            -- Make repeated announcements based on the interval
            if os.clock() - status.lqtime.lqaudioannouncementCounter >= status.announcementIntervalParam then
                status.lqtime.lqaudioannouncementCounter = os.clock()
                rfsuite.utils.playFile("status", "alerts/lq.wav")
                system.playNumber(status.sensors.rssi, UNIT_PERCENT, 2)
            end
        end
    else
        -- Stop the timer if the switch is inactive
        status.lqtime.lqannouncementTimerStart = nil
    end
end

local function playMCU(widget)
    if not status.announcementMCUSwitchParam then return end

    -- Set MCU announcement timer based on switch state
    local switchState = status.announcementMCUSwitchParam:state()
    status.mcutime.mcuannouncementTimer = switchState
    local mcuDoneFirst = not switchState

    if not status.isInConfiguration and status.sensors.temp_mcu then
        if status.mcutime.mcuannouncementTimer then
            -- Start timer if not already started
            if not status.mcutime.mcuannouncementTimerStart and not mcuDoneFirst then
                status.mcutime.mcuannouncementTimerStart = os.time()
                status.mcutime.mcuaudioannouncementCounter = os.clock()
                rfsuite.utils.playFile("status", "alerts/mcu.wav")
                system.playNumber(status.sensors.temp_mcu / 100, UNIT_DEGREE, 2)
                mcuDoneFirst = true
            end
        else
            -- Reset timer if switch is off
            status.mcutime.mcuannouncementTimerStart = nil
        end

        -- Handle repeat announcements
        if status.mcutime.mcuannouncementTimerStart and mcuDoneFirst then
            local elapsedTime = os.clock() - status.mcutime.mcuaudioannouncementCounter
            if elapsedTime >= status.announcementIntervalParam then
                status.mcutime.mcuaudioannouncementCounter = os.clock()
                rfsuite.utils.playFile("status", "alerts/mcu.wav")
                system.playNumber(status.sensors.temp_mcu / 100, UNIT_DEGREE, 2)
            end
        end
    end
end

local function playESC(widget)
    if not status.announcementESCSwitchParam then return end

    -- Determine if ESC announcement timer should be active
    local isESCTimerActive = status.announcementESCSwitchParam:state()
    status.esctime.escannouncementTimer = isESCTimerActive
    escDoneFirst = not isESCTimerActive

    -- Exit if in configuration mode
    if status.isInConfiguration then return end

    -- Ensure ESC sensor is available
    if not status.sensors.temp_esc then return end

    if isESCTimerActive then
        -- Start the timer if not already started
        if not status.esctime.escannouncementTimerStart and not escDoneFirst then
            status.esctime.escannouncementTimerStart = os.time()
            status.esctime.escaudioannouncementCounter = os.clock()
            rfsuite.utils.playFile("status", "alerts/esc.wav")
            system.playNumber(status.sensors.temp_esc / 100, UNIT_DEGREE, 2)
            escDoneFirst = true
        end

        -- Handle repeating announcements
        if status.esctime.escannouncementTimerStart and (os.clock() - status.esctime.escaudioannouncementCounter >= status.announcementIntervalParam) then
            status.esctime.escaudioannouncementCounter = os.clock()
            rfsuite.utils.playFile("status", "alerts/esc.wav")
            system.playNumber(status.sensors.temp_esc / 100, UNIT_DEGREE, 2)
        end
    else
        -- Stop the timer
        status.esctime.escannouncementTimerStart = nil
    end
end

local function playTIMERALARM(widget)
    if status.theTIME and status.timeralarmParam and status.timeralarmParam ~= 0 then

        -- Reset timer delay
        if status.theTIME > status.timeralarmParam + 2 then status.timerAlarmPlay = true end

        -- Trigger first timer
        if status.timerAlarmPlay then
            if status.theTIME >= status.timeralarmParam and status.theTIME <= status.timeralarmParam + 1 then

                rfsuite.utils.playFileCommon("alarm.wav")

                local hours = string.format("%02.f", math.floor(status.theTIME / 3600))
                local mins = string.format("%02.f", math.floor(status.theTIME / 60 - (hours * 60)))
                local secs = string.format("%02.f", math.floor(status.theTIME - hours * 3600 - mins * 60))

                rfsuite.utils.playFile("status", "alerts/timer.wav")
                if mins ~= "00" then system.playNumber(mins, UNIT_MINUTE, 2) end
                system.playNumber(secs, UNIT_SECOND, 2)

                if status.timeralarmVibrateParam then system.playHaptic("- - -") end

                status.timerAlarmPlay = false
            end
        end
    end
end

local function playTIMER(widget)
    if not status.announcementTimerSwitchParam then return end

    -- Update timer announcement state
    local timerSwitchState = status.announcementTimerSwitchParam:state()
    status.timetime.timerannouncementTimer = timerSwitchState
    local timerDoneFirst = not timerSwitchState

    if status.isInConfiguration then return end

    local alertTIME = status.theTIME or 0

    local hours = string.format("%02.f", math.floor(alertTIME / 3600))
    local mins = string.format("%02.f", math.floor(alertTIME / 60) % 60)
    local secs = string.format("%02.f", alertTIME % 60)

    if timerSwitchState then
        -- Start the timer if not already started
        if not status.timetime.timerannouncementTimerStart and not timerDoneFirst then
            status.timetime.timerannouncementTimerStart = os.time()
            status.timetime.timeraudioannouncementCounter = os.clock()
            if mins ~= "00" then system.playNumber(mins, UNIT_MINUTE, 2) end
            system.playNumber(secs, UNIT_SECOND, 2)
            timerDoneFirst = true
        end

        -- Announce timer intervals
        if status.timetime.timerannouncementTimerStart and timerDoneFirst then
            local elapsed = os.clock() - status.timetime.timeraudioannouncementCounter
            if elapsed >= status.announcementIntervalParam then
                status.timetime.timeraudioannouncementCounter = os.clock()
                if mins ~= "00" then system.playNumber(mins, UNIT_MINUTE, 2) end
                system.playNumber(secs, UNIT_SECOND, 2)
            end
        end
    else
        -- Stop the timer
        status.timetime.timerannouncementTimerStart = nil
    end
end

local function playFuel(widget)
    if not status.announcementFuelSwitchParam then return end

    local isSwitchOn = status.announcementFuelSwitchParam:state()
    status.fueltime.fuelannouncementTimer = isSwitchOn
    fuelDoneFirst = not isSwitchOn

    if status.isInConfiguration or not status.sensors.fuel then return end

    if status.fueltime.fuelannouncementTimer then
        -- Start timer if not already started and first announcement not done
        if not status.fueltime.fuelannouncementTimerStart and not fuelDoneFirst then
            status.fueltime.fuelannouncementTimerStart = os.time()
            status.fueltime.fuelaudioannouncementCounter = os.clock()
            rfsuite.utils.playFile("status", "alerts/fuel.wav")
            system.playNumber(status.sensors.fuel, UNIT_PERCENT, 2)
            fuelDoneFirst = true
        end
    else
        status.fueltime.fuelannouncementTimerStart = nil
    end

    if status.fueltime.fuelannouncementTimerStart then
        -- Handle repeated announcements
        local timeElapsed = os.clock() - status.fueltime.fuelaudioannouncementCounter
        if not fuelDoneFirst and timeElapsed >= status.announcementIntervalParam then
            status.fueltime.fuelaudioannouncementCounter = os.clock()
            rfsuite.utils.playFile("status", "alerts/fuel.wav")
            system.playNumber(status.sensors.fuel, UNIT_PERCENT, 2)
        end
    else
        -- Ensure timer is stopped
        status.fueltime.fuelannouncementTimerStart = nil
    end
end

function playRPM(widget)
    if not status.announcementRPMSwitchParam then return end

    -- Update announcement timer state and rpmDoneFirst flag based on switch state
    local switchState = status.announcementRPMSwitchParam:state()
    status.rpmtime.announcementTimer = switchState
    local rpmDoneFirst = not switchState

    if status.isInConfiguration then return end

    local rpmSensor = status.sensors.rpm
    if not rpmSensor then return end

    if status.rpmtime.announcementTimer then
        -- Start the timer if not already started and first announcement is not done
        if not status.rpmtime.announcementTimerStart and not rpmDoneFirst then
            status.rpmtime.announcementTimerStart = os.time()
            status.rpmtime.audioannouncementCounter = os.clock()
            system.playNumber(rpmSensor, UNIT_RPM, 2) -- Play the RPM alert
            rpmDoneFirst = true
        end
    else
        status.rpmtime.announcementTimerStart = nil -- Reset the timer if announcement is off
    end

    if status.rpmtime.announcementTimerStart then
        -- Check if it's time for the next announcement
        local elapsed = os.clock() - (status.rpmtime.audioannouncementCounter or 0)
        if elapsed >= status.announcementIntervalParam then
            status.rpmtime.audioannouncementCounter = os.clock()
            system.playNumber(rpmSensor, UNIT_RPM, 2) -- Repeat the RPM alert
        end
    else
        -- Ensure the timer is stopped
        status.rpmtime.announcementTimerStart = nil
    end
end

local function playVoltage(widget)

    local voltageDoneFirst

    if not status.announcementVoltageSwitchParam then return end

    local switchState = status.announcementVoltageSwitchParam:state()
    status.lvannouncementTimer = switchState
    voltageDoneFirst = not switchState

    if status.isInConfiguration then return end

    local voltageSensor = status.sensors.voltage
    if not voltageSensor then return end

    if status.lvannouncementTimer then
        -- Start timer if not already started and first announcement hasn't been made
        if not status.lvannouncementTimerStart and not voltageDoneFirst then
            status.lvannouncementTimerStart = os.time()
            status.lvaudioannouncementCounter = os.clock()
            system.playNumber(voltageSensor / 100, 2, 2)
            voltageDoneFirst = true
        end
    else
        -- Stop timer
        status.lvannouncementTimerStart = nil
    end

    if not status.lvannouncementTimerStart then return end

    -- Handle repeated announcements
    if not voltageDoneFirst and status.lvaudioannouncementCounter and status.announcementIntervalParam then
        local elapsedTime = os.clock() - status.lvaudioannouncementCounter
        if elapsedTime >= status.announcementIntervalParam then
            status.lvaudioannouncementCounter = os.clock()
            system.playNumber(voltageSensor / 100, 2, 2)
        end
    end
end

local function playGovernor()
    if not status.governorAlertsParam then return end

    playGovernorLastState = playGovernorLastState or status.sensors.govmode

    if status.sensors.govmode ~= playGovernorLastState then
        playGovernorCount = 0
        playGovernorLastState = status.sensors.govmode
    end

    if playGovernorCount == 0 then
        playGovernorCount = 1

        local govmodeActions = {
            [i18n.get("widgets.governor.UNKNOWN")] = {param = status.governorUNKNOWNParam, sound = "unknown.wav"},
            [i18n.get("widgets.governor.DISARMED")] = {param = status.governorDISARMEDParam, sound = "disarmed.wav"},
            [i18n.get("widgets.governor.DISABLED")] = {param = status.governorDISABLEDParam, sound = "disabled.wav"},
            [i18n.get("widgets.governor.BAILOUT")] = {param = status.governorBAILOUTParam, sound = "bailout.wav"},
            [i18n.get("widgets.governor.AUTOROT")] = {param = status.governorAUTOROTParam, sound = "autorot.wav"},
            [i18n.get("widgets.governor.LOSTHS")] = {param = status.governorLOSTHSParam, sound = "lost-hs.wav"},
            [i18n.get("widgets.governor.THROFF")] = {param = status.governorTHROFFParam, sound = "thr-off.wav"},
            [i18n.get("widgets.governor.ACTIVE")] = {param = status.governorACTIVEParam, sound = "active.wav"},
            [i18n.get("widgets.governor.RECOVERY")] = {param = status.governorRECOVERYParam, sound = "recovery.wav"},
            [i18n.get("widgets.governor.SPOOLUP")] = {param = status.governorSPOOLUPParam, sound = "spoolup.wav"},
            [i18n.get("widgets.governor.IDLE")] = {param = status.governorIDLEParam, sound = "idle.wav"},
            [i18n.get("widgets.governor.OFF")] = {param = status.governorOFFParam, sound = "off.wav"}
        }

        local action = govmodeActions[status.sensors.govmode]

        if action and action.param then
            if status.govmodeParam == 0 then rfsuite.utils.playFile("status", "events/governor.wav") end
            rfsuite.utils.playFile("status", "events/" .. action.sound)
        end
    end
end

local function playRPMDiff()
    if not status.rpmAlertsParam then return end

    local govmode = status.sensors.govmode
    local validGovModes = {i18n.get("widgets.governor.ACTIVE"), i18n.get("widgets.governor.LOSTHS"), i18n.get("widgets.governor.BAILOUT"), i18n.get("widgets.governor.RECOVERY")}

    -- Check if the current govmode is in the list of valid modes
    local isGovModeValid = false
    for _, mode in ipairs(validGovModes) do
        if govmode == mode then
            isGovModeValid = true
            break
        end
    end

    if not isGovModeValid then return end

    local playRPMDiff = playRPMdiff
    playRPMDiff.playRPMDiffLastState = playRPMDiff.playRPMDiffLastState or status.sensors.rpm

    -- Take a reading every 5 seconds
    if (os.clock() - (playRPMDiff.playRPMDiffCounter or 0)) >= 5 then
        playRPMDiff.playRPMDiffCounter = os.clock()
        playRPMDiff.playRPMDiffLastState = status.sensors.rpm
    end

    -- Calculate the percentage difference
    local currentRPM = status.sensors.rpm
    local lastStateRPM = playRPMDiff.playRPMDiffLastState
    local percentageDiff = 0

    if currentRPM ~= lastStateRPM then percentageDiff = math.abs(100 - math.min(currentRPM, lastStateRPM) / math.max(currentRPM, lastStateRPM) * 100) end

    -- Check if the percentage difference exceeds the threshold
    if percentageDiff > (status.rpmAlertsPercentageParam / 10) then playRPMDiff.playRPMDiffCount = 0 end

    if playRPMDiff.playRPMDiffCount == 0 then
        playRPMDiff.playRPMDiffCount = 1
        system.playNumber(currentRPM, UNIT_RPM, 2)
    end
end

function status.event(widget, category, value, x, y)

end

local function wakeupUI(widget)

    if not rfsuite.tasks.active() then
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

        status.linkUP = rfsuite.session.telemetryState
        status.sensors = getSensors()

        if status.refresh == true then
            sensorsMAXMIN(status.sensors)
            lcd.invalidate()
        end

        --  find and set image to suite based on craftname or model id
        if lastName ~= rfsuite.session.craftName or lastID ~= rfsuite.session.modelID then
            if rfsuite.session.craftName ~= nil then image1 = "/bitmaps/models/" .. rfsuite.session.craftName .. ".png" end
            if rfsuite.session.modelID ~= nil then image2 = "/bitmaps/models/" .. rfsuite.session.modelID .. ".png" end

            status.gfx_model = rfsuite.utils.loadImage(image1, image2, default_image)

            lcd.invalidate()
        end
        lastName = rfsuite.session.craftName
        lastID = rfsuite.session.modelID

        if status.linkUP == false then status.linkUPTime = os.clock() end

        if status.linkUP == true then

            if status.linkUPTime == nil then status.linkUPTime = 0 end

            if status.linkUPTime ~= nil and ((tonumber(os.clock()) - tonumber(status.linkUPTime)) >= 5) then
                -- voltage alerts
                playVoltage(widget)
                -- governor callouts
                playGovernor(widget)
                -- rpm diff
                playRPMDiff(widget)
                -- rpm
                playRPM(widget)
                -- current
                playCurrent(widget)
                -- fuel
                playFuel(widget)
                -- lq
                playLQ(widget)
                -- esc
                playESC(widget)
                -- mcu
                playMCU(widget)
                -- timer
                playTIMER(widget)
                -- timer alarm
                playTIMERALARM(widget)

                if ((tonumber(os.clock()) - tonumber(status.linkUPTime)) >= 10) then

                    -- IDLE
                    if status.switchIdlelowParam ~= nil and status.switchIdlelowParam:state() == true then
                        if status.switchstatus.idlelow == nil or status.switchstatus.idlelow == false then
                            rfsuite.utils.playFile("status", "switches/idle-l.wav")
                            status.switchstatus.idlelow = true
                            status.switchstatus.idlemedium = false
                            status.switchstatus.idlehigh = false
                        end
                    else
                        status.switchstatus.idlelow = false
                    end
                    if status.switchIdlemediumParam ~= nil and status.switchIdlemediumParam:state() == true then
                        if status.switchstatus.idlemedium == nil or status.switchstatus.idlemedium == false then
                            rfsuite.utils.playFile("status", "switches/idle-m.wav")
                            status.switchstatus.idlelow = false
                            status.switchstatus.idlemedium = true
                            status.switchstatus.idlehigh = false
                        end
                    else
                        status.switchstatus.idlemedium = false
                    end
                    if status.switchIdlehighParam ~= nil and status.switchIdlehighParam:state() == true then
                        if status.switchstatus.idlehigh == nil or status.switchstatus.idlehigh == false then
                            rfsuite.utils.playFile("status", "switches/idle-h.wav")
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
                            rfsuite.utils.playFile("status", "switches/rates-l.wav")
                            status.switchstatus.rateslow = true
                            status.switchstatus.ratesmedium = false
                            status.switchstatus.rateshigh = false
                        end
                    else
                        status.switchstatus.rateslow = false
                    end
                    if status.switchratesmediumParam ~= nil and status.switchratesmediumParam:state() == true then
                        if status.switchstatus.ratesmedium == nil or status.switchstatus.ratesmedium == false then
                            rfsuite.utils.playFile("status", "switches/rates-m.wav")
                            status.switchstatus.rateslow = false
                            status.switchstatus.ratesmedium = true
                            status.switchstatus.rateshigh = false
                        end
                    else
                        status.switchstatus.ratesmedium = false
                    end
                    if status.switchrateshighParam ~= nil and status.switchrateshighParam:state() == true then
                        if status.switchstatus.rateshigh == nil or status.switchstatus.rateshigh == false then
                            rfsuite.utils.playFile("status", "switches/rates-h.wav")
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
                            rfsuite.utils.playFile("status", "switches/rescue-on.wav")
                            status.switchstatus.rescueon = true
                            status.switchstatus.rescueoff = false
                        end
                    else
                        status.switchstatus.rescueon = false
                    end
                    if status.switchrescueoffParam ~= nil and status.switchrescueoffParam:state() == true then
                        if status.switchstatus.rescueoff == nil or status.switchstatus.rescueoff == false then
                            rfsuite.utils.playFile("status", "switches/rescue-off.wav")
                            status.switchstatus.rescueon = false
                            status.switchstatus.rescueoff = true
                        end
                    else
                        status.switchstatus.rescueoff = false
                    end

                    -- BBL
                    if status.switchbblonParam ~= nil and status.switchbblonParam:state() == true then
                        if status.switchstatus.bblon == nil or status.switchstatus.bblon == false then
                            rfsuite.utils.playFile("status", "switches/bbl-on.wav")
                            status.switchstatus.bblon = true
                            status.switchstatus.bbloff = false
                        end
                    else
                        status.switchstatus.bblon = false
                    end
                    if status.switchbbloffParam ~= nil and status.switchbbloffParam:state() == true then
                        if status.switchstatus.bbloff == nil or status.switchstatus.bbloff == false then
                            rfsuite.utils.playFile("status", "switches/bbl-off.wav")
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

                    local armSource = rfsuite.tasks.telemetry.getSensorSource("armflags")
                    if armSource then
                        local isArmed = armSource:value()
                        if isArmed == 0 or isArmed == 2 then
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
                            rfsuite.utils.playFile("status", "alerts/lowfuel.wav")

                            -- system.playNumber(status.sensors.voltage / 100, 2, 2)
                            if status.alrthptParam == true then system.playHaptic("- . -") end
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
                                rfsuite.utils.playFile("status", "alerts/lowvoltage.wav")
                                -- system.playNumber(status.sensors.voltage / 100, 2, 2)
                                if status.alrthptParam == true then system.playHaptic("- . -") end
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

function status.create(widget)

    status.initTime = os.clock()

    status.lastBitmap = model.bitmap()
    default_image = lcd.loadBitmap(model.bitmap()) or rfsuite.utils.loadImage("widgets/status/default_image.png") or nil

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

function status.configure(widget)
    status.isInConfiguration = true

    local line
    local field

    local triggerpanel = form.addExpansionPanel(i18n.get("widgets.status.txt_triggers"))
    triggerpanel:open(false)

    -- line = triggerpanel:addLine("Arm switch")
    -- armswitch = form.addSwitchField(line, form.getFieldSlots(line)[0], function()
    --     return armswitchParam
    -- end, function(value)
    --     armswitchParam = value
    -- end)

    line = triggerpanel:addLine(i18n.get("widgets.status.txt_idleupswitch"))
    local idleupswitch = form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.idleupswitchParam
    end, function(value)
        status.idleupswitchParam = value
    end)

    line = triggerpanel:addLine("    " .. i18n.get("widgets.status.txt_delaybeforeactive"))
    field = form.addNumberField(line, nil, 5, 60, function()
        return status.idleupdelayParam
    end, function(value)
        status.idleupdelayParam = value
    end)
    field:default(5)
    field:suffix("s")

    local timerpanel = form.addExpansionPanel(i18n.get("widgets.status.txt_timerconfiguration"))
    timerpanel:open(false)

    timeTable = {{i18n.get("widgets.status.txt_disabled"), 0}, {"00:30", 30}, {"01:00", 60}, {"01:30", 90}, {"02:00", 120}, {"02:30", 150}, {"03:00", 180}, {"03:30", 210}, {"04:00", 240}, {"04:30", 270}, {"05:00", 300}, {"05:30", 330}, {"06:00", 360}, {"06:30", 390}, {"07:00", 420}, {"07:30", 450}, {"08:00", 480}, {"08:30", 510}, {"09:00", 540}, {"09:30", 570}, {"10:00", 600}, {"10:30", 630}, {"11:00", 660}, {"11:30", 690},
                 {"12:00", 720}, {"12:30", 750}, {"13:00", 780}, {"13:30", 810}, {"14:00", 840}, {"14:30", 870}, {"15:00", 900}, {"15:30", 930}, {"16:00", 960}, {"16:30", 990}, {"17:00", 1020}, {"17:30", 1050}, {"18:00", 1080}, {"18:30", 1110}, {"19:00", 1140}, {"19:30", 1170}, {"20:00", 1200}}

    line = timerpanel:addLine(i18n.get("widgets.status.txt_playalarmat"))
    form.addChoiceField(line, nil, timeTable, function()
        return status.timeralarmParam
    end, function(newValue)
        status.timeralarmParam = newValue
    end)

    line = timerpanel:addLine(i18n.get("widgets.status.txt_vibrate"))
    form.addBooleanField(line, nil, function()
        return status.timeralarmVibrateParam
    end, function(newValue)
        status.timeralarmVibrateParam = newValue
    end)

    local batterypanel = form.addExpansionPanel(i18n.get("widgets.status.txt_battery_configuration"))
    batterypanel:open(false)

    -- BATTERY CELLS
    line = batterypanel:addLine(i18n.get("widgets.status.txt_cells"))
    field = form.addNumberField(line, nil, 1, 14, function()
        return status.cellsParam
    end, function(value)
        status.cellsParam = value
    end)
    field:default(6)

    -- BATTERY MAX
    line = batterypanel:addLine(i18n.get("widgets.status.txt_max_cell_voltage"))
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.maxCellVoltage
    end, function(value)
        status.maxCellVoltage = value
    end)
    field:default(430)
    field:decimals(2)
    field:suffix("V")

    -- BATTERY FULL
    line = batterypanel:addLine(i18n.get("widgets.status.txt_min_cell_voltage"))
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.minCellVoltage
    end, function(value)
        status.minCellVoltage = value
    end)
    field:default(330)
    field:decimals(2)
    field:suffix("V")

    -- BATTERY WARN
    line = batterypanel:addLine(i18n.get("widgets.status.txt_warn_cell_voltage"))
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.warnCellVoltage
    end, function(value)
        status.warnCellVoltage = value
    end)
    field:default(350)
    field:decimals(2)
    field:suffix("V")

    -- LOW FUEL announcement
    line = batterypanel:addLine(i18n.get("widgets.status.txt_low_fuel_percentage"))
    field = form.addNumberField(line, nil, 0, 1000, function()
        return status.lowfuelParam
    end, function(value)
        status.lowfuelParam = value
    end)
    field:default(20)
    field:suffix("%")

    -- ALERT ON
    line = batterypanel:addLine(i18n.get("widgets.status.txt_play_alerton"))
    form.addChoiceField(line, nil, {{i18n.get("widgets.status.txt_low_voltage"), 0}, {i18n.get("widgets.status.txt_low_fuel"), 1}, {i18n.get("widgets.status.txt_low_fuel_voltage"), 2}, {i18n.get("widgets.status.txt_disabled"), 3}}, function()
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
    line = batterypanel:addLine("     " .. i18n.get("widgets.status.txt_interval"))
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
    line = batterypanel:addLine("     " .. i18n.get("widgets.status.txt_vibrate"))
    plalrthap = form.addBooleanField(line, nil, function()
        return status.alrthptParam
    end, function(newValue)
        status.alrthptParam = newValue
    end)
    if status.alertonParam == 3 then
        plalrthap:enable(false)
    else
        plalrthap:enable(true)
    end

    local switchpanel = form.addExpansionPanel(i18n.get("widgets.status.txt_switch_announcements"))
    switchpanel:open(false)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_idlespeedlow"))
    form.addSwitchField(line, nil, function()
        return status.switchIdlelowParam
    end, function(value)
        status.switchIdlelowParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_idlespeedmedium"))
    form.addSwitchField(line, nil, function()
        return status.switchIdlemediumParam
    end, function(value)
        status.switchIdlemediumParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_idlespeedhigh"))
    form.addSwitchField(line, nil, function()
        return status.switchIdlehighParam
    end, function(value)
        status.switchIdlehighParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_rateslow"))
    form.addSwitchField(line, nil, function()
        return status.switchrateslowParam
    end, function(value)
        status.switchrateslowParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_ratesmedium"))
    form.addSwitchField(line, nil, function()
        return status.switchratesmediumParam
    end, function(value)
        status.switchratesmediumParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_rateshigh"))
    form.addSwitchField(line, nil, function()
        return status.switchrateshighParam
    end, function(value)
        status.switchrateshighParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_rescueon"))
    form.addSwitchField(line, nil, function()
        return status.switchrescueonParam
    end, function(value)
        status.switchrescueonParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_rescueoff"))
    form.addSwitchField(line, nil, function()
        return status.switchrescueoffParam
    end, function(value)
        status.switchrescueoffParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_bblon"))
    form.addSwitchField(line, nil, function()
        return status.switchbblonParam
    end, function(value)
        status.switchbblonParam = value
    end)

    line = switchpanel:addLine(i18n.get("widgets.status.txt_bbloff"))
    form.addSwitchField(line, nil, function()
        return status.switchbbloffParam
    end, function(value)
        status.switchbbloffParam = value
    end)

    local announcementpanel = form.addExpansionPanel(i18n.get("widgets.status.txt_telemetry_announcements"))
    announcementpanel:open(false)

    -- announcement VOLTAGE READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_voltage"))
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementVoltageSwitchParam
    end, function(value)
        status.announcementVoltageSwitchParam = value
    end)

    -- announcement RPM READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_rpm"))
    form.addSwitchField(line, nil, function()
        return status.announcementRPMSwitchParam
    end, function(value)
        status.announcementRPMSwitchParam = value
    end)

    -- announcement CURRENT READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_current"))
    form.addSwitchField(line, nil, function()
        return status.announcementCurrentSwitchParam
    end, function(value)
        status.announcementCurrentSwitchParam = value
    end)

    -- announcement FUEL READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_fuel"))
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementFuelSwitchParam
    end, function(value)
        status.announcementFuelSwitchParam = value
    end)

    -- announcement LQ READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_lq"))
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementLQSwitchParam
    end, function(value)
        status.announcementLQSwitchParam = value
    end)

    -- announcement LQ READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_esc_temperature"))
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementESCSwitchParam
    end, function(value)
        status.announcementESCSwitchParam = value
    end)

    -- announcement MCU READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_mcu_temperature"))
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementMCUSwitchParam
    end, function(value)
        status.announcementMCUSwitchParam = value
    end)

    -- announcement TIMER READING
    line = announcementpanel:addLine(i18n.get("widgets.status.txt_timer"))
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return status.announcementTimerSwitchParam
    end, function(value)
        status.announcementTimerSwitchParam = value
    end)

    local govalertpanel = form.addExpansionPanel(i18n.get("widgets.status.txt_governor_announcements"))
    govalertpanel:open(false)

    -- TITLE DISPLAY
    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.OFF"))
    form.addBooleanField(line, nil, function()
        return status.governorOFFParam
    end, function(newValue)
        status.governorOFFParam = newValue
    end)

    -- TITLE DISPLAY
    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.IDLE"))
    form.addBooleanField(line, nil, function()
        return status.governorIDLEParam
    end, function(newValue)
        status.governorIDLEParam = newValue
    end)

    -- TITLE DISPLAY
    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.SPOOLUP"))
    form.addBooleanField(line, nil, function()
        return status.governorSPOOLUPParam
    end, function(newValue)
        status.governorSPOOLUPParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.RECOVERY"))
    form.addBooleanField(line, nil, function()
        return status.governorRECOVERYParam
    end, function(newValue)
        status.governorRECOVERYParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.ACTIVE"))
    form.addBooleanField(line, nil, function()
        return status.governorACTIVEParam
    end, function(newValue)
        status.governorACTIVEParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.THROFF"))
    form.addBooleanField(line, nil, function()
        return status.governorTHROFFParam
    end, function(newValue)
        status.governorTHROFFParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.LOSTHS"))
    form.addBooleanField(line, nil, function()
        return status.governorLOSTHSParam
    end, function(newValue)
        status.governorLOSTHSParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.AUTOROT"))
    form.addBooleanField(line, nil, function()
        return status.governorAUTOROTParam
    end, function(newValue)
        status.governorAUTOROTParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.BAILOUT"))
    form.addBooleanField(line, nil, function()
        return status.governorBAILOUTParam
    end, function(newValue)
        status.governorBAILOUTParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.DISABLED"))
    form.addBooleanField(line, nil, function()
        return status.governorDISABLEDParam
    end, function(newValue)
        status.governorDISABLEDParam = newValue
    end)

    line = govalertpanel:addLine("  " .. i18n.get("widgets.governor.DISARMED"))
    form.addBooleanField(line, nil, function()
        return status.governorDISARMEDParam
    end, function(newValue)
        status.governorDISARMEDParam = newValue
    end)

    line = govalertpanel:addLine("   " .. i18n.get("widgets.governor.UNKNOWN"))
    form.addBooleanField(line, nil, function()
        return status.governorUNKNOWNParam
    end, function(newValue)
        status.governorUNKNOWNParam = newValue
    end)

    local displaypanel = form.addExpansionPanel(i18n.get("widgets.status.txt_customise_display"))
    displaypanel:open(false)

    line = displaypanel:addLine(i18n.get("widgets.status.txt_box1"))
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox1Param
    end, function(newValue)
        status.layoutBox1Param = newValue
    end)

    line = displaypanel:addLine(i18n.get("widgets.status.txt_box2"))
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox2Param
    end, function(newValue)
        status.layoutBox2Param = newValue
    end)

    line = displaypanel:addLine(i18n.get("widgets.status.txt_box3"))
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox3Param
    end, function(newValue)
        status.layoutBox3Param = newValue
    end)

    line = displaypanel:addLine(i18n.get("widgets.status.txt_box4"))
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox4Param
    end, function(newValue)
        status.layoutBox4Param = newValue
    end)

    line = displaypanel:addLine(i18n.get("widgets.status.txt_box5"))
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox5Param
    end, function(newValue)
        status.layoutBox5Param = newValue
    end)

    line = displaypanel:addLine(i18n.get("widgets.status.txt_box6"))
    form.addChoiceField(line, nil, status.layoutOptions, function()
        return status.layoutBox6Param
    end, function(newValue)
        status.layoutBox6Param = newValue
    end)

    -- TITLE DISPLAY
    line = displaypanel:addLine(i18n.get("widgets.status.txt_display_title"))
    form.addBooleanField(line, nil, function()
        return status.titleParam
    end, function(newValue)
        status.titleParam = newValue
    end)

    -- MAX MIN DISPLAY
    line = displaypanel:addLine(i18n.get("widgets.status.txt_display_maxmin"))
    form.addBooleanField(line, nil, function()
        return status.maxminParam
    end, function(newValue)
        status.maxminParam = newValue
    end)

    -- color mode
    line = displaypanel:addLine(i18n.get("widgets.status.txt_usecolours"))
    form.addBooleanField(line, nil, function()
        return status.statusColorParam
    end, function(newValue)
        status.statusColorParam = newValue
    end)

    -- custom sensors
    line = form.addLine(i18n.get("widgets.status.txt_customsensors"), displaypanel)

    -- custom1
    line = displaypanel:addLine("   " .. i18n.get("widgets.status.txt_customsensor_1"))
    form.addSensorField(line, nil, function()
        return status.customSensorParam1
    end, function(newValue)
        status.customSensorParam1 = newValue
    end)

    -- custom2
    line = displaypanel:addLine("   " .. i18n.get("widgets.status.txt_customsensor_2"))
    form.addSensorField(line, nil, function()
        return status.customSensorParam2
    end, function(newValue)
        status.customSensorParam2 = newValue
    end)

    local advpanel = form.addExpansionPanel(i18n.get("widgets.status.txt_advanced"))
    advpanel:open(false)

    line = advpanel:addLine(i18n.get("widgets.status.txt_governor"))
    extgov = form.addChoiceField(line, nil, {{i18n.get("widgets.status.txt_rfgovernor"), 0}, {i18n.get("widgets.status.txt_extgovernor"), 1}}, function()
        return status.govmodeParam
    end, function(newValue)
        status.govmodeParam = newValue
    end)

    line = form.addLine(i18n.get("widgets.status.txt_tempconversion"), advpanel)

    line = advpanel:addLine("    " .. i18n.get("widgets.status.txt_esc"))
    form.addChoiceField(line, nil, {{i18n.get("widgets.status.txt_disable"), 1}, {"°C -> °F", 2}, {"°F -> °C", 3}}, function()
        return status.tempconvertParamESC
    end, function(newValue)
        status.tempconvertParamESC = newValue
    end)

    line = advpanel:addLine("   " .. i18n.get("widgets.status.txt_mcu"))
    form.addChoiceField(line, nil, {{"Disable", 1}, {"°C -> °F", 2}, {"°F -> °C", 3}}, function()
        return status.tempconvertParamMCU
    end, function(newValue)
        status.tempconvertParamMCU = newValue
    end)

    line = form.addLine(i18n.get("widgets.status.txt_voltage"), advpanel)

    -- LVannouncement DISPLAY
    line = advpanel:addLine("    " .. i18n.get("widgets.status.txt_sensitivity"))
    form.addChoiceField(line, nil, {{i18n.get("widgets.status.txt_high"), 1}, {i18n.get("widgets.status.txt_medium"), 2}, {i18n.get("widgets.status.txt_low"), 3}}, function()
        return status.lowvoltagsenseParam
    end, function(newValue)
        status.lowvoltagsenseParam = newValue
    end)

    line = advpanel:addLine("    " .. i18n.get("widgets.status.txt_sagcompensation"))
    field = form.addNumberField(line, nil, 0, 10, function()
        return status.sagParam
    end, function(value)
        status.sagParam = value
    end)
    field:default(5)
    field:suffix("s")
    -- field:decimals(1)

    -- LVSTICK MONITORING
    line = advpanel:addLine("    " .. i18n.get("widgets.status.txt_gimbalmonitoring"))
    form.addChoiceField(line, nil, {{i18n.get("widgets.status.txt_disabled"):upper(), 0}, -- 
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

    line = advpanel:addLine("       " .. i18n.get("widgets.status.txt_stickcutoff"))
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

    line = form.addLine(i18n.get("widgets.status.txt_headspeed"), advpanel)

    -- TITLE DISPLAY
    line = advpanel:addLine("   " .. i18n.get("widgets.status.txt_alertonrpmdiff"))
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
    line = advpanel:addLine("   " .. i18n.get("widgets.status.txt_alertifdifflt"))
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
    line = advpanel:addLine(i18n.get("widgets.status.txt_announcement_interval"))
    form.addChoiceField(line, nil, {{"5s", 5}, {"10s", 10}, {"15s", 15}, {"20s", 20}, {"25s", 25}, {"30s", 30}, {"35s", 35}, {"40s", 40}, {"45s", 45}, {"50s", 50}, {"55s", 55}, {"60s", 60}, {i18n.get("widgets.status.txt_norepeat"), 50000}}, function()
        return status.announcementIntervalParam
    end, function(newValue)
        status.announcementIntervalParam = newValue
    end)

    -- calcfuel
    line = advpanel:addLine(i18n.get("widgets.status.txt_calcfuel_local"))
    form.addBooleanField(line, nil, function()
        return status.calcfuelParam
    end, function(newValue)
        status.calcfuelParam = newValue
    end)

    -- display warning about sensors
    line = advpanel:addLine(i18n.get("widgets.status.txt_warnsensors"))
    form.addBooleanField(line, nil, function()
        return status.sensorwarningParam
    end, function(newValue)
        status.sensorwarningParam = newValue
    end)

    resetALL()

    return widget
end

-- MAIN WAKEUP FUNCTION. THIS SIMPLY FARMS OUT AT DIFFERING SCHEDULES TO SUB FUNCTIONS
function status.wakeup(widget)
    local schedulerUI = lcd.isVisible() and 0.5 or 2 -- Set interval based on visibility

    -- Run UI at reduced interval to minimize CPU load
    local now = os.clock()
    if (now - status.wakeupSchedulerUI) >= schedulerUI then
        status.wakeupSchedulerUI = now
        wakeupUI()
        -- collectgarbage()  -- Uncomment if garbage collection is needed
    end
end

function status.paint(widget)

    if not rfsuite.utils.ethosVersionAtLeast() then
        screenError(string.format("ETHOS < V%d.%d.%d", 
            rfsuite.config.ethosVersion[1], 
            rfsuite.config.ethosVersion[2], 
            rfsuite.config.ethosVersion[3])
        )
        return
    elseif not rfsuite.tasks.active() then

        if (os.clock() - status.initTime) >= 2 then screenError(i18n.get("widgets.status.txt_please_enable_bgtask"):upper()) end
        lcd.invalidate()
        return
    else

        status.isVisible = lcd.isVisible()
        status.isDARKMODE = lcd.darkMode()

        status.isInConfiguration = false

        local cellVoltage = status.warnCellVoltage / 100

        if status.sensors.voltage ~= nil then
            -- we use status.lowvoltagsenseParam is use to raise or lower sensitivity
            local zippo
            if status.lowvoltagsenseParam == 1 then
                zippo = 0.2
            elseif status.lowvoltagsenseParam == 2 then
                zippo = 0.1
            else
                zippo = 0
            end
            -- low
            if status.cellsParam and status.sensors.voltage / 100 < ((cellVoltage * status.cellsParam) + zippo) then
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
            if status.cellsParam and status.sensors.voltage / 100 < (((cellVoltage + 0.2) * status.cellsParam) + zippo) then
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

        local theme = getThemeInfo()

        local w, h = lcd.getWindowSize()
        local sensorTITLE

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
            if theme and theme.supportedRADIO ~= true then
                screenError(i18n.get("widgets.status.txt_unknown") .. " " .. environment.board)
                return
            end

            -- widget size
            local validSizes = {{w = 784, h = 294}, -- X20, X20PRO etc
            {w = 784, h = 316}, -- X20, X20PRO etc (no title)
            {w = 472, h = 191}, -- TWXLITE,X18,X18S
            {w = 472, h = 210}, -- TWXLITE,X18,X18S (no title)
            {w = 630, h = 236}, -- X14
            {w = 630, h = 258}, -- X14 (no title)                              
            {w = 472, h = 158} -- X10,X12
            }

            local isValidSize = false
            for _, size in ipairs(validSizes) do
                if w == size.w and h == size.h then
                    isValidSize = true
                    break
                end
            end

            -- hard error
            if not isValidSize then
                screenError(i18n.get("widgets.status.txt_displaysize_invalid"))
                return
            end

            -- move on to display as no more hard errors
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
                    sensorTITLE = i18n.get("widgets.status.title_fuel")
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

                sensorVALUE = rfsuite.utils.round(status.sensors.rpm,0)
                
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

                sensorVALUE = rfsuite.utils.round(status.sensors.temp_esc / 100, 0)

                if sensorVALUE < 1 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_tempESC
                else
                    sensorTITLE = ""
                end

                if status.sensorTempESCMin == 0 or status.sensorTempESCMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = rfsuite.utils.round(status.sensorTempESCMin / 100, 0)
                end

                if status.sensorTempESCMax == 0 or status.sensorTempESCMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = rfsuite.utils.round(status.sensorTempESCMax / 100, 0)
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

                sensorVALUE = rfsuite.utils.round(status.sensors.temp_mcu / 100, 0)

                if sensorVALUE < 1 then sensorVALUE = 0 end

                if status.titleParam == true then
                    sensorTITLE = theme.title_tempMCU
                else
                    sensorTITLE = ""
                end

                if status.sensorTempMCUMin == 0 or status.sensorTempMCUMin == nil or status.theTIME == 0 then
                    sensorMIN = "-"
                else
                    sensorMIN = rfsuite.utils.round(status.sensorTempMCUMin / 100, 0)
                end

                if status.sensorTempMCUMax == 0 or status.sensorTempMCUMax == nil or status.theTIME == 0 then
                    sensorMAX = "-"
                else
                    sensorMAX = rfsuite.utils.round(status.sensorTempMCUMax / 100, 0)
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
                str = SecondsToClock(status.theTIME)
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
            status.sensordisplay[sensorTGT]['warn'] = govColorFlag(sensorVALUE)
            status.sensordisplay[sensorTGT]['min'] = sensorMIN
            status.sensordisplay[sensorTGT]['max'] = sensorMAX
            status.sensordisplay[sensorTGT]['unit'] = sensorUNIT

            -- CRAFT NAME
            local sensorTGT = 'craft_name'
            local craftName = "UNKNOWN"
            local modelID = nil
            if rfsuite.session.craftName ~= nil then craftName = rfsuite.session.craftName end
            if rfsuite.session.modelID ~= nil then modelID = rfsuite.session.modelID end

            status.sensordisplay[sensorTGT] = {}
            status.sensordisplay[sensorTGT]['title'] = ""
            status.sensordisplay[sensorTGT]['value'] = craftName
            status.sensordisplay[sensorTGT]['warn'] = nil
            status.sensordisplay[sensorTGT]['min'] = nil
            status.sensordisplay[sensorTGT]['max'] = nil
            status.sensordisplay[sensorTGT]['unit'] = ""

            -- CUSTOM SENSOR #1

            if status.customSensorParam1 ~= nil then

                local csSensor = status.customSensorParam1
                if csSensor:value() == nil then
                    sensorVALUE = "-"
                else
                    sensorVALUE = csSensor:value()
                    if csSensor:protocolDecimals() == 0 then sensorVALUE = math.floor(sensorVALUE) end
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
                status.sensordisplay[sensorTGT]['title'] = i18n.get("widgets.status.txt_customsensor_1"):upper()
                status.sensordisplay[sensorTGT]['value'] = i18n.get("widgets.status.txt_na")
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
                    if csSensor:protocolDecimals() == 0 then sensorVALUE = math.floor(sensorVALUE) end

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
                status.sensordisplay[sensorTGT]['title'] = i18n.get("widgets.status.txt_customsensor_2"):upper()
                status.sensordisplay[sensorTGT]['value'] = i18n.get("widgets.status.txt_na")
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
                if sensorTGT == 17 then sensorTGT = 'mah' end
                if sensorTGT == 18 then sensorTGT = 'craft_name' end
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
 
                    telemetryBox(posX, posY, boxW, boxH, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                else

                    if sensorTGT == 'customsensor1' or sensorTGT == 'customsensor2' then

                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            sensorTITLE = status.sensordisplay[sensorTGT]['title']
                            telemetryBox(posX, posY, boxW, boxH, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, "", "")
                        end
                    end

                    if sensorTGT == 'customsensor1_2' then
                        -- SENSOR1 & 2
                        sensorTGT = "customsensor1"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "customsensor2"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'image' then
                        -- IMAGE
                        telemetryBoxImage(posX, posY, boxW, boxH, status.gfx_model)
                    end

                    if sensorTGT == 'image__gov' then
                        -- IMAGE + GOVERNOR        
                        if status.gfx_model ~= nil then
                            telemetryBoxImage(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), status.gfx_model)
                        else
                            telemetryBoxImage(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), default_image)
                        end
                        sensorTGT = "governor"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'lq__gov' then
                        -- LQ + GOV
                        sensorTGT = "rssi"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "governor"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

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
                            telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "timer"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'temp_esc__temp_mcu' then

                        sensorTGT = "temp_esc"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "temp_mcu"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'voltage__fuel' then

                        sensorTGT = "voltage"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "fuel"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'voltage__current' then

                        sensorTGT = "voltage"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "current"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'voltage__mah' then

                        sensorTGT = "voltage"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY, boxW, boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "mah"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW, boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'rssi_timer_temp_esc_temp_mcu' then

                        sensorTGT = "rssi"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY, boxW / 2 - (theme.colSpacing / 2), boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "timer"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX + boxW / 2 + (theme.colSpacing / 2), posY, boxW / 2 - (theme.colSpacing / 2), boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "temp_esc"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX, posY + boxH / 2 + (theme.colSpacing / 2), boxW / 2 - (theme.colSpacing / 2), boxH / 2 - theme.colSpacing / 2, sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end

                        sensorTGT = "temp_mcu"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            smallBOX = true
                            telemetryBox(posX + boxW / 2 + (theme.colSpacing / 2), posY + boxH / 2 + (theme.colSpacing / 2), boxW / 2 - (theme.colSpacing / 2), boxH / 2 - (theme.colSpacing / 2), sensorTITLE, sensorVALUE, sensorUNIT, smallBOX, sensorWARN, sensorMIN, sensorMAX)
                        end
                    end

                    if sensorTGT == 'max_current' then

                        sensorTGT = "current"
                        if status.sensordisplay[sensorTGT] then
                            sensorVALUE = status.sensordisplay[sensorTGT]['value']
                            sensorUNIT = status.sensordisplay[sensorTGT]['unit']
                            sensorMIN = status.sensordisplay[sensorTGT]['min']
                            sensorMAX = status.sensordisplay[sensorTGT]['max']
                            sensorWARN = status.sensordisplay[sensorTGT]['warn']
                            sensorTITLE = status.sensordisplay[sensorTGT]['title']

                            if sensorMAX == "-" or sensorMAX == nil then sensorMAX = 0 end

                            smallBOX = false
                            telemetryBox(posX, posY, boxW, boxH, i18n.get("widgets.status.txt_max"):upper() .. " " .. sensorTITLE, sensorMAX, sensorUNIT, smallBOX)
                        end
                    end

                end

                c = c + 1
            end

            -- initiate timed sensor validation
            local validateSensors = {}
            if rfsuite.tasks and rfsuite.tasks.telemetry then validateSensors = rfsuite.tasks.telemetry.validateSensors() end

            if status.linkUP == false then
                noTelem()
                status.initTime = os.clock()
            elseif (os.clock() - status.initTime) >= 10 and validateSensors and (#rfsuite.tasks.telemetry.validateSensors() > 0) then
                if status.sensorwarningParam == true or status.sensorwarningParam == nil then
                    missingSensors()
                end
            elseif status.idleupswitchParam and status.idleupswitchParam:state() then
                local armSource = rfsuite.tasks.telemetry.getSensorSource("armflags")
                if armSource and armSource:value() then
                    isArmed = math.floor(armSource:value())
                    if isArmed == 1 or isArmed == 3 then
                        if status.theTIME <= status.idleupdelayParam then
                            local count = math.floor(status.idleupdelayParam - status.theTIME)
                            message(i18n.get("widgets.status.txt_initialising").. " ".. count + 1)
                        end
                    end
                end
                status.initTime = os.clock()
            end
        end
    end

end

function status.i18n()
    governorMap = buildGovernorMap()
    status.layoutOptions = buildLayoutOptions()
end    

return status
