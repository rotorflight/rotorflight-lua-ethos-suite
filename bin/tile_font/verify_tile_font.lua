-- Behaviour check for the font of the menu tiles: a screen whose titles all fit their
-- tile keeps the font of the screen size, and a screen with a title that would be cut
-- uses FONT_XS for all its tiles.
--
-- Run it:
--     lua5.4 bin/tile_font/verify_tile_font.lua
--     lua5.4 bin/tile_font/verify_tile_font.lua --self-test
--
-- On 800x480 the tiles are 120px wide and use FONT_S, which leaves 108px for the title.
-- "PID Bandwidth", "Accelerometer", "Motor Override" and "ELRS Telemetry" are wider and
-- were shown cut ("PID Bandwid..."). They fit on the X18, whose tiles use FONT_XS, so
-- bin/i18n/check-fit.py, which measures the X18, reported nothing.
--
-- Drives the real app/tile_grid.lua. lcd is a stub whose text width is 7px a character
-- in FONT_XS and a quarter more in FONT_S.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local GRID_PATH = scriptDir() .. "/../../src/rfsuite/app/tile_grid.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

FONT_XS, FONT_S = 1, 2
local currentFont, measurements = nil, 0
local function textWidth(text, font)
  return #text * 7 * (font == FONT_S and 1.25 or 1)
end
local lcdStub = {
  font = function(font) currentFont = font end,
  getTextSize = function(text)
    measurements = measurements + 1
    return textWidth(text, currentFont), 12
  end,
  getWindowSize = function() return 784, 406 end,
}
lcd = lcdStub

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

local TILE_W = 120  -- the tile of the 800x480 layout: 108px for the title
local short = {title = "Short"}             -- 35px, 44px in FONT_S
local long = {title = "PID Bandwidth"}      -- 91px, 114px in FONT_S

-- The checks, run on the grid module `grid`. Returns how many of them failed.
local function run(grid, report)
  local failed = 0
  local function expect(label, ok, detail)
    if not ok then failed = failed + 1 end
    if report then check(label, ok, detail) end
  end

  local _, tileW, _, _, font = grid.metrics(784, 406)
  expect("the 800x480 layout has 120px tiles in FONT_S", tileW == TILE_W and font == FONT_S,
    "tileW=" .. tostring(tileW) .. " font=" .. tostring(font))

  expect("a screen whose titles fit keeps FONT_S",
    grid.fontForTitles({short, short}, TILE_W, FONT_S) == FONT_S)
  local chosen = grid.fontForTitles({short, long, short}, TILE_W, FONT_S)
  expect("a screen with a title too long uses FONT_XS", chosen == FONT_XS, "font=" .. tostring(chosen))
  expect("the long title is whole in the font chosen",
    grid.fitLabel(long.title, TILE_W, chosen) == long.title, grid.fitLabel(long.title, TILE_W, chosen))
  expect("an entry that gets no tile does not count",
    grid.fontForTitles({short, long}, TILE_W, FONT_S, function(entry) return entry ~= long end) == FONT_S)
  expect("a title that is not text does not count",
    grid.fontForTitles({short, {title = 12345678901234567890}}, TILE_W, FONT_S) == FONT_S)

  measurements = 0
  expect("a screen already on FONT_XS measures nothing",
    grid.fontForTitles({short, long}, 110, FONT_XS) == FONT_XS and measurements == 0,
    "measurements=" .. measurements)

  lcd = nil
  expect("without lcd the font is kept", grid.fontForTitles({long}, TILE_W, FONT_S) == FONT_S)
  lcd = lcdStub
  return failed
end

print("menu tile font")
run(assert(loadfile(GRID_PATH))(), true)

-- ---------------------------------------------------------------------------
-- self-test: with the font of the screen size always kept, the checks must go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the checks must go red when the font never changes")
  local source = readFile(GRID_PATH)
  local mutated, replacements = source:gsub("      return FONT_XS\n", "      return font\n", 1)
  if replacements == 0 then
    mutated, replacements = source:gsub("      return FONT_XS\r\n", "      return font\r\n", 1)
  end
  check("self-test: the font choice was found in tile_grid.lua", replacements == 1, "replacements=" .. replacements)
  if replacements == 1 then
    local failed = run(assert(load(mutated, "@" .. GRID_PATH))(), false)
    check("self-test: with FONT_S always kept, checks fail", failed > 0, "failed=" .. failed)
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
