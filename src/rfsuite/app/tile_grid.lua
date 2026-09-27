-- Shared resolution-based tile grid sizing for menu-like icon buttons.

local tile_grid = {}

local MENU_TILE_MIN_WIDTH = 84
local LOW_RES_WIDTH = 640
local BUTTON_INNER_PADDING = 12

tile_grid.MENU_TILE_MIN_WIDTH = MENU_TILE_MIN_WIDTH
tile_grid.LOW_RES_WIDTH = LOW_RES_WIDTH
tile_grid.BUTTON_INNER_PADDING = BUTTON_INNER_PADDING

local MENU_PROFILES = {
  {w = 784, h = 406, large = {w = 120, h = 120, pad = 10, perRow = 6}, small = {w = 105, h = 110, pad = 6, perRow = 7}},
  {w = 632, h = 314, large = {w = 118, h = 124, pad = 7, perRow = 5}, small = {w = 97, h = 120, pad = 8, perRow = 6}},
  {w = 472, h = 288, large = {w = 110, h = 118, pad = 8, perRow = 4}, small = {w = 89, h = 104, pad = 5, perRow = 5}},
}

local function closestProfile(windowWidth, windowHeight)
  local bestProfile, bestDistance
  for i = 1, #MENU_PROFILES do
    local profile = MENU_PROFILES[i]
    local distance = math.abs(profile.w - windowWidth) + math.abs(profile.h - windowHeight)
    if not bestDistance or distance < bestDistance then
      bestProfile = profile
      bestDistance = distance
    end
  end
  return bestProfile or MENU_PROFILES[#MENU_PROFILES]
end

-- Standard tile grid uses profile.large across all resolutions:
-- - 784x406 (X20 / 800x480): 6 columns, 120 px width, FONT_S
-- - 632x314 (X14 / 640x360): 5 columns, 118 px width, FONT_XS
-- - 472x288 (X18 / 480x320): 4 columns, 110 px width, FONT_XS
-- This gives consistent, touch-friendly ~110-120 px tile widths on all radios
-- and avoids cramming 5 narrow columns (89 px) onto 480x320 screens (Issue #2299).
local function chooseSpec(profile, windowWidth)
  local font = FONT_XS
  if windowWidth > LOW_RES_WIDTH then
    font = FONT_S
  end
  return profile.large or profile, font
end

local function fitSpecToWindow(spec, windowWidth)
  local perRow = spec.perRow
  while perRow > 1 and math.floor((windowWidth - (spec.pad * (perRow - 1))) / perRow) < MENU_TILE_MIN_WIDTH do
    perRow = perRow - 1
  end

  local tileW = spec.w
  local tileH = spec.h
  local availableTileW = math.floor((windowWidth - (spec.pad * (perRow - 1))) / perRow)
  if availableTileW < tileW then
    tileW = availableTileW
    tileH = math.floor((spec.h * tileW / spec.w) + 0.5)
  end
  if tileW < MENU_TILE_MIN_WIDTH then tileW = MENU_TILE_MIN_WIDTH end
  return perRow, tileW, tileH, spec.pad
end

function tile_grid.metrics(windowWidth, windowHeight)
  if not windowWidth or not windowHeight then
    windowWidth, windowHeight = lcd.getWindowSize()
  end
  local profile = closestProfile(windowWidth, windowHeight)
  local spec, tileFont = chooseSpec(profile, windowWidth)
  local numPerRow, tileW, tileH, tilePadding = fitSpecToWindow(spec, windowWidth)
  return numPerRow, tileW, tileH, tilePadding, tileFont
end

local function trimLastUtf8Char(str)
  local len = #str
  while len > 0 and str:byte(len) >= 128 and str:byte(len) < 192 do
    len = len - 1
  end
  if len > 0 then
    len = len - 1
  end
  return str:sub(1, len)
end

function tile_grid.fitText(text, maxW, font)
  if type(text) ~= "string" or text == "" then return text end
  if text:sub(1, 6) == "@i18n(" then return text end
  if not maxW or maxW <= 0 then return text end
  if font and lcd and lcd.font then
    lcd.font(font)
  end
  if not (lcd and lcd.getTextSize) then
    return text
  end

  local tw = lcd.getTextSize(text)
  if tw <= maxW then
    return text
  end

  local ellipsis = "..."
  local ellW = lcd.getTextSize(ellipsis)
  if ellW >= maxW then
    return ellipsis
  end

  local trimmed = text
  while #trimmed > 1 do
    trimmed = trimLastUtf8Char(trimmed)
    if trimmed == "" then break end
    tw = lcd.getTextSize(trimmed)
    if tw + ellW <= maxW then
      local clean = trimmed:gsub("%s+$", "")
      return (clean ~= "" and clean or trimmed) .. ellipsis
    end
  end

  return ellipsis
end

function tile_grid.fitLabel(text, tileW, font, padding)
  local pad = padding or BUTTON_INNER_PADDING
  local maxW = (tileW or 0) - pad
  return tile_grid.fitText(text, maxW, font)
end

return tile_grid
