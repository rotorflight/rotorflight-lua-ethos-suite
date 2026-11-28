-- FRAME of the theme: the cockpit lines as code on the one background. Sizes from the 480 x 320 layout: head band with
-- notch, three fields, foot row, corners, gauge arc, ticks. A line is three points of mid tone with one point of bright
-- core and one point of glow on each side; at 800 x 480 two points of core, four of mid tone, six of glow (sizes). Everything goes through
-- M = {X, Y, sx, sy} (window) and F = {mid, core, glow, fade} (colours, cockpit.lua lineColors). The gauge carries the pointer;
-- the cockpit lines fade towards the edge on the pages, the pages' lines into the cockpit (spikes): three pictures that belong together.
local R = {}
local floor, sin, cos, rad, min = math.floor, math.sin, math.cos, math.rad, math.min

R.GREEN, R.YELLOW, R.RED = lcd.RGB(12, 228, 16), lcd.RGB(245, 224, 26), lcd.RGB(240, 35, 12)
R.GRAY, R.NEEDLE = lcd.RGB(134, 138, 145), lcd.RGB(255, 80, 80)
local MODES = {{R.GREEN, R.YELLOW, R.RED, R.GRAY, R.NEEDLE},   -- arc, zones, ticks and pointer per mode: dark as measured from the pictures; light darker so yellow and green stand on white
               {lcd.RGB(20, 170, 40), lcd.RGB(214, 170, 0), lcd.RGB(215, 30, 20), lcd.RGB(150, 154, 160), lcd.RGB(215, 30, 20)}}
function R.mode(light)                   -- cockpit.lua calls it before every background (BG.paint): the colours of the mode before any line is drawn
    light = light == true
    if R.light == light then return end
    R.light = light
    local m = MODES[light and 2 or 1]
    R.GREEN, R.YELLOW, R.RED, R.GRAY, R.NEEDLE = m[1], m[2], m[3], m[4], m[5]
end
R.BIG = {r = 101, from = -104.4, to = 104.4, ticks = {-104.4, 104.4, 49, 7, 4}, needle = {60, 88}}   -- the two gauges: arc (from, to; 0 = top, clockwise), ticks (from, to, count, long, short); green up to 78 %, yellow up to 90 %, then red
R.SMALL = {r = 47, from = -135, to = 100, ticks = {-135, 100, 29, 5, 3}, bar = 4}          -- the banks page
R.STEPS = 12                            -- steps in which a line fades out (colours: cockpit.lua lineColors, F.fade - the same number there)
R.FADE_LEFT = {{5, 394}, {55, 200}, {250, 225}, {255, 215}, {314, 120}}   -- per line of a page: the row and how far it reaches into the picture from the cockpit (furthest at the top, short at the bottom); on the left the line ends at 55 before the photo (x 0-259)
R.FADE_RIGHT = {{5, 394}, {55, 330}, {250, 225}, {255, 215}, {314, 120}}
R.FADE_SOFT = 120                    -- length of the fade at the end of a line (for short lines 80 % of the line, R.soft)
R.SPIKES = {left = {{66, 105}, {240, 60}, {262, 45}, {310, 24}}, right = {{66, 105}, {124, 60}, {136, 45}, {240, 24}}}   -- the lines of the pages that end at the edge of their page and run on in the cockpit: from the left the battery box (66, 240) and the foot chip (262, 310) of the preflight page, from the right the chips of the banks page (66, 124, 136, 240); per row, how far the line reaches into the cockpit from the edge of the screen - full at the edge, then fading, the top one the longest, left and right alike; the lines come into the middle picture from outside and fade there
R.NOTCH = {x = 114, y = 34, files = {"notch_glow", "notch_mid", "notch_core"}}   -- the notch at the top of the middle field as a smoothed mask in three layers (gfx/<name><suffix>.png); rounding r 5 at the top, r 4 at the side lines
R.CORNER = {{n = 7, near = 2, far = 4}, {n = 11, near = 2, far = 7}, {n = 9, near = 2, far = 6}}   -- the corner masks per screen size 480, 800, 640 (gfx/corner_<layer>_<pos><suffix>.png): edge length, distance of the core from the near and from the far edge; 640 and 800 carry the line on along both arms, 640 two points, 800 one (the place of the lines gives one point more or less distance per corner there)

function R.refresh(M)                     -- the line sizes for window M, computed once per paint (page.lua S.background, cockpit.lua paintBackground) and hung on M (M.q; no memo with M as key - otherwise Lua memory stays behind per page): 480 x 320: core 1, mid tone 3, glow 5 at the place of M; from 700 points wide (800 x 480): core 2, mid tone 4, glow 6, the place as the first column and row of the core - column x0 + (x*w+160)/480, row y0 + (y*h+80)/320 rounded down, x0/y0 the place of the window
    local w, h, x0, y0 = M.sx(480), M.sy(320), M.X(0), M.Y(0)
    local q = M.q
    if q and q.w == w and q.h == h and q.x0 == x0 and q.y0 == y0 then return q end
    if w < 600 then
        q = {w = w, h = h, x0 = x0, y0 = y0, k = 1, suffix = "", corner = R.CORNER[1], x = M.X, y = M.Y}
    elseif w < 700 then   -- 640 x 360 (X14): core 1 like 480 x 320, the place as column and row of the core like 800 x 480, masks with the suffix _640
        q = {w = w, h = h, x0 = x0, y0 = y0, k = 1, suffix = "_640", corner = R.CORNER[3],
             x = function(v) return x0 + floor((v * w + 160) / 480) end,
             y = function(v) return y0 + floor((v * h + 80) / 320) end}
    else
        q = {w = w, h = h, x0 = x0, y0 = y0, k = 2, suffix = "_800", corner = R.CORNER[2],
             x = function(v) return x0 + floor((v * w + 160) / 480) end,
             y = function(v) return y0 + floor((v * h + 80) / 320) end}
    end
    M.q = q
    return q
end

local function sizes(M)                  -- the sizes from M, without computing (every draw call goes through here: instructions per paint, otherwise 'Max instructions count reached' at 800 x 480)
    return M.q or R.refresh(M)
end

function R.suffix(M) return sizes(M).suffix end   -- the suffix of the mask files of this screen size: "", "_640" or "_800"

function R.horizontal(M, F, y, x0, x1)    -- core in row y, mid tone one row above and below, outside one row of glow each (at 800 x 480 the core two rows)
    local q = sizes(M)
    local X, Y, k = q.x(x0), q.y(y), q.k
    local w = q.x(x1) - X
    lcd.color(F.glow)
    lcd.drawFilledRectangle(X, Y - 2, w, k + 4)
    lcd.color(F.mid)
    lcd.drawFilledRectangle(X, Y - 1, w, k + 2)
    lcd.color(F.core)
    lcd.drawFilledRectangle(X, Y, w, k)
end

function R.vertical(M, F, x, y0, y1)
    local q = sizes(M)
    local X, Y, k = q.x(x), q.y(y0), q.k
    local h = q.y(y1) - Y
    lcd.color(F.glow)
    lcd.drawFilledRectangle(X - 2, Y, k + 4, h)
    lcd.color(F.mid)
    lcd.drawFilledRectangle(X - 1, Y, k + 2, h)
    lcd.color(F.core)
    lcd.drawFilledRectangle(X, Y, k, h)
end

function R.slant(M, F, x0, y0, x1, y1)
    lcd.color(F.glow)
    for d = -2, 2 do lcd.drawLine(M.X(x0), M.Y(y0 + d), M.X(x1), M.Y(y1 + d)) end
    lcd.color(F.mid)
    for d = -1, 1 do lcd.drawLine(M.X(x0), M.Y(y0 + d), M.X(x1), M.Y(y1 + d)) end
    lcd.color(F.core)
    lcd.drawLine(M.X(x0), M.Y(y0), M.X(x1), M.Y(y1))
end

function R.corner(M, F, cx, cy, r, a0, a1, E)   -- a round r 4 corner around (cx, cy) as a mask per layer (E from cockpit.lua): Ethos draws a ring including both radii, a core of one point cannot be had that way; without masks ring sectors
    if E then
        local q = sizes(M)
        local pos = (a0 == 270) and "tl" or ((a0 == 0) and "tr" or ((a0 == 90) and "br" or "bl"))
        local left, top = (pos == "tl" or pos == "bl"), (pos == "tl" or pos == "tr")
        local m, e = E[pos], q.corner
        local X = q.x(left and (cx - r) or (cx + r)) - (left and e.near or e.far)   -- the mask lies against the two lines it joins: the vertical at cx -+ r, the horizontal at cy -+ r
        local Y = q.y(top and (cy - r) or (cy + r)) - (top and e.near or e.far)
        lcd.color(F.glow)
        lcd.drawMask(X, Y, m.glow)
        lcd.color(F.mid)
        lcd.drawMask(X, Y, m.mid)
        lcd.color(F.core)
        lcd.drawMask(X, Y, m.core)
        return
    end
    lcd.color(F.glow)
    lcd.drawAnnulusSector(M.X(cx), M.Y(cy), M.sx(r - 2), M.sx(r + 2), a0, a1)
    lcd.color(F.mid)
    lcd.drawAnnulusSector(M.X(cx), M.Y(cy), M.sx(r - 1), M.sx(r + 1), a0, a1)
    lcd.color(F.core)
    lcd.drawAnnulusSector(M.X(cx), M.Y(cy), M.sx(r), M.sx(r + 1), a0, a1)
end

function R.rect(M, F, x, y, w, h)    -- a thin frame in the core (tank, battery)
    lcd.color(F.core)
    lcd.drawRectangle(M.X(x), M.Y(y), M.sx(w), M.sy(h))
end

function R.soft(far) return min(R.FADE_SOFT, floor(far * 0.8)) end   -- how long a line of the pages fades that reaches far into the picture

function R.fadeLengths()              -- the lengths of the fade that occur on the pages and at the spikes of the cockpit (for the masks)
    local t, seen = {}, {}
    local function remember(l)
        if not seen[l] then seen[l] = true t[#t + 1] = l end
    end
    for _, tab in ipairs({R.FADE_LEFT, R.FADE_RIGHT}) do
        for _, l in ipairs(tab) do remember(R.soft(l[2])) end
    end
    for _, tab in ipairs({R.SPIKES.left, R.SPIKES.right}) do
        for _, s in ipairs(tab) do remember(s[2]) end
    end
    return t
end

function R.fading(M, F, y, x0, x1, toLeft, A)   -- the line fades between x0 and x1: full at x1 (toLeft) or x0, nothing at the other end; A = the masks per side and length (cockpit.lua) - the background stays below; without masks steps of full rectangles on F.fade
    local q = sizes(M)
    local X0, X1, Y, k = q.x(x0), q.x(x1), q.y(y), q.k
    local m = A and A[toLeft and "left" or "right"][x1 - x0]
    if m then
        lcd.color(F.glow)
        lcd.drawMask(X0, Y - 2, m.glow)
        lcd.color(F.mid)
        lcd.drawMask(X0, Y - 1, m.mid)
        lcd.color(F.core)
        lcd.drawMask(X0, Y, m.core)
        return
    end
    local width = (X1 - X0) / R.STEPS
    local b = floor(width) + 1
    for i = 0, R.STEPS - 1 do
        local step = F.fade[toLeft and (i + 1) or (R.STEPS - i)]
        local x = floor(X0 + i * width + 0.5)
        lcd.color(step[3])
        lcd.drawFilledRectangle(x, Y - 2, b, k + 4)
        lcd.color(step[1])
        lcd.drawFilledRectangle(x, Y - 1, b, k + 2)
        lcd.color(step[2])
        lcd.drawFilledRectangle(x, Y, b, k)
    end
end

function R.page(M, F, left, A)         -- the five lines of a page: from the cockpit into the picture, then fading (A = the fade masks)
    for _, l in ipairs(left and R.FADE_LEFT or R.FADE_RIGHT) do
        local y, far = l[1], l[2]
        local soft = R.soft(far)
        if left then
            R.horizontal(M, F, y, 480 - far + soft, 480)
            R.fading(M, F, y, 480 - far, 480 - far + soft, true, A)
        else
            R.horizontal(M, F, y, 0, far - soft)
            R.fading(M, F, y, far - soft, far, false, A)
        end
    end
end

function R.notch(M, F, masks)          -- the notch with its rise and roundings: as a mask in three layers, without masks as strokes
    if masks then
        local q = sizes(M)
        local X, Y = q.x(R.NOTCH.x), q.y(R.NOTCH.y)
        lcd.color(F.glow)
        lcd.drawMask(X, Y, masks.glow)
        lcd.color(F.mid)
        lcd.drawMask(X, Y, masks.mid)
        lcd.color(F.core)
        lcd.drawMask(X, Y, masks.core)
        return
    end
    R.slant(M, F, 141, 50, 175, 40)
    R.horizontal(M, F, 40, 175, 306)
    R.slant(M, F, 306, 40, 341, 50)
    R.slant(M, F, 141, 50, 125, 56)
    R.corner(M, F, 125, 60, 4, 270, 360)
    R.corner(M, F, 354, 60, 4, 0, 90)
    R.slant(M, F, 341, 50, 354, 56)
end

function R.spikes(M, F, A)             -- the spikes (R.SPIKES): the lines of the pages come into the cockpit from the edge of the screen, full at the edge, and fade like the lines on the pages (A = the fade masks; without masks steps)
    for _, s in ipairs(R.SPIKES.left) do R.fading(M, F, s[1], 0, s[2], false, A) end
    for _, s in ipairs(R.SPIKES.right) do R.fading(M, F, s[1], 480 - s[2], 480, true, A) end
end

function R.cockpit(M, F, masks, E, A)   -- the whole frame of the cockpit, open on the left and right (the lines run to the edge and on along the pages); E = the corner masks, A = the fade masks of the spikes
    local function corner(cx, cy, a0, a1) R.corner(M, F, cx, cy, 4, a0, a1, E) end
    R.horizontal(M, F, 5, 0, 480)
    R.notch(M, F, masks)   -- the head band has no line at the bottom beside the middle field; the notch: from (141,50) up to 40, 175-306, down to (341,50)
    R.spikes(M, F, A)   -- the lines of the pages that come into the cockpit
    R.horizontal(M, F, 55, 0, 112)   -- the left field (to x 116) and the right one (from 363), r 4 corners
    corner(112, 59, 0, 90)
    R.vertical(M, F, 116, 59, 246)
    corner(112, 246, 90, 180)
    R.horizontal(M, F, 250, 0, 112)
    R.horizontal(M, F, 55, 367, 480)
    corner(367, 59, 270, 360)
    R.vertical(M, F, 363, 59, 246)
    corner(367, 246, 180, 270)
    R.horizontal(M, F, 250, 367, 480)
    R.vertical(M, F, 121, 60, 248)   -- the middle field (x 121-358): from the notch with an r 4 rounding into the side line, the bend on the top edge of the side fields; at the bottom at 252, the foot row lies at 255
    corner(125, 248, 180, 270)
    R.horizontal(M, F, 252, 125, 354)
    corner(354, 248, 90, 180)
    R.vertical(M, F, 358, 60, 248)
    R.horizontal(M, F, 255, 0, 113)   -- the foot row (y 255-314): three fields, open on the left and right, r 4 corners
    corner(113, 259, 0, 90)
    R.vertical(M, F, 117, 259, 310)
    corner(113, 310, 90, 180)
    R.horizontal(M, F, 314, 0, 113)
    R.horizontal(M, F, 255, 125, 354)
    corner(125, 259, 270, 360)
    R.vertical(M, F, 121, 259, 310)
    corner(125, 310, 180, 270)
    R.horizontal(M, F, 314, 125, 354)
    corner(354, 259, 0, 90)
    R.vertical(M, F, 358, 259, 310)
    corner(354, 310, 90, 180)
    R.horizontal(M, F, 255, 366, 480)
    corner(366, 259, 270, 360)
    R.vertical(M, F, 362, 259, 310)
    corner(366, 310, 180, 270)
    R.horizontal(M, F, 314, 366, 480)
    R.rect(M, F, 136, 267, 20, 35)   -- the battery at the bottom (the cockpit draws its bars); the tank bars stand free, without a box
    lcd.color(F.core)
    lcd.drawFilledRectangle(M.X(142), M.Y(263), M.sx(8), M.sy(4))
end

local function circular(M)                   -- the gauge is a circle: the smaller of width and height applies in both directions; 480 x 320 is 1 : 1, 640 x 360 and 800 x 480 are stretched wider than high
    local bx, by = M.sx(1000), M.sy(1000)
    if bx <= by then return 1, bx / by, M.sx end
    return by / bx, 1, M.sy
end

local TICKS = {}                       -- the ticks per gauge and place, ready in window pixels, computed once
local function ticks(M, kind, cx, cy)
    local X, Y = M.X(cx), M.Y(cy)
    local key = kind.r .. "|" .. X .. "|" .. Y .. "|" .. M.sx(1000) .. "|" .. M.sy(1000)
    local t = TICKS[key]
    if t then return t end
    local from, to, n, long, short = kind.ticks[1], kind.ticks[2], kind.ticks[3], kind.ticks[4], kind.ticks[5]
    local ra = kind.r - 4
    local kx, ky = circular(M)
    t = {}
    for i = 0, n - 1 do
        local a = rad(from + i * (to - from) / (n - 1))
        local l = (i % 4 == 0) and long or short
        local dx, dy = sin(a) * kx, -cos(a) * ky
        t[#t + 1] = {M.X(cx + dx * ra), M.Y(cy + dy * ra), M.X(cx + dx * (ra - l)), M.Y(cy + dy * (ra - l))}
    end
    TICKS[key] = t
    return t
end

local function sector(X, Y, ri, ro, a0, a1)   -- a ring sector from a0 to a1 degrees, also across 0 (Ethos counts 0 to 360)
    if a1 <= a0 then return end
    if a0 < 0 then a0 = a0 + 360 end
    if a1 <= 0 then a1 = a1 + 360 end
    if a0 < a1 then
        lcd.drawAnnulusSector(X, Y, ri, ro, a0, a1)
    else
        lcd.drawAnnulusSector(X, Y, ri, ro, a0, 360)
        if a1 > 0 then lcd.drawAnnulusSector(X, Y, ri, ro, 0, a1) end
    end
end

function R.gauge(M, F, kind, cx, cy, share)   -- a gauge of the kind R.BIG or R.SMALL: ticks, the arc green-yellow-red, the value (share 0..1 of the arc, nil = none) as a pointer (BIG) or as a bar inside the arc (SMALL)
    lcd.color(R.GRAY)
    local t = ticks(M, kind, cx, cy)
    for i = 1, #t do
        local s = t[i]
        lcd.drawLine(s[1], s[2], s[3], s[4])
    end
    local X, Y, r = M.X(cx), M.Y(cy), kind.r
    local kx, ky, rs = circular(M)
    local ri, ro = rs(r - 1), rs(r + 1)
    local from, to = kind.from, kind.to
    local greenTo, yellowTo = from + (to - from) * 0.78, from + (to - from) * 0.90
    lcd.color(R.GREEN)
    sector(X, Y, ri, ro, from, greenTo)
    lcd.color(R.YELLOW)
    sector(X, Y, ri, ro, greenTo, yellowTo)
    lcd.color(R.RED)
    sector(X, Y, ri, ro, yellowTo, to)
    if share == nil then return end
    if share < 0 then share = 0 elseif share > 1 then share = 1 end
    local a = from + (to - from) * share
    if kind.needle then
        local base, tip = kind.needle[1], kind.needle[2]
        local w, w1, w2 = rad(a), rad(a - 7), rad(a + 7)
        local xs, ys = M.X(cx + tip * sin(w) * kx), M.Y(cy - tip * cos(w) * ky)
        lcd.color(R.NEEDLE)
        if type(lcd.drawFilledTriangle) == "function" then
            lcd.drawFilledTriangle(M.X(cx + base * sin(w1) * kx), M.Y(cy - base * cos(w1) * ky), M.X(cx + base * sin(w2) * kx), M.Y(cy - base * cos(w2) * ky), xs, ys)
        else
            lcd.drawLine(X, Y, xs, ys)
        end
    elseif kind.bar then
        local outer = r - 4 - kind.ticks[4] - 2   -- inside the ticks
        lcd.color(F.mid)
        sector(X, Y, rs(outer - kind.bar), rs(outer), from, a)
    end
end

return R
