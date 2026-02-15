--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local app = rfsuite.app
local tasks = rfsuite.tasks
local prefs = rfsuite.preferences
local session = rfsuite.session

local sin = math.sin
local cos = math.cos
local rad = math.rad
local floor = math.floor
local max = math.max
local min = math.min

local formFields = app.formFields
local radio = app.radio

local MSP_ATTITUDE = 108

local state = {
    pageIdx = nil,
    wakeupEnabled = false,
    dataLoaded = false,
    saving = false,
    triggerSave = false,
    dirty = false,
    invalidateAt = 0,
    attitudeSamplePeriod = 0.08,
    lastAttitudeAt = 0,
    pendingAttitude = false,
    pendingAt = 0,
    pendingTimeout = 1.0,
    pollingEnabled = false,
    display = {
        roll_degrees = 0,
        pitch_degrees = 0,
        yaw_degrees = 0,
        gyro_1_alignment = 0,
        gyro_2_alignment = 0,
        mag_alignment = 0
    },
    live = {
        roll = 0,
        pitch = 0,
        yaw = 0
    }
}

local magAlignChoices = {
    {"Default", 1},
    {"CW 0 deg", 2},
    {"CW 90 deg", 3},
    {"CW 180 deg", 4},
    {"CW 270 deg", 5},
    {"CW 0 deg flip", 6},
    {"CW 90 deg flip", 7},
    {"CW 180 deg flip", 8},
    {"CW 270 deg flip", 9},
    {"Custom", 10}
}

local function toSigned16(v)
    v = tonumber(v) or 0
    if v > 32767 then return v - 65536 end
    return v
end

local function toU16(v)
    v = floor(tonumber(v) or 0)
    if v < -32768 then v = -32768 end
    if v > 32767 then v = 32767 end
    if v < 0 then return v + 65536 end
    return v
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function markDirty()
    state.dirty = true
    if app and app.ui and app.ui.setPageDirty then app.ui.setPageDirty(true) end
    lcd.invalidate()
end

local function parseAttitude(buf)
    local m = tasks and tasks.msp and tasks.msp.mspHelper
    if not m then return false end

    local rollRaw = m.readS16(buf)
    local pitchRaw = m.readS16(buf)
    local yawRaw = m.readS16(buf)
    if rollRaw == nil or pitchRaw == nil or yawRaw == nil then return false end

    -- MSP_ATTITUDE provides roll/pitch in 0.1 deg and heading/yaw in deg.
    state.live.roll = (tonumber(rollRaw) or 0) / 10.0
    state.live.pitch = (tonumber(pitchRaw) or 0) / 10.0
    state.live.yaw = tonumber(yawRaw) or 0
    return true
end

local function requestAttitude()
    if state.pendingAttitude then return false end
    if not (tasks and tasks.msp and tasks.msp.mspQueue) then return false end

    state.pendingAttitude = true
    state.pendingAt = os.clock()

    return tasks.msp.mspQueue:add({
        command = MSP_ATTITUDE,
        uuid = "alignment.attitude",
        processReply = function(_, buf)
            parseAttitude(buf)
            state.pendingAttitude = false
        end,
        errorHandler = function()
            state.pendingAttitude = false
        end,
        simulatorResponse = {}
    })
end

local function readData()
    state.dataLoaded = false

    local boardAPI = tasks.msp.api.load("BOARD_ALIGNMENT_CONFIG")
    local sensorAPI = tasks.msp.api.load("SENSOR_ALIGNMENT")
    if not boardAPI or not sensorAPI then
        rfsuite.utils.log("Alignment read failed: API unavailable", "error")
        return
    end

    boardAPI.setCompleteHandler(function()
        state.display.roll_degrees = toSigned16(boardAPI.readValue("roll_degrees"))
        state.display.pitch_degrees = toSigned16(boardAPI.readValue("pitch_degrees"))
        state.display.yaw_degrees = toSigned16(boardAPI.readValue("yaw_degrees"))

        sensorAPI.setCompleteHandler(function()
            state.display.gyro_1_alignment = clamp(tonumber(sensorAPI.readValue("gyro_1_alignment")) or 0, 0, 255)
            state.display.gyro_2_alignment = clamp(tonumber(sensorAPI.readValue("gyro_2_alignment")) or 0, 0, 255)
            state.display.mag_alignment = clamp(tonumber(sensorAPI.readValue("mag_alignment")) or 0, 0, 9)
            state.dataLoaded = true
            state.dirty = false
            if app and app.ui and app.ui.setPageDirty then app.ui.setPageDirty(false) end
            lcd.invalidate()
        end)

        sensorAPI.setErrorHandler(function()
            rfsuite.utils.log("Alignment read failed: SENSOR_ALIGNMENT", "error")
        end)

        sensorAPI.read()
    end)

    boardAPI.setErrorHandler(function()
        rfsuite.utils.log("Alignment read failed: BOARD_ALIGNMENT_CONFIG", "error")
    end)

    boardAPI.read()
end

local function writeData()
    if state.saving then return end
    state.saving = true

    app.ui.progressDisplay("@i18n(app.msg_saving_settings)@", "@i18n(app.msg_saving_to_fbl)@")

    local boardAPI = tasks.msp.api.load("BOARD_ALIGNMENT_CONFIG")
    local sensorAPI = tasks.msp.api.load("SENSOR_ALIGNMENT")
    local eepromAPI = tasks.msp.api.load("EEPROM_WRITE")

    if not boardAPI or not sensorAPI or not eepromAPI then
        state.saving = false
        app.triggers.closeProgressLoader = true
        rfsuite.utils.log("Alignment save failed: API unavailable", "error")
        return
    end

    boardAPI.setValue("roll_degrees", toU16(state.display.roll_degrees))
    boardAPI.setValue("pitch_degrees", toU16(state.display.pitch_degrees))
    boardAPI.setValue("yaw_degrees", toU16(state.display.yaw_degrees))

    sensorAPI.setValue("gyro_1_alignment", clamp(tonumber(state.display.gyro_1_alignment) or 0, 0, 255))
    sensorAPI.setValue("gyro_2_alignment", clamp(tonumber(state.display.gyro_2_alignment) or 0, 0, 255))
    sensorAPI.setValue("mag_alignment", clamp(tonumber(state.display.mag_alignment) or 0, 0, 9))

    boardAPI.setCompleteHandler(function()
        sensorAPI.setCompleteHandler(function()
            eepromAPI.setCompleteHandler(function()
                state.saving = false
                state.dirty = false
                if app and app.ui and app.ui.setPageDirty then app.ui.setPageDirty(false) end
                app.triggers.closeProgressLoader = true
            end)
            eepromAPI.setErrorHandler(function()
                state.saving = false
                app.triggers.closeProgressLoader = true
                rfsuite.utils.log("Alignment save failed: EEPROM_WRITE", "error")
            end)
            eepromAPI.write()
        end)
        sensorAPI.setErrorHandler(function()
            state.saving = false
            app.triggers.closeProgressLoader = true
            rfsuite.utils.log("Alignment save failed: SENSOR_ALIGNMENT", "error")
        end)
        sensorAPI.write()
    end)
    boardAPI.setErrorHandler(function()
        state.saving = false
        app.triggers.closeProgressLoader = true
        rfsuite.utils.log("Alignment save failed: BOARD_ALIGNMENT_CONFIG", "error")
    end)
    boardAPI.write()
end

local function rotatePoint(x, y, z, rollR, pitchR, yawR)
    local cy = cos(yawR)
    local sy = sin(yawR)
    local cp = cos(pitchR)
    local sp = sin(pitchR)
    local cr = cos(rollR)
    local sr = sin(rollR)

    local x1 = x
    local y1 = y * cr - z * sr
    local z1 = y * sr + z * cr

    local x2 = x1 * cp + z1 * sp
    local y2 = y1
    local z2 = -x1 * sp + z1 * cp

    local x3 = x2 * cy - y2 * sy
    local y3 = x2 * sy + y2 * cy
    local z3 = z2

    return x3, y3, z3
end

local function projectPoint(px, py, pz, cx, cy, scale)
    local d = 7.0
    local f = d / (d - pz)
    local sx = cx + (px * f * scale)
    local sy = cy - (py * f * scale)
    return sx, sy
end

local function drawLine3D(a, b, cx, cy, scale, rr, pr, yr, color)
    local ax, ay, az = rotatePoint(a[1], a[2], a[3], rr, pr, yr)
    local bx, by, bz = rotatePoint(b[1], b[2], b[3], rr, pr, yr)
    local x1, y1 = projectPoint(ax, ay, az, cx, cy, scale)
    local x2, y2 = projectPoint(bx, by, bz, cx, cy, scale)
    lcd.color(color)
    lcd.drawLine(x1, y1, x2, y2)
end

local function drawVisual()
    local w, h = lcd.getWindowSize()
    local x = 0
    local y = floor(form.height() + 2)
    local vw = w - 1
    local vh = h - y - 2
    if vh < 40 then return end

    local isDark = lcd.darkMode()
    local bg = isDark and lcd.RGB(18, 18, 18) or lcd.RGB(245, 245, 245)
    local grid = isDark and lcd.GREY(55) or lcd.GREY(200)
    local mainColor = isDark and lcd.RGB(235, 235, 235) or lcd.RGB(20, 20, 20)
    local accent = isDark and lcd.RGB(255, 200, 80) or lcd.RGB(0, 120, 255)
    local disc = isDark and lcd.RGB(120, 120, 120) or lcd.RGB(170, 170, 170)

    local panelX = x + 4
    local panelY = y + 2
    local panelW = vw - 8
    local panelH = vh - 4

    lcd.color(bg)
    lcd.drawFilledRectangle(panelX, panelY, panelW, panelH)
    lcd.color(grid)
    lcd.drawRectangle(panelX, panelY, panelW, panelH)

    local rr = rad(state.live.roll + state.display.roll_degrees)
    local pr = rad(state.live.pitch + state.display.pitch_degrees)
    local yr = rad(state.live.yaw + state.display.yaw_degrees)

    lcd.font(FONT_XS)
    local liveText = string.format("Live  R:%0.1f  P:%0.1f  Y:%0.1f", state.live.roll, state.live.pitch, state.live.yaw)
    local offsText = string.format("Offset R:%d  P:%d  Y:%d  Mag:%d", state.display.roll_degrees, state.display.pitch_degrees, state.display.yaw_degrees, state.display.mag_alignment)
    local _, th1 = lcd.getTextSize(liveText)
    local _, th2 = lcd.getTextSize(offsText)
    local textPad = 3
    local headerH = th1 + th2 + textPad + 8

    lcd.color(bg)
    lcd.drawFilledRectangle(panelX + 1, panelY + 1, panelW - 2, headerH)
    lcd.color(grid)
    lcd.drawLine(panelX + 1, panelY + headerH, panelX + panelW - 2, panelY + headerH)

    lcd.color(mainColor)
    lcd.drawText(panelX + 8, panelY + 4, liveText, LEFT)
    lcd.drawText(panelX + 8, panelY + 4 + th1 + textPad, offsText, LEFT)

    local gx0 = panelX + 1
    local gy0 = panelY + headerH + 2
    local gw0 = panelW - 2
    local gh0 = panelH - headerH - 3
    if gh0 < 40 then return end

    lcd.color(grid)
    local step = 24
    for gy = gy0 + step, gy0 + gh0 - 1, step do
        lcd.drawLine(gx0, gy, gx0 + gw0, gy)
    end
    for gx = gx0 + step, gx0 + gw0 - 1, step do
        lcd.drawLine(gx, gy0, gx, gy0 + gh0)
    end

    local cx = gx0 + floor(gw0 * 0.5)
    local cy = gy0 + floor(gh0 * 0.62)
    local scale = max(8, min(gw0, gh0) * 0.12)

    local bodyNose = {2.3, 0.0, 0.2}
    local bodyTail = {-2.2, 0.0, 0.1}
    local bodyLeft = {0.3, -0.45, 0.1}
    local bodyRight = {0.3, 0.45, 0.1}
    local mastTop = {0.0, 0.0, 0.8}
    local skidL1 = {0.7, -0.55, -0.55}
    local skidL2 = {-0.8, -0.55, -0.55}
    local skidR1 = {0.7, 0.55, -0.55}
    local skidR2 = {-0.8, 0.55, -0.55}
    local tailUp = {-2.1, 0.0, 0.35}
    local tailDown = {-2.1, 0.0, -0.15}

    local rotorA = {0.0, -1.5, 0.8}
    local rotorB = {0.0, 1.5, 0.8}
    local rotorC = {-1.5, 0.0, 0.8}
    local rotorD = {1.5, 0.0, 0.8}

    drawLine3D(rotorA, rotorB, cx, cy, scale, rr, pr, yr, disc)
    drawLine3D(rotorC, rotorD, cx, cy, scale, rr, pr, yr, disc)

    drawLine3D(bodyTail, bodyNose, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(bodyLeft, bodyNose, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(bodyRight, bodyNose, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(bodyLeft, bodyTail, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(bodyRight, bodyTail, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(bodyTail, mastTop, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(mastTop, bodyNose, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(tailUp, tailDown, cx, cy, scale, rr, pr, yr, accent)
    drawLine3D(skidL1, skidL2, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(skidR1, skidR2, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(skidL1, skidR1, cx, cy, scale, rr, pr, yr, mainColor)
    drawLine3D(skidL2, skidR2, cx, cy, scale, rr, pr, yr, mainColor)

end

local function openPage(opts)
    state.wakeupEnabled = false
    state.pageIdx = opts.idx

    app.lastIdx = opts.idx
    app.lastTitle = opts.title
    app.lastScript = opts.script
    session.lastPage = opts.script

    state.dirty = false
    state.triggerSave = false
    state.saving = false
    state.dataLoaded = false
    state.invalidateAt = 0
    state.lastAttitudeAt = 0
    state.pendingAttitude = false
    state.pendingAt = 0
    state.pollingEnabled = false

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    form.clear()
    app.ui.fieldHeader("Board and Sensor Alignment")

    local line1 = form.addLine("")
    local rowY = radio.linePaddingTop
    local rowH = radio.navbuttonHeight
    local screenW = lcd.getWindowSize()
    local leftPad = 2
    local rightPad = 6
    local gap = 4
    local labelW = 130
    local axisLabelW = 0
    local fieldX = floor(screenW * 0.48)
    local fieldW = screenW - fieldX - rightPad
    if fieldW < 180 then
        fieldX = min(fieldX, screenW - 180 - rightPad)
        fieldW = screenW - fieldX - rightPad
    end
    if fieldX < (leftPad + labelW + gap) then
        fieldX = leftPad + labelW + gap
        fieldW = screenW - fieldX - rightPad
    end

    local slotGap = gap
    local slotW = floor((fieldW - (slotGap * 2)) / 3)
    local labels = {"Roll", "Pitch", "Yaw"}
    local x = fieldX

    form.addStaticText(line1, {x = leftPad, y = rowY, w = labelW, h = rowH}, "Alignment:")

    lcd.font(FONT_STD)
    local wRoll = lcd.getTextSize("Roll ")
    local wPitch = lcd.getTextSize("Pitch ")
    local wYaw = lcd.getTextSize("Yaw ")
    local labelWidths = {wRoll, wPitch, wYaw}

    local slotX1 = fieldX
    local slotX2 = fieldX + slotW + slotGap
    local slotX3 = fieldX + (slotW + slotGap) * 2
    local slotX = {slotX1, slotX2, slotX3}

    local bw1 = clamp(slotW - labelWidths[1] - 2, 30, 56)
    local bw2 = clamp(slotW - labelWidths[2] - 2, 30, 56)
    local bw3 = clamp(slotW - labelWidths[3] - 2, 30, 56)
    local boxWidths = {bw1, bw2, bw3}

    form.addStaticText(line1, {x = slotX[1], y = rowY, w = labelWidths[1], h = rowH}, labels[1])
    formFields[1] = form.addNumberField(line1, {x = slotX[1] + labelWidths[1] + 2, y = rowY, w = boxWidths[1], h = rowH}, -180, 360, function()
        return state.display.roll_degrees
    end, function(v)
        state.display.roll_degrees = floor(v or 0)
        markDirty()
    end)
    formFields[1]:suffix("°")

    form.addStaticText(line1, {x = slotX[2], y = rowY, w = labelWidths[2], h = rowH}, labels[2])
    formFields[2] = form.addNumberField(line1, {x = slotX[2] + labelWidths[2] + 2, y = rowY, w = boxWidths[2], h = rowH}, -180, 360, function()
        return state.display.pitch_degrees
    end, function(v)
        state.display.pitch_degrees = floor(v or 0)
        markDirty()
    end)
    formFields[2]:suffix("°")

    form.addStaticText(line1, {x = slotX[3], y = rowY, w = labelWidths[3], h = rowH}, labels[3])
    formFields[3] = form.addNumberField(line1, {x = slotX[3] + labelWidths[3] + 2, y = rowY, w = boxWidths[3], h = rowH}, -180, 360, function()
        return state.display.yaw_degrees
    end, function(v)
        state.display.yaw_degrees = floor(v or 0)
        markDirty()
    end)
    formFields[3]:suffix("°")

    local line4 = form.addLine("MAG Alignment")
    formFields[4] = form.addChoiceField(line4, {x = fieldX, y = rowY, w = fieldW, h = rowH}, magAlignChoices, function()
        return state.display.mag_alignment + 1
    end, function(v)
        state.display.mag_alignment = clamp((tonumber(v) or 1) - 1, 0, 9)
        markDirty()
    end)

    readData()
    app.triggers.closeProgressLoader = true
    state.wakeupEnabled = true
end

local function onSaveMenu()
    if state.saving then return true end

    if prefs and prefs.general and (prefs.general.save_confirm == false or prefs.general.save_confirm == "false") then
        state.triggerSave = true
        return true
    end

    form.openDialog({
        title = "@i18n(app.modules.profile_select.save_settings)@",
        message = "@i18n(app.modules.profile_select.save_prompt)@",
        buttons = {
            {
                label = "@i18n(app.btn_ok_long)@",
                action = function()
                    state.triggerSave = true
                    return true
                end
            },
            {
                label = "@i18n(app.btn_cancel)@",
                action = function()
                    state.triggerSave = false
                    return true
                end
            }
        },
        options = TEXT_LEFT
    })
    return true
end

local function onReloadMenu()
    app.triggers.triggerReloadFull = true
end

local function wakeup()
    if not state.wakeupEnabled then return end

    if state.triggerSave then
        state.triggerSave = false
        writeData()
        return
    end

    local now = os.clock()
    local dialogs = app and app.dialogs

    -- Do not start movement polling until loaders are gone.
    if not state.pollingEnabled then
        if dialogs and (dialogs.progressDisplay or dialogs.saveDisplay) then
            return
        end
        state.pollingEnabled = true
        state.lastAttitudeAt = 0
    end

    -- Saving path: pause movement MSP calls completely.
    if state.saving or (dialogs and dialogs.saveDisplay) then
        state.pendingAttitude = false
        if (now - state.invalidateAt) >= 0.15 then
            state.invalidateAt = now
            lcd.invalidate()
        end
        return
    end

    if state.pendingAttitude and (now - state.pendingAt) > state.pendingTimeout then
        state.pendingAttitude = false
    end

    if (now - state.lastAttitudeAt) >= state.attitudeSamplePeriod then
        state.lastAttitudeAt = now
        if tasks and tasks.msp and tasks.msp.mspQueue and tasks.msp.mspQueue:isProcessed() then
            requestAttitude()
        end
    end

    if (now - state.invalidateAt) >= 0.08 then
        state.invalidateAt = now
        lcd.invalidate()
    end
end

local function paint()
    drawVisual()
end

local function onNavMenu()
    app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.FAST)
    app.ui.openMainMenuSub("hardware")
    return true
end

local function event(_, category, value)
    if (category == EVT_CLOSE and value == 0) or value == 35 then
        app.ui.openMainMenuSub("hardware")
        return true
    end
end

return {
    reboot = false,
    eepromWrite = false,
    openPage = openPage,
    wakeup = wakeup,
    paint = paint,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    onNavMenu = onNavMenu,
    event = event,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true},
    API = {}
}
