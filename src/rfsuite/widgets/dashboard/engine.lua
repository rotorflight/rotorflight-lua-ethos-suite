-- Old dashboard render flow adapted to Lite's isolated widget.

local engine = {}
local context = assert(loadfile("widgets/dashboard/context.lua"))()

local floor = math.floor
local ceil = math.ceil
local max = math.max
local sort = table.sort

local objectsByType = {}
local boxRects = {}
local typeScratch = {}
local preparedConfig = nil
local preparedW = nil
local preparedH = nil
local preparedObjectsLoaded = false
local wakeCursor = 1
local wakePassCount = 0

local function clearArray(t)
  for i = #t, 1, -1 do t[i] = nil end
end

local function resolveMaybe(value)
  if type(value) == "function" then return value() end
  return value
end

local function adjustDimension(dim, cells, padCount, pad)
  return dim - ((dim - padCount * pad) % cells)
end

local function getBoxSize(box, boxWidth, boxHeight, padding, widgetW, widgetH)
  if box.w_pct and box.h_pct then
    local wp = box.w_pct > 1 and box.w_pct / 100 or box.w_pct
    local hp = box.h_pct > 1 and box.h_pct / 100 or box.h_pct
    return floor(wp * widgetW), floor(hp * widgetH)
  elseif box.w and box.h then
    return tonumber(box.w) or boxWidth, tonumber(box.h) or boxHeight
  elseif box.colspan or box.rowspan then
    local colspan = box.colspan or 1
    local rowspan = box.rowspan or 1
    return floor(colspan * boxWidth + (colspan - 1) * padding),
      floor(rowspan * boxHeight + (rowspan - 1) * padding)
  end
  return boxWidth, boxHeight
end

local function getBoxPosition(box, boxW, boxH, cellW, cellH, padding, widgetW, widgetH)
  if box.x_pct and box.y_pct then
    local xp = box.x_pct > 1 and box.x_pct / 100 or box.x_pct
    local yp = box.y_pct > 1 and box.y_pct / 100 or box.y_pct
    return floor(xp * widgetW), floor(yp * widgetH)
  elseif box.x and box.y then
    return tonumber(box.x) or 0, tonumber(box.y) or 0
  end
  local col = box.col or 1
  local row = box.row or 1
  local x = floor((col - 1) * (cellW + padding)) + (box.xOffset or 0)
  local y = floor(padding + (row - 1) * (cellH + padding))
  return x, y
end

local function buildBoxTypeList(boxes, headerBoxes)
  clearArray(typeScratch)
  for _, box in ipairs(boxes or {}) do
    if box.type then typeScratch[#typeScratch + 1] = box.type end
  end
  for _, box in ipairs(headerBoxes or {}) do
    if box.type then typeScratch[#typeScratch + 1] = box.type end
  end
  sort(typeScratch)
  return typeScratch
end

local function loadObjectType(objectType)
  if objectsByType[objectType] then return objectsByType[objectType] end
  local loader = loadfile("widgets/dashboard/objects/" .. objectType .. ".lua")
  if not loader then return nil end
  local ok, object = pcall(loader)
  if not ok then
    print("[dashboard] failed to load object " .. tostring(objectType) .. ": " .. tostring(object))
    return nil
  end
  objectsByType[objectType] = object
  return object
end

local function loadObjects(boxes, headerBoxes)
  local types = buildBoxTypeList(boxes, headerBoxes)
  for i = 1, #types do loadObjectType(types[i]) end
end

local function loadPreparedObjects()
  clearArray(typeScratch)
  for _, rect in ipairs(boxRects) do
    local box = rect.box
    if box and box.type then typeScratch[#typeScratch + 1] = box.type end
  end
  sort(typeScratch)
  for i = 1, #typeScratch do loadObjectType(typeScratch[i]) end
end

local function schedulerSettings(config)
  local scheduler = resolveMaybe((config or {}).scheduler)
  if type(scheduler) ~= "table" then return true, nil end
  local ratio = scheduler.spread_ratio
  if type(ratio) ~= "number" or ratio <= 0 or ratio > 1 then ratio = nil end
  return scheduler.spread_scheduling ~= false, ratio
end

local function defaultWakeRatio(count)
  if count < 0 then count = 0 end
  if count > 10 then count = 10 end
  return 1.0 - (count / 10) * 0.5
end

local function wakeupsPerCycle(count, ratio)
  if count <= 0 then return 0 end
  return max(1, ceil(count * (ratio or defaultWakeRatio(count))))
end

local function addBoxRect(rectCount, box, x, y, w, h, isHeader)
  rectCount = rectCount + 1
  local rect = boxRects[rectCount]
  if not rect then
    rect = {}
    boxRects[rectCount] = rect
  end
  rect.box = box
  rect.x = x
  rect.y = y
  rect.w = w
  rect.h = h
  rect.isHeader = isHeader == true
  return rectCount
end

local function buildRects(config, screenW, screenH)
  local layout = resolveMaybe(config.layout) or {}
  local headerLayout = resolveMaybe(config.header_layout) or {}
  local boxes = resolveMaybe(config.boxes or layout.boxes or {}) or {}
  local headerBoxes = resolveMaybe(config.header_boxes or {}) or {}

  local cols = layout.cols or 1
  local rows = layout.rows or 1
  local pad = layout.padding or 0
  local isFullScreen = context.widgets.dashboard.utils.isFullScreen(screenW, screenH)
  local headerH = isFullScreen and type(headerLayout.height) == "number" and headerLayout.height or 0
  local contentScreenH = screenH - headerH

  local w = adjustDimension(screenW, cols, cols - 1, pad)
  local h = adjustDimension(contentScreenH, rows, rows + 1, pad)
  local xOffset = floor((screenW - w) / 2)
  local contentW = w - ((cols - 1) * pad)
  local contentH = h - ((rows + 1) * pad)
  local cellW = contentW / cols
  local cellH = contentH / rows

  local rectCount = 0
  for _, box in ipairs(boxes) do
    local bw, bh = getBoxSize(box, cellW, cellH, pad, w, h)
    box.xOffset = xOffset
    local x, y = getBoxPosition(box, bw, bh, cellW, cellH, pad, w, h)
    if headerH > 0 then y = y + headerH end
    rectCount = addBoxRect(rectCount, box, x, y, bw, bh, false)
  end

  if isFullScreen and headerH > 0 and #headerBoxes > 0 then
    local hCols = headerLayout.cols or 1
    local hRows = headerLayout.rows or 1
    local hPad = headerLayout.padding or 0
    local hw = adjustDimension(screenW, hCols, hCols - 1, hPad)
    local hh = adjustDimension(headerH, hRows, hRows - 1, hPad)
    local hCellW = (hw - ((hCols - 1) * hPad)) / hCols
    local hCellH = (hh - ((hRows - 1) * hPad)) / hRows
    for _, box in ipairs(headerBoxes) do
      local bw, bh = getBoxSize(box, hCellW, hCellH, hPad, hw, hh)
      local x, y = getBoxPosition(box, bw, bh, hCellW, hCellH, hPad, hw, hh)
      rectCount = addBoxRect(rectCount, box, x, y, bw, bh, true)
    end
  end

  for i = rectCount + 1, #boxRects do boxRects[i] = nil end
  return boxes, headerBoxes
end

local function prepareLayout(config, screenW, screenH, skipObjectLoad)
  config = config or {}
  local sameLayout = preparedConfig == config and preparedW == screenW and preparedH == screenH
  if not sameLayout then
    local boxes, headerBoxes = buildRects(config, screenW, screenH)
    if not skipObjectLoad then
      loadObjects(boxes, headerBoxes)
      preparedObjectsLoaded = true
    else
      preparedObjectsLoaded = false
    end
    preparedConfig = config
    preparedW = screenW
    preparedH = screenH
    wakeCursor = 1
    wakePassCount = 0
    return
  end

  if not skipObjectLoad and not preparedObjectsLoaded then
    loadPreparedObjects()
    preparedObjectsLoaded = true
    wakeCursor = 1
    wakePassCount = 0
  end
end

local function wakeOne(rect)
  local box = rect and rect.box
  local object = box and box.type and loadObjectType(box.type)
  if object and object.wakeup then
    local ok, err = pcall(object.wakeup, box)
    if not ok then print("[dashboard] object wakeup failed: " .. tostring(err)) end
  end
end

local function finishWakePass()
  wakeCursor = 1
  wakePassCount = wakePassCount + 1
  return true
end

local function wakeObjects(maxCount, config)
  local count = #boxRects
  if count == 0 then return finishWakePass() end

  local spreadScheduling, spreadRatio = schedulerSettings(config)
  if wakePassCount < 1 or spreadScheduling == false then
    maxCount = nil
  elseif not maxCount or maxCount <= 0 then
    maxCount = wakeupsPerCycle(count, spreadRatio)
  end

  if not maxCount or maxCount <= 0 or maxCount >= count then
    for i = 1, count do wakeOne(boxRects[i]) end
    return finishWakePass()
  end

  local processed = 0
  while wakeCursor <= count and processed < maxCount do
    wakeOne(boxRects[wakeCursor])
    wakeCursor = wakeCursor + 1
    processed = processed + 1
  end

  if wakeCursor > count then
    return finishWakePass()
  end

  return false
end

local function drawBoxShell(rect)
  local box = rect and rect.box
  if not box then return end

  local utils = context.widgets.dashboard.utils
  local bgcolor = utils.resolveThemeColor("bgcolor", utils.getParam(box, "bgcolor"))
  if bgcolor ~= nil then utils.drawBoxBackground(rect.x, rect.y, rect.w, rect.h, bgcolor) end

  local title = utils.getParam(box, "title")
  if type(title) ~= "string" and type(title) ~= "number" then return end
  title = tostring(title)
  if title == "" then return end

  local titlefont = utils.resolveFont(utils.getParam(box, "titlefont"), FONT_XS)
  local titlepadding = utils.getParam(box, "titlepadding") or 0
  local titlepaddingleft = utils.getParam(box, "titlepaddingleft") or titlepadding
  local titlepaddingright = utils.getParam(box, "titlepaddingright") or titlepadding
  local titlepaddingtop = utils.getParam(box, "titlepaddingtop") or titlepadding
  local titlepaddingbottom = utils.getParam(box, "titlepaddingbottom") or titlepadding
  local titlepos = utils.getParam(box, "titlepos")
  local titlealign = utils.getParam(box, "titlealign")

  lcd.font(titlefont)
  local tw, th = lcd.getTextSize(title)
  tw = tw or 0
  th = th or 0

  local regionW = rect.w - titlepaddingleft - titlepaddingright
  local sx = rect.x + titlepaddingleft + (regionW - tw) / 2
  if titlealign == "left" then sx = rect.x + titlepaddingleft end
  if titlealign == "right" then sx = rect.x + titlepaddingleft + regionW - tw end
  local sy = titlepos == "bottom" and (rect.y + rect.h - titlepaddingbottom - th) or (rect.y + titlepaddingtop)

  lcd.color(utils.resolveThemeColor("titlecolor", utils.getParam(box, "titlecolor")))
  lcd.drawText(sx, sy, title)
end

local function paintShellObjects()
  for _, rect in ipairs(boxRects) do drawBoxShell(rect) end
end

local function paintObjects()
  for _, rect in ipairs(boxRects) do
    local box = rect.box
    local object = box and box.type and loadObjectType(box.type)
    if object and object.paint then
      local ok, err = pcall(object.paint, rect.x, rect.y, rect.w, rect.h, box)
      if not ok then print("[dashboard] object paint failed: " .. tostring(err)) end
    end
  end
end

function engine.paint(widget, themeDef, stateDef, state, screenW, screenH)
  context.setWidget(widget)
  if context.tasks and context.tasks.telemetry and context.tasks.telemetry.collectPresentationStats then
    context.tasks.telemetry.collectPresentationStats()
  end
  prepareLayout(stateDef, screenW, screenH)
  if wakePassCount < 1 then wakeObjects(nil, stateDef) end
  context.widgets.dashboard.utils.setBackgroundColourBasedOnTheme()
  paintObjects()
  context.widgets.dashboard.utils.drawScreenBorder()
end

function engine.paintShell(widget, stateDef, screenW, screenH)
  context.setWidget(widget)
  prepareLayout(stateDef, screenW, screenH, true)
  context.widgets.dashboard.utils.setBackgroundColourBasedOnTheme()
  paintShellObjects()
  context.widgets.dashboard.utils.drawScreenBorder()
end

function engine.preload(widget, stateDef)
  context.setWidget(widget)
  local layout = resolveMaybe((stateDef or {}).layout) or {}
  local boxes = resolveMaybe((stateDef or {}).boxes or layout.boxes or {}) or {}
  local headerBoxes = resolveMaybe((stateDef or {}).header_boxes or {}) or {}
  loadObjects(boxes, headerBoxes)
end

function engine.wakeup(widget, stateDef, screenW, screenH, options)
  context.setWidget(widget)
  prepareLayout(stateDef, screenW, screenH)
  return wakeObjects(options and options.maxObjects, stateDef), true
end

function engine.reset()
  preparedConfig = nil
  preparedW = nil
  preparedH = nil
  preparedObjectsLoaded = false
  wakeCursor = 1
  wakePassCount = 0
  for i = #boxRects, 1, -1 do boxRects[i] = nil end
end

return engine
