-- Setup Wizard pictures for a helicopter.
--
--   art.swash(servos, highlight, arrow)
--       The swashplate from above, nose at the top: a dot where each servo
--       sits (lib/setup_wizard_heli.lua's angles), numbered, the one being
--       worked on highlighted, with an optional "up"/"down" mark beside it.
--   art.tilt(view, motion)
--       The rotor head from behind ("rear") or from the left ("side"), the
--       swash drawn as it should move: "level", "left"/"right" (roll),
--       "forward"/"back" (pitch), "up"/"down" (collective), with arrows.
--   art.tail(motion, label)
--       The tail from above: "left"/"right" arrows for the tail blades' push,
--       and an optional value beside it.
--   art.level(roll, pitch, coll, focus, rearLabel, sideLabel)
--       The swash from behind and from the left, tilted by its trims.
--   art.blade(deg, label, mirror, mirrorLabel)
--       A blade section at its pitch angle, with the angle as an arc.
--   art.bars(items)            values as bars against their maximum
--   art.pulse(mid, other, ...) a servo's centre pulse, the other band ghosted
--   art.gears(a, b, focus, ...) a pinion and main gear to their tooth counts
--   art.poles(poles, label)    a motor's magnets
--   art.map(servos, opts)      the swash servos, the main motor and the tail,
--                              coloured by state (live fields main / tail)
--   art.heli(lift, arrow)      the helicopter from the left, tail lifted
--   art.bubble(state)          a spirit level, coloured by state
--   art.rotor(dir)             the rotor disc from above, turning CW or CCW
--   art.tailType(mode)         pitch tail with its servo, or a tail motor
--   art.tailMotor(reverse)     the tail motor from above (live field running)
--   art.attitude(state, style) the live helicopter of the orientation check:
--                              solid (default, lib/heli3d.lua: the
--                              Configurator's helicopter) or "wire";
--                              state.rotorDir (main_rotor_dir) puts its tail
--                              rotor on the right side
--   art.service(picture)       from wakeup: the solid model's next step (one
--                              per call); lib/heli3d.lua redraws the screen
--                              itself when a frame is ready
--   art.image(name, w, h)      a picture of its own size, as the Configurator's
--   art.photo(name, view, front)
--                              a picture from app/gfx/setup_wizard/ (the EdgeTX
--                              suite's helicopter_setup artwork), with the view
--                              named at the top and an arrow to the front
--
-- Each returns a small layout table, built when a screen is built.
-- art.draw() runs from paint and only draws what the layout says, without
-- allocating.

if package.loaded["rfsuite.app.setup_wizard_art"] then
  return package.loaded["rfsuite.app.setup_wizard_art"]
end

local floor = math.floor
local min = math.min
local rad = math.rad
local sin, cos = math.sin, math.cos

local art = {}

-- The solid helicopter (lib/heli3d.lua, shared with the Alignment page),
-- made and drawn by it.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local heli3d = requireModule("lib/heli3d.lua")

-- opts (optional): status = true colours a missing servo (s.missing) as a
-- fault; dir = 0 (CW) / 1 (CCW) draws the main rotor direction round the
-- ring.
function art.swash(servos, highlight, arrow, opts)
  local labels = {}
  for i = 1, #(servos or {}) do labels[i] = tostring(servos[i].servo + 1) end
  return {kind = "swash", servos = servos, labels = labels, highlight = highlight, arrow = arrow,
    status = opts and opts.status, dir = opts and opts.dir}
end

function art.tilt(view, motion)
  return {kind = "tilt", view = view, motion = motion or "level"}
end

-- label (optional): a value drawn beside the tail, e.g. "22.0°".
function art.tail(motion, label)
  return {kind = "tail", motion = motion, label = label}
end

local function arrowShape(x, y, dir, size, thick)
  local h = floor(size * 0.45)
  if dir == "up" or dir == "down" then
    local sign = (dir == "up") and -1 or 1
    local tipY = y + sign * size
    local baseY = tipY - sign * h
    lcd.drawFilledRectangle(x - floor(thick / 2), min(y, baseY), thick, math.abs(baseY - y) + 1)
    lcd.drawFilledTriangle(x, tipY, x - h, baseY, x + h, baseY)
  elseif dir == "right" then
    local tipX = x + size
    local baseX = tipX - h
    lcd.drawFilledRectangle(x, y - floor(thick / 2), baseX - x + 1, thick)
    lcd.drawFilledTriangle(tipX, y, baseX, y - h, baseX, y + h)
  else -- left
    local tipX = x - size
    local baseX = tipX + h
    lcd.drawFilledRectangle(baseX, y - floor(thick / 2), x - baseX + 1, thick)
    lcd.drawFilledTriangle(tipX, y, baseX, y - h, baseX, y + h)
  end
end
art.arrow = arrowShape

-- A thick line, as a fan of 1 px lines (Ethos has no line width).
local function thickLine(x1, y1, x2, y2, t)
  local half = floor(t / 2)
  for k = -half, half do
    lcd.drawLine(x1, y1 + k, x2, y2 + k)
  end
end

-- A filled four-sided shape, as two triangles.
local function quad(x1, y1, x2, y2, x3, y3, x4, y4)
  lcd.drawFilledTriangle(x1, y1, x2, y2, x3, y3)
  lcd.drawFilledTriangle(x1, y1, x3, y3, x4, y4)
end

-- A point on a circle: angle in degrees, counter-clockwise from 3 o'clock
-- as seen on screen.
local function onCircle(cx, cy, r, deg)
  local a = rad(deg)
  return cx + floor(cos(a) * r + 0.5), cy - floor(sin(a) * r + 0.5)
end

-- An arc from a0 to a1 degrees (onCircle()'s angles), t px thick, drawn as
-- concentric polylines; with head, an arrowhead at a1 pointing along it.
local function arc(cx, cy, r, a0, a1, t, head)
  local steps = math.max(6, floor(math.abs(a1 - a0) / 6))
  local half = floor(t / 2)
  for k = -half, half do
    local px, py = onCircle(cx, cy, r + k, a0)
    for i = 1, steps do
      local nx, ny = onCircle(cx, cy, r + k, a0 + (a1 - a0) * i / steps)
      lcd.drawLine(px, py, nx, ny)
      px, py = nx, ny
    end
  end
  if head then
    local a = rad(a1)
    local sign = (a1 >= a0) and 1 or -1
    -- Screen direction of travel at a1, and the radial direction.
    local tx, ty = -sin(a) * sign, -cos(a) * sign
    local rx, ry = cos(a), -sin(a)
    local hx, hy = onCircle(cx, cy, r, a1)
    local size = math.max(8, t * 3)
    lcd.drawFilledTriangle(floor(hx + tx * size), floor(hy + ty * size),
      floor(hx + rx * size * 0.6), floor(hy + ry * size * 0.6),
      floor(hx - rx * size * 0.6), floor(hy - ry * size * 0.6))
  end
end

-- Main rotor direction round a centre, seen from above: two arcs with heads.
local function rotorArrows(cx, cy, r, ccw, t)
  if ccw then
    arc(cx, cy, r, 20, 130, t, true)
    arc(cx, cy, r, 200, 310, t, true)
  else
    arc(cx, cy, r, 160, 50, t, true)
    arc(cx, cy, r, 340, 230, t, true)
  end
end

local function drawSwash(l, x, y, w, h, colors)
  local cx, cy = x + floor(w / 2), y + floor(h / 2)
  local r = floor(min(w, h) * 0.27)
  local dot = math.max(6, floor(r * 0.16))
  if l.dir ~= nil then
    lcd.color(colors.muted)
    rotorArrows(cx, cy, floor(r * 0.55), l.dir == 1, 2)
  end
  -- Nose marker above the ring, clear of the number of a servo at the front.
  lcd.color(colors.muted)
  local noseTip = cy - r - floor(dot * 5.2)
  lcd.drawFilledTriangle(cx, noseTip, cx - dot, noseTip + dot * 2, cx + dot, noseTip + dot * 2)
  lcd.color(colors.body)
  lcd.drawCircle(cx, cy, r)
  lcd.drawCircle(cx, cy, r - 1)
  lcd.drawFilledCircle(cx, cy, floor(dot * 0.7))
  lcd.font(FONT_S)
  local servos = l.servos or {}
  for i = 1, #servos do
    local s = servos[i]
    if not s.tail and s.angle then
      local a = rad(s.angle)
      local sx = cx + floor(sin(a) * r + 0.5)
      local sy = cy - floor(cos(a) * r + 0.5)
      local on = l.highlight == s.servo
      local bad = l.status and s.missing
      lcd.color(bad and colors.bad or (on and colors.active) or (l.status and colors.good) or colors.surface)
      lcd.drawFilledCircle(sx, sy, dot)
      -- Number outside the ring.
      local lx = cx + floor(sin(a) * (r + dot * 2.6) + 0.5)
      local ly = cy - floor(cos(a) * (r + dot * 2.6) + 0.5)
      lcd.color(bad and colors.bad or (on and colors.active) or colors.text)
      lcd.drawText(lx, ly - 8, l.labels[i], CENTERED)
      if on and l.arrow then
        arrowShape(sx + dot * 3, sy + (l.arrow == "up" and dot or -dot), l.arrow, dot * 2, math.max(3, floor(dot / 2)))
      end
    end
  end
end

-- Tilt of the swash bar for each motion, as (left end dy, right end dy) in
-- units of the bar's half-length, and the arrows to draw at each end.
local TILT = {
  level = {0, 0},
  left = {0.25, -0.25},    -- roll left: left side down
  right = {-0.25, 0.25},
  forward = {0.25, -0.25}, -- side view, nose to the left: front down
  back = {-0.25, 0.25},
  up = {-0.25, -0.25},
  down = {0.25, 0.25},
}

local function drawTilt(l, x, y, w, h, colors)
  local cx = x + floor(w / 2)
  local s = floor(min(w * 0.4, h * 0.45))
  local t = math.max(4, floor(s * 0.06))
  local barY = y + floor(h * 0.42)
  local bodyTop = barY + floor(s * 0.35)
  -- Frame and mast.
  lcd.color(colors.body)
  if l.view == "side" then
    -- Nose to the left: cabin, boom to the right.
    lcd.drawFilledRectangle(cx - floor(s * 0.55), bodyTop, floor(s * 0.75), floor(s * 0.35))
    lcd.drawFilledRectangle(cx + floor(s * 0.2), bodyTop + floor(s * 0.08), floor(s * 0.8), t)
  else
    lcd.drawFilledRectangle(cx - floor(s * 0.22), bodyTop, floor(s * 0.44), floor(s * 0.45))
  end
  lcd.drawFilledRectangle(cx - floor(t / 2), barY - floor(s * 0.3), t, bodyTop - barY + floor(s * 0.3))
  -- Swash bar.
  local d = TILT[l.motion] or TILT.level
  local half = floor(s * 0.45)
  local ly = barY + floor(d[1] * half)
  local ry = barY + floor(d[2] * half)
  lcd.color(l.motion == "level" and colors.surface or colors.active)
  thickLine(cx - half, ly, cx + half, ry, t)
  if l.motion == "level" then return end
  -- An arrow at each end that moves.
  local size = math.max(12, floor(s * 0.22))
  local thick = math.max(3, floor(t * 0.8))
  lcd.color(colors.active)
  local gap = floor(s * 0.08)
  if d[1] ~= 0 then
    arrowShape(cx - half, ly + (d[1] < 0 and -gap or gap), d[1] < 0 and "up" or "down", size, thick)
  end
  if d[2] ~= 0 then
    arrowShape(cx + half, ry + (d[2] < 0 and -gap or gap), d[2] < 0 and "up" or "down", size, thick)
  end
end

local function drawTail(l, x, y, w, h, colors)
  -- From above, nose at the top: the boom runs down to the tail rotor.
  local cx = x + floor(w / 2)
  local s = floor(min(w * 0.4, h * 0.45))
  local t = math.max(4, floor(s * 0.06))
  local top = y + floor(h * 0.08)
  local tailY = y + floor(h * 0.75)
  lcd.color(colors.body)
  lcd.drawFilledRectangle(cx - floor(s * 0.18), top, floor(s * 0.36), floor(s * 0.5))
  lcd.drawFilledRectangle(cx - floor(t / 2), top + floor(s * 0.5), t, tailY - top - floor(s * 0.5))
  lcd.color(l.motion and colors.active or colors.surface)
  lcd.drawFilledRectangle(cx + floor(s * 0.08), tailY - floor(s * 0.25), t, floor(s * 0.5))
  if l.motion == "left" or l.motion == "right" then
    lcd.color(colors.active)
    local size = math.max(12, floor(s * 0.28))
    local thick = math.max(3, floor(t * 0.8))
    local ax = l.motion == "right" and (cx + floor(s * 0.2)) or (cx - floor(s * 0.1))
    arrowShape(ax, tailY, l.motion, size, thick)
  end
  if l.label then
    lcd.font(FONT_STD)
    lcd.color(colors.active)
    if l.motion == "right" then
      lcd.drawText(cx - floor(s * 0.15), tailY - 12, l.label, RIGHT)
    else
      lcd.drawText(cx + floor(s * 0.25), tailY - 12, l.label, LEFT)
    end
  end
end

---------------------------------------------------------------------------
-- Level the swash: the swash from behind (roll, collective) and from the
-- left (pitch), each tilted by its trim, exaggerated so a small trim shows.
---------------------------------------------------------------------------

-- roll/pitch/coll: swash_trim_0/1/2 (0.1 %); focus: "roll" | "pitch" |
-- "collective" | nil; rearLabel/sideLabel: text under each view.
function art.level(roll, pitch, coll, focus, rearLabel, sideLabel)
  return {kind = "level", roll = roll or 0, pitch = pitch or 0, coll = coll or 0, focus = focus,
    rearLabel = rearLabel, sideLabel = sideLabel}
end

local function trimAngle(raw)
  local f = raw / 50
  if f > 1 then f = 1 elseif f < -1 then f = -1 end
  return f * 0.35
end

local function swashPanel(cx, cy, s, tiltRad, lift, on, side, label, colors)
  local t = math.max(4, floor(s * 0.06))
  local half = floor(s * 0.42)
  -- Level reference, dashed.
  lcd.color(colors.muted)
  local dash = math.max(4, floor(s * 0.05))
  local xx = cx - half - dash
  while xx < cx + half + dash do
    lcd.drawLine(xx, cy, math.min(xx + dash, cx + half + dash), cy)
    xx = xx + dash * 2
  end
  -- Mast and frame.
  lcd.color(colors.body)
  lcd.drawFilledRectangle(cx - floor(t / 2), cy - floor(s * 0.3), t, floor(s * 0.7))
  if side then
    lcd.drawFilledRectangle(cx - floor(s * 0.35), cy + floor(s * 0.38), floor(s * 0.5), floor(s * 0.22))
    lcd.drawFilledRectangle(cx + floor(s * 0.15), cy + floor(s * 0.44), floor(s * 0.35), floor(t * 0.8))
  else
    lcd.drawFilledRectangle(cx - floor(s * 0.16), cy + floor(s * 0.38), floor(s * 0.32), floor(s * 0.28))
  end
  -- The swash: right end down for a positive tilt.
  local dx, dy = floor(cos(tiltRad) * half), floor(sin(tiltRad) * half)
  local yy = cy - lift
  lcd.color(on and colors.active or colors.surface)
  thickLine(cx - dx, yy - dy, cx + dx, yy + dy, t)
  if label then
    lcd.font(FONT_S)
    lcd.color(on and colors.active or colors.text)
    lcd.drawText(cx, cy + floor(s * 0.68), label, CENTERED)
  end
end

local function drawLevel(l, x, y, w, h, colors)
  local pw = floor(w / 2)
  local s = floor(min(pw * 0.7, h * 0.7))
  local cy = y + floor(h * 0.38)
  local lift = floor(trimAngle(l.coll) * s * 0.4)
  swashPanel(x + floor(pw / 2), cy, s, trimAngle(l.roll), lift,
    l.focus == "roll" or l.focus == "collective", false, l.rearLabel, colors)
  -- Side view, nose to the left: a positive pitch trim puts the front down.
  swashPanel(x + pw + floor(pw / 2), cy, s, -trimAngle(l.pitch), lift, l.focus == "pitch", true, l.sideLabel, colors)
end

---------------------------------------------------------------------------
-- Blade pitch: a blade section seen from the blade tip, leading edge to the
-- left, at its angle, with the angle drawn as an arc and a number.
---------------------------------------------------------------------------

-- deg: blade angle; label: e.g. "9.0°"; mirror: also show -deg (a +- limit).
function art.blade(deg, label, mirror, mirrorLabel)
  return {kind = "blade", deg = deg or 0, label = label, mirror = mirror, mirrorLabel = mirrorLabel}
end

local function bladeShape(cx, cy, len, t, deg)
  local a = rad(deg)
  local c, s = cos(a), sin(a)
  local hx, hy = c * len / 2, s * len / 2
  -- Leading edge up and to the left for a positive angle.
  local lx, ly = cx - hx, cy - hy
  local tx, ty = cx + hx, cy + hy
  local nx, ny = -s * t / 2, c * t / 2
  quad(floor(lx + nx), floor(ly + ny), floor(tx + nx * 0.3), floor(ty + ny * 0.3),
    floor(tx - nx * 0.3), floor(ty - ny * 0.3), floor(lx - nx), floor(ly - ny))
  lcd.drawFilledCircle(floor(lx), floor(ly), math.max(2, floor(t / 2)))
end

local function drawBlade(l, x, y, w, h, colors)
  local len = floor(min(w * 0.5, h * 1.5))
  local cx, cy = x + floor(w / 2), y + floor(h / 2)
  local t = math.max(5, floor(len * 0.07))
  lcd.color(colors.muted)
  lcd.drawLine(cx - floor(len * 0.62), cy, cx + floor(len * 0.62), cy)
  local r = floor(len * 0.36)
  lcd.font(FONT_STD)
  -- The leading edge of a blade at +deg sits at onCircle() angle 180 - deg.
  if l.mirror then
    lcd.color(colors.body)
    bladeShape(cx, cy, len, t, -l.deg)
    lcd.color(colors.muted)
    if l.deg ~= 0 then arc(cx, cy, r, 180, 180 + l.deg, 2, false) end
    if l.mirrorLabel then
      -- Left of the reference line, below it: clear of both blades.
      lcd.drawText(cx - floor(len * 0.62) - 8, cy + 4, l.mirrorLabel, RIGHT)
    end
  end
  lcd.color(colors.surface)
  bladeShape(cx, cy, len, t, l.deg)
  lcd.color(colors.active)
  if l.deg ~= 0 then arc(cx, cy, r, 180, 180 - l.deg, 3, false) end
  if l.label then
    -- Left of the reference line, above it: clear of the blade and its arc.
    local _, th = lcd.getTextSize(l.label)
    lcd.drawText(cx - floor(len * 0.62) - 8, cy - th - 2, l.label, RIGHT)
  end
end

---------------------------------------------------------------------------
-- Bars: one row per value, a label, a filled bar and the value.
---------------------------------------------------------------------------

-- items: {{label =, frac = 0..1, text =}, ...}
function art.bars(items)
  return {kind = "bars", items = items}
end

local function drawBars(l, x, y, w, h, colors)
  local n = #l.items
  if n == 0 then return end
  lcd.font(FONT_S)
  local _, th = lcd.getTextSize("Ag")
  local rowH = math.min(floor(h / n), th + 16)
  local labelW = floor(w * 0.32)
  local valueW = floor(w * 0.16)
  local barW = w - labelW - valueW - 16
  for i = 1, n do
    local it = l.items[i]
    local ry = y + (i - 1) * rowH
    local by = ry + floor((rowH - 10) / 2)
    lcd.color(colors.text)
    lcd.drawText(x, ry + floor((rowH - th) / 2), it.label, LEFT)
    lcd.color(colors.body)
    lcd.drawFilledRectangle(x + labelW, by, barW, 10)
    local f = it.frac or 0
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    lcd.color(colors.active)
    if f > 0 then lcd.drawFilledRectangle(x + labelW, by, math.max(2, floor(barW * f)), 10) end
    lcd.color(colors.text)
    lcd.drawText(x + w, ry + floor((rowH - th) / 2), it.text, RIGHT)
  end
end

---------------------------------------------------------------------------
-- Servo type: the servo pulse, with the other band's pulse ghosted, and the
-- update rate.
---------------------------------------------------------------------------

local PULSE_FROM, PULSE_TO = -400, 2600
local PULSE_TICKS = {0, 500, 1000, 1500, 2000, 2500}
local PULSE_TICK_LABELS = {}
for i = 1, #PULSE_TICKS do PULSE_TICK_LABELS[i] = tostring(PULSE_TICKS[i]) end

-- mid: the servo's centre pulse, us; other: the other band's centre;
-- midLabel ("1520 us"), hzLabel ("333 Hz").
function art.pulse(mid, other, midLabel, hzLabel)
  return {kind = "pulse", mid = mid or 1520, other = other, midLabel = midLabel, hzLabel = hzLabel}
end

local function pulseX(x, w, t)
  return x + floor((t - PULSE_FROM) * w / (PULSE_TO - PULSE_FROM))
end

local function drawPulse(l, x, y, w, h, colors)
  lcd.font(FONT_S)
  local _, th = lcd.getTextSize("Ag")
  local hiY = y + th + 8
  local loY = y + floor(h * 0.68)
  if loY - hiY < 20 then loY = hiY + 20 end
  local x0, xm = pulseX(x, w, 0), pulseX(x, w, l.mid)
  if l.other then
    local xo = pulseX(x, w, l.other)
    lcd.color(colors.muted)
    lcd.drawLine(x0, loY, x0, hiY + 6)
    lcd.drawLine(x0, hiY + 6, xo, hiY + 6)
    lcd.drawLine(xo, hiY + 6, xo, loY)
  end
  lcd.color(colors.active)
  local t = 3
  thickLine(x, loY, x0, loY, t)
  lcd.drawFilledRectangle(x0 - 1, hiY, t, loY - hiY)
  thickLine(x0, hiY, xm, hiY, t)
  lcd.drawFilledRectangle(xm - 1, hiY, t, loY - hiY)
  thickLine(xm, loY, x + w, loY, t)
  if l.midLabel then lcd.drawText(floor((x0 + xm) / 2), hiY - th - 4, l.midLabel, CENTERED) end
  if l.hzLabel then
    lcd.color(colors.text)
    lcd.drawText(x + w, hiY - th - 4, l.hzLabel, RIGHT)
  end
  -- Time axis.
  lcd.color(colors.muted)
  local axisY = loY + 8
  if axisY + th <= y + h then
    for i = 1, #PULSE_TICKS do
      local tx = pulseX(x, w, PULSE_TICKS[i])
      lcd.drawLine(tx, axisY - 4, tx, axisY)
      lcd.drawText(tx, axisY, PULSE_TICK_LABELS[i], CENTERED)
    end
  end
end

---------------------------------------------------------------------------
-- Gears: a pinion driving a main gear, drawn to their tooth counts.
---------------------------------------------------------------------------

-- a, b: tooth counts (driving, driven); focus: 1 or 2 (the one being set);
-- aLabel, bLabel: the counts; ratioLabel: e.g. "10.00 : 1".
function art.gears(a, b, focus, aLabel, bLabel, ratioLabel)
  return {kind = "gears", a = a or 0, b = b or 0, focus = focus, aLabel = aLabel, bLabel = bLabel,
    ratioLabel = ratioLabel}
end

local function gear(cx, cy, r, teeth, on, colors)
  lcd.color(on and colors.active or colors.surface)
  lcd.drawFilledCircle(cx, cy, floor(r * 0.86))
  local n = math.min(math.max(teeth, 6), 60)
  for i = 0, n - 1 do
    local deg = i * 360 / n
    local x1, y1 = onCircle(cx, cy, r * 0.8, deg)
    local x2, y2 = onCircle(cx, cy, r, deg)
    lcd.drawLine(x1, y1, x2, y2)
    lcd.drawLine(x1 + 1, y1, x2 + 1, y2)
  end
  lcd.color(colors.body)
  lcd.drawFilledCircle(cx, cy, math.max(2, floor(r * 0.18)))
end

local function drawGears(l, x, y, w, h, colors)
  lcd.font(FONT_S)
  local _, th = lcd.getTextSize("Ag")
  local rmax = floor(min((h - 2 * th - 12) / 2, w * 0.24))
  if rmax < 8 then return end
  local rb = rmax
  local ra = rmax * 0.5
  if l.a > 0 and l.b > 0 then ra = math.max(rmax * 0.2, min(rmax, rmax * l.a / l.b)) end
  ra = floor(ra)
  local cy = y + th + 6 + rmax
  local left = x + floor((w - 2 * ra - 2 * rb) / 2)
  local ca, cb = left + ra, left + 2 * ra + rb
  gear(cb, cy, rb, l.b, l.focus == 2, colors)
  gear(ca, cy, ra, l.a, l.focus == 1, colors)
  if l.ratioLabel then
    lcd.color(colors.text)
    lcd.drawText(x + floor(w / 2), y, l.ratioLabel, CENTERED)
  end
  local ly = cy + rmax + 4
  lcd.color(l.focus == 1 and colors.active or colors.text)
  if l.aLabel then lcd.drawText(ca, ly, l.aLabel, CENTERED) end
  lcd.color(l.focus == 2 and colors.active or colors.text)
  if l.bLabel then lcd.drawText(cb, ly, l.bLabel, CENTERED) end
end

---------------------------------------------------------------------------
-- Motor poles: the rotor's magnets round a ring, north and south in turn.
---------------------------------------------------------------------------

function art.poles(poles, label)
  return {kind = "poles", poles = poles or 0, label = label}
end

local function drawPoles(l, x, y, w, h, colors)
  local cx, cy = x + floor(w / 2), y + floor(h / 2)
  local r = floor(min(w, h) * 0.4)
  local n = math.min(math.max(l.poles, 2), 40)
  local dot = math.max(3, floor(r * math.pi / n * 0.4))
  lcd.color(colors.body)
  lcd.drawFilledCircle(cx, cy, r)
  lcd.color(colors.muted)
  lcd.drawFilledCircle(cx, cy, floor(r * 0.65))
  for i = 0, n - 1 do
    local px, py = onCircle(cx, cy, r * 0.83, 90 + i * 360 / n)
    lcd.color(i % 2 == 0 and colors.active or colors.surface)
    lcd.drawFilledCircle(px, py, dot)
  end
  if l.label then
    lcd.font(FONT_STD)
    lcd.color(colors.text)
    lcd.drawText(cx, cy - 12, l.label, CENTERED)
  end
end

---------------------------------------------------------------------------
-- The helicopter's outputs: the swash servos (art.swash) with the main
-- motor and the tail (servo or motor) beside them, each coloured by its
-- state. main / tail are live fields: true OK, false missing, nil unknown.
---------------------------------------------------------------------------

-- opts: status, dir (as art.swash), motorised, tailLabel (the tail servo's
-- number), tailMissing.
function art.map(servos, opts)
  opts = opts or {}
  local l = art.swash(servos, nil, nil, opts)
  l.kind = "map"
  l.motorised = opts.motorised
  l.tailLabel = opts.tailLabel
  l.tailMissing = opts.tailMissing
  l.main, l.tail = nil, nil
  return l
end

local function stateColor(state, colors)
  if state == true then return colors.good end
  if state == false then return colors.bad end
  return colors.muted
end

local function motorIcon(cx, cy, r, state, colors)
  lcd.color(stateColor(state, colors))
  lcd.drawFilledCircle(cx, cy, r)
  lcd.color(colors.body)
  lcd.drawFilledCircle(cx, cy, floor(r * 0.6))
  lcd.color(stateColor(state, colors))
  lcd.drawFilledCircle(cx, cy, math.max(2, floor(r * 0.2)))
end

local function drawMap(l, x, y, w, h, colors)
  local sw = floor(w * 0.62)
  drawSwash(l, x, y, sw, h, colors)
  local ix = x + sw + floor((w - sw) / 2)
  local r = math.max(8, floor(min((w - sw) * 0.18, h * 0.14)))
  -- Main motor above, tail below.
  motorIcon(ix, y + floor(h * 0.3), r, l.main, colors)
  local ty = y + floor(h * 0.7)
  if l.motorised then
    motorIcon(ix, ty, floor(r * 0.75), l.tail, colors)
  else
    lcd.color(l.tailMissing and colors.bad or colors.good)
    lcd.drawFilledRectangle(ix - r, ty - floor(r * 0.6), 2 * r, floor(r * 1.2))
    lcd.color(colors.body)
    lcd.drawFilledCircle(ix + floor(r * 0.45), ty, math.max(2, floor(r * 0.3)))
    if l.tailLabel then
      lcd.font(FONT_S)
      lcd.color(l.tailMissing and colors.bad or colors.text)
      lcd.drawText(ix, ty + floor(r * 0.7), l.tailLabel, CENTERED)
    end
  end
end

---------------------------------------------------------------------------
-- Board orientation: the helicopter from the left with its tail lifted
-- (lift degrees), and a spirit level for the accelerometer.
---------------------------------------------------------------------------

function art.heli(lift, arrow)
  return {kind = "heli", lift = lift or 0, arrow = arrow}
end

-- The pose drawHeli() draws in: pivot (front of the skid), scale, and the
-- tail-lift turn. Module locals, so paint creates no closure.
local hpX, hpY, hpS, hpC, hpSn = 0, 0, 1, 1, 0

-- Unit coordinates (x right, y up from the front of the skid) to screen,
-- turned about the front of the skid so the tail rises.
local function P(ux, uy)
  local dx, dy = ux * hpS, -uy * hpS
  return floor(hpX + dx * hpC + dy * hpSn), floor(hpY - dx * hpSn + dy * hpC)
end

local STRUTS = {0.08, 0.38}

local function drawHeli(l, x, y, w, h, colors)
  local s = floor(min(w * 0.6, h * 1.05))
  local px = x + floor((w - 1.15 * s) / 2 + 0.1 * s)
  local py = y + h - 6
  local a = rad(l.lift)
  hpX, hpY, hpS, hpC, hpSn = px, py, s, cos(a), sin(a)
  lcd.color(colors.muted)
  lcd.drawLine(x, py + 1, x + w, py + 1)
  lcd.color(colors.body)
  local x1, y1 = P(-0.05, 0)
  local x2, y2 = P(0.55, 0)
  thickLine(x1, y1, x2, y2, 3)
  -- Skid struts, up to the body.
  for _, u in ipairs(STRUTS) do
    x1, y1 = P(u, 0)
    x2, y2 = P(u, 0.12)
    thickLine(x1, y1, x2, y2, 3)
  end
  local ax, ay = P(0.02, 0.12)
  local bx, by = P(0.45, 0.12)
  local cx, cy = P(0.45, 0.34)
  local dx, dy = P(0.02, 0.34)
  quad(ax, ay, bx, by, cx, cy, dx, dy)
  x1, y1 = P(0.4, 0.26)
  x2, y2 = P(1.0, 0.26)
  thickLine(x1, y1, x2, y2, math.max(3, floor(s * 0.04)))
  x1, y1 = P(1.0, 0.26)
  x2, y2 = P(1.0, 0.42)
  thickLine(x1, y1, x2, y2, 3)
  x1, y1 = P(0.22, 0.34)
  x2, y2 = P(0.22, 0.46)
  thickLine(x1, y1, x2, y2, 3)
  lcd.color(colors.surface)
  x1, y1 = P(-0.15, 0.46)
  x2, y2 = P(0.6, 0.46)
  thickLine(x1, y1, x2, y2, 3)
  if l.arrow then
    lcd.color(colors.active)
    local tx, ty = P(1.0, 0.5)
    arrowShape(tx, ty, "up", math.max(12, floor(s * 0.16)), 4)
  end
end

---------------------------------------------------------------------------
-- Pictures: the EdgeTX suite's helicopter side views (rotorflight-lua-edgetx-suite
-- PR #839, artwork/helicopter_setup/), each in a 220 by 160 frame with the
-- helicopter between 25 and 135 (rotor at about 55, skids at about 125). The
-- view is named just above the rotor and an arrow under the skids points to
-- the front (nose left), as on the EdgeTX cards.
--
-- Ethos scales a bitmap without smoothing, so each picture comes in the
-- frame sizes of PHOTO_SCALES (name.png, name-125.png, ...: the 2000 by 1000
-- accepted image resampled to 220k by 110k, 25k from the top). The largest
-- that fits is drawn as it is; only a space smaller than the 1x frame scales.
---------------------------------------------------------------------------

local PHOTO_DIR = "app/gfx/setup_wizard/"
local PHOTO_W, PHOTO_H = 220, 160
local PHOTO_SCALES = {2, 1.5, 1.25, 1}
local PHOTO_SUFFIX = {[2] = "-200", [1.5] = "-150", [1.25] = "-125", [1] = ""}
local PHOTO_TOP = 55     -- top of the rotor head in the frame
local PHOTO_ARROW = 150  -- the front arrow, below the skids

function art.photo(name, view, front)
  return {kind = "photo", name = name, view = view, front = front, lift = 0}
end

-- A picture of its own size, such as the Configurator's: w x h is the size of
-- the 1x file (name.png), and name-200.png is the 2x one for a larger screen.
-- Drawn centred, as the 1x or 2x file that fits, or smaller when the space is.
function art.image(name, w, h)
  return {kind = "image", name = name, w = w, h = h}
end

local function imageBitmap(l, k)
  local bitmap = l[k]
  if bitmap == nil then
    bitmap = lcd.loadBitmap and lcd.loadBitmap(PHOTO_DIR .. l.name .. (k == 2 and "-200" or "") .. ".png") or false
    l[k] = bitmap
  end
  return bitmap
end

local function drawImage(l, x, y, w, h, colors)
  local fit = min(w / l.w, h / l.h)
  local k = (fit >= 2) and 2 or 1
  local bitmap = imageBitmap(l, k)
  if not bitmap then return end
  local s = (fit < 1) and fit or k
  local fw, fh = floor(l.w * s), floor(l.h * s)
  local ox, oy = x + floor((w - fw) / 2), y + floor((h - fh) / 2)
  if s == k then
    lcd.drawBitmap(ox, oy, bitmap)
  else
    lcd.drawBitmap(ox, oy, bitmap, fw, fh)
  end
end

-- The bitmap for scale k, loaded the first time a screen of that size draws
-- it (once per step: the layout lives as long as the step). false when the
-- file is missing.
local function photoBitmap(l, k)
  local bitmap = l[k]
  if bitmap == nil then
    bitmap = lcd.loadBitmap and lcd.loadBitmap(PHOTO_DIR .. l.name .. PHOTO_SUFFIX[k] .. ".png") or false
    l[k] = bitmap
  end
  return bitmap
end

local function drawPhoto(l, x, y, w, h, colors)
  local fit = min(w / PHOTO_W, h / PHOTO_H)
  local k = 1
  for i = 1, #PHOTO_SCALES do
    if PHOTO_SCALES[i] <= fit then k = PHOTO_SCALES[i]; break end
  end
  local bitmap = photoBitmap(l, k)
  if not bitmap then return drawHeli(l, x, y, w, h, colors) end
  local s = (fit < 1) and fit or k
  local fw, fh = floor(PHOTO_W * s), floor(PHOTO_H * s)
  local ox, oy = x + floor((w - fw) / 2), y + floor((h - fh) / 2)
  if s == k then
    lcd.drawBitmap(ox, oy, bitmap)
  else
    lcd.drawBitmap(ox, oy, bitmap, fw, fh)
  end
  lcd.font(FONT_S)
  if l.view then
    local _, th = lcd.getTextSize(l.view)
    lcd.color(colors.text)
    lcd.drawText(ox + floor(5 * s), oy + floor(PHOTO_TOP * s) - th - 2, l.view, LEFT)
  end
  if l.front then
    -- As EdgeTX draws it: a shaft from 70 to 24 with a 9 by 5 head.
    local ay = oy + floor(PHOTO_ARROW * s)
    local tip, tail = ox + floor(24 * s), ox + floor(70 * s)
    local head, half = floor(9 * s), math.max(3, floor(5 * s))
    local t = math.max(2, floor(3 * s))
    lcd.color(colors.active)
    lcd.drawFilledRectangle(tip + head, ay - floor(t / 2), tail - tip - head, t)
    lcd.drawFilledTriangle(tip, ay, tip + head, ay - half, tip + head, ay + half)
    local _, th = lcd.getTextSize(l.front)
    lcd.color(colors.text)
    lcd.drawText(ox + floor(89 * s), ay - floor(th / 2), l.front, LEFT)
  end
end

---------------------------------------------------------------------------
-- Orientation check: the EdgeTX suite's live wireframe (rotorflight-lua-edgetx-
-- suite PR #839, app/pages/helicopter_setup/attitude_view.lua), turned by the
-- flight controller's MSP_ATTITUDE. Body axes: forward, right, up; positive
-- pitch lowers the nose, positive roll the right side. Seen from behind the
-- left side and a little above, nose left; the rotor disc a level ellipse.
--
--   art.attitude(state)   state = {roll =, pitch =, valid =, readout =},
--                         degrees; the step updates it in place
---------------------------------------------------------------------------

local ATT_V = {
  {1.125,0,-0.125},{0.9,-0.28,0.575},{0.375,-0.32,0.875},{-0.65,-0.3,0.775},{-1.05,-0.18,0},
  {-0.675,-0.4,-0.275},{0.725,-0.4,-0.275},{0.9,0.28,0.575},{0.375,0.32,0.875},{-0.65,0.3,0.775},
  {-1.05,0.18,0},{-0.675,0.4,-0.275},{0.725,0.4,-0.275},{2.9,0,1.375},{2.511,1.45,1.375},{1.45,2.511,1.375},
  {0,2.9,1.375},{-1.45,2.511,1.375},{-2.511,1.45,1.375},{-2.9,0,1.375},{-2.511,-1.45,1.375},
  {-1.45,-2.511,1.375},{-0,-2.9,1.375},{1.45,-2.511,1.375},{2.511,-1.45,1.375},{0,0,0.875},{0,0,1.375},
  {-0.85,0,0.425},{-3.075,0,0.725},{-3.225,0,0.5},{-1,0,0},{-3.15,0,0.675},{-3.15,0,1.275},{-3.475,0,0.6},
  {-3.3,0,0.15},{-3.15,0,0.5},{-3,-0.2,1.125},{-3.475,-0.2,0.25},{-2.875,-0.2,0.45},{-3.575,-0.2,0.925},
  {0.825,-0.36,0.55},{0.225,-0.36,0.625},{-0.075,-0.36,0.1},{1,-0.36,0.1},{1.25,-0.55,-0.55},{1.1,-0.55,-0.7},
  {0.75,-0.55,-0.7},{0.65,-0.55,-0.275},{-0.925,-0.55,-0.7},{-0.8,-0.55,-0.275},{-1.3,-0.55,-0.7},
  {1.25,0.55,-0.55},{1.1,0.55,-0.7},{0.75,0.55,-0.7},{0.65,0.55,-0.275},{-0.925,0.55,-0.7},{-0.8,0.55,-0.275},
  {-1.3,0.55,-0.7}
}
local ATT_PATHS = {
  {1,2,3,4,5,6,7,1},{1,8,9,10,11,12,13,1},{3,9},{6,12},{41,42,43,44,41},{28,29,30,31},{32,33,34,35,36},
  {37,38},{39,40},{26,27},{14,15,16,17,18,19,20,21,22,23,24,25,14},{45,46,47,48,47,49,50,49,51},
  {52,53,54,55,54,56,57,56,58}
}
local ATT_THICK = {3,1,1,1,2,2,2,2,2,3,2,2,1}
local ATT_ACCENT = {false,false,false,false,true,false,false,true,true,false,true,false,false}
-- Projected points, filled in place by paint (no allocation there).
local attX, attY = {}, {}
for i = 1, #ATT_V do attX[i], attY[i] = 0, 0 end

-- style: nil for the solid model (below), "wire" for the EdgeTX wireframe.
function art.attitude(state, style)
  return {kind = "attitude", state = state, wire = style == "wire"}
end

-- A line t pixels wide: offset across its steeper direction.
local function attLine(x1, y1, x2, y2, t)
  if t <= 1 then lcd.drawLine(x1, y1, x2, y2) return end
  local half = floor(t / 2)
  local steep = math.abs(y2 - y1) > math.abs(x2 - x1)
  for k = -half, t - 1 - half do
    if steep then lcd.drawLine(x1 + k, y1, x2 + k, y2) else lcd.drawLine(x1, y1 + k, x2, y2 + k) end
  end
end

local function drawAttitude(l, x, y, w, h, colors)
  local s = l.state
  lcd.font(FONT_S)
  local _, th = lcd.getTextSize("Ag")
  -- The readout under the picture: the angles, or that none are current.
  lcd.color(s.valid and colors.text or colors.muted)
  lcd.drawText(x + 8, y + h - th, s.readout or "", LEFT)
  if not s.valid then return end
  h = h - th - 4
  local r, p = rad(s.roll or 0), rad(s.pitch or 0)
  local cr, sr, cp, sp = cos(r), sin(r), cos(p), sin(p)
  local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
  for i = 1, #ATT_V do
    local v = ATT_V[i]
    local vy, vz = v[2], v[3]
    local yr, zr = vy * cr + vz * sr, -vy * sr + vz * cr
    local xp, zp = v[1] * cp + zr * sp, -v[1] * sp + zr * cp
    local px, py = -0.766 * xp + 0.643 * yr, -0.94 * zp - 0.22 * xp - 0.262 * yr
    attX[i], attY[i] = px, py
    if px < minX then minX = px end
    if px > maxX then maxX = px end
    if py < minY then minY = py end
    if py > maxY then maxY = py end
  end
  -- Fit the whole helicopter, steep tilts included.
  local scale = min((w - 12) / (maxX - minX), (h - 6) / (maxY - minY))
  local ox = x + w / 2 - scale * (minX + maxX) / 2 + 0.5
  local oy = y + h / 2 - scale * (minY + maxY) / 2 + 0.5
  for i = 1, #ATT_V do
    attX[i], attY[i] = floor(ox + scale * attX[i]), floor(oy + scale * attY[i])
  end
  for i = 1, #ATT_PATHS do
    local path = ATT_PATHS[i]
    lcd.color(ATT_ACCENT[i] and colors.active or colors.text)
    for j = 2, #path do
      local a, b = path[j - 1], path[j]
      attLine(attX[a], attY[a], attX[b], attY[b], ATT_THICK[i])
    end
  end
end

---------------------------------------------------------------------------
-- The helicopter of the orientation check, solid: lib/heli3d.lua makes and
-- draws it, seen from behind on the left (nose to the left, as in the
-- photos) and a little above. Paint only asks for its box and attitude; the
-- wakeup (art.service) makes the frames, one step per call.
local ATT_VIEW_YAW = -68
local ROTOR_CW, ROTOR_CCW = {rotor = "cw"}, {rotor = "ccw"}

local function drawAttitudeSolid(l, x, y, w, h, colors)
  local s = l.state
  lcd.font(FONT_S)
  local _, th = lcd.getTextSize("Ag")
  lcd.color(s.valid and colors.text or colors.muted)
  lcd.drawText(x + 8, y + h - th, s.readout or "", LEFT)
  if not s.valid then return end
  heli3d.setup(s.rotorDir == 1 and ROTOR_CCW or ROTOR_CW)
  heli3d.pose(nil)
  heli3d.draw(x, y, w, h - th - 4, s.roll or 0, s.pitch or 0, ATT_VIEW_YAW)
end

-- From wakeup: the solid model's next step (lib/heli3d.lua). It builds the
-- model ahead of the first attitude, and redraws the screen itself when a
-- frame is ready, so this never asks the page for one.
function art.service(l)
  if l and not l.wire then heli3d.service() end
  return false
end

-- state: nil (not run), "busy", "done", "failed".
function art.bubble(state)
  return {kind = "bubble", state = state}
end

local function drawBubble(l, x, y, w, h, colors)
  local vw = floor(min(w * 0.5, h * 2.2))
  local vh = math.max(16, floor(min(h * 0.32, vw * 0.22)))
  local cx, cy = x + floor(w / 2), y + floor(h / 2)
  lcd.color(colors.body)
  lcd.drawFilledRectangle(cx - floor(vw / 2), cy - floor(vh / 2), vw, vh)
  lcd.drawFilledCircle(cx - floor(vw / 2), cy, floor(vh / 2))
  lcd.drawFilledCircle(cx + floor(vw / 2), cy, floor(vh / 2))
  lcd.color(colors.muted)
  lcd.drawLine(cx - floor(vh * 0.8), cy - floor(vh / 2), cx - floor(vh * 0.8), cy + floor(vh / 2))
  lcd.drawLine(cx + floor(vh * 0.8), cy - floor(vh / 2), cx + floor(vh * 0.8), cy + floor(vh / 2))
  local c = colors.surface
  if l.state == "busy" then c = colors.active
  elseif l.state == "done" then c = colors.good
  elseif l.state == "failed" then c = colors.bad end
  lcd.color(c)
  lcd.drawFilledCircle(cx, cy, floor(vh * 0.38))
end

---------------------------------------------------------------------------
-- Main rotor direction: the disc from above, nose at the top, with arrows.
---------------------------------------------------------------------------

function art.rotor(dir)
  return {kind = "rotor", dir = dir}
end

local function drawRotor(l, x, y, w, h, colors)
  local cx, cy = x + floor(w / 2), y + floor(h / 2)
  local r = floor(min(w, h) * 0.44)
  lcd.color(colors.muted)
  lcd.drawCircle(cx, cy, r)
  lcd.drawFilledTriangle(cx, cy - r - 2, cx - 6, cy - r + 10, cx + 6, cy - r + 10)
  lcd.color(colors.surface)
  local x1, y1 = onCircle(cx, cy, r * 0.95, 30)
  local x2, y2 = onCircle(cx, cy, r * 0.95, 210)
  thickLine(x1, y1, x2, y2, math.max(4, floor(r * 0.07)))
  lcd.color(colors.body)
  lcd.drawFilledCircle(cx, cy, math.max(4, floor(r * 0.1)))
  if l.dir ~= nil then
    lcd.color(colors.active)
    rotorArrows(cx, cy, floor(r * 0.72), l.dir == 1, 3)
  end
end

---------------------------------------------------------------------------
-- Tail type, from the left: a pitch tail driven by a servo, or a motor on
-- the tail, turning one way or both.
---------------------------------------------------------------------------

function art.tailType(mode)
  return {kind = "tailType", mode = mode}
end

local function drawTailType(l, x, y, w, h, colors)
  local cy = y + floor(h * 0.55)
  local x0, x1 = x + floor(w * 0.18), x + floor(w * 0.72)
  local t = math.max(4, floor(h * 0.05))
  lcd.color(colors.body)
  -- Boom, with the frame's end at the left.
  lcd.drawFilledRectangle(x0 - floor(w * 0.1), cy - floor(h * 0.18), floor(w * 0.1), floor(h * 0.36))
  thickLine(x0, cy, x1, cy, t)
  lcd.drawFilledRectangle(x1 - floor(t / 2), cy - floor(h * 0.4), t, floor(h * 0.4))
  local rh = floor(h * 0.35)
  if l.mode == 0 then
    -- Tail blades, and a servo on the boom pushing the pitch slider.
    lcd.color(colors.surface)
    lcd.drawFilledRectangle(x1 + t, cy - rh, t, 2 * rh)
    lcd.color(colors.active)
    local sx = x0 + floor((x1 - x0) * 0.3)
    lcd.drawFilledRectangle(sx - floor(h * 0.12), cy - floor(h * 0.24), floor(h * 0.24), floor(h * 0.16))
    lcd.drawLine(sx, cy - floor(h * 0.16), x1 + t, cy - floor(h * 0.16))
  elseif l.mode ~= nil then
    lcd.color(colors.active)
    local mr = math.max(6, floor(h * 0.13))
    lcd.drawFilledCircle(x1, cy, mr)
    lcd.color(colors.surface)
    lcd.drawFilledRectangle(x1 + mr + 2, cy - rh, t, 2 * rh)
    lcd.color(colors.active)
    local size = math.max(10, floor(h * 0.16))
    arrowShape(x1 + mr + 8, cy - rh - floor(size / 2), "right", size, 3)
    if l.mode == 2 then
      arrowShape(x1 - 4, cy + rh + floor(size / 2), "left", size, 3)
    end
  end
end

---------------------------------------------------------------------------
-- Tail motor test: the tail from above with its rotor; arrows round it
-- while the motor runs (running is a live field).
---------------------------------------------------------------------------

function art.tailMotor(reverse)
  return {kind = "tailMotor", running = false, reverse = reverse}
end

local function drawTailMotor(l, x, y, w, h, colors)
  local cx = x + floor(w / 2)
  local s = floor(min(w * 0.4, h * 0.45))
  local t = math.max(4, floor(s * 0.06))
  local top = y + floor(h * 0.06)
  local tailY = y + floor(h * 0.7)
  lcd.color(colors.body)
  lcd.drawFilledRectangle(cx - floor(s * 0.18), top, floor(s * 0.36), floor(s * 0.45))
  lcd.drawFilledRectangle(cx - floor(t / 2), top + floor(s * 0.45), t, tailY - top - floor(s * 0.45))
  local mr = math.max(5, floor(s * 0.1))
  lcd.color(l.running and colors.active or colors.surface)
  lcd.drawFilledCircle(cx, tailY, mr)
  local rr = floor(s * 0.32)
  lcd.color(colors.surface)
  lcd.drawFilledRectangle(cx - rr, tailY - floor(t / 2), 2 * rr, t)
  if l.running then
    lcd.color(colors.active)
    if l.reverse then
      arc(cx, tailY, rr + 6, 30, 150, 3, true)
      arc(cx, tailY, rr + 6, 210, 330, 3, true)
    else
      arc(cx, tailY, rr + 6, 150, 30, 3, true)
      arc(cx, tailY, rr + 6, 330, 210, 3, true)
    end
  end
end

function art.draw(l, x, y, w, h, colors)
  if not l or w <= 0 or h <= 20 then return end
  local k = l.kind
  if k == "swash" then
    drawSwash(l, x, y, w, h, colors)
  elseif k == "tilt" then
    drawTilt(l, x, y, w, h, colors)
  elseif k == "tail" then
    drawTail(l, x, y, w, h, colors)
  elseif k == "level" then
    drawLevel(l, x, y, w, h, colors)
  elseif k == "blade" then
    drawBlade(l, x, y, w, h, colors)
  elseif k == "bars" then
    drawBars(l, x, y, w, h, colors)
  elseif k == "pulse" then
    drawPulse(l, x, y, w, h, colors)
  elseif k == "gears" then
    drawGears(l, x, y, w, h, colors)
  elseif k == "poles" then
    drawPoles(l, x, y, w, h, colors)
  elseif k == "map" then
    drawMap(l, x, y, w, h, colors)
  elseif k == "heli" then
    drawHeli(l, x, y, w, h, colors)
  elseif k == "photo" then
    drawPhoto(l, x, y, w, h, colors)
  elseif k == "image" then
    drawImage(l, x, y, w, h, colors)
  elseif k == "attitude" then
    if l.wire then drawAttitude(l, x, y, w, h, colors) else drawAttitudeSolid(l, x, y, w, h, colors) end
  elseif k == "bubble" then
    drawBubble(l, x, y, w, h, colors)
  elseif k == "rotor" then
    drawRotor(l, x, y, w, h, colors)
  elseif k == "tailType" then
    drawTailType(l, x, y, w, h, colors)
  elseif k == "tailMotor" then
    drawTailMotor(l, x, y, w, h, colors)
  end
end

local cachedDark, cachedColors = nil, nil

function art.colors()
  local dark = lcd.darkMode and lcd.darkMode() or false
  if dark ~= cachedDark or not cachedColors then
    cachedDark = dark
    cachedColors = {
      body = dark and lcd.GREY(110) or lcd.GREY(150),
      surface = dark and lcd.GREY(170) or lcd.GREY(90),
      active = lcd.RGB(255, 165, 30),
      text = dark and lcd.GREY(240) or lcd.GREY(20),
      muted = dark and lcd.GREY(170) or lcd.GREY(90),
      good = lcd.RGB(70, 190, 100),
      bad = lcd.RGB(230, 70, 60),
    }
  end
  return cachedColors
end

package.loaded["rfsuite.app.setup_wizard_art"] = art
return art
