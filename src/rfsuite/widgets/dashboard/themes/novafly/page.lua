-- PAGE PARTS: what the two pages beside the cockpit (preflight.lua, banks.lua) draw in common - the same background as the
-- cockpit (gloss, carbon or light, cockpit.lua BG), the cockpit lines run in from the cockpit and fade out
-- (furthest at the top, short at the bottom, frame.lua FADE), chips from the same lines with r 4 corners, rows of number and unit.
-- The colours come from the cockpit (H.lines, H.light), frame.lua draws the lines and corners.
local A = ...   -- {H = the cockpit's helpers, style = style.lua}
local H, style = A.H, A.style
local floor = math.floor

local S = {}
S.HEAD = {y = 8, h = 40}      -- the bands between the lines: head, middle, foot
S.MIDDLE = {y = 59, h = 188}
S.FOOT = {y = 258, h = 54}
S.BLACK = lcd.RGB(0, 0, 0)
local ORIGINAL = {WHITE = style.WHITE, DIM = style.DIM, FIELD_DIM = style.FIELD_DIM, RED = style.RED}   -- the colours of the drawing parts on a dark background, as style.lua sets them
local LIGHT = {WHITE = lcd.RGB(20, 20, 19), DIM = lcd.RGB(95, 107, 120), FIELD_DIM = lcd.RGB(95, 107, 120), RED = lcd.RGB(200, 32, 32)}   -- on a light background: dark text, dim and red as in the cockpit (cockpit.lua palette)
local modeSet = nil
local GAP = 4                -- between number and unit of a row, points of the 480 x 320 layout
local gap = GAP           -- the same gap in the window, computed once per paint in S.background
local M = {X = style.sx, Y = style.sy, sx = style.sx, sy = style.sy}   -- the page's window for frame.lua: style.lua's own converters, without an extra call (instructions per paint); frame.lua hangs M.q on it (R.refresh)

local function suiteModule(path)   -- a module of the suite through its loader; nil without the loader (rfsuite 2.3.x) or without the module
    local loader = package.loaded["rfsuite.lib.require"]
    if type(loader) ~= "function" then return nil end
    local ok, m = pcall(loader, path)
    if ok and type(m) == "table" then return m end
    return nil
end

function S.busRead(codecPath, done)   -- one message over the suite's "msp.request" bus with its codec; done(values) once, on error done(nil, the suite's reason); false when nothing went out
    local bus, codec = suiteModule("lib/bus.lua"), codecPath and suiteModule(codecPath) or nil
    if bus == nil or type(bus.publish) ~= "function" or codec == nil or type(codec.buildReadMessage) ~= "function" then return false end
    local once = false
    local function finish(w, reason)
        if once then return end
        once = true
        done(w, reason)
    end
    local ok, message = pcall(codec.buildReadMessage, function(d) finish(type(d) == "table" and d or nil) end, function(reason) finish(nil, reason) end)
    if not ok or type(message) ~= "table" or not pcall(bus.publish, "msp.request", message) then once = true return false end
    return true
end

function S.light() return type(H.light) == "function" and H.light() == true end   -- the mode of the cockpit

local function colors()   -- the colours of the drawing parts by mode, before every background: labels, units, the set line and the peak mark turn dark on white
    local light = S.light()
    if modeSet == light then return end
    modeSet = light
    local q = light and LIGHT or ORIGINAL
    style.WHITE, style.DIM, style.FIELD_DIM, style.RED = q.WHITE, q.DIM, q.FIELD_DIM, q.RED
end

function S.size() return M end

function S.suffix()   -- the suffix of the picture files of this screen size (frame.lua R.suffix): "", "_640" or "_800"
    local R = H.frame()
    return R and R.suffix(M) or ""
end

function S.background()   -- the cockpit background (H.background: gloss, carbon or light), whole; without the picture plain black; before it the line sizes for the window, once per paint
    colors()
    gap = style.sx(GAP)
    local R = H.frame()
    if R then R.refresh(M) end
    if type(H.background) == "function" and H.background() then return end
    lcd.color(S.BLACK)
    lcd.drawFilledRectangle(style.sx(0), style.sy(0), style.sx(480), style.sy(320))
end

function S.lines(left)   -- the five cockpit lines, fading as masks over the background; left = the page left of the cockpit
    local R = H.frame()
    if R then R.page(M, H.lines(), left, type(H.fadeMasks) == "function" and H.fadeMasks(R) or nil) end
end
function S.chip(x, y, w, h, open)   -- a box of the cockpit lines with r 4 corners (masks); open = "left" or "right": without that edge, the lines run to the edge of the screen
    local R = H.frame()
    if not R then return end
    local F = H.lines()
    local E = type(H.cornerMasks) == "function" and H.cornerMasks(R) or nil
    local r = 4
    local x0 = (open == "left") and 0 or (x + r)
    local x1 = (open == "right") and 480 or (x + w - r)
    R.horizontal(M, F, y, x0, x1)
    R.horizontal(M, F, y + h, x0, x1)
    if open ~= "left" then
        R.vertical(M, F, x, y + r, y + h - r)
        R.corner(M, F, x + r, y + r, r, 270, 360, E)
        R.corner(M, F, x + r, y + h - r, r, 180, 270, E)
    end
    if open ~= "right" then
        R.vertical(M, F, x + w, y + r, y + h - r)
        R.corner(M, F, x + w - r, y + r, r, 0, 90, E)
        R.corner(M, F, x + w - r, y + h - r, r, 90, 180, E)
    end
end

function S.fillRect(x, y, w, h, color)
    lcd.color(color)
    lcd.drawFilledRectangle(style.sx(x), style.sy(y), style.sx(w), style.sy(h))
end

local function rowPaint(x, cy, segs, width, height)   -- the pieces side by side, aligned at the bottom, the row centred on cy
    local top = style.sy(cy) - floor(height / 2)
    for i = 1, #segs do
        local sg = segs[i]
        local b, h = style.measure(sg[1], sg[3] or FONT_S)
        style.drawTextAt(x, top + height - (h or height) - (i > 1 and 1 or 0), sg[1], sg[2], sg[3] or FONT_S)
        x = x + b + gap
    end
    return width
end

local function rowSize(segs)
    local width, height = -gap, 0
    for i = 1, #segs do
        local b, h = style.measure(segs[i][1], segs[i][3] or FONT_S)
        width = width + b + gap
        if (h or 0) > height then height = h end
    end
    return width, height
end

function S.row(cx, cy, segs)   -- a row of pieces {text, colour, font}, together centred on cx: the number large, the unit small behind it
    local b, h = rowSize(segs)
    rowPaint(style.sx(cx) - floor(b / 2), cy, segs, b, h)
end

function S.rowLeft(x, cy, segs)
    local b, h = rowSize(segs)
    rowPaint(style.sx(x), cy, segs, b, h)
end

function S.rowRight(rx, cy, segs)
    local b, h = rowSize(segs)
    rowPaint(style.sx(rx) - b, cy, segs, b, h)
end

return S
