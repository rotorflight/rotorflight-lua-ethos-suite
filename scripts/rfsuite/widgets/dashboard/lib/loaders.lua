-- loaders.lua
local loaders = {}

local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color)
  local stepDeg   = 3
  local radThick  = thickness / 2
  angleStart = math.rad(angleStart)
  angleEnd   = math.rad(angleEnd)
  if angleEnd > angleStart then
    angleEnd = angleEnd - 2 * math.pi
  end
  lcd.color(color or lcd.RGB(255,255,255))
  local stepRad = math.rad(stepDeg)
  for a = angleStart, angleEnd, -stepRad do
    local x = cx + radius * math.cos(a)
    local y = cy - radius * math.sin(a)
    lcd.drawFilledCircle(x, y, radThick)
  end
  -- end‐cap dot
  local xe = cx + radius * math.cos(angleEnd)
  local ye = cy - radius * math.sin(angleEnd)
  lcd.drawFilledCircle(xe, ye, radThick)
end

-- Helper to draw logo image centered
local function drawLogoImage(cx, cy, w, h)
  local imageName = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/gfx/logo.png"
  local bmp = rfsuite.utils.loadImage(imageName)
  if bmp then
    local imgSize = math.min(w, h) * 0.5
    lcd.drawBitmap(cx - imgSize / 2, cy - imgSize / 2, bmp, imgSize, imgSize)
  end
end

-- Helper to wrap and truncate message text
local function getWrappedTextLines(message, fonts, maxWidth, maxHeight)
  local lines = {}
  local chosenFont = fonts[1]
  local _, lineH = lcd.getTextSize("Ay")

  for i = #fonts, 1, -1 do
    lcd.font(fonts[i])
    local tw, th = lcd.getTextSize(message)
    if tw <= maxWidth and th <= maxHeight then
      chosenFont = fonts[i]
      _, lineH = lcd.getTextSize("Ay")
      break
    end
  end

  local function wrap(str)
    local words = {}
    for w in str:gmatch("%S+") do table.insert(words, w) end
    local current = words[1] or ""
    for i = 2, #words do
      local test = current .. " " .. words[i]
      if lcd.getTextSize(test) <= maxWidth then
        current = test
      else
        table.insert(lines, current)
        current = words[i]
      end
    end
    table.insert(lines, current)
  end

  wrap(message)
  local maxLines = math.floor(maxHeight / lineH)
  if #lines > maxLines then
    lines = { unpack(lines, 1, maxLines) }
    local last = lines[#lines]
    while lcd.getTextSize(last .. "…") > maxWidth and #last > 1 do
      last = last:sub(1, -2)
    end
    lines[#lines] = last .. "…"
  end

  return lines, chosenFont, lineH
end

-- Shared overlay rendering
local function drawOverlayBackground(cx, cy, innerR, bg)
  lcd.color(bg)
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, innerR)
  else
    lcd.drawFilledRectangle(cx - innerR, cy - innerR, innerR * 2, innerR * 2)
  end
end

local function renderOverlayText(dashboard, cx, cy, innerR, fg)
  local message = dashboard._overlay_text or rfsuite.i18n.get("widgets.dashboard.loading")
  local fonts = dashboard.utils.getFontListsForResolution().value_default
  local lines, chosenFont, lineH = getWrappedTextLines(message, fonts, innerR * 2 * 0.9, innerR * 2 * 0.8)

  lcd.color(fg)
  lcd.font(chosenFont)
  local totalH = #lines * lineH
  for i, line in ipairs(lines) do
    local tw = lcd.getTextSize(line)
    lcd.drawText(cx - tw / 2, cy - totalH / 2 + (i - 1) * lineH, line)
  end
end

-- Arc loader
function loaders.arcLoader(dashboard, x, y, w, h)
  local color = lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(0, 0, 0)
  dashboard._loader = dashboard._loader or { angle = 0 }
  local st, cx, cy = dashboard._loader, x + w/2, y + h/2
  local radius = math.min(w, h) * (dashboard.loaderScale or 0.3)
  local thickness = math.max(6, radius * 0.15)

  drawArc(cx, cy, radius, thickness, st.angle, st.angle - 90, color)
  st.angle = (st.angle + 20) % 360
  drawLogoImage(cx, cy, w, h)
end


-- Pulse loader
function loaders.pulseLoader(dashboard, x, y, w, h)
  dashboard._pulse = dashboard._pulse or { time = os.clock(), alpha = 1.0, dir = -1 }
  local now, st = os.clock(), dashboard._pulse
  local elapsed = now - st.time
  st.time = now
  st.alpha = st.alpha + (elapsed / 2) * st.dir
  if st.alpha <= 0.5 then st.alpha, st.dir = 0.5, 1 elseif st.alpha >= 1.0 then st.alpha, st.dir = 1.0, -1 end

  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.loaderScale or 0.3)
  local thickness = math.max(6, radius * 0.15)
  local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0
  lcd.color(lcd.RGB(r, g, b, st.alpha))

  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(255,255,255,1.0))
    lcd.drawFilledCircle(cx, cy, radius - thickness)
  end

  drawLogoImage(cx, cy, w, h)
end

-- Pulse overlay message (fully opaque inner background + inner cut‐out)
function loaders.pulseOverlayMessage(dashboard, x, y, w, h, txt)
  dashboard._overlay_cycles_required = dashboard._overlay_cycles_required or math.ceil(5 / (dashboard.paint_interval or 0.5))
  dashboard._overlay_cycles = dashboard._overlay_cycles or 0

  if txt and txt ~= "" then
    dashboard._overlay_text = txt
    dashboard._overlay_cycles = dashboard._overlay_cycles_required
  end

  if dashboard._overlay_cycles <= 0 then return end
  dashboard._overlay_cycles = dashboard._overlay_cycles - 1

  -- fg unchanged; bg now fully opaque
  local fg = lcd.darkMode() and lcd.RGB(255,255,255)
  local bg = lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(255,255,255,1.0)

  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.overlayScale or 0.35)
  local thickness = math.max(6, radius * 0.15)
  local innerR = radius - (thickness / 2) - 1

  -- draw fully opaque background circle
  drawOverlayBackground(cx, cy, innerR, bg)

  -- recreate the pulse α‐oscillation exactly as before
  dashboard._pulse = dashboard._pulse or { time = os.clock(), alpha = 1.0, dir = -1 }
  local now, st = os.clock(), dashboard._pulse
  local elapsed = now - st.time
  st.time = now
  st.alpha = st.alpha + (elapsed / 2) * st.dir
  if st.alpha <= 0.5 then st.alpha, st.dir = 0.5, 1 elseif st.alpha >= 1.0 then st.alpha, st.dir = 1.0, -1 end

  -- outer pulsating circle (alpha varies for the ring itself)
  local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0
  lcd.color(lcd.RGB(r, g, b, st.alpha))
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
    -- inner cut‐out is now fully opaque (alpha = 1.0)
    lcd.color(lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(255,255,255,1.0))
    lcd.drawFilledCircle(cx, cy, radius - thickness)
  end

  renderOverlayText(dashboard, cx, cy, innerR, fg)
end


return loaders
