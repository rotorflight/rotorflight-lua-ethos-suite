-- Custom Alignment 3D visualizer.
--
-- Stateless renderer for app/pages/alignment.lua. It keeps the original
-- module's important behavior: live attitude text, configured offset text,
-- nose-direction cue, and a projected heli model whose orientation follows
-- MSP_ATTITUDE plus any *unsaved* edits to the board offset fields (see
-- state.baseline in app/pages/alignment.lua -- the offsets already saved
-- on the FC are subtracted back out, since MSP_ATTITUDE already includes
-- them).

if package.loaded["rfsuite.app.alignment_visual"] then
  return package.loaded["rfsuite.app.alignment_visual"]
end

local cos = math.cos
local sin = math.sin
local rad = math.rad
local floor = math.floor
local sqrt = math.sqrt
local max = math.max
local min = math.min
local t_sort = table.sort

local BASE_VIEW_PITCH_R = rad(-90)
local BASE_VIEW_YAW_R = rad(90)
local CAMERA_DIST = 7.0
local CAMERA_NEAR_EPS = 0.25

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function rotatePoint(x, y, z, pitchR, yawR, rollR)
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
  return cx + (px * f * scale), cy - (py * f * scale)
end

local function drawLine3D(a, b, cx, cy, scale, pitchR, yawR, rollR, color)
  local ax, ay, az = rotatePoint(a[1], a[2], a[3], pitchR, yawR, rollR)
  local bx, by, bz = rotatePoint(b[1], b[2], b[3], pitchR, yawR, rollR)
  if (CAMERA_DIST - az) <= CAMERA_NEAR_EPS or (CAMERA_DIST - bz) <= CAMERA_NEAR_EPS then return end
  local x1, y1 = projectPoint(ax, ay, az, cx, cy, scale)
  local x2, y2 = projectPoint(bx, by, bz, cx, cy, scale)
  if not x1 or not x2 then return end
  lcd.color(color)
  lcd.drawLine(x1, y1, x2, y2)
end

local function collectTriangle3D(list, a, b, c, cx, cy, scale, pitchR, yawR, rollR, color)
  local ax, ay, az = rotatePoint(a[1], a[2], a[3], pitchR, yawR, rollR)
  local bx, by, bz = rotatePoint(b[1], b[2], b[3], pitchR, yawR, rollR)
  local cx3, cy3, cz3 = rotatePoint(c[1], c[2], c[3], pitchR, yawR, rollR)
  if (CAMERA_DIST - az) <= CAMERA_NEAR_EPS or (CAMERA_DIST - bz) <= CAMERA_NEAR_EPS or (CAMERA_DIST - cz3) <= CAMERA_NEAR_EPS then return end

  local x1, y1 = projectPoint(ax, ay, az, cx, cy, scale)
  local x2, y2 = projectPoint(bx, by, bz, cx, cy, scale)
  local x3, y3 = projectPoint(cx3, cy3, cz3, cx, cy, scale)
  if not x1 or not x2 or not x3 then return end
  list[#list + 1] = {x1 = x1, y1 = y1, x2 = x2, y2 = y2, x3 = x3, y3 = y3, z = (az + bz + cz3) / 3, color = color}
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

local POINTS = {
  nose = {2.35, 0.0, -0.02},
  tail = {-2.65, 0.0, 0.03},
  lf = {1.10, -0.62, 0.02},
  rf = {1.10, 0.62, 0.02},
  lb = {-0.55, -0.46, 0.05},
  rb = {-0.55, 0.46, 0.05},
  top = {0.05, 0.0, 0.84},
  mast = {0.0, 0.0, 1.02},
  boomU = {-0.88, 0.0, 0.18},
  boomD = {-0.88, 0.0, 0.06},
  boomL = {-0.88, -0.10, 0.11},
  boomR = {-0.88, 0.10, 0.11},
  boomEU = {-2.35, 0.0, 0.12},
  boomED = {-2.35, 0.0, 0.05},
  boomEL = {-2.35, -0.06, 0.08},
  boomER = {-2.35, 0.06, 0.08},
  finU = {-2.25, 0.0, 0.45},
  finD = {-2.25, 0.0, -0.18},
  rotorA = {0.0, -1.9, 1.02},
  rotorB = {0.0, 1.9, 1.02},
  rotorC = {-1.9, 0.0, 1.02},
  rotorD = {1.9, 0.0, 1.02},
  skidL1 = {1.12, -0.66, -0.69},
  skidL2 = {0.76, -0.66, -0.64},
  skidL3 = {0.00, -0.66, -0.62},
  skidL4 = {-0.96, -0.66, -0.63},
  skidL5 = {-1.24, -0.66, -0.67},
  skidR1 = {1.12, 0.66, -0.69},
  skidR2 = {0.76, 0.66, -0.64},
  skidR3 = {0.00, 0.66, -0.62},
  skidR4 = {-0.96, 0.66, -0.63},
  skidR5 = {-1.24, 0.66, -0.67},
  strutLFTop = {0.52, -0.50, -0.12},
  strutLFBot = {0.48, -0.66, -0.63},
  strutLBTop = {-0.52, -0.44, -0.10},
  strutLBBot = {-0.58, -0.66, -0.63},
  strutRFTop = {0.52, 0.50, -0.12},
  strutRFBot = {0.48, 0.66, -0.63},
  strutRBTop = {-0.52, 0.44, -0.10},
  strutRBBot = {-0.58, 0.66, -0.63},
}

local alignment_visual = {}

function alignment_visual.recenterYaw(state)
  local baseline = state.baseline or {}
  state.viewYawOffset = (tonumber(state.live.yaw) or 0) + (tonumber(state.display.yaw_degrees) or 0) - (tonumber(baseline.yaw_degrees) or 0)
end

function alignment_visual.draw(state)
  local w, h = lcd.getWindowSize()
  local y = floor(form.height() + 2)
  local vw = w - 1
  local vh = h - y - 2
  if vh < 40 then return end

  local isDark = lcd.darkMode()
  local bg = isDark and lcd.RGB(18, 18, 18) or lcd.RGB(245, 245, 245)
  local grid = isDark and lcd.GREY(70) or lcd.GREY(210)
  local mainColor = isDark and lcd.RGB(248, 248, 248) or lcd.RGB(8, 8, 8)
  local accent = isDark and lcd.RGB(255, 220, 110) or lcd.RGB(0, 110, 235)
  local disc = lcd.RGB(150, 150, 150)
  local bodyLight = isDark and lcd.RGB(220, 220, 220) or lcd.RGB(180, 180, 180)
  local bodyMid = isDark and lcd.RGB(180, 180, 180) or lcd.RGB(145, 145, 145)
  local bodyDark = isDark and lcd.RGB(140, 140, 140) or lcd.RGB(112, 112, 112)

  local panelX = 4
  local panelY = y + 2
  local panelW = vw - 8
  local panelH = vh - 4

  lcd.color(bg)
  lcd.drawFilledRectangle(panelX, panelY, panelW, panelH)
  lcd.color(grid)
  lcd.drawRectangle(panelX, panelY, panelW, panelH)

  -- MSP_ATTITUDE already reflects the board-alignment offsets currently
  -- saved on the FC (alignment is applied to the sensor data before
  -- attitude is computed), so state.baseline -- the offsets in effect
  -- when this page opened -- must be subtracted back out before adding
  -- state.display (the, possibly still unsaved, offsets shown in the
  -- fields). Adding state.display on its own double-counts whatever was
  -- already saved, e.g. a correctly-configured upside-down mount (board
  -- roll 180) renders upside down here even though live attitude is
  -- already level.
  local baseline = state.baseline or {}
  local pitchR = rad(-((state.live.pitch or 0) + (state.display.pitch_degrees or 0) - (baseline.pitch_degrees or 0)))
  local yawR = rad(-(((state.live.yaw or 0) + (state.display.yaw_degrees or 0) - (baseline.yaw_degrees or 0)) - (state.viewYawOffset or 0)))
  local rollR = rad(-((state.live.roll or 0) + (state.display.roll_degrees or 0) - (baseline.roll_degrees or 0)))

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

  lcd.font(FONT_XS)
  local liveText = string.format("@i18n(app.modules.alignment.live_fmt)@", state.live.roll or 0, state.live.pitch or 0, state.live.yaw or 0)
  local offsText = string.format("@i18n(app.modules.alignment.offset_fmt)@", state.display.roll_degrees or 0, state.display.pitch_degrees or 0, state.display.yaw_degrees or 0, state.display.mag_alignment or 0)
  local _, th1 = lcd.getTextSize(liveText)
  local _, th2 = lcd.getTextSize(offsText)
  local textX = infoX + 8
  local textY = infoY + 6
  lcd.color(mainColor)
  lcd.drawText(textX, textY, liveText, LEFT)
  lcd.drawText(textX, textY + th1 + 2, offsText, LEFT)
  lcd.drawText(textX, textY + th1 + th2 + 14, string.format("@i18n(app.modules.alignment.view_yaw_fmt)@", state.viewYawOffset or 0), LEFT)

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
  local p = POINTS

  local fuselage = {}
  collectTriangle3D(fuselage, p.nose, p.lf, p.top, cx, cy, scale, pitchR, yawR, rollR, bodyLight)
  collectTriangle3D(fuselage, p.nose, p.top, p.rf, cx, cy, scale, pitchR, yawR, rollR, bodyLight)
  collectTriangle3D(fuselage, p.lf, p.lb, p.top, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
  collectTriangle3D(fuselage, p.rf, p.top, p.rb, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
  collectTriangle3D(fuselage, p.lf, p.lb, p.rb, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
  collectTriangle3D(fuselage, p.lf, p.rb, p.rf, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
  collectTriangle3D(fuselage, p.boomU, p.boomL, p.boomEU, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
  collectTriangle3D(fuselage, p.boomL, p.boomEL, p.boomEU, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
  collectTriangle3D(fuselage, p.boomU, p.boomEU, p.boomR, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
  collectTriangle3D(fuselage, p.boomR, p.boomEU, p.boomER, cx, cy, scale, pitchR, yawR, rollR, bodyMid)
  collectTriangle3D(fuselage, p.boomL, p.boomD, p.boomEL, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
  collectTriangle3D(fuselage, p.boomD, p.boomED, p.boomEL, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
  collectTriangle3D(fuselage, p.boomD, p.boomR, p.boomED, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
  collectTriangle3D(fuselage, p.boomR, p.boomER, p.boomED, cx, cy, scale, pitchR, yawR, rollR, bodyDark)
  drawTriangleList(fuselage)

  drawLine3D(p.rotorA, p.rotorB, cx, cy, scale, pitchR, yawR, rollR, disc)
  drawLine3D(p.rotorC, p.rotorD, cx, cy, scale, pitchR, yawR, rollR, disc)
  drawLine3D(p.top, p.mast, cx, cy, scale, pitchR, yawR, rollR, disc)

  drawLine3D(p.lb, p.lf, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.rb, p.rf, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.lf, p.nose, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.rf, p.nose, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.top, p.nose, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.boomU, p.boomEU, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.boomL, p.boomEL, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.boomR, p.boomER, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.boomD, p.boomED, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.boomU, p.boomL, cx, cy, scale, pitchR, yawR, rollR, accent)
  drawLine3D(p.boomL, p.boomD, cx, cy, scale, pitchR, yawR, rollR, accent)
  drawLine3D(p.boomD, p.boomR, cx, cy, scale, pitchR, yawR, rollR, accent)
  drawLine3D(p.boomR, p.boomU, cx, cy, scale, pitchR, yawR, rollR, accent)
  drawLine3D(p.finU, p.finD, cx, cy, scale, pitchR, yawR, rollR, accent)

  drawLine3D(p.skidL1, p.skidL2, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.skidL2, p.skidL3, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.skidL3, p.skidL4, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.skidL4, p.skidL5, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.skidR1, p.skidR2, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.skidR2, p.skidR3, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.skidR3, p.skidR4, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.skidR4, p.skidR5, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutLFTop, p.strutLFBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutLBTop, p.strutLBBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutRFTop, p.strutRFBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutRBTop, p.strutRBBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutLFBot, p.strutRFBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutLBBot, p.strutRBBot, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutLFTop, p.strutRFTop, cx, cy, scale, pitchR, yawR, rollR, mainColor)
  drawLine3D(p.strutLBTop, p.strutRBTop, cx, cy, scale, pitchR, yawR, rollR, mainColor)
end

package.loaded["rfsuite.app.alignment_visual"] = alignment_visual
return alignment_visual
