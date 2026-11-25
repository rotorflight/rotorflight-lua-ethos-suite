-- Drawing parts of the theme's pages: colours, text in the radio's font, text fitted to a width, fields, buttons and frames.
local H = ...
local nova = H.nova
local style = {}

style.BG    = lcd.RGB(8, 10, 13)        -- #080a0d
style.CYAN     = lcd.RGB(60, 200, 255)     -- left
style.MAGENTA  = lcd.RGB(255, 60, 130)     -- right
style.WHITE    = lcd.RGB(240, 244, 248)
style.DIM    = lcd.RGB(152, 164, 178)
style.LINE    = lcd.RGB(188, 200, 214)
style.RED      = lcd.RGB(255, 70, 70)
style.YELLOW     = lcd.RGB(255, 200, 60)
style.GREEN    = lcd.RGB(90, 220, 130)     -- the green tick
style.SIGN  = lcd.RGB(100, 205, 125)   -- the signs under the word mark - a tone of its own, so that GREEN alone means confirmed
style.NEON     = lcd.RGB(90, 255, 70)
style.BAR_RIM    = lcd.RGB(62, 24, 28)
style.BAR_BED    = lcd.RGB(58, 62, 70)
style.BED_DARK    = lcd.RGB(26, 29, 34)
style.BUBBLE         = lcd.RGB(20, 23, 28)
style.STOP_DIM = lcd.RGB(120, 66, 90)
style.BED_RED = lcd.RGB(58, 18, 24)
style.TRACK     = lcd.RGB(120, 126, 136)

style.RGB_OF = {
    [style.CYAN]    = {60, 200, 255},
    [style.MAGENTA] = {255, 60, 130},
    [style.WHITE]   = {240, 244, 248},
    [style.GREEN]   = {90, 220, 130},
    [style.YELLOW]    = {255, 200, 60},
    [style.RED]     = {255, 70, 70},
    [style.LINE]   = {170, 182, 196},
    [style.NEON]    = {90, 255, 70},
}

local G_R, G_G, G_B = 8, 10, 13
style.GLOW_RINGS = 3
style.FRAME_THICK = 4

local glowCache = {}

function style.glowStep(color, share)
    local c = style.RGB_OF[color]
    if c == nil then return nil end
    local slot = glowCache[color]
    if slot == nil then slot = {}; glowCache[color] = slot end
    local step = math.floor(share * 100)
    local done = slot[step]
    if done ~= nil then return done end
    done = lcd.RGB(math.floor(G_R + (c[1] - G_R) * share),
                     math.floor(G_G + (c[2] - G_G) * share),
                     math.floor(G_B + (c[3] - G_B) * share))
    slot[step] = done
    return done
end

style.REF_W, style.REF_H = 480, 320

local fx, fy, fb, fh = nil, nil, nil, nil

function style.windowRefresh()
    fx, fy, fb, fh = nil, nil, nil, nil
    local k = nova.italic
    if k then k.windowNew() end
end

function style.window()
    if fb ~= nil then return fb, fh end
    fb, fh = lcd.getWindowSize()
    fx, fy = fb / style.REF_W, fh / style.REF_H
    return fb, fh
end

local function factors()
    if fx ~= nil then return fx, fy end
    style.window()
    return fx, fy
end

local floor = math.floor

function style.sx(x)                           -- every draw call goes through here: no detour through factors()
    if fx == nil then factors() end
    return floor(x * fx + 0.5)
end

function style.sy(y)
    if fy == nil then factors() end
    return floor(y * fy + 0.5)
end

function style.background(x, y, w, h)
    lcd.color(style.BG)
    lcd.drawFilledRectangle(style.sx(x), style.sy(y), style.sx(w), style.sy(h))
end

function style.fillRect(x, y, w, h, color)
    lcd.color(color or style.WHITE)
    lcd.drawFilledRectangle(style.sx(x), style.sy(y), style.sx(w), style.sy(h))
end

local HAS_CIRCLE = type(lcd.drawFilledCircle) == "function"   -- once on loading, not per corner (instructions)
local function fillCircle(x, y, r)
    if HAS_CIRCLE then
        lcd.drawFilledCircle(x, y, r)
    else
        lcd.drawFilledRectangle(x - r, y - r, 2 * r, 2 * r)
    end
end

local HAS_SECTOR = type(lcd.drawAnnulusSector) == "function"   -- Ethos from 1.1.0: an arc is ONE call instead of twelve triangles

local function mix(r1, g1, b1, r2, g2, b2, t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return lcd.RGB(math.floor(r1 + (r2 - r1) * t),
                   math.floor(g1 + (g2 - g1) * t),
                   math.floor(b1 + (b2 - b1) * t))
end

function style.measure(text, font)
    text = tostring(text or "")
    local k = nova.italic
    if k then
        local b, h = k.width(text, font)
        if b then return b, h end
    end
    lcd.font(font or FONT_S)
    local b, h = lcd.getTextSize(text)
    return b, h
end

function style.drawTextAt(px, py, text, color, font)
    text = tostring(text or "")
    lcd.color(color or style.WHITE)
    local k = nova.italic
    if k then
        local b = k.paint(px, py, text, font)
        if b then return b end
    end
    lcd.font(font or FONT_S)
    lcd.drawText(math.floor(px), math.floor(py), text)
    return (lcd.getTextSize(text))
end

function style.shorten(text, font, maxReal)
    local full = style.measure(text, font)
    if full <= maxReal then return text end
    local n = #text
    if n <= 4 then return text end
    local perChar = full / n
    local fits = math.floor(maxReal / perChar) - 3
    if fits < 4 then fits = 4 end
    if fits > n then fits = n end
    text = text:sub(1, fits)
    local guard = 0
    while #text > 4 and style.measure(text .. "...", font) > maxReal and guard < 40 do
        text = text:sub(1, #text - 1)
        guard = guard + 1
    end
    return text .. "..."
end

local function labelRaw(x, y, text, color, font)
    return style.drawTextAt(x, y, text, color or style.DIM, font or FONT_S)
end

function style.label(x, y, text, color, font)
    labelRaw(style.sx(x), style.sy(y), text, color, font)
end

local STEP_DOWN = {}
do
    local steps = {"FONT_XXL", "FONT_XL", "FONT_L", "FONT_STD", "FONT_S"}
    local prev = nil
    for _, name in ipairs(steps) do
        local val = rawget(_G, name)
        if val ~= nil then
            if prev ~= nil then STEP_DOWN[prev] = val end
            prev = val
        end
    end
end

local stepMemo, stepMemoN = {}, 0
local STEP_MEMO_MAX = 64                       -- a full screen carries more than 16 words: with 16 it was computed again every paint
function style.stepMemoCount() return stepMemoN end   -- for the tests
function style.memoClear() stepMemo, stepMemoN = {}, 0 end   -- the font decisions belong to the screen that needed them

local function stepDecide(text, f, maxReal)
    local k = nova.italic
    local fb = style.window()
    local key = ((k and k.off) and "g" or "k")
                       .. "\1" .. fb .. "\1" .. tostring(f) .. "\1" .. maxReal .. "\1" .. text
    local e = stepMemo[key]
    if e then return e.f, e.text, e.dy end
    local orig = key
    local hBig, hSmall
    while true do
        local b, h = style.measure(text, f)
        hBig, hSmall = hBig or h, h
        if b <= maxReal then break end
        local smaller = STEP_DOWN[f]
        if not smaller then
            text = style.shorten(text, f, maxReal)
            break
        end
        f = smaller
    end
    local dy = 0
    if hBig and hSmall and hBig > hSmall then
        dy = math.floor((hBig - hSmall) / 2)   -- set smaller: the word stays on the middle of the row it would have stood in large
    end
    if stepMemoN >= STEP_MEMO_MAX then stepMemo, stepMemoN = {}, 0 end
    stepMemo[orig] = {f = f, text = text, dy = dy}
    stepMemoN = stepMemoN + 1
    return f, text, dy
end

function style.fitting(text, font, maxWidthRef)   -- in which font and with which text a ...Fit call draws the word (to prepare)
    return stepDecide(tostring(text or ""), font or FONT_STD, style.sx(maxWidthRef))
end

function style.labelFit(x, y, text, color, font, maxWidthRef)
    text = tostring(text or "")
    if text == "" then return end
    local maxRef = maxWidthRef or (style.REF_W - x - 4)
    local f, dy
    f, text, dy = stepDecide(text, font or FONT_STD, style.sx(maxRef))
    labelRaw(style.sx(x), style.sy(y) + dy, text, color, f)
end

local function systemMeasure(text, font)
    lcd.font(font or FONT_STD)
    return lcd.getTextSize(text)
end

style.BAR_FIELDS = 4   -- saving: four fields on the right of the message line, one per radio step
local function bar(step, color)
    local bw, bh = style.window()
    local _, th = systemMeasure("Ag", FONT_STD)
    local height = (th or 19) + 2
    if not style.bandDrawn then              -- no sentence before it: the strip gets its background here
        lcd.color(style.BG)
        lcd.drawFilledRectangle(0, bh - height - style.FRAME_THICK, bw, height + style.FRAME_THICK)
        style.bandDrawn = true
    end
    local left = math.max((style.bandEnd or 0) + style.sx(12), style.sx(250))   -- right of the word, never on it
    local right, air = bw - style.sx(8), style.sx(4)
    local w = math.floor((right - left - air * (style.BAR_FIELDS - 1)) / style.BAR_FIELDS)
    local h = height - 6
    if h < 4 or right - left < 20 then return false end   -- no room at all: not drawn, and the return value says so
    if w < 4 then w = 4 end                      -- a long sentence leaves little room: the bar gets narrow but does not silently vanish
    local y = bh - height - style.FRAME_THICK + 4
    for i = 1, style.BAR_FIELDS do
        local x = left + (i - 1) * (w + air)
        if i <= step then
            lcd.color(color)
            lcd.drawFilledRectangle(x, y, w, h)
        else
            lcd.color(style.LINE)
            lcd.drawRectangle(x, y, w, h)
        end
    end
    return true
end

function style.saveBar(step)
    if bar(step, style.GREEN) then style.barDrawn = "save" end   -- acknowledged = green like every confirmation; not drawn = not drawn
end

function style.workBar(fields)   -- reading or waiting: blue
    if bar(fields or 0, style.CYAN) then style.barDrawn = "work" end
end

function style.labelCenteredFit(cx, cy, text, color, font, maxWidthRef)
    text = tostring(text or "")
    if text == "" then return end
    local maxReal = style.sx(maxWidthRef or (style.REF_W - 8))
    local f
    f, text = stepDecide(text, font or FONT_STD, maxReal)
    local tb, th = style.measure(text, f)
    labelRaw(style.sx(cx) - math.floor(tb / 2),
                    style.sy(cy) - math.floor((th or 12) / 2), text, color, f)
end

function style.labelCentered(cx, cy, text, color, font)
    local tb, th = style.measure(text, font or FONT_S)
    labelRaw(style.sx(cx) - math.floor(tb / 2), style.sy(cy) - math.floor((th or 12) / 2),
                    text, color, font)
end

function style.systemCentered(cx, cy, text, color, font)
    text = tostring(text or "")
    if text == "" then return end
    lcd.font(font or FONT_S)
    local tb, th = lcd.getTextSize(text)
    lcd.color(color or style.DIM)
    lcd.drawText(style.sx(cx) - math.floor((tb or 0) / 2),
                 style.sy(cy) - math.floor((th or 12) / 2), text)
end

function style.baseline(px, gl, text, color, font)
    text = tostring(text or "")
    if text == "" then return 0 end
    local _, th = style.measure(text, font or FONT_S)
    return style.drawTextAt(px, style.sy(gl) - (th or 12), text, color, font)
end

function style.title(text, color, font)
    color = color or style.WHITE
    local f = font or FONT_XL
    style.labelCentered(240, 26, text, color, f)
end

function style.drawTextRight(rx, py, text, color, font)
    text = tostring(text or "")
    local k = nova.italic
    if k and k.paintRight then
        lcd.color(color or style.WHITE)
        local b = k.paintRight(rx, py, text, font)
        if b then return b end
    end
    local tb = style.measure(text, font)
    style.drawTextAt(rx - tb, py, text, color, font)
    return tb
end

function style.labelRight(rx, y, text, color, font)
    return style.drawTextRight(style.sx(rx), style.sy(y), text, color, font)
end

function style.labelRightFit(rx, y, text, color, font, maxWidthRef)
    text = tostring(text or "")
    if text == "" then return 0 end
    local maxReal = style.sx(maxWidthRef or rx)
    local f, dy
    f, text, dy = stepDecide(text, font or FONT_S, maxReal)
    return style.drawTextRight(style.sx(rx), style.sy(y) + dy, text, color, f)
end

style.FOOT_Y      = 276
style.FOOT_Y_LOW = 292

style.BUTTON_PAD_X = 8
style.BUTTON_PAD_Y = 4

style.BUTTON_BG = lcd.RGB(16, 42, 56)
style.BUTTON_DIM = lcd.RGB(140, 152, 164)

style.FIELD_DIM = lcd.RGB(158, 170, 184)
style.FIELD_RED   = lcd.RGB(255, 96, 96)     -- red ON the red field (gloss)

local function roundFill(x, y, w, h, r)             -- after the suite (GPLv3): a filled rectangle with round corners
    lcd.drawFilledRectangle(x + r, y, w - 2 * r, h)
    lcd.drawFilledRectangle(x, y + r, r, h - 2 * r)
    lcd.drawFilledRectangle(x + w - r, y + r, r, h - 2 * r)
    fillCircle(x + r, y + r, r)
    fillCircle(x + w - r - 1, y + r, r)
    fillCircle(x + r, y + h - r - 1, r)
    fillCircle(x + w - r - 1, y + h - r - 1, r)
end

style.M_DROP    = lcd.RGB(5, 7, 11)
style.TILE          = lcd.RGB(9, 13, 18)
style.TILE_EDGE    = lcd.RGB(43, 54, 66)
style.TILE_OPEN    = lcd.RGB(36, 52, 66)
style.TILE_SHIMMER = {lcd.RGB(92, 38, 62), lcd.RGB(150, 46, 88)}   -- magenta shimmer behind the word, outside to inside
style.M_FACE   = lcd.RGB(23, 29, 38)
style.M_SHEEN     = lcd.RGB(30, 37, 49)
style.M_LIGHT     = lcd.RGB(46, 57, 73)
style.M_SHADOW  = lcd.RGB(4, 6, 10)
style.M_FACE_S = lcd.RGB(28, 36, 47)
style.M_SHEEN_S   = lcd.RGB(38, 48, 63)
style.M_LIGHT_S   = lcd.RGB(61, 76, 96)
style.M_DEEP      = lcd.RGB(8, 10, 14)
style.M_DEEP_EDGE = lcd.RGB(35, 43, 54)
style.GLOSS_RGB = {
    normal   = {{46, 57, 73}, {23, 29, 38}},
    selected = {{61, 76, 96}, {28, 36, 47}},
    red      = {{74, 44, 56}, {32, 20, 26}},
}

style.M_FACE_R = lcd.RGB(32, 20, 26)
style.M_SHEEN_R   = lcd.RGB(42, 26, 34)
style.M_LIGHT_R   = lcd.RGB(74, 44, 56)

local glossCache, glossCacheN = {}, 0      -- rows per (width, height, radius, colour pair): computed once

local function glossRows(w, h, r, pair)
    local key = w .. "/" .. h .. "/" .. r .. "/" .. tostring(pair)
    local z = glossCache[key]
    if z then return z end
    if h > 64 then h = 64 end                -- the gloss ends, the tile does not
    local sh = (h > 11) and 2 or 1           -- from a ~28 px field: 2 px rows (cost)
    local n = math.max(2, math.floor(h / sh))
    local A, B = pair[1], pair[2]
    z = {sh = sh}
    for i = 0, n - 1 do
        local yy = i * sh
        local dx = 0                         -- at the top follow the rounding (chord)
        if r > 0 and yy < r then
            local d = r - yy
            dx = r - math.floor(math.sqrt(r * r - d * d))
        end
        local ww = w - 2 * dx - yy           -- each row as much shorter as it is high: 45 degrees
        if ww < 4 then break end
        z[#z + 1] = {dx, yy, ww,             -- a tone only every second row (cost)
                     (i % 2 == 0) and mix(A[1], A[2], A[3], B[1], B[2], B[3], i / (n - 1)) or false}
    end
    if glossCacheN >= 96 then glossCache, glossCacheN = {}, 0 end
    glossCache[key] = z
    glossCacheN = glossCacheN + 1
    return z
end

local function glossSlant(x, y, w, h, r, pair)
    local z = glossRows(w, h, r, pair)
    local sh = z.sh
    for i = 1, #z do
        local e = z[i]
        if e[4] then lcd.color(e[4]) end
        lcd.drawFilledRectangle(x + e[1], y + e[2], e[3], sh)
    end
end

local function edgesPaint(x, y, w, h, r, light)
    local k = math.max(1, r)
    lcd.color(light)                         -- light from the top left; the shadow
    lcd.drawFilledRectangle(x + k, y, w - 2 * k, 1)     -- comes from the drop
    lcd.drawFilledRectangle(x, y + k, 1, h - 2 * k)
end

local function shape(x, y, w, h, r)
    if r == 0 then lcd.drawFilledRectangle(x, y, w, h)
    else roundFill(x, y, w, h, r) end
end

local function fieldPaint(ex, ey, ew, eh, r, accent, kind)
    local k = math.max(2, r)

    if kind == "deep" then
        lcd.color(style.M_DEEP)
        shape(ex, ey, ew, eh, r)
        lcd.color(style.M_DEEP_EDGE)
        lcd.drawFilledRectangle(ex + k, ey + eh - 1, ew - 2 * k, 1)
        lcd.drawFilledRectangle(ex + ew - 1, ey + k, 1, eh - 2 * k)
        return
    end

    local face, sheen, lit = style.M_FACE, style.M_SHEEN, style.M_LIGHT
    local pair = style.GLOSS_RGB.normal
    if kind == "selected" then
        face, sheen, lit = style.M_FACE_S, style.M_SHEEN_S, style.M_LIGHT_S
        pair = style.GLOSS_RGB.selected
    elseif kind == "red" then
        face, sheen, lit = style.M_FACE_R, style.M_SHEEN_R, style.M_LIGHT_R
        pair = style.GLOSS_RGB.red
    end

    local narrow = accent ~= nil and ew < style.sx(200)
    if narrow then
        if nova.highDetail ~= false and style.RGB_OF[accent] ~= nil then
            for i = style.GLOW_RINGS, 1, -1 do
                local f = style.glowStep(accent, 0.75 / (i + 1))
                if f then
                    lcd.color(f)
                    shape(ex - i, ey - i, ew + 2 * i, eh + 2 * i, r + i)
                end
            end
        end
        lcd.color(accent)
        shape(ex, ey, ew, eh, r)
        ex, ey, ew, eh = ex + 2, ey + 2, ew - 4, eh - 4
        r = math.max(0, r - 2)
    end

    if nova.highDetail == false then
        lcd.color(lit)
        lcd.drawFilledRectangle(ex, ey, ew, eh)
        lcd.color(face)
        lcd.drawFilledRectangle(ex + 1, ey + 1, ew - 2, eh - 2)
    else
        local a = (eh >= 40) and 2 or 1
        lcd.color(style.M_DROP)
        shape(ex + a, ey + a, ew, eh, r)
        lcd.color(face)
        shape(ex, ey, ew, eh, r)
        local sheenH = math.max(1, math.floor((eh - 2) * 0.45))
        glossSlant(ex, ey, ew, sheenH, r, pair)
        edgesPaint(ex, ey, ew, eh, r, lit)
    end

    if accent ~= nil and not narrow then         -- wide fields: the bar on the left
        lcd.color(accent)
        local av = 1
        if r > 0 then av = r - math.floor(math.sqrt(4 * r - 4)) + 1 end
        lcd.drawFilledRectangle(ex + 2, ey + av, math.max(3, style.sx(4)),
                                eh - 2 * av)
    end
end

local function fieldRadius(eh)   -- ONE radius for fields, frames and round fills
    if eh < 22 then return 0 end
    return math.max(3, math.min(12, math.floor(eh / 4)))
end

function style.field(x, y, w, h, accent, kind)
    local ex, ey = style.sx(x), style.sy(y)
    local ew, eh = style.sx(w), style.sy(h)
    if ew < 6 or eh < 6 then return end
    fieldPaint(ex, ey, ew, eh, fieldRadius(eh), accent, kind)
end

function style.fillRounded(x, y, w, h, color)
    local ex, ey = style.sx(x), style.sy(y)
    local ew, eh = style.sx(w), style.sy(h)
    lcd.color(color or style.WHITE)
    shape(ex, ey, ew, eh, fieldRadius(eh))
end

function style.chip(rightX, cy, text, color, font, minB)
    text = tostring(text or "")
    if text == "" then return end
    local f = font or FONT_S
    local tw, th = style.measure(text, f)
    th = th or 12
    local px, py = 9, 4
    local b = math.max(tw + 2 * px, minB or 0)
    local hh = th + 2 * py
    local ex, ey = style.sx(rightX - b), style.sy(cy - hh / 2)
    local ew, eh = style.sx(b), style.sy(hh)
    if ew >= 6 and eh >= 6 then fieldPaint(ex, ey, ew, eh, 0, nil, "deep") end
    style.labelRight(rightX - px, cy - th / 2, text, color, f)
end

function style.dash(cx, cy, color, long, thick)
    long, thick = long or 30, thick or 4
    style.fillRect(cx - long / 2, cy - thick / 2, long, thick, color or style.DIM)
end

local function buttonPaint(x, y, tw, th, word, color, f)
    if color == style.DIM then color = style.BUTTON_DIM end
    local px = math.max(2, style.sx(style.BUTTON_PAD_X))
    local py = math.max(2, style.sy(style.BUTTON_PAD_Y))
    local bx, by = x - px, y - py
    local bw, bh = tw + 2 * px, th + 2 * py
    local r = math.max(3, math.floor(bh / 3))
    local cap = math.floor((math.min(bw, bh) - 2) / 2)
    if r > cap then r = cap end
    lcd.color(style.CYAN)
    roundFill(bx, by, bw, bh, r)
    lcd.color(style.BUTTON_BG)
    roundFill(bx + 1, by + 1, bw - 2, bh - 2, math.max(2, r - 1))
    labelRaw(x, y, word, color, f)
end

function style.buttonCentered(cx, cy, word, color, font)
    word = tostring(word or "")
    if word == "" then return end
    local f = STEP_DOWN[font] or font or FONT_STD
    local tw, th = style.measure(word, f)
    th = th or 12
    local x = style.sx(cx) - math.floor(tw / 2)
    local y = style.sy(cy) - math.floor(th / 2)
    buttonPaint(x, y, tw, th, word, color, f)
end

function style.button(xRef, cy, word, color, font, rightAligned, maxWidthRef)
    word = tostring(word or "")
    if word == "" then return end
    local f = STEP_DOWN[font] or font or FONT_STD
    if maxWidthRef then
        local pad = 2 * math.max(2, style.sx(style.BUTTON_PAD_X))
        f, word = stepDecide(word, f, math.max(8, style.sx(maxWidthRef) - pad))
    end
    local tw, th = style.measure(word, f)
    th = th or 12
    local x = style.sx(xRef)
    if rightAligned then x = x - tw end
    local y = style.sy(cy) - math.floor(th / 2)
    buttonPaint(x, y, tw, th, word, color, f)
end

style.FOOT_BACK = 228          -- right word edge of BACK
style.FOOT_OK = 252          -- left word edge of SAVE/OK

function style.footer(cy, left, leftColor, right, rightColor,
                        leftFont, rightFont, leftX)
    style.footDrawn = true   -- only screens with a footer get the flight controller's sentence at the bottom
    if left then
        style.button(style.FOOT_BACK, cy, left, leftColor, leftFont, true)
    end
    if right then
        style.button(style.FOOT_OK, cy, right, rightColor, rightFont, false)
    end
end

function style.frame(z, color)
    local x, y = style.sx(z.x), style.sy(z.y)
    local w, h = style.sx(z.w), style.sy(z.h)
    lcd.color(color or style.WHITE)
    local r = HAS_SECTOR and fieldRadius(h) or 0   -- round like every field
    if r == 0 then
        lcd.drawRectangle(x, y, w, h)
        lcd.drawRectangle(x + 1, y + 1, w - 2, h - 2)
        return
    end
    lcd.drawFilledRectangle(x + r, y, w - 2 * r, 2)
    lcd.drawFilledRectangle(x + r, y + h - 2, w - 2 * r, 2)
    lcd.drawFilledRectangle(x, y + r, 2, h - 2 * r)
    lcd.drawFilledRectangle(x + w - 2, y + r, 2, h - 2 * r)
    lcd.drawAnnulusSector(x + w - r - 1, y + r, r - 2, r, 0, 90)      -- angles: 0 = top (12 o'clock), clockwise
    lcd.drawAnnulusSector(x + w - r - 1, y + h - r - 1, r - 2, r, 90, 180)
    lcd.drawAnnulusSector(x + r, y + h - r - 1, r - 2, r, 180, 270)
    lcd.drawAnnulusSector(x + r, y + r, r - 2, r, 270, 360)
end

return style
