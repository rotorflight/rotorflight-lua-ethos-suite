-- loaders.lua
local loaders = {}

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

-- Arc overlay message
function loaders.arcOverlayMessage(dashboard, x, y, w, h, txt)
  dashboard._overlay_cycles_required = dashboard._overlay_cycles_required or math.ceil(5 / (dashboard.paint_interval or 0.5))
  dashboard._overlay_cycles = dashboard._overlay_cycles or 0
  if txt and txt ~= "" then
    dashboard._overlay_text, dashboard._overlay_cycles = txt, dashboard._overlay_cycles_required
  end
  if dashboard._overlay_cycles <= 0 then return end

  dashboard._overlay_cycles = dashboard._overlay_cycles - 1
  local fg, bg = lcd.darkMode() and lcd.RGB(255,255,255), lcd.darkMode() and lcd.RGB(0,0,0,0.9) or lcd.RGB(255,255,255,0.9)
  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.overlayScale or 0.35)
  local thickness, innerR = math.max(6, radius * 0.15), radius - (thickness / 2) - 1

  drawOverlayBackground(cx, cy, innerR, bg)
  dashboard._loader = dashboard._loader or { angle = 0 }
  drawArc(cx, cy, radius, thickness, dashboard._loader.angle, dashboard._loader.angle - 90, fg)
  dashboard._loader.angle = (dashboard._loader.angle + 20) % 360
  renderOverlayText(dashboard, cx, cy, innerR, fg)
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

-- Pulse overlay message
function loaders.pulseOverlayMessage(dashboard, x, y, w, h, txt)
  loaders.arcOverlayMessage(dashboard, x, y, w, h, txt) -- shared logic
  loaders.pulseLoader(dashboard, x, y, w, h)
end

-- Static loader
function loaders.staticLoader(dashboard, x, y, w, h)
  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.loaderScale or 0.3)
  local thickness = math.max(6, radius * 0.15)
  local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0

  lcd.color(lcd.RGB(r, g, b, 0.9))
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(255,255,255,1.0))
    lcd.drawFilledCircle(cx, cy, radius - thickness)
  end

  drawLogoImage(cx, cy, w, h)
end

-- Static overlay message
function loaders.staticOverlayMessage(dashboard, x, y, w, h, txt)
  dashboard._overlay_cycles_required = dashboard._overlay_cycles_required or math.ceil(5 / (dashboard.paint_interval or 0.5))
  dashboard._overlay_cycles = dashboard._overlay_cycles or 0
  if txt and txt ~= "" then
    dashboard._overlay_text, dashboard._overlay_cycles = txt, dashboard._overlay_cycles_required
  end
  if dashboard._overlay_cycles <= 0 then return end

  dashboard._overlay_cycles = dashboard._overlay_cycles - 1
  local fg, bg = lcd.darkMode() and lcd.RGB(255,255,255), lcd.darkMode() and lcd.RGB(0,0,0,0.9) or lcd.RGB(255,255,255,0.9)
  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.overlayScale or 0.35)
  local thickness, innerR = math.max(6, radius * 0.15), radius - (thickness / 2) - 1

  drawOverlayBackground(cx, cy, innerR, bg)
  lcd.color(fg)
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(255,255,255,1.0))
    lcd.drawFilledCircle(cx, cy, radius - thickness)
  end

  renderOverlayText(dashboard, cx, cy, innerR, fg)
end

function loaders.blinkLoader(dashboard, x, y, w, h)
  dashboard._blink = dashboard._blink or { time = os.clock(), high = true }

  local now = os.clock()
  local st = dashboard._blink
  if now - st.time >= 2.0 then
    st.high = not st.high
    st.time = now
  end

  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.loaderScale or 0.3)
  local thickness = math.max(6, radius * 0.15)
  local innerRadius = radius - thickness
  local alpha = st.high and 1.0 or 0.8
  local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0

  -- Outer ring
  lcd.color(lcd.RGB(r, g, b, alpha))
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
  end

  -- Inner cut-out (fully opaque)
  lcd.color(lcd.darkMode() and lcd.RGB(0, 0, 0, 1.0) or lcd.RGB(255, 255, 255, 1.0))
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, innerRadius)
  end

  drawLogoImage(cx, cy, w, h)
end


function loaders.blinkOverlayMessage(dashboard, x, y, w, h, txt)
  dashboard._overlay_cycles_required = dashboard._overlay_cycles_required or math.ceil(5 / (dashboard.paint_interval or 0.5))
  dashboard._overlay_cycles = dashboard._overlay_cycles or 0

  if txt and txt ~= "" then
    dashboard._overlay_text = txt
    dashboard._overlay_cycles = dashboard._overlay_cycles_required
  end

  if dashboard._overlay_cycles <= 0 then return end
  dashboard._overlay_cycles = dashboard._overlay_cycles - 1

  local fg, bg = lcd.darkMode() and lcd.RGB(255,255,255), lcd.darkMode() and lcd.RGB(0,0,0,0.9) or lcd.RGB(255,255,255,0.9)
  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.overlayScale or 0.35)
  local thickness = math.max(6, radius * 0.15)
  local innerR = radius - (thickness / 2) - 1

  drawOverlayBackground(cx, cy, innerR, bg)

  dashboard._blink = dashboard._blink or { time = os.clock(), high = true }
  local now, st = os.clock(), dashboard._blink
  if now - st.time >= 2.0 then
    st.high = not st.high
    st.time = now
  end

  local alpha = st.high and 1.0 or 0.8
  local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0

  -- Outer ring with blinking opacity
  lcd.color(lcd.RGB(r, g, b, alpha))
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
  end

  -- Inner cut-out (fully opaque)
  local innerRadius = radius - thickness
  lcd.color(lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(255,255,255,1.0))
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, innerRadius)
  end

  renderOverlayText(dashboard, cx, cy, innerR, fg)
end



return loaders
