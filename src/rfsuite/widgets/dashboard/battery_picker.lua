-- Battery profile picker for the dashboard's Battery tile (#2357).
--
-- form.openDialog lays its buttons out in one row. Six battery profiles in
-- that row overflow a 480x320 screen, so the picker is painted instead: a
-- grid, three cells across on a screen 400 px wide or more and two below
-- that, every cell at least MIN_TARGET px in both directions so a fingertip
-- can hit it.
--
-- widgets/dashboard.lua loads this module when the Battery tile is opened,
-- not with the widget, so the boot closure does not carry it.
--
-- The geometry is computed once per size and item set (the caller keeps it
-- until either changes). draw() and hit() allocate nothing per frame.

local M = {}

M.MIN_TARGET = 44
M.WIDE_MIN_WIDTH = 400

local MARGIN = 8
local GAP = 8
local PAD = 6
local NUMBER_NAME_GAP = 4
local MIN_TITLE_H = 32

function M.columnsFor(w)
  if w >= M.WIDE_MIN_WIDTH then return 3 end
  return 2
end

-- The name is fitted to the cell: the small font first, then the smaller
-- one, then cut with ".." -- measured with the real font, so a long
-- user-given profile name never runs past the cell edge.
local function fitName(name, maxW)
  lcd.font(FONT_S)
  local tw, th = lcd.getTextSize(name)
  if tw <= maxW then return name, FONT_S, th end

  lcd.font(FONT_XS)
  tw, th = lcd.getTextSize(name)
  if tw <= maxW then return name, FONT_XS, th end

  local text = name
  while #text > 1 do
    text = text:sub(1, -2)
    local candidate = text .. ".."
    tw, th = lcd.getTextSize(candidate)
    if tw <= maxW then return candidate, FONT_XS, th end
  end
  return name:sub(1, 1), FONT_XS, th
end

local function labelFor(item, maxW)
  local number = tostring(item.number)
  local name, nameFont, nameH = fitName(tostring(item.name), maxW)
  lcd.font(FONT_STD)
  local _, numberH = lcd.getTextSize(number)
  return {number = number, name = name, nameFont = nameFont, numberH = numberH, nameH = nameH}
end

-- items: array of {number = "1", name = "3300mAh"}; number is the 1-based
-- pack label the pilot knows the battery by.
function M.layout(w, h, items)
  local count = #items
  local cols = M.columnsFor(w)
  if cols > count then cols = count end
  if cols < 1 then cols = 1 end
  local rows = count > 0 and math.ceil(count / cols) or 0

  local titleH = math.max(MIN_TITLE_H, math.floor(h * 0.14))
  local gridY = titleH + MARGIN
  local gridW = w - 2 * MARGIN
  local gridH = h - gridY - MARGIN
  local cellW = math.floor((gridW - GAP * (cols - 1)) / cols)
  local cellH = rows > 0 and math.floor((gridH - GAP * (rows - 1)) / rows) or 0

  local cells, labels = {}, {}
  local minTarget = nil
  for i = 1, count do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    cells[i] = {
      x = MARGIN + col * (cellW + GAP),
      y = gridY + row * (cellH + GAP),
      w = cellW,
      h = cellH,
    }
    labels[i] = labelFor(items[i], cellW - 2 * PAD)
    local target = math.min(cellW, cellH)
    if minTarget == nil or target < minTarget then minTarget = target end
  end

  return {
    w = w,
    h = h,
    cols = cols,
    rows = rows,
    titleH = titleH,
    cells = cells,
    labels = labels,
    minTarget = minTarget or 0,
  }
end

-- Index of the cell under (x, y), or nil for the title, the margins and the
-- gaps between cells.
function M.hit(layout, x, y)
  if not layout or not x or not y then return nil end
  local cells = layout.cells
  for i = 1, #cells do
    local c = cells[i]
    if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then
      return i
    end
  end
  return nil
end

-- Next selection for a rotary step, wrapping at both ends.
function M.step(selected, delta, count)
  if count < 1 then return nil end
  return ((selected - 1 + delta) % count) + 1
end

-- colors: the table toolbarColors() returns in widgets/dashboard.lua.
function M.draw(layout, title, selected, colors)
  local w, h = layout.w, layout.h

  lcd.color(colors.surfaceBg)
  lcd.drawFilledRectangle(0, 0, w, h)

  lcd.font(FONT_S)
  local _, titleTextH = lcd.getTextSize(title)
  lcd.color(colors.text)
  lcd.drawText(w * 0.5, math.floor((layout.titleH - titleTextH) / 2), title, CENTERED)

  local cells, labels = layout.cells, layout.labels
  for i = 1, #cells do
    local cell = cells[i]
    local label = labels[i]
    local isSelected = i == selected

    lcd.color(isSelected and colors.selectedFill or colors.tileFill)
    lcd.drawFilledRectangle(cell.x, cell.y, cell.w, cell.h)

    local textColor = isSelected and colors.selectedText or colors.text
    local blockH = label.numberH + NUMBER_NAME_GAP + label.nameH
    local y = cell.y + math.floor((cell.h - blockH) / 2)
    local cx = cell.x + cell.w * 0.5

    lcd.color(textColor)
    lcd.font(FONT_STD)
    lcd.drawText(cx, y, label.number, CENTERED)
    lcd.font(label.nameFont)
    lcd.drawText(cx, y + label.numberH + NUMBER_NAME_GAP, label.name, CENTERED)
  end
end

return M
