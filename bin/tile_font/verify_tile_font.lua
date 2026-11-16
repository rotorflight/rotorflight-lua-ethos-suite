-- Behaviour check for the font of the menu tiles: every screen size uses FONT_S, so
-- the tiles of all screens look alike, and a title too wide for its tile is cut.
--
-- Run it:
--     lua5.4 bin/tile_font/verify_tile_font.lua
--     lua5.4 bin/tile_font/verify_tile_font.lua --self-test
--
-- On 800x480 the tiles are 120px wide, which leaves 108px for the title. In FONT_S,
-- "PID Bandwidth", "Accelerometer", "Motor Override" and "ELRS Telemetry" are wider and
-- are cut ("PID Bandwid..."). #2798 moved only the screens holding such a title to
-- FONT_XS, so the tile font changed from one screen to the next. Now every screen, the
-- X18 and X14 too, uses FONT_S, and a title that does not fit is cut with "...".
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
local currentFont = nil
lcd = {
  font = function(font) currentFont = font end,
  getTextSize = function(text)
    return #text * 7 * (currentFont == FONT_S and 1.25 or 1), 12
  end,
  getWindowSize = function() return 784, 406 end,
}

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

local LAYOUTS = {
  {name = "800x480", w = 784, h = 406, tileW = 120},
  {name = "640x360", w = 632, h = 314, tileW = 118},
  {name = "480x320", w = 472, h = 288, tileW = 110},
}
local LONG = "PID Bandwidth"   -- 91px in FONT_XS, 114px in FONT_S

-- The checks, run on the grid module `grid`. Returns how many of them failed.
local function run(grid, report)
  local failed = 0
  local function expect(label, ok, detail)
    if not ok then failed = failed + 1 end
    if report then check(label, ok, detail) end
  end

  for _, layout in ipairs(LAYOUTS) do
    local _, tileW, _, _, font = grid.metrics(layout.w, layout.h)
    expect(layout.name .. " tiles use FONT_S", tileW == layout.tileW and font == FONT_S,
      "tileW=" .. tostring(tileW) .. " font=" .. tostring(font))
    local label = grid.fitLabel(LONG, tileW, font)
    lcd.font(font)
    expect(layout.name .. ": '" .. LONG .. "' is cut to fit its tile",
      label:sub(-3) == "..." and lcd.getTextSize(label) <= tileW - grid.BUTTON_INNER_PADDING, label)
  end
  expect("no per-screen font switch is left", grid.fontForTitles == nil)
  return failed
end

print("menu tile font")
run(assert(loadfile(GRID_PATH))(), true)

-- ---------------------------------------------------------------------------
-- self-test: with FONT_XS as the tile font, the checks must go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the checks must go red when the tiles use FONT_XS")
  local source = readFile(GRID_PATH)
  local mutated, replacements = source:gsub("local TILE_FONT = FONT_S", "local TILE_FONT = FONT_XS", 1)
  check("self-test: the tile font was found in tile_grid.lua", replacements == 1, "replacements=" .. replacements)
  if replacements == 1 then
    local failed = run(assert(load(mutated, "@" .. GRID_PATH))(), false)
    check("self-test: with FONT_XS, checks fail", failed > 0, "failed=" .. failed)
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
