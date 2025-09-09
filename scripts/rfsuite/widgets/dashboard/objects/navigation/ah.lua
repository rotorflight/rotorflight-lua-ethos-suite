--[[
    Attitude Horizon Widget (AH)
    Configurable Parameters (box table fields):
    ------------------------------------------------
    wakeupinterval      : number   -- Optional wakeup interval in seconds (default: 0.2)
    pixelsperdeg        : number   -- Pixels per degree for pitch & compass (default: 2.0)
    dynamicscalemin     : number   -- Minimum scale factor (default: 1.05)
    dynamicscalemax     : number   -- Maximum scale factor (default: 1.95)
    showarc             : bool     -- Show arc markers (default: true)
    showladder          : bool     -- Show pitch ladder (default: true)
    showcompass         : bool     -- Show compass ribbon (default: true)
    showaltitude        : bool     -- Show altitude bar on right (default: false)
    showgroundspeed           : bool     -- Show groundspeed bar on left (default: false)
    arccolor            : color    -- Color for arc markings (default: white)
    laddercolor         : color    -- Color for pitch ladder (default: white)
    compasscolor        : color    -- Color for compass (default: white)
    crosshaircolor      : color    -- Color for central cross marker (default: white)
    altitudecolor       : color    -- Color for altitude bar (default: white)
    groundspeedcolor          : color    -- Color for groundspeed bar (default: white)
    altitudemin         : number   -- Minimum displayed altitude (default: 0)
    altitudemax         : number   -- Maximum displayed altitude (default: 200)
    groundspeedmin            : number   -- Minimum displayed groundspeed (default: 0)
    groundspeedmax            : number   -- Maximum displayed groundspeed (default: 100)
]]

local render    = {}
local utils     = rfsuite.widgets.dashboard.utils
local getParam  = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- external invalidation hook
function render.invalidate(box) box._cfg = nil end

-- rotation helper (unchanged)
local function rotate(px, py, cx, cy, angle)
    local s = math.sin(angle)
    local c = math.cos(angle)
    px, py = px - cx, py - cy
    local xnew = px * c - py * s
    local ynew = px * s + py * c
    return xnew + cx, ynew + cy
end

-- Build/refresh static config once
local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version     = theme_version
        cfg._param_version     = param_version

        cfg.ppd                = getParam(box, "pixelsperdeg") or 2.0
        cfg.dMin               = getParam(box, "dynamicscalemin") or 1.05
        cfg.dMax               = getParam(box, "dynamicscalemax") or ((getParam(box, "dynamicscalemin") or 1.05) + 0.9)

        cfg.showarc            = getParam(box, "showarc") ~= false
        cfg.showladder         = getParam(box, "showladder") ~= false
        cfg.showcompass        = getParam(box, "showcompass") ~= false
        cfg.showaltitude       = getParam(box, "showaltitude") ~= false
        cfg.showgroundspeed    = getParam(box, "showgroundspeed") ~= false

        cfg.arccolor           = resolveThemeColor("arccolor", getParam(box, "arccolor") or lcd.RGB(255,255,255))
        cfg.laddercolor        = resolveThemeColor("laddercolor", getParam(box, "laddercolor") or lcd.RGB(255,255,255))
        cfg.compasscolor       = resolveThemeColor("compasscolor", getParam(box, "compasscolor") or lcd.RGB(255,255,255))
        cfg.crosshaircolor     = resolveThemeColor("crosshaircolor", getParam(box, "crosshaircolor") or lcd.RGB(255,255,255))
        cfg.altitudecolor      = resolveThemeColor("altitudecolor", getParam(box, "altitudecolor") or lcd.RGB(255,255,255))
        cfg.groundspeedcolor   = resolveThemeColor("groundspeedcolor", getParam(box, "groundspeedcolor") or lcd.RGB(255,255,255))

        cfg.altitudemin        = getParam(box, "altitudemin") or 0
        cfg.altitudemax        = getParam(box, "altitudemax") or 200
        cfg.groundspeedmin     = getParam(box, "groundspeedmin") or 0
        cfg.groundspeedmax     = getParam(box, "groundspeedmax") or 100

        box._cfg = cfg
    end
    return box._cfg
end

-- Only repaint when telemetry-driven display actually changed
function render.dirty(box)
    local d = box._dyn
    if not d then return false end
    local l = box._last
    if not l
        or d.pitch ~= l.pitch
        or d.roll  ~= l.roll
        or d.yaw   ~= l.yaw
        or d.altitude ~= l.altitude
        or d.groundspeed ~= l.groundspeed
    then
        box._last = { pitch = d.pitch, roll = d.roll, yaw = d.yaw, altitude = d.altitude, groundspeed = d.groundspeed }
        return true
    end
    return false
end

function render.wakeup(box)
    ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    if not telemetry then return end
    local getSensor = telemetry.getSensor

    -- Dynamic values only
    local pitch = getSensor("attpitch") or 0
    local roll  = getSensor("attroll")  or 0
    local yaw   = getSensor("attyaw")   or 0
    local altitude    = getSensor("altitude")    or 20
    local groundspeed = getSensor("groundspeed") or 20

    box._dyn = {
        pitch = pitch,
        roll = roll,
        yaw = yaw,
        altitude = altitude,
        groundspeed = groundspeed,
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cfg; if not c then return end
    local d = box._dyn; if not d then return end

    local pitch, roll, yaw = d.pitch, d.roll, d.yaw
    local ppd = c.ppd
    local cx, cy = x + w / 2, y + h / 2

    -- Define sky and ground colors
    local skyColor = lcd.RGB(70, 130, 180)     -- Steel blue
    local groundColor = lcd.RGB(160, 82, 45)   -- Saddle brown

    lcd.setClipping(x, y, w, h)

    -- 1. Fill background with dominant color
    lcd.color(pitch >= 0 and skyColor or groundColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- 2. Overlay the opposite color using triangles to simulate horizon
    local dominantColor = pitch >= 0 and skyColor or groundColor
    local overlayColor  = pitch >= 0 and groundColor or skyColor
    lcd.color(dominantColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- 3. Overlay two triangles in the other color to cover below/above horizon
    lcd.color(overlayColor)
    local horizonY = cy + pitch * ppd
    local rollRad = math.rad(roll)

    -- Extend points far beyond width to ensure coverage
    local xL, yL = rotate(cx - 2*w, horizonY, cx, horizonY, rollRad)
    local xR, yR = rotate(cx + 2*w, horizonY, cx, horizonY, rollRad)

    if pitch >= 0 then
        lcd.drawFilledTriangle(xL, yL, xR, yR, cx - 2*w, y + h)
        lcd.drawFilledTriangle(xR, yR, cx + 2*w, y + h, cx - 2*w, y + h)
    else
        lcd.drawFilledTriangle(xL, yL, xR, yR, cx - 2*w, y)
        lcd.drawFilledTriangle(xR, yR, cx + 2*w, y, cx - 2*w, y)
    end

    -- 4. Crosshair
    lcd.color(c.crosshaircolor)
    lcd.drawLine(cx - 5, cy, cx + 5, cy)
    lcd.drawLine(cx, cy - 5, cx, cy + 5)
    lcd.drawCircle(cx, cy, 3)

    -- 5. Arc markers
    if c.showarc then
        lcd.color(c.arccolor)
        local arcR = w * 0.4
        for _, ang in ipairs({-60,-45,-30,-20,-10,0,10,20,30,45,60}) do
            local rad = math.rad(ang)
            local x1  = cx + arcR * math.sin(rad)
            local y1  = y + 10 + arcR * (1 - math.cos(rad))
            local x2  = cx + (arcR - 6) * math.sin(rad)
            local y2  = y + 10 + (arcR - 6) * (1 - math.cos(rad))
            lcd.drawLine(x1, y1, x2, y2)
        end
        lcd.drawFilledTriangle(cx, y+5, cx-6, y+15, cx+6, y+15)
    end

    -- 6. Pitch ladder
    if c.showladder then
        lcd.color(c.laddercolor)
        for ang = -90, 90, 10 do
            local off = (pitch - ang) * ppd
            local py  = cy + off
            if py > y-40 and py < y+h+40 then
                local major = (ang % 20 == 0)
                local len   = major and 25 or 15
                local x1,y1 = rotate(cx-len, py, cx, cy, math.rad(roll))
                local x2,y2 = rotate(cx+len, py, cx, cy, math.rad(roll))
                lcd.drawLine(x1, y1, x2, y2)
                if major then
                    local lbl = tostring(ang)
                    local lx,ly = rotate(cx-len-10, py-4, cx, cy, math.rad(roll))
                    local rx,ry = rotate(cx+len+2, py-4, cx, cy, math.rad(roll))
                    lcd.drawText(lx, ly, lbl, RIGHT)
                    lcd.drawText(rx, ry, lbl, LEFT)
                end
            end
        end
    end

    -- 7. Compass ribbon
    if c.showcompass then
        lcd.color(c.compasscolor)
        local heading  = math.floor((yaw + 360) % 360)
        local compassY = y + h - 24
        local labels   = {[0]="N",[45]="NE",[90]="E",[135]="SE",[180]="S",[225]="SW",[270]="W",[315]="NW"}
        for ang = -90, 90, 10 do
            local hdg = (heading + ang + 360) % 360
            local px  = cx + ang * ppd
            if px > x and px < x+w then
                local th = (hdg % 30 == 0) and 8 or 4
                lcd.drawLine(px, compassY, px, compassY-th)
                if hdg % 30 == 0 then
                    lcd.drawText(px, compassY-th-8, labels[hdg] or tostring(hdg), CENTERED+FONT_XS)
                end
            end
        end
        lcd.drawFilledTriangle(cx, compassY+1, cx-5, compassY-7, cx+5, compassY-7)

        local bw, bh = 60, 14
        local bx, by = cx - bw/2, compassY + 6
        if by + bh < y + h then
            lcd.color(lcd.RGB(0,0,0)); lcd.drawFilledRectangle(bx, by, bw, bh)
            lcd.color(c.compasscolor); lcd.drawRectangle(bx, by, bw, bh)
            lcd.drawText(cx, by+1, string.format("%03d° %s", heading, labels[heading - (heading % 45)] or (heading.."°")), CENTERED+FONT_XS)
        end
    end

    -- 8. Altitude bar
    if c.showaltitude then
        lcd.color(c.altitudecolor)
        local barX = x + w - 10
        local barY = y + 5
        local barH = h - 10
        local fillH = math.floor((d.altitude - c.altitudemin) / (c.altitudemax - c.altitudemin) * barH)
        fillH = math.max(0, math.min(barH, fillH))
        lcd.drawRectangle(barX, barY, 6, barH)
        lcd.drawFilledRectangle(barX, barY + barH - fillH, 6, fillH)
        lcd.font(FONT_XS)
        local label = string.format("%d m", math.floor(d.altitude))
        lcd.drawText(barX - 4, barY + barH - fillH - 6, label, RIGHT)
    end

    -- 9. Groundspeed bar
    if c.showgroundspeed then
        lcd.color(c.groundspeedcolor)
        local barX = x + 4
        local barY = y + 5
        local barH = h - 10
        local fillH = math.floor((d.groundspeed - c.groundspeedmin) / (c.groundspeedmax - c.groundspeedmin) * barH)
        fillH = math.max(0, math.min(barH, fillH))
        lcd.drawRectangle(barX, barY, 6, barH)
        lcd.drawFilledRectangle(barX, barY + barH - fillH, 6, fillH)
        lcd.font(FONT_XS)
        local label = string.format("%d knots", math.floor(d.groundspeed))
        lcd.drawText(barX + 10, barY + barH - fillH - 6, label, LEFT)
    end

    lcd.setClipping(0, 0, lcd.getWindowSize())
end

-- Update rate similar to original (fluid horizon)
render.scheduler = 0.2

return render