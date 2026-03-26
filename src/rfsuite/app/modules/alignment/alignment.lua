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
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({
    defaultSection = "hardware",
    showProgress = true,
    progressSpeed = rfsuite.app.loaderSpeed.FAST
})

local sin = math.sin
local cos = math.cos
local rad = math.rad
local floor = math.floor
local sqrt = math.sqrt
local max = math.max
local min = math.min
local t_sort = table.sort

local formFields = app.formFields
local radio = app.radio

local MSP_ATTITUDE = 108
local BASE_VIEW_PITCH_R = rad(-90)
local BASE_VIEW_YAW_R = rad(90)
local CAMERA_DIST = 7.0
local CAMERA_NEAR_EPS = 0.25
local SHOW_BACKGROUND_GRID = false
local HIGH_DETAIL_MODEL = false

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
    movementPaused = false,
    resumeMovementPending = false,
    autoRecenterPending = false,
    simStartAt = 0,
    viewYawOffset = 0,
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
    {"@i18n(app.modules.alignment.mag_default)@", 1},
    {"@i18n(app.modules.alignment.mag_cw_0)@", 2},
    {"@i18n(app.modules.alignment.mag_cw_90)@", 3},
    {"@i18n(app.modules.alignment.mag_cw_180)@", 4},
    {"@i18n(app.modules.alignment.mag_cw_270)@", 5},
    {"@i18n(app.modules.alignment.mag_cw_0_flip)@", 6},
    {"@i18n(app.modules.alignment.mag_cw_90_flip)@", 7},
    {"@i18n(app.modules.alignment.mag_cw_180_flip)@", 8},
    {"@i18n(app.modules.alignment.mag_cw_270_flip)@", 9},
    {"@i18n(app.modules.alignment.mag_custom)@", 10}
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

local function recenterYawView()
    state.viewYawOffset = (tonumber(state.live.yaw) or 0) + (tonumber(state.display.yaw_degrees) or 0)
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
    if state.autoRecenterPending then
        recenterYawView()
        state.autoRecenterPending = false
    end
    return true
end

local function buildSimulatedAttitudeResponse(now)
    local m = tasks and tasks.msp and tasks.msp.mspHelper
    if not m then return {} end

    local t0 = state.simStartAt or 0
    local t = max(0, (now or os.clock()) - t0)

    local rollDeg = 25.0 * sin(t * 1.25)
    local pitchDeg = 18.0 * sin((t * 0.90) + 0.9)
    local yawDeg = 90.0 * sin((t * 0.42) + 0.2)

    local rollRaw = floor((rollDeg * 10.0) + 0.5)
    local pitchRaw = floor((pitchDeg * 10.0) + 0.5)
    local yawRaw = floor(yawDeg + 0.5)

    local buf = {}
    m.writeS16(buf, rollRaw)
    m.writeS16(buf, pitchRaw)
    m.writeS16(buf, yawRaw)
    return buf
end

local function requestAttitude()
    if state.pendingAttitude then return false end
    if not (tasks and tasks.msp and tasks.msp.mspQueue) then return false end

    local now = os.clock()
    state.pendingAttitude = true
    state.pendingAt = now
    local sim = system.getVersion().simulation
    local simResponse = sim and buildSimulatedAttitudeResponse(now) or {}

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
        simulatorResponse = simResponse
    })
end

local function clearMspQueue()
    local q = tasks and tasks.msp and tasks.msp.mspQueue
    if q and q.clear then q:clear() end
end

local requestRebootAfterSave

local function pauseMovement()
    state.movementPaused = true
    state.pendingAttitude = false
    state.pollingEnabled = false
end

local function resumeMovement()
    state.movementPaused = false
    state.resumeMovementPending = false
    state.pendingAttitude = false
    state.pollingEnabled = false
    state.lastAttitudeAt = 0
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
    pauseMovement()

    app.ui.progressDisplay("@i18n(app.msg_saving_settings)@", "@i18n(app.msg_saving_to_fbl)@")
    clearMspQueue()

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
                state.resumeMovementPending = true
                state.dirty = false
                if app and app.ui and app.ui.setPageDirty then app.ui.setPageDirty(false) end
                app.triggers.closeProgressLoader = true
                requestRebootAfterSave()
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

requestRebootAfterSave = function()
    local rebootAPI = tasks and tasks.msp and tasks.msp.api and tasks.msp.api.load and tasks.msp.api.load("REBOOT")
    if not rebootAPI then
        if app and app.utils and app.utils.invalidatePages then app.utils.invalidatePages() end
        return
    end

    rebootAPI.setCompleteHandler(function()
        rfsuite.utils.log("Rebooting FC", "info")
        rfsuite.utils.onReboot()
    end)

    rebootAPI.setErrorHandler(function()
        if app and app.utils and app.utils.invalidatePages then app.utils.invalidatePages() end
    end)

    rebootAPI.write()
end

-- Match configurator model transform:
-- model.rotation.x = -pitch
-- modelWrapper.rotation.y = -yaw
-- model.rotation.z = -roll
-- World transform on points becomes: Rz(roll) -> Rx(pitch) -> Ry(yaw).
local function rotatePoint(x, y, z, pitchR, yawR, rollR)
    -- Rear-view baseline (tail toward viewer) while keeping model upright.
    local cbp = cos(BASE_VIEW_PITCH_R)
    local sbp = sin(BASE_VIEW_PITCH_R)
    local px = x
    local py = y * cbp - z * sbp
    local pz = y * sbp + z * cbp

    local cby = cos(BASE_VIEW_YAW_R)
    local sby = sin(BASE_VIEW_YAW_R)
    local bx = px * cby + pz * sby
    local by = py
    local bz = -px * sby + pz * cby

    local cz = cos(rollR)
    local sz = sin(rollR)
    local cx = cos(pitchR)
    local sx = sin(pitchR)
    local cy = cos(yawR)
    local sy = sin(yawR)

    local x1 = bx * cz - by * sz
    local y1 = bx * sz + by * cz
    local z1 = bz

    local x2 = x1
    local y2 = y1 * cx - z1 * sx
    local z2 = y1 * sx + z1 * cx

    local x3 = x2 * cy + z2 * sy
    local y3 = y2
    local z3 = -x2 * sy + z2 * cy

    return x3, y3, z3
end

local function projectPoint(px, py, pz, cx, cy, scale)
    local denom = CAMERA_DIST - pz
    if denom <= CAMERA_NEAR_EPS then return nil, nil end
    local f = CAMERA_DIST / denom
    local sx = cx + (px * f * scale)
    local sy = cy - (py * f * scale)
    return sx, sy
end

local function drawLine3D(a, b, cx, cy, scale, pitchR, yawR, rollR, color)
    local ax, ay, az = rotatePoint(a[1], a[2], a[3], pitchR, yawR, rollR)
    local bx, by, bz = rotatePoint(b[1], b[2], b[3], pitchR, yawR, rollR)
    if (CAMERA_DIST - az) <= CAMERA_NEAR_EPS or (CAMERA_DIST - bz) <= CAMERA_NEAR_EPS then
        return
    end
    local x1, y1 = projectPoint(ax, ay, az, cx, cy, scale)
    local x2, y2 = projectPoint(bx, by, bz, cx, cy, scale)
    if x1 == nil or x2 == nil then return end
    lcd.color(color)
    lcd.drawLine(x1, y1, x2, y2)
end

local function drawFilledTriangle3D(a, b, c, cx, cy, scale, pitchR, yawR, rollR, color)
    local ax, ay, az = rotatePoint(a[1], a[2], a[3], pitchR, yawR, rollR)
    local bx, by, bz = rotatePoint(b[1], b[2], b[3], pitchR, yawR, rollR)
    local cx3, cy3, cz3 = rotatePoint(c[1], c[2], c[3], pitchR, yawR, rollR)
    if (CAMERA_DIST - az) <= CAMERA_NEAR_EPS or (CAMERA_DIST - bz) <= CAMERA_NEAR_EPS or (CAMERA_DIST - cz3) <= CAMERA_NEAR_EPS then
        return
    end

    local x1, y1 = projectPoint(ax, ay, az, cx, cy, scale)
    local x2, y2 = projectPoint(bx, by, bz, cx, cy, scale)
    local x3, y3 = projectPoint(cx3, cy3, cz3, cx, cy, scale)
    if x1 == nil or x2 == nil or x3 == nil then return end

    lcd.color(color)
    lcd.drawFilledTriangle(x1, y1, x2, y2, x3, y3)
end

local function collectTriangle3D(list, a, b, c, cx, cy, scale, pitchR, yawR, rollR, color)
    local ax, ay, az = rotatePoint(a[1], a[2], a[3], pitchR, yawR, rollR)
    local bx, by, bz = rotatePoint(b[1], b[2], b[3], pitchR, yawR, rollR)
    local cx3, cy3, cz3 = rotatePoint(c[1], c[2], c[3], pitchR, yawR, rollR)
    if (CAMERA_DIST - az) <= CAMERA_NEAR_EPS or (CAMERA_DIST - bz) <= CAMERA_NEAR_EPS or (CAMERA_DIST - cz3) <= CAMERA_NEAR_EPS then
        return
    end

    local x1, y1 = projectPoint(ax, ay, az, cx, cy, scale)
    local x2, y2 = projectPoint(bx, by, bz, cx, cy, scale)
    local x3, y3 = projectPoint(cx3, cy3, cz3, cx, cy, scale)
    if x1 == nil or x2 == nil or x3 == nil then return end

    list[#list + 1] = {
        x1 = x1, y1 = y1, x2 = x2, y2 = y2, x3 = x3, y3 = y3,
        z = (az + bz + cz3) / 3,
        color = color
    }
end

local function drawTriangleList(list)
    if #list == 0 then return end
    t_sort(list, function(a, b) return a.z < b.z end)
    for i = 1, #list do
        local t = list[i]
        lcd.color(t.color)
        lcd.drawFilledTriangle(t.x1, t.y1, t.x2, t.y2, t.x3, t.y3)
    end
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
    local grid = isDark and lcd.GREY(70) or lcd.GREY(210)
    local mainColor = isDark and lcd.RGB(248, 248, 248) or lcd.RGB(8, 8, 8)
    local accent = isDark and lcd.RGB(255, 220, 110) or lcd.RGB(0, 110, 235)
    local disc = isDark and lcd.RGB(150, 150, 150) or lcd.RGB(150, 150, 150)
    local bodyLight = isDark and lcd.RGB(220, 220, 220) or lcd.RGB(180, 180, 180)
    local bodyMid = isDark and lcd.RGB(180, 180, 180) or lcd.RGB(145, 145, 145)
    local bodyDark = isDark and lcd.RGB(140, 140, 140) or lcd.RGB(112, 112, 112)

    local panelX = x + 4
    local panelY = y + 2
    local panelW = vw - 8
    local panelH = vh - 4

    lcd.color(bg)
    lcd.drawFilledRectangle(panelX, panelY, panelW, panelH)
    lcd.color(grid)
    lcd.drawRectangle(panelX, panelY, panelW, panelH)

    -- Configurator mapping:
    -- x = -pitch, y = -yaw, z = -roll.
    local pitchR = rad(-(state.live.pitch + state.display.pitch_degrees))
    local yawR = rad(-((state.live.yaw + state.display.yaw_degrees) - state.viewYawOffset))
    local rollR = rad(-(state.live.roll + state.display.roll_degrees))

    local leftPanelW = clamp(floor(panelW * 0.40), 150, floor(panelW * 0.70))
    local infoX = panelX + 1
    local infoY = panelY + 1
    local infoW = leftPanelW
    local infoH = panelH - 2

    local gx0 = infoX + infoW + 1
    local gy0 = panelY + 1
    local gw0 = panelW - infoW - 3
    local gh0 = panelH - 2
    if gh0 < 40 then return end

    lcd.color(grid)
    lcd.drawRectangle(infoX, infoY, infoW, infoH)
    lcd.drawLine(gx0 - 1, panelY + 1, gx0 - 1, panelY + panelH - 2)

    if SHOW_BACKGROUND_GRID then
        lcd.color(grid)
        local step = 24
        for gy = gy0 + step, gy0 + gh0 - 1, step do
            lcd.drawLine(gx0, gy, gx0 + gw0, gy)
        end
        for gx = gx0 + step, gx0 + gw0 - 1, step do
            lcd.drawLine(gx, gy0, gx, gy0 + gh0)
        end
    end

    lcd.font(FONT_XS)
    local liveText = string.format("@i18n(app.modules.alignment.live_fmt)@", state.live.roll, state.live.pitch, state.live.yaw)
    local offsText = string.format("@i18n(app.modules.alignment.offset_fmt)@", state.display.roll_degrees, state.display.pitch_degrees, state.display.yaw_degrees, state.display.mag_alignment)
    local _, th1 = lcd.getTextSize(liveText)
    local _, th2 = lcd.getTextSize(offsText)
    local textPad = 2
    local textX = infoX + 8
    local textY = infoY + 6

    lcd.color(mainColor)
    lcd.drawText(textX, textY, liveText, LEFT)
    lcd.drawText(textX, textY + th1 + textPad, offsText, LEFT)
    lcd.drawText(textX, textY + th1 + th2 + 14, string.format("@i18n(app.modules.alignment.view_yaw_fmt)@", state.viewYawOffset), LEFT)

    local miniX = infoX + 8
    local miniY = textY + th1 + th2 + 46
    local miniW = max(40, infoW - 16)
    local miniH = max(40, infoH - (miniY - infoY) - 8)
    if miniH >= 56 then
        lcd.color(grid)
        lcd.drawRectangle(miniX, miniY, miniW, miniH)

        lcd.color(mainColor)
        lcd.drawText(miniX + 4, miniY + 2, "@i18n(app.modules.alignment.nose_direction)@", LEFT)

        local mx = miniX + floor(miniW * 0.5)
        local my = miniY + floor(miniH * 0.60)

        -- Use projected nose/tail points to generate a clear textual cue.
        local nwx, nwy, nwz = rotatePoint(2.2, 0.0, 0.0, pitchR, yawR, rollR)
        local twx, twy, twz = rotatePoint(-2.2, 0.0, 0.0, pitchR, yawR, rollR)
        local npx, npy = projectPoint(nwx, nwy, nwz, mx, my, 1.0)
        local tpx, tpy = projectPoint(twx, twy, twz, mx, my, 1.0)
        if npx and npy and tpx and tpy then
            local dx = npx - tpx
            local dy = -(npy - tpy)
            local mag = sqrt((dx * dx) + (dy * dy))
            if mag > 0.001 then
                local ux = dx / mag
                local uy = dy / mag
                local htxt, vtxt = "center", "center"
                if ux > 0.35 then htxt = "left" elseif ux < -0.35 then htxt = "right" end
                if uy > 0.35 then vtxt = "up" elseif uy < -0.35 then vtxt = "down" end

                local primary = "@i18n(app.modules.alignment.nose_level)@"
                if vtxt == "up" then primary = "@i18n(app.modules.alignment.nose_up)@" end
                if vtxt == "down" then primary = "@i18n(app.modules.alignment.nose_down)@" end

                local secondary = ""
                if htxt == "left" then secondary = "@i18n(app.modules.alignment.leaning_left)@" end
                if htxt == "right" then secondary = "@i18n(app.modules.alignment.leaning_right)@" end

                lcd.font(FONT_STD)
                lcd.color(accent)
                lcd.drawText(miniX + 6, miniY + floor(miniH * 0.42), primary, LEFT)
                lcd.font(FONT_XS)
                lcd.color(mainColor)
                if secondary ~= "" then
                    lcd.drawText(miniX + 6, miniY + floor(miniH * 0.42) + 22, secondary, LEFT)
                end
            end
        end
    end

    local cx = gx0 + floor(gw0 * 0.5)
    local cy = gy0 + floor(gh0 * 0.63)
    local scale = max(8, min(gw0, gh0) * 0.2112)

    -- Simplified heli wireframe for clearer orientation cues.
    local nose = {2.35, 0.0, -0.02}
    local tail = {-2.65, 0.0, 0.03}
    local lf = {1.10, -0.62, 0.02}
    local rf = {1.10, 0.62, 0.02}
    local lb = {-0.55, -0.46, 0.05}
    local rb = {-0.55, 0.46, 0.05}
    local top = {0.05, 0.0, 0.84}
    local podAftTop = {-0.66, 0.0, 0.56}
    local podAftBot = {-0.66, 0.0, -0.12}
    local podAftL = {-0.66, -0.30, 0.14}
    local podAftR = {-0.66, 0.30, 0.14}
    local mast = {0.0, 0.0, 1.02}
    local finU = {-2.25, 0.0, 0.45}
    local finD = {-2.25, 0.0, -0.18}
    local boomSL = {-0.88, -0.10, 0.11}
    local boomSR = {-0.88, 0.10, 0.11}
    local boomSU = {-0.88, 0.0, 0.18}
    local boomSD = {-0.88, 0.0, 0.06}
    local boomEL = {-2.35, -0.06, 0.08}
    local boomER = {-2.35, 0.06, 0.08}
    local boomEU = {-2.35, 0.0, 0.12}
    local boomED = {-2.35, 0.0, 0.05}
    local stabL = {-2.35, -0.30, 0.10}
    local stabR = {-2.35, 0.30, 0.10}

    local skidL1 = {1.12, -0.66, -0.69}
    local skidL2 = {0.76, -0.66, -0.64}
    local skidL3 = {0.00, -0.66, -0.62}
    local skidL4 = {-0.96, -0.66, -0.63}
    local skidL5 = {-1.24, -0.66, -0.67}
    local skidR1 = {1.12, 0.66, -0.69}
    local skidR2 = {0.76, 0.66, -0.64}
    local skidR3 = {0.00, 0.66, -0.62}
    local skidR4 = {-0.96, 0.66, -0.63}
    local skidR5 = {-1.24, 0.66, -0.67}

    local strutLFTop = {0.52, -0.50, -0.12}
    local strutLFBot = {0.48, -0.66, -0.63}
    local strutLBTop = {-0.52, -0.44, -0.10}
    local strutLBBot = {-0.58, -0.66, -0.63}
    local strutRFTop = {0.52, 0.50, -0.12}
    local strutRFBot = {0.48, 0.66, -0.63}
    local strutRBTop = {-0.52, 0.44, -0.10}
    local strutRBBot = {-0.58, 0.66, -0.63}

    local rotorA = {0.0, -1.9, 1.02}
    local rotorB = {0.0, 1.9, 1.02}
    local rotorC = {-1.9, 0.0, 1.02}
    local rotorD = {1.9, 0.0, 1.02}

    local fuselage = {}
    collectTriangle3D(fuselage, nose, lf, top, cx, cy, scale, pitchR, yawR, rollR, bodyLight)
    collectTriangle3D(fuselage, nose, top, rf, cx, cy, scale, pitchR, yawR, rollR, bodyLight)
    collectTriangle3D(fuselage, lf, lb, top, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
    collectTriangle3D(fuselage, rf, top, rb, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
    collectTriangle3D(fuselage, lb, podAftTop, top, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, rb, top, podAftTop, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, lf, lb, rb, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, lf, rb, rf, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, lb, podAftL, podAftTop, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, rb, podAftTop, podAftR, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, lb, podAftBot, podAftL, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, rb, podAftR, podAftBot, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    if HIGH_DETAIL_MODEL then
        -- Rounded aft pod
        collectTriangle3D(fuselage, lb, podAftTop, top, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
        collectTriangle3D(fuselage, rb, top, podAftTop, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
        collectTriangle3D(fuselage, lb, podAftL, podAftTop, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
        collectTriangle3D(fuselage, rb, podAftTop, podAftR, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
        collectTriangle3D(fuselage, lb, podAftBot, podAftL, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
        collectTriangle3D(fuselage, rb, podAftR, podAftBot, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    end
    -- Tail boom (low-poly pod-and-boom profile)
    collectTriangle3D(fuselage, boomSU, boomSL, boomEU, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
    collectTriangle3D(fuselage, boomSL, boomEL, boomEU, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
    collectTriangle3D(fuselage, boomSU, boomEU, boomSR, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
    collectTriangle3D(fuselage, boomSR, boomEU, boomER, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
    collectTriangle3D(fuselage, boomSL, boomSD, boomEL, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, boomSD, boomED, boomEL, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, boomSD, boomSR, boomED, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    collectTriangle3D(fuselage, boomSR, boomER, boomED, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    if HIGH_DETAIL_MODEL then
        -- Pod to boom shoulder transition
        collectTriangle3D(fuselage, podAftTop, podAftL, boomSU, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
        collectTriangle3D(fuselage, podAftTop, boomSU, podAftR, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
        collectTriangle3D(fuselage, podAftL, podAftBot, boomSD, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
        collectTriangle3D(fuselage, podAftBot, podAftR, boomSD, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
    end
    drawTriangleList(fuselage)

    -- Rotor plane + mast
    drawLine3D(rotorA, rotorB, cx, cy, scale, pitchR, yawR, rollR, disc)
    drawLine3D(rotorC, rotorD, cx, cy, scale, pitchR, yawR, rollR, disc)
    drawLine3D(top, mast, cx, cy, scale, pitchR, yawR, rollR, disc)

    -- Fuselage
    drawFilledTriangle3D(nose, lf, rf, cx, cy, scale, pitchR, yawR, rollR, accent)
    drawLine3D(lb, lf, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(rb, rf, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(lf, nose, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(rf, nose, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(top, nose, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(boomSU, boomEU, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(boomSL, boomEL, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(boomSR, boomER, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(boomSD, boomED, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    -- Shoulder ring helps separate pod from the narrower boom.
    drawLine3D(boomSU, boomSL, cx, cy, scale, pitchR, yawR, rollR, accent)
    drawLine3D(boomSL, boomSD, cx, cy, scale, pitchR, yawR, rollR, accent)
    drawLine3D(boomSD, boomSR, cx, cy, scale, pitchR, yawR, rollR, accent)
    drawLine3D(boomSR, boomSU, cx, cy, scale, pitchR, yawR, rollR, accent)
    if HIGH_DETAIL_MODEL then
        drawLine3D(podAftTop, podAftL, cx, cy, scale, pitchR, yawR, rollR, mainColor)
        drawLine3D(podAftTop, podAftR, cx, cy, scale, pitchR, yawR, rollR, mainColor)
        drawLine3D(podAftL, podAftBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
        drawLine3D(podAftR, podAftBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    end

    -- Tail fin + skids
    drawLine3D(finU, finD, cx, cy, scale, pitchR, yawR, rollR, accent)
    if HIGH_DETAIL_MODEL then
        drawLine3D(stabL, stabR, cx, cy, scale, pitchR, yawR, rollR, accent)
    end
    drawLine3D(skidL1, skidL2, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(skidL2, skidL3, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(skidL3, skidL4, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(skidL4, skidL5, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(skidR1, skidR2, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(skidR2, skidR3, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(skidR3, skidR4, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(skidR4, skidR5, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutLFTop, strutLFBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutLBTop, strutLBBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutRFTop, strutRFBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutRBTop, strutRBBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutLFBot, strutRFBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutLBBot, strutRBBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutLFTop, strutRFTop, cx, cy, scale, pitchR, yawR, rollR, mainColor)
    drawLine3D(strutLBTop, strutRBTop, cx, cy, scale, pitchR, yawR, rollR, mainColor)

end

local function openPage(opts)
    state.wakeupEnabled = false
    state.pageIdx = opts.idx
    local title = opts.title or "@i18n(app.modules.alignment.name)@"

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
    state.movementPaused = false
    state.resumeMovementPending = false
    state.autoRecenterPending = true
    state.simStartAt = os.clock()
    state.viewYawOffset = 0

    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

    form.clear()
    app.ui.fieldHeader(title)

    local line1 = form.addLine("")
    local rowY = radio.linePaddingTop
    local rowH = radio.navbuttonHeight
    local screenW = lcd.getWindowSize()
    local leftPad = 2
    local rightPad = 6
    local gap = 4
    local fieldX = leftPad
    local fieldW = screenW - leftPad - rightPad
    local slotGap = gap
    local slotW = floor((fieldW - (slotGap * 3)) / 4)
    local labels = {
        "@i18n(app.modules.alignment.roll)@",
        "@i18n(app.modules.alignment.pitch)@",
        "@i18n(app.modules.alignment.yaw)@",
        "@i18n(app.modules.alignment.mag)@"
    }

    lcd.font(FONT_STD)
    local wRoll = lcd.getTextSize(labels[1] .. " ")
    local wPitch = lcd.getTextSize(labels[2] .. " ")
    local wYaw = lcd.getTextSize(labels[3] .. " ")
    local wMag = lcd.getTextSize(labels[4] .. " ")
    local labelWidths = {wRoll, wPitch, wYaw, wMag}

    local slotX1 = fieldX
    local slotX2 = fieldX + slotW + slotGap
    local slotX3 = fieldX + (slotW + slotGap) * 2
    local slotX4 = fieldX + (slotW + slotGap) * 3
    local slotX = {slotX1, slotX2, slotX3, slotX4}

    local bw1 = clamp(slotW - labelWidths[1] - 2, 34, 86)
    local bw2 = clamp(slotW - labelWidths[2] - 2, 34, 86)
    local bw3 = clamp(slotW - labelWidths[3] - 2, 34, 86)
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

    form.addStaticText(line1, {x = slotX[4], y = rowY, w = labelWidths[4], h = rowH}, labels[4])
    local magW = max(72, slotW - labelWidths[4] - 2)
    formFields[4] = form.addChoiceField(line1, {x = slotX[4] + labelWidths[4] + 2, y = rowY, w = magW, h = rowH}, magAlignChoices, function()
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

local function onToolMenu()
    form.openDialog({
        title = "@i18n(app.modules.alignment.name)@",
        message = "@i18n(app.modules.alignment.msg_reset_tail_view)@",
        buttons = {
            {
                label = "@i18n(app.btn_ok_long)@",
                action = function()
                    recenterYawView()
                    return true
                end
            },
            {
                label = "@i18n(app.btn_cancel)@",
                action = function()
                    return true
                end
            }
        },
        options = TEXT_LEFT
    })
    return true
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

    if state.resumeMovementPending then
        local queueIdle = tasks and tasks.msp and tasks.msp.mspQueue and tasks.msp.mspQueue:isProcessed()
        if queueIdle and not (dialogs and (dialogs.progressDisplay or dialogs.saveDisplay)) then
            resumeMovement()
        else
            return
        end
    end

    if state.movementPaused then
        if (now - state.invalidateAt) >= 0.15 then
            state.invalidateAt = now
            lcd.invalidate()
        end
        return
    end

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
    return navHandlers.onNavMenu()
end

local function event(_, category, value, x, y)
    if value == 128 then
        recenterYawView()
        return true
    end

    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {
    reboot = false,
    eepromWrite = false,
    openPage = openPage,
    wakeup = wakeup,
    paint = paint,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    onToolMenu = onToolMenu,
    onNavMenu = onNavMenu,
    event = event,
    navButtons = {menu = true, save = true, reload = true, tool = true, help = true},
    API = {}
}
