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
    lines = { table.unpack(lines, 1, maxLines) }
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
  local message = dashboard._overlay_text or "@i18n(widgets.dashboard.loading)@"
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


-- Static loader (no pulse)
function loaders.staticLoader(dashboard, x, y, w, h)

  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.loaderScale or 0.3)
  local thickness = math.max(6, radius * 0.15)

  local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0
  lcd.color(lcd.RGB(r, g, b, 1.0))  -- Solid color with full opacity

  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(lcd.darkMode() and lcd.RGB(0, 0, 0, 1.0) or lcd.RGB(0, 0, 0, 1.0))
    lcd.drawFilledCircle(cx, cy, radius - thickness)
  end

  drawLogoImage(cx, cy, w, h)

-- Animated dots below the logo
  dashboard._dots_index = dashboard._dots_index or 1
  dashboard._dots_time = dashboard._dots_time or os.clock()
  if os.clock() - dashboard._dots_time > 0.5 then
    dashboard._dots_time = os.clock()
    dashboard._dots_index = (dashboard._dots_index % 3) + 1
  end

  local dotRadius = 4
  local spacing = 3 * dotRadius
  local startX = cx - spacing
  local yPos = cy + (radius - thickness / 2) / 2  -- Midway between center and outer edge

  for i = 1, 3 do
    if i == dashboard._dots_index then
      lcd.color(lcd.darkMode() and lcd.RGB(255,255,255) or lcd.RGB(0,0,0))
    else
      lcd.color(lcd.darkMode() and lcd.RGB(80,80,80) or lcd.RGB(180,180,180))
    end
    lcd.drawFilledCircle(startX + (i - 1) * spacing, yPos, dotRadius)
  end

end

-- Static overlay message (no pulse animation)
function loaders.staticOverlayMessage(dashboard, x, y, w, h, txt)
  dashboard._overlay_cycles_required = dashboard._overlay_cycles_required or math.ceil(5 / (dashboard.paint_interval or 0.5))
  dashboard._overlay_cycles = dashboard._overlay_cycles or 0

  if txt and txt ~= "" then
    dashboard._overlay_text = txt
    dashboard._overlay_cycles = dashboard._overlay_cycles_required
  end

  if dashboard._overlay_cycles <= 0 then return end
  dashboard._overlay_cycles = dashboard._overlay_cycles - 1

  local fg = lcd.darkMode() and lcd.RGB(255,255,255) or lcd.RGB(255,255,255)
  local bg = lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(255,255,255,1.0)

  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * (dashboard.overlayScale or 0.35)
  local thickness = math.max(6, radius * 0.15)
  local innerR = radius - (thickness / 2) - 1

  -- draw solid background circle
  drawOverlayBackground(cx, cy, innerR, bg)

  -- outer circle with full opacity
  local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0
  lcd.color(lcd.RGB(r, g, b, 1.0))
  if lcd.drawFilledCircle then
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(lcd.darkMode() and lcd.RGB(0,0,0,1.0) or lcd.RGB(0,0,0,1.0))
    lcd.drawFilledCircle(cx, cy, radius - thickness)
  end

-- Animated dots below the logo
  dashboard._dots_index = dashboard._dots_index or 1
  dashboard._dots_time = dashboard._dots_time or os.clock()
  if os.clock() - dashboard._dots_time > 0.5 then
    dashboard._dots_time = os.clock()
    dashboard._dots_index = (dashboard._dots_index % 3) + 1
  end

  local dotRadius = 4
  local spacing = 3 * dotRadius
  local startX = cx - spacing
  local yPos = cy + (radius - thickness / 2) / 2  -- Midway between center and outer edge

  for i = 1, 3 do
    if i == dashboard._dots_index then
      lcd.color(lcd.darkMode() and lcd.RGB(255,255,255) or lcd.RGB(0,0,0))
    else
      lcd.color(lcd.darkMode() and lcd.RGB(80,80,80) or lcd.RGB(180,180,180))
    end
    lcd.drawFilledCircle(startX + (i - 1) * spacing, yPos, dotRadius)
  end

  renderOverlayText(dashboard, cx, cy, innerR, fg)
end


return loaders
