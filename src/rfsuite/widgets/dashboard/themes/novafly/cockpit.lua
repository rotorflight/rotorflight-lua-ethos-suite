-- NovaFly cockpit as a dashboard theme: one background, the lines as code in the chosen colour (frame.lua), values from the
-- suite's telemetry in the radio's font; a long press on the head steps the colour on the ground, a sideways swipe turns to
-- the pages (preflight.lua, banks.lua). The mode (configure.lua, key mode: 1 dark, 2 light) swaps the text colours, the
-- background (light: bands from white to the tint of the colour) and the lines (light: dark core).
local BASE = ...
local BASE_ALT = tostring(BASE):gsub("^SCRIPTS:/", "/scripts/")
local NO_LINK = {link = false}
local THEME_KEY = tostring(BASE):find("/widgets/dashboard/themes/novafly/", 1, true) and "novafly" or "user/novafly"   -- the section of the theme settings: the shipped theme or the copy under rfsuite.user
local rf = nil
if type(package.loaded["rfsuite.lib.require"]) == "function" then
    local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
    if ok then rf = r end
end
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local COLORS = {"blue", "magenta", "green", "orange", "yellow",
                "carbon", "carbon_green", "carbon_violet", "carbon_red"}

local RGB = lcd.RGB
local MODE = {light = false, pages = {},   -- the mode (light = true after the setting mode) and all it swaps - one table: Lua allows 200 locals per file
    palette = {   -- text and fill colours per mode: dark as before; light after the design system (text 20,20,19, dim 95,107,120, green 10,122,36),
        {white = {245, 248, 252}, dim = {120, 132, 145}, gray = {52, 56, 64}, green = {90, 255, 70}, yellow = {240, 210, 30}, orange = {255, 130, 20}, red = {255, 80, 80},   -- yellow, orange and red darker on white so they stay readable
         bg = {8, 8, 10}, needleLight = {255, 255, 255}, needleShadow = {160, 176, 200}},
        {white = {20, 20, 19}, dim = {95, 107, 120}, gray = {214, 218, 225}, green = {10, 122, 36}, yellow = {176, 124, 0}, orange = {196, 96, 10}, red = {200, 32, 32},
         bg = {243, 245, 248}, needleLight = {36, 40, 48}, needleShadow = {120, 130, 150}}},
    names = {"blue", "magenta", "green", "orange", "yellow"}, base = {1, 2, 3, 4, 5, 1, 3, 2, 4},   -- the light version of each cockpit colour (COLORS): the carbon colours on blue, green, magenta, orange
    mid = {{238, 243, 249}, {247, 237, 244}, {238, 246, 239}, {249, 241, 234}, {248, 246, 234}},   -- the background of the light mode (170 degrees): white at the top, the mid tone at 45 %, the tint of the colour at the bottom
    tint = {{221, 231, 243}, {238, 219, 232}, {220, 236, 222}, {241, 226, 211}, {239, 234, 208}},
    lines = {{core = {11, 90, 168}, mid = {143, 193, 236}}, {core = {155, 21, 119}, mid = {231, 163, 211}}, {core = {30, 127, 42}, mid = {166, 220, 172}},   -- the lines on a light background: dark core, light mid tone
              {core = {154, 78, 15}, mid = {240, 191, 142}}, {core = {138, 122, 10}, mid = {233, 221, 134}}},
    BANDS = 20, bands = {}}
local C_WHITE, C_DIM, C_GRAY, C_LGREEN, C_YELLOW, C_ORANGE, C_LRED, C_BLACK, C_NEEDLE_LIGHT, C_NEEDLE_SHADOW   -- set in MODE.set
local C_RED, C_GREEN, C_RING = RGB(225, 40, 40), RGB(40, 180, 55), RGB(0, 152, 224)   -- the ARMED and DISARMED fields and the heading ring: the same in both modes
local SETC = {field = RGB(245, 248, 252)}   -- value colours by their limit; the table stays, a mode change refills it; field = the light text on ARMED and DISARMED
function MODE.set(newLight)   -- the colour upvalues, SETC and the colours of the pages (MODE.pages = HELPERS.colors) anew
    MODE.light = newLight == true
    local p = MODE.palette[MODE.light and 2 or 1]
    local function c(k) return RGB(p[k][1], p[k][2], p[k][3]) end
    C_WHITE, C_DIM, C_GRAY, C_LGREEN, C_YELLOW, C_ORANGE, C_LRED, C_BLACK = c("white"), c("dim"), c("gray"), c("green"), c("yellow"), c("orange"), c("red"), c("bg")
    C_NEEDLE_LIGHT, C_NEEDLE_SHADOW = c("needleLight"), c("needleShadow")
    SETC.g, SETC.y, SETC.o, SETC.r, SETC.w = C_LGREEN, C_YELLOW, C_ORANGE, C_LRED, C_WHITE
    local s = MODE.pages
    s.green, s.yellow, s.red, s.white, s.dim = C_LGREEN, C_YELLOW, C_LRED, C_WHITE, C_DIM
end
MODE.set(false)

local F_TINY = FONT_XS or FONT_S or FONT_STD
local F_SM = FONT_S or FONT_STD
local F_STD_T = FONT_STD or FONT_S
local F_MID = FONT_L or FONT_STD
local F_BIG = FONT_XL or FONT_L or FONT_STD
local F_HUGE = FONT_XXL or FONT_XL or FONT_L or FONT_STD
local FONT_STEPS = {F_HUGE, F_BIG, F_MID, F_STD_T, F_SM}

local T = {timer = "@i18n(widgets.dashboard.novafly.flight_timer)@", unknown = "@i18n(widgets.dashboard.novafly.arm_unknown)@",
           link = "@i18n(widgets.dashboard.novafly.no_link)@", armed = "@i18n(widgets.dashboard.novafly.armed_setup)@"}

local VFR_YEL, VFR_RED = 90, 80
local GAUGE = {cx = 239.5, cy = 171.5}   -- the centre of the gauge; frame.lua draws the arc and the bars
local RPM_REF_DEFAULT = 2000
local LONG, DRIFT, LOCK_SEC, COLOR_READ_SEC = 0.6, 12, 2.5, 1.0
local BEC_FILL_BYTE, BEC_MIN, BEC_MAX = 25.5, 3.0, 13.0
local HEADING = {x = 147, y = 27, r = 16, rim = 1, tip = 12, base = 10, corner = 145}
local CPU_NAMES = {"RT Load", "CPU Load", "System Load", "MCU Load",   -- RT Load is the live value, CPU Load the average (Rotorflight sends both)
                   ids = {{0x51D2, "RT Load"}, {0x51D0, "CPU Load"}, {0x51D1, "System Load"}}}   -- the same sensors by their id when no name matches
local YAW_SOURCES ={0x5210, 0x1103, 0x5022}   -- the suite does not pass yaw through getSensor, nor the altitude without its sensor: the theme then reads the Ethos sensors itself (S.Port, CRSF, the suite's simulator)
local ALT_SOURCES = {0x0100, 0x10B2, 0x5016}
local FLIGHT_MODE_SOURCES = {0x5121, 0x1201}   -- the firmware's raw flightModeFlags (S.Port, CRSF): both suites only create the sensor, the theme reads it itself

local U = {
    arm = {x = 14, y = 14, w = 94, h = 28, f = F_MID, dy = 1},
    rssi = {x = 413, y = 14, f = F_SM},
    vfr = {x = 413, y = 28, f = F_TINY},
    timer = {x = 58, y = 89, f = F_BIG},         -- the left field runs from 0 to the line at 116: centre 58; the block centred in y 55-250
    rate = {x = 58, y = 150, f = F_MID},         -- RATE halfway between FLIGHT TIMER and BANK, the same space (37) above and below
    bank = {x = 58, y = 215, f = F_MID},
    rpm = {x = 241, y = 126, f = F_BIG},
    bec = {x = 421, y = 89, f = F_BIG},          -- the right field runs from the line at 363 to 480: centre 421; the three blocks on the right at the heights of the three on the left: BEC like FLIGHT TIMER, TX like RATE, ESC like BANK
    tx = {x = 421, y = 150, f = F_BIG},
    amp = {x = 421, y = 215, f = F_BIG},
    cpu = {x = 331, y = 63, f = F_SM},
    pack = {x = 164, y = 273, f = F_HUGE, align = "left"},      -- the voltage starts after the battery, the charge ends at the field edge: the V stays with its number
    battpct = {x = 346, y = 273, f = F_HUGE, align = "right"},   -- ends before the line at 358
    modelname = {x = 239.5, y = 218, f = F_MID},   -- centred under the arc
    batt = {x = 140, y = 294, bw = 12, bh = 5, gap = 1, n = 5},
    tank = {x = 370, y = 243, bw = 23, bh = 5, gap = 1, n = 4},   -- the four bars under the ESC value (x 370-465, y 243-247): below the spike of the banks page at 240, above the line at 250
    temp = {x = 422, y = 282, f = F_BIG},
    mcutemp = {x = 187, y = 51, f = F_SM},
    alt = {x = 58, y = 280, f = F_BIG},          -- the altitude bottom left, centred in the foot field (x 0-117, y 255-314)
    labels = {{58, 134, "RATE"}, {58, 195, "BANK"}, {421, 71, "BEC"},   -- the labels in the small size (three sizes on every screen: small, medium, large); only VFR under RSSI stays tiny; BEC at the height of FLIGHT TIMER (77), TX like RATE, ESC like BANK
              {421, 134, "TX"}, {421, 195, "ESC"},   -- the word above the bottom right field (421, 262) changes with the value and is drawn there
              {241, 170, "rpm"}, {143, 65, "MCU"}, {58, 266, "ALT"}},
}
local ZONES = {header = {x = 176, y = 0, w = 184, h = 48}, heading = {x = 127, y = 7, w = 40, h = 40}}

local tableStage = 0   -- the first paint draws only the background, the first wakeup carries the loading: so every call stays under Ethos' limit

local function tableStep()
    tableStage = 2
end

local ox, oy, fx, fy = 0, 0, 1, 1
local function sx(v) return floor(v * fx + 0.5) end
local function sy(v) return floor(v * fy + 0.5) end
local function X(v) return ox + floor(v * fx + 0.5) end   -- like sx, without the extra call: every draw call goes through here (instructions per paint)
local function Y(v) return oy + floor(v * fy + 0.5) end

local function loadAsset(fn, file)
    local ok, x, reason = pcall(fn, BASE .. file)
    if ok and x then return x end
    local first = ok and reason or x
    ok, x, reason = pcall(fn, BASE_ALT .. file)
    if ok and x then return x end
    return nil, tostring(first or (ok and reason) or x)
end

local function measure(text, font)
    lcd.font(font or F_SM)
    return lcd.getTextSize(text)
end

local function drawTextAt(px, py, text, color, font)
    lcd.color(color or C_WHITE)
    lcd.font(font or F_SM)
    lcd.drawText(floor(px), floor(py), text)
    return (lcd.getTextSize(text))
end

local function labelCentered(cx, cy, text, color, font)
    text = tostring(text or "")
    if text == "" then return end
    local tb, th = measure(text, font or F_SM)
    drawTextAt(X(cx) - floor(tb / 2), Y(cy) - floor((th or 12) / 2), text, color, font or F_SM)
end

local function labelCenteredFit(cx, cy, text, color, font, maxRef)
    text = tostring(text or "")
    if text == "" then return end
    local limit, f, start = sx(maxRef), font, false
    for _, step in ipairs(FONT_STEPS) do
        if step == font then start = true end
        if start then
            f = step
            if measure(text, step) <= limit then break end
        end
    end
    labelCentered(cx, cy, text, color, f)
end

local function systemCentered(cx, cy, text, color, font)
    text = tostring(text or "")
    if text == "" then return end
    lcd.font(font or F_SM)
    local tb, th = lcd.getTextSize(text)
    lcd.color(color or C_DIM)
    lcd.drawText(X(cx) - floor((tb or 0) / 2), Y(cy) - floor((th or 12) / 2), text)
end

local function showValue(fld, text, color, yoff) labelCentered(fld.x, fld.y + (yoff or 14), text, color, fld.f) end
local function showSystem(fld, text, color, yoff) systemCentered(fld.x, fld.y + (yoff or 14), text, color, fld.f) end

local function showValue2(fld, number, unit, color, yoff, font)   -- returns the right edge; font replaces fld.f
    font = font or fld.f
    number = tostring(number)
    local zw, th = measure(number, font)
    local uw = measure(unit, font)
    local gap = max(1, sx(2))   -- the unit close to its number
    local left   -- centred on fld.x, or from fld.x (align left), or up to fld.x (align right)
    if fld.align == "left" then left = X(fld.x)
    elseif fld.align == "right" then left = X(fld.x) - (zw + gap + uw)
    else left = X(fld.x) - floor((zw + gap + uw) / 2) end
    local top = Y(fld.y + (yoff or 14)) - floor((th or 12) / 2)
    drawTextAt(left, top, number, color, font)
    drawTextAt(left + zw + gap, top, unit, C_WHITE, font)
    return left + zw + gap + uw
end

local function timerLine(fld, tag, text, color)
    local tw, th = measure(text, fld.f)
    local gw = 0
    if tag and tag ~= "" then gw = measure(tag, F_TINY) end
    local gap = (gw > 0) and max(2, sx(5)) or 0
    local left = X(fld.x) - floor((gw + gap + tw) / 2)
    local base = Y(fld.y + 14) + floor((th or 15) / 2)
    if gw > 0 then
        local _, gh = measure(tag, F_TINY)
        drawTextAt(left, base - (gh or 12), tag, C_DIM, F_TINY)
    end
    drawTextAt(left + gw + gap, base - (th or 15), text, color, fld.f)
end

local function fillRect(x, y, w, h, color)
    lcd.color(color)
    lcd.drawFilledRectangle(X(x), Y(y), sx(w), sy(h))
end

local function fillCircle(x, y, r)
    if type(lcd.drawFilledCircle) == "function" then lcd.drawFilledCircle(x, y, r) else lcd.drawFilledRectangle(x - r, y - r, 2 * r, 2 * r) end
end

local function radius(eh)
    if eh < 22 then return 0 end
    return max(3, min(12, floor(eh / 4)))
end

local function fillRounded(x, y, w, h, color)
    local ex, ey, ew, eh = X(x), Y(y), sx(w), sy(h)
    local r = radius(eh)
    lcd.color(color)
    if r == 0 then lcd.drawFilledRectangle(ex, ey, ew, eh) return end
    lcd.drawFilledRectangle(ex + r, ey, ew - 2 * r, eh)
    lcd.drawFilledRectangle(ex, ey + r, r, eh - 2 * r)
    lcd.drawFilledRectangle(ex + ew - r, ey + r, r, eh - 2 * r)
    fillCircle(ex + r, ey + r, r)
    fillCircle(ex + ew - r - 1, ey + r, r)
    fillCircle(ex + r, ey + eh - r - 1, r)
    fillCircle(ex + ew - r - 1, ey + eh - r - 1, r)
end

local LINES = {tab = nil, active = nil, nr = nil, frame = nil, notch = {}, corners = {}, fade = {}, M = {X = X, Y = Y, sx = sx, sy = sy}}   -- the line colours per colour from lines.lua, unpacked once; the pages draw with the same (kept in a table: 200 locals per file)
local function lineColors(nr)
    local light = MODE.light
    if LINES.active ~= nil and LINES.nr == nr and LINES.light == light then return LINES.active end
    if LINES.tab == nil then
        local chunk = loadAsset(loadfile, "lines.lua")
        local ok, tab = false, nil
        if chunk then ok, tab = pcall(chunk) end
        LINES.tab = (ok and type(tab) == "table") and tab or {}
    end
    local e = LINES.tab[nr] or LINES.tab[1] or {mid = {29, 126, 208}, core = {153, 255, 255}, bg = {9, 10, 14}}
    if light then   -- on a light background the lines of the light design: dark core, light mid tone, the background the light fill
        local h = MODE.lines[MODE.base[nr] or 1]
        e = {mid = h.mid, core = h.core, bg = MODE.palette[2].bg}
    end
    local fade = {}   -- the steps in which a line of the pages fades into the background (frame.lua R.STEPS), mixed once
    local g = e.bg or {0, 0, 0}
    local function mix(color, factor, share)   -- the colour (times factor) towards the background: share 1 the colour, 0 the background
        return RGB(floor(g[1] + (color[1] * factor - g[1]) * share + 0.5), floor(g[2] + (color[2] * factor - g[2]) * share + 0.5),
                   floor(g[3] + (color[3] * factor - g[3]) * share + 0.5))
    end
    for i = 1, 12 do
        local share = (i - 0.5) / 12
        fade[i] = {mix(e.mid, 1, share), mix(e.core, 1, share), light and mix(e.mid, 1, share * 0.3) or mix(e.mid, 0.3, share)}
    end
    LINES.active = {mid = RGB(e.mid[1], e.mid[2], e.mid[3]), core = RGB(e.core[1], e.core[2], e.core[3]),   -- the glow outside every line: 30 % of the mid tone; light 30 % of the mid tone over the background
                 glow = light and mix(e.mid, 1, 0.3) or RGB(floor(e.mid[1] * 0.3 + 0.5), floor(e.mid[2] * 0.3 + 0.5), floor(e.mid[3] * 0.3 + 0.5)), fade = fade}
    LINES.nr, LINES.light = nr, light
    return LINES.active
end

local function photoPath(b)   -- the pilot's model picture: Ethos gives only the file name; like the suite (objects/image/model.lua) it lies under BITMAPS:/models/ - the card roots are only here and in state.lua
    if b:match("^/bitmaps/") then return (b:gsub("^/bitmaps", "BITMAPS:", 1)) end
    if b:match("^/scripts/") then return (b:gsub("^/scripts", "SCRIPTS:", 1)) end
    if b:match("^/system/") then return (b:gsub("^/system", "SYSTEM:", 1)) end
    if not b:match("^[A-Z]+:") and not b:match("^/") then return "BITMAPS:/models/" .. b end
    return b
end

local function frame()   -- the cockpit lines as code (frame.lua), loaded once; false when the file is missing
    if LINES.frame == nil then
        local chunk = loadAsset(loadfile, "frame.lua")
        local ok, r = false, nil
        if chunk then ok, r = pcall(chunk) end
        LINES.frame = (ok and type(r) == "table") and r or false
    end
    return LINES.frame or nil
end

local function notchMasks(R)   -- the three layers of the notch as masks per screen size (frame.lua R.NOTCH, R.suffix), loaded once; nil when one is missing
    local e = R.suffix(LINES.M)
    local m = LINES.notch[e]
    if m == nil then
        local d = R.NOTCH.files
        m = {glow = loadAsset(lcd.loadMask, "gfx/" .. d[1] .. e .. ".png"), mid = loadAsset(lcd.loadMask, "gfx/" .. d[2] .. e .. ".png"), core = loadAsset(lcd.loadMask, "gfx/" .. d[3] .. e .. ".png")}
        m = (m.glow and m.mid and m.core) and m or false
        LINES.notch[e] = m
    end
    return m or nil
end

function LINES.cornerMasks(R)   -- the r 4 corners of the frame as masks per screen size, three layers per corner position (frame.lua R.corner, gfx/corner_*.png),
    local e = R.suffix(LINES.M)   -- loaded once; nil when one is missing - then the corners come as ring sectors
    local corners = LINES.corners[e]
    if corners == nil then
        local t, all = {}, true
        for _, corner in ipairs({"tl", "tr", "bl", "br"}) do
            t[corner] = {glow = loadAsset(lcd.loadMask, "gfx/corner_glow_" .. corner .. e .. ".png"), mid = loadAsset(lcd.loadMask, "gfx/corner_mid_" .. corner .. e .. ".png"),
                      core = loadAsset(lcd.loadMask, "gfx/corner_core_" .. corner .. e .. ".png")}
            if not (t[corner].glow and t[corner].mid and t[corner].core) then all = false end
        end
        corners = all and t or false
        LINES.corners[e] = corners
    end
    return corners or nil
end

function LINES.fadeMasks(R)   -- the fade of the lines on the pages as masks per screen size: three layers per side and length (frame.lua R.fading,
    local e = R.suffix(LINES.M)   -- gfx/fade_*.png), loaded once when a page opens; nil when one is missing - then the fade comes as steps
    local a = LINES.fade[e]
    if a == nil then
        local t, all = {left = {}, right = {}}, true
        for _, side in ipairs({"left", "right"}) do
            for _, length in ipairs(R.fadeLengths()) do
                local name = side .. "_" .. length .. e .. ".png"
                local m = {glow = loadAsset(lcd.loadMask, "gfx/fade_glow_" .. name), mid = loadAsset(lcd.loadMask, "gfx/fade_mid_" .. name), core = loadAsset(lcd.loadMask, "gfx/fade_core_" .. name)}
                if not (m.glow and m.mid and m.core) then all = false end
                t[side][length] = m
            end
        end
        a = all and t or false
        LINES.fade[e] = a
    end
    return a or nil
end

local BG = {image = nil, name = nil, tries = 0}   -- the one background (gloss, carbon for the carbon colours) of the cockpit and the two pages, one picture per screen size (gfx/gloss<suffix>.png: Ethos fits a picture with a fixed aspect ratio into the window, a 480 picture would leave 40 points free on both sides at 800 x 480); without the picture plain black
local function bands(f)   -- the band colours of the light background of light version f, computed once
    local b = MODE.bands[f]
    if b == nil then
        b = {}
        for i = 0, MODE.BANDS - 1 do   -- the colour of band i (0 at the top): up to 45 % from white to the mid tone, then to the tint; photo_frame_light_<colour>.png carries the same sum
            local t = (i + 0.5) / MODE.BANDS
            local a, c, u
            if t < 0.45 then a, c, u = {255, 255, 255}, MODE.mid[f], t / 0.45 else a, c, u = MODE.mid[f], MODE.tint[f], (t - 0.45) / 0.55 end
            b[i + 1] = RGB(floor(a[1] + (c[1] - a[1]) * u + 0.5), floor(a[2] + (c[2] - a[2]) * u + 0.5), floor(a[3] + (c[3] - a[3]) * u + 0.5))
        end
        MODE.bands[f] = b
    end
    return b
end
local LIGHT_BANDS = {y = {}, h = {}}   -- top and height of the bands in the window, computed once per window (instructions per paint)
function BG.light(nr)   -- the light background: 20 bands over the height, from white to the tint of the colour (the gradient in steps); no picture, no memory
    local b, L = bands(MODE.base[nr] or 1), LIGHT_BANDS
    if L.ox ~= ox or L.oy ~= oy or L.fx ~= fx or L.fy ~= fy then
        local step = 320 / MODE.BANDS
        L.ox, L.oy, L.fx, L.fy, L.x, L.w = ox, oy, fx, fy, X(0), sx(480)
        for i = 1, MODE.BANDS do
            L.y[i], L.h[i] = Y((i - 1) * step), Y(i * step) - Y((i - 1) * step)
        end
    end
    local setColor, rect, x, w, ys, hs = lcd.color, lcd.drawFilledRectangle, L.x, L.w, L.y, L.h
    for i = 1, MODE.BANDS do
        setColor(b[i])
        rect(x, ys[i], w, hs[i])
    end
end
function BG.paint(nr, R)
    if R then R.mode(MODE.light) end   -- arc, zones, ticks and pointer in the colours of the mode before any line is drawn
    if MODE.light then
        BG.light(nr)
        return true
    end
    local name = (COLORS[nr]:find("carbon", 1, true) and "carbon" or "gloss") .. (R and R.suffix(LINES.M) or "") .. ".png"
    if BG.name ~= name then BG.image, BG.name, BG.tries = nil, name, 0 end
    if BG.image == nil and BG.tries < 20 then
        BG.tries = BG.tries + 1
        BG.image = loadAsset(lcd.loadBitmap, "gfx/" .. name)
    end
    local drawn = BG.image and pcall(lcd.drawBitmap, X(0), Y(0), BG.image, sx(480), sy(320))
    if not drawn then
        lcd.color(C_BLACK)
        lcd.drawFilledRectangle(X(0), Y(0), sx(480), sy(320))
    end
    return drawn == true
end
local LOGO = {image = {}, tries = {}}   -- the suite's logo at the top centre of the head band, one picture per screen size (gfx/rotorflight<suffix>.png, 24 or 36 points high, width in the ratio 400 : 84); light the dark version rotorflight_light<suffix>.png
function LOGO.paint(R)
    local e = (MODE.light and "_light" or "") .. (R and R.suffix(LINES.M) or "")
    local tries = LOGO.tries[e] or 0
    if LOGO.image[e] == nil and tries < 20 then
        LOGO.tries[e] = tries + 1
        LOGO.image[e] = loadAsset(lcd.loadBitmap, "gfx/rotorflight" .. e .. ".png")
    end
    local img = LOGO.image[e]
    if not img then return false end
    local h = sy(24)
    local w = floor(h * 400 / 84 + 0.5)
    return pcall(lcd.drawBitmap, X(240) - floor(w / 2), Y(11), img, w, h) == true
end
local function paintBackground(nr)
    local R = frame()
    if R then R.refresh(LINES.M) end   -- the line sizes for the window, once per paint (frame.lua sizes then reads them without computing)
    local drawn = BG.paint(nr, R)
    if R then R.cockpit(LINES.M, lineColors(nr), notchMasks(R), LINES.cornerMasks(R), LINES.fadeMasks(R)) end
    LOGO.paint(R)
    return drawn
end

local colorNr, colorReadAt, txSrc, cpuSrc, cpuName, sourceSearchAt = 1, -99, nil, nil, nil, -99
local yawSrc, altSrc, modeSrc = nil, nil, nil

local function sourceValue(src)
    if not src then return nil end
    local ok, v = pcall(function() return src:value() end)
    if ok then return tonumber(v) end
    return nil
end

local function findSensor(ids)   -- the first sensor that currently has a value; a model can carry old sensors without one
    for _, id in ipairs(ids) do
        local ok, src = pcall(system.getSource, {category = CATEGORY_TELEMETRY_SENSOR, appId = id})
        if ok and src then
            local ov, v = pcall(function() return src:value() end)
            if ov and tonumber(v) ~= nil then return src end
        end
    end
    return nil
end

local function dash() return rf and rf.widgets and rf.widgets.dashboard end

local colorSave = {step = nil, settings = nil, pending = nil, at = nil}   -- the long-press colour goes to settings.ini in three ticks (read; set and write; publish) - in one call together over 28 000 instructions, Ethos stops at 20 000
local COLOR_GAP = 2   -- s without a tick: the dashboard was covered, a settings page may have saved meanwhile; the read state is stale, the ticks start with a fresh read

local function readColor()   -- colour and mode as saved (configure.lua); without an entry the defaults apply, as on the settings page
    local d = dash()
    if not (d and d.getPreference) then return end
    local v = tonumber(d.getPreference("color"))   -- English keys (the maintainers' rule)
    local m = tonumber(d.getPreference("mode"))    -- 1 dark, 2 light
    v, m = v or 1, m or 1
    local before, beforeLight = colorNr, MODE.light
    if colorSave.step == nil and v and COLORS[v] then colorNr = floor(v) end   -- while the long press saves, its colour applies
    if m ~= nil and (m == 2) ~= MODE.light then MODE.set(m == 2) end
    if colorNr ~= before or MODE.light ~= beforeLight then   -- this tick computes the lines and the light background, not the first paint after it: that one carries the whole page (instructions)
        lineColors(colorNr)
        if MODE.light then bands(MODE.base[colorNr] or 1) end
    end
end

local function getStore()   -- the suite's lib/settings_store.lua; nil if it does not load
    local req = package.loaded["rfsuite.lib.require"]
    if type(req) ~= "function" then return nil end
    local ok, store = pcall(req, "lib/settings_store.lua")
    if not ok or type(store) ~= "table" or type(store.setDashboardTheme) ~= "function" or type(store.dashboardTheme) ~= "function" then return nil end
    return store, req
end

local function colorStep()   -- one step of saving per tick, like the settings page: the theme's section, the mode and everything else in it stay; settings.update reloads the theme with the new state
    local store, req = getStore()
    if store == nil then colorSave.step, colorSave.settings = nil, nil return end
    local now = os.clock()
    if now - (colorSave.at or now) > COLOR_GAP then colorSave.step = 1 end   -- after the gap neither write nor publish an old state
    colorSave.at = now
    if colorSave.step == 1 then
        colorSave.settings, colorSave.step = store.load(), 2
    elseif colorSave.step == 2 then
        local values = store.dashboardTheme(colorSave.settings, THEME_KEY) or {}
        values.color = colorSave.pending
        store.setDashboardTheme(colorSave.settings, THEME_KEY, values)
        colorSave.step = (store.save(colorSave.settings) == true) and 3 or nil
    else
        local ok, bus = pcall(req, "lib/bus.lua")
        if ok and type(bus) == "table" and type(bus.publish) == "function" then
            bus.publish("settings.update", type(store.clone) == "function" and store.clone(colorSave.settings) or colorSave.settings)
        end
        colorSave.step = nil
    end
    if colorSave.step == nil then colorSave.settings, colorSave.at = nil, nil end
end

local function nextColor()                   -- false when nothing is saved: without a link the suite does not wake the theme, and a colour still being saved goes first
    local newNr = colorNr % #COLORS + 1
    if getStore() == nil or not (rf and rf.session and rf.session.isConnected == true) or colorSave.step ~= nil then return false end
    colorSave.pending, colorSave.step, colorSave.at = newNr, 1, os.clock()
    colorNr = newNr
    return true
end

local function findSources()
    if not (system and system.getSource) then return end
    if txSrc == nil and CATEGORY_SYSTEM and MAIN_VOLTAGE ~= nil then
        local ok, src = pcall(system.getSource, {category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE})
        if ok and src then
            local ov, v = pcall(function() return src:value() end)
            if ov and tonumber(v) and tonumber(v) > 4 and tonumber(v) < 13 then txSrc = src end
        end
    end
    if cpuSrc ~= nil and sourceValue(cpuSrc) == nil then cpuSrc = nil end   -- sensor gone quiet: search again in 5 s
    if cpuSrc == nil and CATEGORY_TELEMETRY_SENSOR then
        for _, n in ipairs(CPU_NAMES) do
            local ok, src = pcall(system.getSource, {category = CATEGORY_TELEMETRY_SENSOR, name = n})
            if ok and src and sourceValue(src) ~= nil then cpuSrc, cpuName = src, n break end
        end
        if cpuSrc == nil then   -- go through the radio's list: compare the names, then the id
            local ok, list = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
            if ok and type(list) == "table" then
                for _, src in ipairs(list) do
                    local on, n = pcall(function() return src:name() end)
                    for _, want in ipairs(CPU_NAMES) do
                        if on and n == want and sourceValue(src) ~= nil then cpuSrc, cpuName = src, n break end
                    end
                    if cpuSrc ~= nil then break end
                end
            end
        end
        if cpuSrc == nil then
            for _, q in ipairs(CPU_NAMES.ids) do
                local src = findSensor({q[1]})
                if src then cpuSrc, cpuName = src, q[2] break end
            end
        end
    end
    if CATEGORY_TELEMETRY_SENSOR then
        if yawSrc ~= nil and sourceValue(yawSrc) == nil then yawSrc = nil end   -- sensor gone quiet: search again in 5 s
        if altSrc ~= nil and sourceValue(altSrc) == nil then altSrc = nil end
        if yawSrc == nil then yawSrc = findSensor(YAW_SOURCES) end
        if altSrc == nil then altSrc = findSensor(ALT_SOURCES) end
        if modeSrc ~= nil and sourceValue(modeSrc) == nil then modeSrc = nil end
        if modeSrc == nil then modeSrc = findSensor(FLIGHT_MODE_SOURCES) end
    end
end

local seen, seenFc = {}, nil   -- per heli: the FC's id (session.mcu_id), not the name of the Ethos model (one model for several helis; 'sync model name' renames on disconnect)
local function nonZero(key, v)
    if v == nil then return nil end
    if v ~= 0 then seen[key] = true end
    if seen[key] then return v end
    return nil
end

local function becValid(v)
    if v == nil then return nil end
    if abs(v - BEC_FILL_BYTE) < 0.05 or v < BEC_MIN or v > BEC_MAX then return nil end
    return v
end

local function modelName()
    if model and model.name then
        local ok, n = pcall(model.name)
        if ok and n and tostring(n) ~= "" then return tostring(n) end
    end
    return nil
end

local headingRef, captured = nil, false
local function readHeading(tele)
    local v = tele.getSensor and tonumber((tele.getSensor("attyaw")))
    local q = nil
    if v ~= nil then
        q = tele.getSensorSource and tele.getSensorSource("attyaw")
    elseif yawSrc then
        v, q = sourceValue(yawSrc), yawSrc
    end
    if v == nil then return nil end
    if q and type(q.protocolDecimals) == "function" then
        local ok, n = pcall(q.protocolDecimals, q)
        if ok and n == 0 then v = v / 10 end
    end
    return v % 360
end

local function headingStep(deg, armed)
    if deg == nil then
        if not captured then headingRef = nil end
        return
    end
    if armed then
        if not captured then headingRef = deg end
        captured = true
    else
        captured = false
        if headingRef == nil then headingRef = deg end
    end
end

local rpmPeak, cellF = 0, nil
local st = {link = false}
local peaks = {}   -- per bank min and max of the headspeed while armed: the peak marker on the banks page reads here
local lastFlight = {}   -- the current maximum, used mAh and bank of the last flight: the pages before and after the flight read here
local flight = {running = false, ended = false, mahStart = nil, currentMax = nil, bank = {0, 0, 0, 0, 0, 0}, clock = nil}   -- the running flight; the clock per bank (Rotorflight 4.6: up to six) counts armed with a turning rotor, from zero at arming, after the flight it stops
flight.session = {}   -- altitude and climb/sink since connecting, armed or not: the left page shows them as long as no flight is recorded here
local function celsius(v, fahrenheit) return fahrenheit and (v - 32) * 5 / 9 or v end   -- the colour limits are in °C
local function degreeSign(fahrenheit) return fahrenheit and "\194\176F" or "\194\176C" end

function flight.altitude(t, alt, now)   -- the highest altitude and the strongest climb and sink, computed from the altitude over at least half a second (t = flight or flight.session)
    if t.altMax == nil or alt > t.altMax then t.altMax = alt end
    if t.altAt == nil then t.altPrev, t.altAt = alt, now
    elseif now - t.altAt >= 0.5 then
        local rate = (alt - t.altPrev) / (now - t.altAt)
        if t.climbMax == nil or rate > t.climbMax then t.climbMax = rate end
        if t.sinkMax == nil or rate < t.sinkMax then t.sinkMax = rate end
        t.altPrev, t.altAt = alt, now
    end
end

function flight.lastTime()   -- the flight time of the last flight as the suite keeps it per model (session.modelPreferences, general.lastflighttime in seconds); nil without an entry
    local ini = rf and rf.ini
    local prefs = rf and rf.session and rf.session.modelPreferences
    if type(ini) ~= "table" or type(ini.getvalue) ~= "function" or type(prefs) ~= "table" then return nil end
    local ok, v = pcall(ini.getvalue, prefs, "general", "lastflighttime")
    v = ok and tonumber(v) or nil
    if v ~= nil and v > 0 then return v end
    return nil
end

local function read(tele)
    local s = {link = tele.active and tele.active() or false}
    local mn = modelName()
    local fc = rf and rf.session and rf.session.mcu_id
    if fc ~= nil and fc ~= seenFc then   -- another FC: what belonged to the previous one no longer applies; without a link it stays
        seen, seenFc, rpmPeak, cellF, lastFlight = {}, fc, 0, nil, {}
        for k in pairs(peaks) do peaks[k] = nil end
        for k in pairs(flight.session) do flight.session[k] = nil end
    end
    s.craft = mn
    if s.link then
        local function g(k) return tonumber((tele.getSensor(k))) end
        s.pack = nonZero("pack", g("voltage"))
        s.cell = nonZero("cell", g("cell_voltage"))
        local cells = g("cell_count")
        if s.cell == nil and s.pack ~= nil and cells ~= nil and cells >= 1 then s.cell = s.pack / cells end
        if s.cell ~= nil then
            if cellF == nil or abs(s.cell - cellF) > 0.3 then cellF = s.cell else cellF = cellF * 0.9 + s.cell * 0.1 end
            s.cellF = cellF
        end
        s.rssi, s.vfr = g("link"), g("vfr")
        s.rpm = g("rpm")
        if s.rpm and s.rpm > rpmPeak then rpmPeak = s.rpm end
        local function readTemp(k)   -- temperatures in the radio's unit: in Fahrenheit the suite gives the value in °F and names the unit as the third return value; limits and sign follow it
            local v, _, b = tele.getSensor(k)
            local unit = (type(b) == "string" and b:find("\194\176") and b) or nil
            return tonumber(v), unit == "\194\176F"
        end
        local tempEsc, escF = readTemp("temp_esc")
        s.temp, s.tempF = nonZero("temp", tempEsc), escF
        local tempMcu, mcuF = readTemp("temp_mcu")
        s.mcutemp, s.mcutempF = tempMcu, mcuF
        if s.mcutemp ~= nil and (celsius(s.mcutemp, mcuF) < 10 or celsius(s.mcutemp, mcuF) > 130) then s.mcutemp = nil end
        local arm = g("armflags")
        if arm ~= nil then s.armed = floor(arm) % 2 == 1 end
        s.bec = nonZero("bec", becValid(g("bec_voltage")))
        s.bank, s.rate = g("pid_profile"), g("rate_profile")
        s.amps = nonZero("amps", g("current"))
        s.fuel = g("fuel")
        if s.fuel ~= nil and (s.fuel < 0 or s.fuel > 100) then s.fuel = nil end
        s.cells = cells
        s.used = g("consumption")
        local alt, _, altUnit = tele.getSensor("altitude")   -- the unit is the third value; a value in feet comes as ft
        alt = tonumber(alt)
        if alt == nil and altSrc then alt, altUnit = sourceValue(altSrc), nil end
        s.alt = nonZero("alt", alt)
        s.altFt = altUnit == "ft"
        if s.alt ~= nil then flight.altitude(flight.session, s.alt, os.clock()) end
        s.cpu = sourceValue(cpuSrc)
        if s.cpu ~= nil and (s.cpu < 0 or s.cpu > 100) then s.cpu = nil end
        s.flightMode = sourceValue(modeSrc)   -- the firmware's bits (runtime_config.h): ANGLE 2, HORIZON 4, RESCUE 32
        s.deg = readHeading(tele)
    end
    if s.armed == true and s.rpm ~= nil and s.rpm > 0 and s.bank ~= nil then
        local b = floor(s.bank)
        local pk = peaks[b]
        if pk == nil then
            peaks[b] = {min = s.rpm, max = s.rpm}
        else
            if s.rpm < pk.min then pk.min = s.rpm end
            if s.rpm > pk.max then pk.max = s.rpm end
        end
    end
    if s.armed == true then   -- the flight: current maximum, consumption and the clock per bank run until the heli is disarmed
        if not flight.running then
            flight.running, flight.mahStart, flight.currentMax, flight.bank, flight.clock = true, s.used, nil, {0, 0, 0, 0, 0, 0}, nil
            flight.altMax, flight.climbMax, flight.sinkMax, flight.altPrev, flight.altAt = nil, nil, nil, nil, nil
        end
        if s.amps ~= nil and (flight.currentMax == nil or s.amps > flight.currentMax) then flight.currentMax = s.amps end
        local now, b = os.clock(), s.bank and floor(s.bank) or nil
        if flight.clock ~= nil and s.rpm ~= nil and s.rpm > 0 and b ~= nil and flight.bank[b] ~= nil then flight.bank[b] = flight.bank[b] + (now - flight.clock) end
        flight.clock = now
        if s.alt ~= nil then flight.altitude(flight, s.alt, now) end   -- the highest altitude and the strongest climb and sink of the flight
    elseif flight.running and s.armed == false then   -- the flight ends on a confirmed disarm
        flight.running, flight.ended, flight.clock = false, true, nil
        lastFlight = {current = flight.currentMax, bank = s.bank and floor(s.bank) or nil,
                       mah = (s.used ~= nil and flight.mahStart ~= nil) and (s.used - flight.mahStart) or nil,
                       alt = flight.altMax, climb = flight.climbMax, sink = flight.sinkMax, time = flight.bank[1] + flight.bank[2] + flight.bank[3] + flight.bank[4] + flight.bank[5] + flight.bank[6]}
    elseif flight.running then
        flight.clock = nil   -- link lost, arm state unknown: the flight stays open and the gap counts for no bank
    end
    s.tx = sourceValue(txSrc)
    local tm = rf and rf.session and rf.session.timer
    s.timer = tm and tonumber(tm.live) or nil
    headingStep(s.deg, s.armed == true)
    s.angle = (headingRef ~= nil and s.deg ~= nil) and (s.deg - headingRef) % 360 or nil
    return s
end

local function fmt(n, u, d)
    if n == nil then return "" end
    local z = string.format("%." .. (d or 0) .. "f", n)
    if n < 0 and z:find("^%-[0.]*$") then z = z:sub(2) end   -- what rounds to zero stands without a minus (altitude -0.3 m, current -0.2 A)
    return z .. (u or "")
end

local function fmtT(sec)
    if sec == nil then return "" end
    sec = max(0, floor(sec + 0.5))
    return string.format("%02d:%02d", floor(sec / 60), sec % 60)
end

local function cellKey(v)
    if v == nil then return "w" end
    if v < 3.45 then return "r" end
    if v < 3.65 then return "o" end
    if v < 3.75 then return "y" end
    return "g"
end

local function cellBars(v, n)
    if v == nil then return 0 end
    local p = (v - 3.5) / (4.2 - 3.5)
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    return floor(p * n + 0.5)
end

local function armInfo(s)
    if not s.link then return T.link, C_GRAY, C_LRED end
    if s.armed == true then return "ARMED", C_GREEN, SETC.field end
    if s.armed == false then return "DISARMED", C_RED, SETC.field end
    return T.unknown, C_GRAY, C_WHITE
end

local function rpmShare(v)   -- the value as a share of the arc (0 bottom left, 1 right); the highest flown headspeed sits at 0.8
    if v == nil then return nil end
    local full = max(RPM_REF_DEFAULT, rpmPeak) * 1.25
    if v < 0 then v = 0 elseif v > full then v = full end
    return v / full
end

local function paintHeading(w)
    local R = HEADING
    lcd.color(C_RING)
    fillCircle(X(R.x), Y(R.y), max(1, floor(sx(R.r) + 0.5)))
    lcd.color(C_BLACK)
    fillCircle(X(R.x), Y(R.y), max(1, floor(sx(R.r - R.rim) + 0.5)))
    if w == nil then return end
    local function point(r, deg)
        local a = math.rad(w + deg)
        return X(R.x + r * math.sin(a)), Y(R.y - r * math.cos(a))
    end
    local x1, y1 = point(R.tip, 0)
    if type(lcd.drawFilledTriangle) == "function" then
        local x2, y2 = point(R.base, R.corner)
        local x3, y3 = point(R.base, -R.corner)
        local xm, ym = point(R.base * math.cos(math.rad(180 - R.corner)), 180)
        lcd.color(C_NEEDLE_LIGHT)
        lcd.drawFilledTriangle(x1, y1, x3, y3, xm, ym)
        lcd.color(C_NEEDLE_SHADOW)
        lcd.drawFilledTriangle(x1, y1, xm, ym, x2, y2)
    else
        lcd.color(C_NEEDLE_LIGHT)
        lcd.drawLine(X(R.x), Y(R.y), x1, y1)
    end
end

local lockedUntil = 0

local MONITORS, DOORS, LOADERS = {}, {}, {}   -- monitors: full screens over the cockpit; MONITORS[name] = {paint, event, back}, DOORS = {zone, target}; LOADERS[name] loads a screen only when it opens and releases it when it closes
local activeMonitor = nil
local PAGES = {preflight = -1, banks = 1}   -- the pages beside the cockpit: on the left the one before the flight, on the right the banks

local function openMonitor(name)
    local m = MONITORS[name]
    if m == nil and LOADERS[name] then
        collectgarbage("collect")   -- make room first: the suite and other scripts share the radio's Lua memory with the theme (seen on the X18)
        m = LOADERS[name]()
    end
    if m == nil then return false end
    if m.open then
        local ok, opened = pcall(m.open)
        if not ok or opened == false then return false end
    end
    MONITORS[name], activeMonitor = m, name
    return true
end

local function closeMonitor()
    local name = activeMonitor
    local m = name and MONITORS[name]
    activeMonitor = nil
    if m and m.leave then m.leave() end
    if name and LOADERS[name] then
        MONITORS[name] = nil
        collectgarbage("collect")   -- the page is free: its memory should go now, not some time later (seen on the X18)
    end
end

local function paint(x, y, w, h, s)
    ox, oy, fx, fy = x, y, w / 480, h / 320
    if tableStage < 2 then
        tableStep()
        paintBackground(colorNr)
        return
    end
    s = s or st
    if s.link and rf and rf.session and rf.session.isConnected == false then s = NO_LINK end   -- the suite wakes the box only once when the link drops; if that falls into the 0.1 s, the picture still shows NO LINK
    local m = activeMonitor and MONITORS[activeMonitor]
    if m then
        m.paint(x, y, w, h, s)
        return
    end
    paintBackground(colorNr)
    for _, L in ipairs(U.labels) do labelCentered(L[1], L[2] + 6, L[3], C_WHITE, L[4] or F_SM) end

    local at, ac, atc = armInfo(s)
    fillRounded(U.arm.x, U.arm.y, U.arm.w, U.arm.h, ac)
    labelCenteredFit(U.arm.x + U.arm.w / 2, U.arm.y + U.arm.h / 2 + U.arm.dy, at, atc, U.arm.f, U.arm.w - 4)
    paintHeading(s.angle)

    if s.rssi then showSystem(U.rssi, "RSSI " .. fmt(s.rssi, "dB", 0), C_WHITE, 8) end
    if s.vfr then
        local vk = (s.vfr >= VFR_YEL) and "w" or ((s.vfr >= VFR_RED) and "y" or "r")
        showSystem(U.vfr, "VFR " .. fmt(s.vfr, "", 0), SETC[vk], 8)
    end
    labelCentered(58, 77, T.timer, C_WHITE, F_SM)
    if s.timer ~= nil then timerLine(U.timer, "", fmtT(s.timer), C_LGREEN) else timerLine(U.timer, "", "--:--", C_DIM) end   -- the three dashes below are gone

    local bf = (s.bank ~= nil and s.rate ~= nil and s.bank ~= s.rate) and C_LRED or C_LGREEN
    if s.bank ~= nil then showValue(U.bank, fmt(s.bank, "", 0), bf) else showValue(U.bank, "?", C_DIM) end
    if s.rate ~= nil then showValue(U.rate, fmt(s.rate, "", 0), bf) else showValue(U.rate, "?", C_DIM) end

    if s.alt ~= nil then showValue2(U.alt, fmt(s.alt, "", 0), s.altFt and "ft" or "m", C_LGREEN) else showValue(U.alt, "--", C_DIM) end

    local R = frame()
    if R then R.gauge(LINES.M, lineColors(colorNr), R.BIG, GAUGE.cx, GAUGE.cy, rpmShare(s.rpm)) end   -- arc, ticks and the pointer as before
    if s.craft then
        local name = (#s.craft > 16) and s.craft:sub(1, 16) or s.craft
        local b, h = measure(name, U.modelname.f)
        drawTextAt(X(U.modelname.x) - floor(b / 2), Y(U.modelname.y + 10) - h / 2, name, C_WHITE, U.modelname.f)
    end
    if s.rpm then showValue(U.rpm, fmt(s.rpm, "", 0), C_LGREEN, 16) end

    if s.bec then showValue2(U.bec, fmt(s.bec, "", 1), "V", (s.bec >= 5.0) and C_LGREEN or C_YELLOW) else showValue(U.bec, "--", C_DIM) end
    if s.tx then
        showValue2(U.tx, fmt(s.tx, "", 1), "V", (s.tx >= 7.4) and C_LGREEN or ((s.tx >= 7.0) and C_YELLOW or C_LRED))
    else showValue(U.tx, "--", C_DIM) end
    if s.amps then showValue2(U.amp, fmt(s.amps, "", 1), "A", C_LGREEN) else showValue(U.amp, "--", C_DIM) end
    labelCentered(289, 59, (cpuName == "RT Load") and "RT" or "CPU", C_WHITE, F_SM)
    if s.cpu then
        showValue2(U.cpu, fmt(s.cpu, "", 0), "%", (s.cpu < 50) and C_LGREEN or ((s.cpu < 80) and C_YELLOW or C_LRED), 8)
    else showValue(U.cpu, "--", C_DIM, 8) end

    local locked = os.clock() < lockedUntil
    local cv = s.cellF or s.cell
    local packEnd = nil
    if s.pack and not locked then packEnd = showValue2(U.pack, fmt(s.pack, "", 1), "V", SETC[cellKey(cv)], 16) end
    local p = s.fuel   -- the charge as the suite computes it (the same as the bars in the tank); without a fuel sensor estimated from the cell
    if p == nil and cv then p = (cv - 3.5) / 0.7 * 100 end
    if p ~= nil and not locked then
        if p < 0 then p = 0 elseif p > 100 then p = 100 end
        local text, font = fmt(p, "", 0), U.battpct.f
        if packEnd ~= nil and X(U.battpct.x) - (measure(text, font) + max(1, sx(2)) + measure("%", font)) < packEnd + sx(8) then font = F_BIG end   -- 100 % would run into the V of the voltage: one font smaller, the same place
        showValue2(U.battpct, text, "%", SETC[cellKey(cv)], 16, font)
    end
    local bars, hc = cellBars(cv, U.batt.n), SETC[cellKey(cv)]
    for i = 1, bars do fillRect(U.batt.x, U.batt.y - (i - 1) * (U.batt.bh + U.batt.gap), U.batt.bw, U.batt.bh, hc) end
    if s.fuel then   -- the tank: consumption against the battery capacity, in the frame under ESC, coloured like the battery bars; without a sensor the frame stays empty
        for i = 1, floor(s.fuel / (100 / U.tank.n)) do   -- 100 % over the four bars: one bar per full quarter
            fillRect(U.tank.x + (i - 1) * (U.tank.bw + U.tank.gap), U.tank.y, U.tank.bw, U.tank.bh, hc)
        end
    end

    local wordBottom = "ESC"   -- the bottom right field: the ESC temperature; if the ESC sends none, the voltage per cell in the battery colour, and the word above changes with it
    if s.temp then
        local tc = celsius(s.temp, s.tempF)
        showValue2(U.temp, fmt(s.temp, "", 0), degreeSign(s.tempF), (tc < 60) and C_LGREEN or ((tc < 80) and C_YELLOW or C_LRED))
    elseif cv then
        wordBottom = "CELL"   -- the same in every language, like ESC and BEC
        if not locked then showValue2(U.temp, fmt(cv, "", 2), "V", SETC[cellKey(cv)]) end
    else showValue(U.temp, "--", C_DIM) end
    labelCentered(421, 262 + 6, wordBottom, C_WHITE, F_SM)
    if s.mcutemp then
        local tc = celsius(s.mcutemp, s.mcutempF)
        showValue2(U.mcutemp, fmt(s.mcutemp, "", 0), degreeSign(s.mcutempF), (tc < 70) and C_LGREEN or ((tc < 90) and C_YELLOW or C_LRED), 8)
    else showValue(U.mcutemp, "--", C_DIM, 8) end

    if locked then labelCenteredFit(252, 300, T.armed, C_LRED, F_SM, 196) end
end

local press = nil
local fingerOurs = false                       -- the finger came down on a zone of the theme and has not left it
local TOUCH_HOLD = rawget(_G, "TOUCH_LONG")     -- Ethos: long press

local function tone(hz, ms) if system and type(system.playTone) == "function" then pcall(system.playTone, hz, ms, 0) end end

local function armedNow() return (st.armed == true) or (rf ~= nil and rf.session ~= nil and rf.session.isArmed == true) end

local function headLong()
    press = nil
    if armedNow() then
        lockedUntil = os.clock() + LOCK_SEC
        tone(200, 90)
    elseif nextColor() then
        tone(880, 120)
    else
        tone(200, 90)                               -- nothing saved, nothing changed
    end
end

local function checkLongPress()   -- true when the long press changed the colour here: the tick then carries only the saving
    local d = press
    if d == nil or d.zone ~= "header" then return false end
    local age = os.clock() - d.since
    if age < LONG then return false end
    if age > LONG + 0.4 then   -- the tick sees it this old only when the suite took the finger (the toolbar swipe): no press any more
        press = nil
        return false
    end
    headLong()
    return true
end

local firstWake = true
local function wake(box, tele)
    if firstWake then firstWake = false   -- the first wakeup already carries loading this file
    elseif colorSave.step ~= nil then colorStep() return st   -- a step of saving carries this tick alone
    elseif tableStage < 2 then tableStep()
    end
    local now = os.clock()
    if checkLongPress() then return st end
    if now - colorReadAt >= COLOR_READ_SEC then
        colorReadAt = now
        readColor()
    end
    if now - sourceSearchAt >= 5 then
        sourceSearchAt = now
        findSources()
    end
    if tele then st = read(tele) end
    if flight.ended then   -- after the flight the banks page opens by itself
        flight.ended = false
        if activeMonitor == nil then openMonitor("banks") end
    end
    local m = activeMonitor and MONITORS[activeMonitor]
    if m and m.tick then m.tick() end
    return st
end

local function hits(z, x, y)
    return x ~= nil and y ~= nil and x >= X(z.x) and x < X(z.x) + sx(z.w) and y >= Y(z.y) and y < Y(z.y) + sy(z.h)
end

local swipe = nil   -- a sideways swipe over free space turns between the pages (left the one before, the centre the cockpit, right the one after); vertical stays with Ethos and the suite, on the pages too
local SWIPE_FAR, SWIPE_DECIDE = 50, 16   -- decided after 16 points by the larger direction: the start of a swipe often goes at a slant
local function turnPage(dir)   -- -1: swiped to the left = the page after; +1: swiped to the right = the page before
    local side = activeMonitor and PAGES[activeMonitor]
    if activeMonitor == nil then return openMonitor(dir < 0 and "banks" or "preflight") end
    if side == nil then return false end   -- a screen without a side (BANK) does not turn
    if (side > 0 and dir > 0) or (side < 0 and dir < 0) then closeMonitor() return true end   -- back to the cockpit
    return false   -- there is no further page beyond this one
end
local function swiping(value, x, y)   -- true = consumed, false = for Ethos, nil = no swipe (the tap goes on)
    if value == TOUCH_START then
        swipe = (x ~= nil and y ~= nil) and {x = x, y = y, across = nil, lastX = x} or nil
        return nil
    end
    if swipe == nil then return nil end
    if value == TOUCH_MOVE then
        if x == nil or y == nil then return nil end
        local dx, dy = x - swipe.x, y - swipe.y
        if swipe.across == nil then
            if abs(dx) < SWIPE_DECIDE and abs(dy) < SWIPE_DECIDE then return true end   -- not decided yet: the finger stays with the theme
            if abs(dy) > abs(dx) then   -- vertical: for the dashboard (toolbar up, info panel down)
                swipe = nil
                return false
            end
            swipe.across = true
        end
        swipe.lastX = x
        return true
    end
    if value == TOUCH_END then
        local w = swipe
        swipe = nil
        if not w.across then return nil end
        local dx = (x or w.lastX) - w.x
        if dx <= -SWIPE_FAR then turnPage(-1) elseif dx >= SWIPE_FAR then turnPage(1) end
        return true   -- a sideways swipe stays consumed, even when it turns nothing
    end
    if TOUCH_HOLD ~= nil and value == TOUCH_HOLD then swipe = nil end
    return nil
end

local function captureHeading(widget)   -- the ring: on the ground the measured heading becomes the reference, armed or without a heading the low tone
    if st.deg ~= nil and not armedNow() then
        headingRef = st.deg
        tone(880, 120)
    else
        tone(200, 90)
    end
    if widget then lcd.invalidate(widget) end
    return true
end

local function event(widget, category, value, x, y)
    if category ~= EVT_TOUCH then return false end
    local m = activeMonitor and MONITORS[activeMonitor]
    if m then   -- in a monitor only its BACK zone and its own event count; the cockpit zones are closed
        local consumed = true   -- a page lets through what free space on the cockpit lets through: the start, a vertical swipe, an end that turned nothing
        if value == TOUCH_START then
            press = hits(m.back, x, y) and {zone = "back", since = os.clock(), x = x, y = y} or nil
            if press == nil and m.page then
                swiping(TOUCH_START, x, y)
                consumed = false
            end
        elseif value == TOUCH_MOVE then
            if press and x and y and (abs(x - press.x) > DRIFT or abs(y - press.y) > DRIFT) then
                if m.page then swiping(TOUCH_START, press.x, press.y) end   -- the finger leaves the zone: a swipe from where it came down
                press = nil
            end
            if press == nil and m.page then consumed = swiping(TOUCH_MOVE, x, y) == true end
        elseif value == TOUCH_END and press == nil and m.page and swiping(TOUCH_END, x, y) then
            if widget then lcd.invalidate(widget) end
            return true
        elseif value == TOUCH_END and press == nil and m.page then
            consumed = false
        elseif (value == TOUCH_END or value == TOUCH_HOLD) and press ~= nil then
            local d = press
            press = nil
            if d.zone == "back" then   -- what counts is the release on the button, not how long it was pressed
                tone(880, 120)   -- the same tone as the buttons on the screens
                closeMonitor()
                if widget then lcd.invalidate(widget) end
                return true
            end
        end
        if m.event then m.event(widget, category, value, x, y) end
        return consumed   -- a move the theme does not consume Ethos may take, then no TOUCH_END comes: only a vertical swipe goes
    end
    if value == TOUCH_START then
        press = nil
        if hits(ZONES.header, x, y) then press = {zone = "header", since = os.clock(), x = x, y = y}
        elseif hits(ZONES.heading, x, y) then press = {zone = "heading", since = os.clock(), x = x, y = y}
        else
            for i = 1, #DOORS do
                local t = DOORS[i]
                if hits(t.zone, x, y) then
                    press = {zone = "door", target = t.target, since = os.clock(), x = x, y = y}
                    break
                end
            end
        end
        fingerOurs = (press ~= nil)
        if press == nil then swiping(TOUCH_START, x, y) end   -- free space: if it becomes a sideways swipe, the theme turns the page
        return press ~= nil   -- when the finger comes down on a zone, the theme keeps it
    end
    if value == TOUCH_MOVE then
        if press and x and y and (abs(x - press.x) > DRIFT or abs(y - press.y) > DRIFT) then   -- the finger leaves its zone: a swipe from where it came down, as on free space, else Ethos takes it and moves the whole dashboard on
            swiping(TOUCH_START, press.x, press.y)
            press, fingerOurs = nil, false
        end
        if press ~= nil then return true end   -- while the finger is still on its zone the theme consumes the move: else Ethos takes it for turning and TOUCH_END never comes
        local r = swiping(TOUCH_MOVE, x, y)
        return r == true
    end
    if value == TOUCH_END and press == nil and swiping(TOUCH_END, x, y) then
        if widget then lcd.invalidate(widget) end
        return true
    end
    if value == TOUCH_HOLD then   -- after about a second Ethos reports the long press itself, no TOUCH_END comes after it
        swipe = nil
        local d = press
        if d and d.zone == "header" then
            headLong()
            if widget then lcd.invalidate(widget) end
        else
            press = nil
            if d and d.zone == "door" and openMonitor(d.target) then
                tone(880, 120)   -- the door beeps on a long press too
                if widget then lcd.invalidate(widget) end
            elseif d and d.zone == "heading" then
                captureHeading(widget)   -- the ring takes the heading on a long press too
            end
        end
        return fingerOurs   -- if the finger lay on a zone, the long press is consumed: Ethos puts nothing of its own over it
    end
    if value ~= TOUCH_END or press == nil then return false end
    local d = press
    press = nil
    if d.zone == "door" then
        if openMonitor(d.target) then   -- a door opens on release, however long the finger lay
            tone(880, 120)   -- a door that opens beeps like the compass
            if widget then lcd.invalidate(widget) end
            return true
        end
        return false
    end
    if d.zone ~= "heading" then return false end
    return captureHeading(widget)   -- on release, however long the finger lay
end

do   -- the pages beside the cockpit: files of their own, they get the peak memo, a memo that outlives closing, and the suite; and the pictures go when the suite clears its caches
    local HELPERS = {hits = hits, tone = tone, peaks = peaks, loadAsset = loadAsset, fadeMasks = LINES.fadeMasks, cornerMasks = LINES.cornerMasks, memo = {},
                    rf = function() return rf end, state = function() return st end,
                    open = function(name) return openMonitor(name) end, close = function() closeMonitor() end,
                    color = function() return colorNr end, colorName = function() return COLORS[colorNr] end,
                    light = function() return MODE.light end, lightName = function() return MODE.names[MODE.base[colorNr] or 1] end,   -- the mode and the light version of the colour (photo_frame_light_<name>.png)
                    background = function() return BG.paint(colorNr, frame()) end,   -- the cockpit background, whole; the pages draw it first
                    lines = function() return lineColors(colorNr) end, frame = frame, photoPath = photoPath,
                    rpmFull = function() return max(RPM_REF_DEFAULT, rpmPeak) * 1.25 end,   -- the end of the arc, as in the cockpit
                    flight = function() return lastFlight end, bankTime = function() return flight.bank end,
                    session = function() return flight.session end, lastFlightTime = flight.lastTime,   -- without a flight here: the maximum values since connecting and the suite's last flight time
                    colors = MODE.pages,   -- the value colours: the same limits as in the cockpit, by mode (MODE.set refills the table)
                    cellColor = function(cell) return SETC[cellKey(cell)] end,
                    linkColor = function(s) return s.vfr and SETC[(s.vfr >= VFR_YEL) and "w" or ((s.vfr >= VFR_RED) and "y" or "r")] or C_WHITE end}
    local PAGE_FILES = {{"preflight"}, {"banks", {x = 20, y = 184, w = 92, h = 44}}}   -- door: the BANK/RATE field opens the banks page; the left page has no door, both also open with a sideways swipe
    for _, m in ipairs(PAGE_FILES) do
        LOADERS[m[1]] = function()
            local chunk = loadAsset(loadfile, m[1] .. ".lua")
            if not chunk then return nil end
            local ok, page = pcall(chunk, HELPERS)
            if ok and type(page) == "table" then return page end
            return nil
        end
        if m[2] then DOORS[#DOORS + 1] = {zone = m[2], target = m[1]} end
    end
    local function releaseImages()   -- the suite's clearCaches({images = true}), on every theme reload, theme switch and close: every picture and mask goes, the next paint loads what it needs
        BG.image, BG.name, BG.tries = nil, nil, 0
        for k in pairs(LOGO.image) do LOGO.image[k] = nil end
        for k in pairs(LOGO.tries) do LOGO.tries[k] = nil end
        for k in pairs(LINES.notch) do LINES.notch[k] = nil end
        for k in pairs(LINES.corners) do LINES.corners[k] = nil end
        for k in pairs(LINES.fade) do LINES.fade[k] = nil end
        local images = HELPERS.memo.images   -- photo and photo frame of the left page
        if images then for k in pairs(images) do images[k] = nil end end
    end
    local utils = rf and rf.widgets and rf.widgets.dashboard and rf.widgets.dashboard.utils
    if type(utils) == "table" and type(utils.registerImageCacheClearer) == "function" then utils.registerImageCacheClearer(releaseImages) end
end

local BOX = {col = 1, row = 1, type = "func", wakeupinterval = 0.1, wakeup = wake, paint = function(x, y, w, h, box, cache) paint(x, y, w, h, cache) end}

local STATE = {layout = {cols = 1, rows = 1, padding = 0}, boxes = {BOX}, event = event,
                 scheduler = {spread_scheduling = false, spread_scheduling_paint = false, spread_ratio = 1.0}}

return {state = function() return STATE end, paint = paint, read = read, wake = wake, event = event, dir = BASE,   -- dir: the folder this cockpit is loaded from (state.lua)
        monitors = MONITORS, doors = DOORS, openMonitor = openMonitor, closeMonitor = closeMonitor,
        activeMonitor = function() return activeMonitor end}
