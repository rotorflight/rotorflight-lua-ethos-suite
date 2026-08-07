-- Shared resolution-based tile grid sizing for menu-like icon buttons.

local tile_grid = {}

local MENU_TILE_MIN_WIDTH = 84
local LOW_RES_WIDTH = 640

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

local function chooseSpec(profile, windowWidth)
  if windowWidth > LOW_RES_WIDTH then
    return profile.large, FONT_S
  end
  return profile.small, FONT_XS
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

return tile_grid
