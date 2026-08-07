-- System -> Logs browser/viewer.

local closeKey = assert(loadfile("app/close_key.lua"))()
local header = assert(loadfile("app/header.lua"))()
local ini = assert(loadfile("lib/ini.lua"))()
local tileGrid = assert(loadfile("app/tile_grid.lua"))()

local PAGE_TITLE = "@i18n(app.modules.logs.name)@"
local BASE_DIR = "LOGS:/rfsuite/telemetry"
local LOG_PADDING = 5
local LOG_CHUNK_SIZE = 1000
local SAMPLE_RATE = 1

local folderIcon = lcd.loadMask("app/gfx/logs_folder.png")
local logIcon = lcd.loadMask("app/gfx/logs.png")
local orange = COLOR_ORANGE or lcd.RGB(220, 100, 0)
local cyan = COLOR_CYAN or lcd.RGB(0, 180, 220)
local yellow = COLOR_YELLOW or lcd.RGB(180, 160, 0)

local LOG_COLUMNS = {
  {name = "voltage", keyindex = 1, keyname = "Voltage", keyunit = "v", keyminmax = 1, color = COLOR_RED, pen = SOLID, graph = true},
  {name = "current", keyindex = 2, keyname = "Current", keyunit = "A", keyminmax = 1, color = orange, pen = SOLID, graph = true},
  {name = "rpm", keyindex = 3, keyname = "Headspeed", keyunit = "rpm", keyminmax = 1, keyfloor = true, color = COLOR_GREEN, pen = SOLID, graph = true},
  {name = "temp_esc", keyindex = 4, keyname = "Esc. Temperature", keyunit = "deg", keyminmax = 1, color = cyan, pen = SOLID, graph = true},
  {name = "throttle_percent", keyindex = 5, keyname = "Throttle %", keyunit = "%", keyminmax = 1, color = yellow, pen = SOLID, graph = true},
}

local zoomLevelToDecimation = {[1] = 5, [2] = 4, [3] = 2, [4] = 1, [5] = 1}
local zoomLevelToTime = {[1] = 600, [2] = 300, [3] = 120, [4] = 60, [5] = 30}
local SMALL_LEFT = LEFT + FONT_S

local function safeMkdir(path)
  if os and os.mkdir then pcall(os.mkdir, path) end
end

local function ensureBaseDir()
  safeMkdir("LOGS:")
  safeMkdir("LOGS:/rfsuite")
  safeMkdir(BASE_DIR)
end

local function listFiles(path)
  if not system or not system.listFiles then return {} end
  local ok, files = pcall(system.listFiles, path)
  if ok and type(files) == "table" then return files end
  return {}
end

local function readModelName(folder)
  local data = ini.load_ini_file(BASE_DIR .. "/" .. folder .. "/logs.ini") or {}
  local modelSection = data.model or {}
  local name = modelSection.name
  if name then
    name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
    if name ~= "" then return name end
  end
  return folder
end

local function isDirName(name)
  if not name or name == "." or name == ".." then return false end
  if name:match("%.%w+$") then return false end
  return true
end

local function listFolders()
  ensureBaseDir()
  local folders = {}
  local files = listFiles(BASE_DIR)
  for i = 1, #files do
    local name = files[i]
    if isDirName(name) then
      folders[#folders + 1] = {folder = name, title = readModelName(name)}
    end
  end
  table.sort(folders, function(a, b) return a.title < b.title end)
  return folders
end

local function listLogs(folder)
  local logs = {}
  local files = listFiles(BASE_DIR .. "/" .. folder)
  for i = 1, #files do
    local name = files[i]
    if name and name:match("%.csv$") then
      local date, time = name:match("(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)")
      logs[#logs + 1] = {
        file = name,
        title = time and time:gsub("%-", ":") or name,
        group = date,
        sortKey = (date or "") .. "_" .. (time or "") .. "_" .. name,
      }
    end
  end
  table.sort(logs, function(a, b) return a.sortKey > b.sortKey end)
  return logs
end

local function logPath(folder, file)
  return BASE_DIR .. "/" .. folder .. "/" .. file
end

local function dateTitle(date)
  local y, m, d = tostring(date or ""):match("^(%d+)%-(%d+)%-(%d+)$")
  if not y then return tostring(date or "") end
  return string.format("%s/%s/%s", d, m, y)
end

local function extractShortTimestamp(filename)
  local date, time = tostring(filename or ""):match(".-(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)")
  if date and time then return date:gsub("%-", "/") .. " " .. time:gsub("%-", ":") end
  return filename or ""
end

local function addCenteredMessage(text)
  local w, h = lcd.getWindowSize()
  local tw, th = lcd.getTextSize(text)
  local y = math.floor((h + form.height() - th) / 2)
  form.addStaticText(nil, {x = math.floor((w - tw) / 2), y = y, w = tw, h = th + 4}, text)
end

local function map(x, inMin, inMax, outMin, outMax)
  return (x - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end

local function secondsToSamples(sec)
  return math.floor(sec * SAMPLE_RATE)
end

local function formatTime(seconds)
  return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function getColumn(csvData, colIndex)
  local column = {}
  local start = 1
  local len = #csvData
  while start <= len do
    local newlinePos = csvData:find("\n", start) or (len + 1)
    local row = csvData:sub(start, newlinePos - 1)
    local colStart = 1
    local colCount = 0
    while true do
      local colEnd = row:find(",", colStart) or (#row + 1)
      colCount = colCount + 1
      if colCount == colIndex then
        column[#column + 1] = row:sub(colStart, colEnd - 1)
        break
      end
      colStart = colEnd + 1
      if colEnd == #row + 1 then break end
    end
    start = newlinePos + 1
  end
  return column
end

local function cleanColumn(data)
  local out = {}
  for i = 2, #data do out[i - 1] = tonumber(data[i]) or 0 end
  return out
end

local function padTable(tbl, padCount)
  local first = tbl[1] or 0
  local last = tbl[#tbl] or first
  local padded = {}
  for i = 1, padCount do padded[#padded + 1] = first end
  for i = 1, #tbl do padded[#padded + 1] = tbl[i] end
  for i = 1, padCount do padded[#padded + 1] = last end
  return padded
end

local function paginateTable(data, stepSize, position, decimationFactor)
  local page = {}
  local startIndex = math.max(1, position)
  local endIndex = math.min(startIndex + stepSize - 1, #data)
  for i = startIndex, endIndex, decimationFactor or 1 do page[#page + 1] = data[i] end
  return page
end

local function minMaxAvg(numbers)
  local minValue = numbers[1] or 0
  local maxValue = minValue
  local sum = 0
  for i = 1, #numbers do
    local value = numbers[i] or 0
    if value < minValue then minValue = value end
    if value > maxValue then maxValue = value end
    sum = sum + value
  end
  return minValue, maxValue, (#numbers > 0 and (sum / #numbers) or 0)
end

local function calculateZoomSteps(logLineCount)
  local duration = logLineCount / SAMPLE_RATE
  for level = 5, 1, -1 do
    local desiredTime = zoomLevelToTime[level]
    if duration >= desiredTime * 1.5 then return level end
  end
  return 1
end

local function getValueAtPercentage(array, percentage)
  if #array == 0 then return 0 end
  local index = math.ceil((percentage / 100) * #array)
  if index < 1 then index = 1 end
  if index > #array then index = #array end
  return array[index] or 0
end

local function drawGraph(points, color, pen, x, y, w, h, minValue, maxValue)
  if #points < 2 then return end
  local padding = math.max(5, math.floor(h * 0.1))
  y = y + (padding / 2)
  h = h - padding
  if maxValue == minValue then
    maxValue = maxValue + 1
    minValue = minValue - 1
  end
  lcd.color(color or COLOR_GREY)
  lcd.pen(pen or SOLID)
  local xScale = w / (#points - 1)
  local yScale = h / (maxValue - minValue)
  for i = 1, #points - 1 do
    local x1 = x + (i - 1) * xScale
    local y1 = y + h - (points[i] - minValue) * yScale
    local x2 = x + i * xScale
    local y2 = y + h - (points[i + 1] - minValue) * yScale
    lcd.drawLine(x1, y1, x2, y2)
  end
end

local function drawKey(meta, minimum, maximum, x, y, w)
  local titleH = 18
  lcd.color(meta.color or COLOR_GREY)
  lcd.drawFilledRectangle(x, y, w, titleH)
  lcd.color(COLOR_BLACK)
  lcd.drawText(x + 5, y + 2, meta.keyname or meta.name, SMALL_LEFT)
  lcd.color(COLOR_WHITE)
  if meta.keyfloor then
    minimum = math.floor(minimum)
    maximum = math.floor(maximum)
  end
  lcd.drawText(x + 5, y + 21, tostring(minimum) .. (meta.keyunit or ""), SMALL_LEFT)
  local maxText = tostring(maximum) .. (meta.keyunit or "")
  local tw = ({lcd.getTextSize(maxText)})[1]
  lcd.drawText(x + w - tw - 4, y + 21, maxText, SMALL_LEFT)
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local selectedFolder = nil
  local selectedTitle = nil
  local selectedFile = nil
  local mode = "folders"
  local headerHandle = nil
  local wakeupHandler = nil
  local paintHandler = nil
  local fileHandle = nil
  local rawChunks = {}
  local rawData = nil
  local readOffset = 0
  local readComplete = false
  local processed = false
  local processIndex = 1
  local logData = {}
  local logLineCount = 0
  local sliderPosition = 1
  local sliderOld = 1
  local zoomLevel = 1
  local zoomCount = 1
  local graph = {}
  local graphPos = nil
  local progress = nil

  local function closeProgress()
    if progress then
      pcall(function() progress:close() end)
      progress = nil
    end
  end

  local function closeFile()
    if fileHandle then
      pcall(function() fileHandle:close() end)
      fileHandle = nil
    end
  end

  local function clearViewState()
    closeProgress()
    closeFile()
    rawChunks = {}
    rawData = nil
    readOffset = 0
    readComplete = false
    processed = false
    processIndex = 1
    logData = {}
    logLineCount = 0
    graph = {}
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
  end

  local function cleanup()
    disposed = true
    clearViewState()
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
  end

  local renderFolders, renderLogs, renderView

  local function buildHeader(title)
    headerHandle = header.build(title, {
      onBack = function()
        if mode == "view" then
          renderLogs()
        elseif mode == "logs" then
          renderFolders()
        else
          cleanup()
          if opts.onBack then opts.onBack() end
        end
      end,
      onReload = function()
        if mode == "view" and selectedFile then
          renderView(selectedFile)
        elseif mode == "logs" then
          renderLogs()
        elseif mode == "folders" then
          renderFolders()
        end
      end,
    })
    return headerHandle
  end

  local function addTileGrid(entries, icon, press)
    local windowWidth, windowHeight = lcd.getWindowSize()
    local numPerRow, tileW, tileH, tilePadding, tileFont = tileGrid.metrics(windowWidth, windowHeight)
    local x, y = 0, form.height() + tilePadding
    local col = 0
    local lastGroup = nil
    local firstButton = nil
    for i = 1, #entries do
      local entry = entries[i]
      if entry.group and entry.group ~= lastGroup then
        lastGroup = entry.group
        form.addLine(dateTitle(lastGroup))
        x = 0
        y = form.height() + tilePadding
        col = 0
      end
      local button = form.addButton(nil, {x = x, y = y, w = tileW, h = tileH}, {
        text = entry.title,
        icon = icon,
        options = tileFont,
        press = function() press(entry) end,
      })
      if not firstButton then firstButton = button end
      col = col + 1
      if col >= numPerRow then
        col = 0
        x = 0
        y = y + tileH + tilePadding
      else
        x = x + tileW + tilePadding
      end
    end
    if firstButton then firstButton:focus() end
  end

  renderFolders = function()
    if disposed then return end
    clearViewState()
    mode = "folders"
    selectedFolder = nil
    selectedTitle = nil
    selectedFile = nil
    form.clear()
    local hh = buildHeader(PAGE_TITLE)
    local folders = listFolders()
    if #folders == 0 then
      addCenteredMessage("@i18n(app.modules.logs.msg_no_logs_found)@")
      hh.focusMenu()
      return
    end
    addTileGrid(folders, folderIcon, function(entry)
      selectedFolder = entry.folder
      selectedTitle = entry.title
      renderLogs()
    end)
  end

  renderLogs = function()
    if disposed or not selectedFolder then return end
    clearViewState()
    mode = "logs"
    selectedFile = nil
    form.clear()
    local hh = buildHeader(PAGE_TITLE .. " / " .. (selectedTitle or selectedFolder))
    local logs = listLogs(selectedFolder)
    if #logs == 0 then
      addCenteredMessage("@i18n(app.modules.logs.msg_no_logs_found)@")
      hh.focusMenu()
      return
    end
    addTileGrid(logs, logIcon, function(entry)
      renderView(entry.file)
    end)
  end

  local function updateZoomButtons(minusButton, plusButton)
    if zoomCount <= 1 then
      minusButton:enable(false)
      plusButton:enable(false)
    else
      minusButton:enable(zoomLevel > 1)
      plusButton:enable(zoomLevel < zoomCount)
    end
  end

  local function updatePaintCache()
    if not processed or not graphPos then return end
    local logDuration = math.floor(logLineCount / SAMPLE_RATE)
    local windowSec = math.min(zoomLevelToTime[zoomLevel] or zoomLevelToTime[1], logDuration)
    local stepSize = secondsToSamples(windowSec)
    local maxPosition = math.max(1, logLineCount - stepSize + 1)
    local position = math.floor(map(sliderPosition, 1, 100, 1, maxPosition))
    if position < 1 then position = 1 end
    local decimation = zoomLevelToDecimation[zoomLevel] or 1
    if zoomCount == 1 then decimation = 1 end

    graph.points = {}
    graph.count = 0
    for i = 1, #logData do
      local item = logData[i]
      if item.graph then
        graph.count = graph.count + 1
        graph.points[graph.count] = {
          points = paginateTable(item.data, stepSize, position, decimation),
          meta = item,
          minimum = item.minimum,
          maximum = item.maximum,
        }
      end
    end
    graph.laneHeight = graph.count > 0 and (graphPos.h / graph.count) or graphPos.h
  end

  local function readNextChunk()
    if readComplete or not fileHandle then return end
    fileHandle:seek("set", readOffset)
    local chunk = fileHandle:read(LOG_CHUNK_SIZE)
    if chunk then
      rawChunks[#rawChunks + 1] = chunk
      readOffset = readOffset + #chunk
    else
      closeFile()
      readComplete = true
      rawData = table.concat(rawChunks)
      rawChunks = {}
    end
  end

  local function processNextColumn(minusButton, plusButton)
    local meta = LOG_COLUMNS[processIndex]
    if not meta then
      logLineCount = logData[#logData] and #logData[#logData].data or 0
      zoomCount = calculateZoomSteps(logLineCount)
      if zoomLevel > zoomCount then zoomLevel = zoomCount end
      updateZoomButtons(minusButton, plusButton)
      processed = true
      closeProgress()
      updatePaintCache()
      lcd.invalidate()
      return
    end

    local cleaned = cleanColumn(getColumn(rawData or "", processIndex + 1))
    local padded = padTable(cleaned, LOG_PADDING)
    local minimum, maximum, average = minMaxAvg(padded)
    logData[processIndex] = {
      name = meta.name,
      keyindex = meta.keyindex,
      keyname = meta.keyname,
      keyunit = meta.keyunit,
      keyminmax = meta.keyminmax,
      keyfloor = meta.keyfloor,
      color = meta.color,
      pen = meta.pen,
      graph = meta.graph,
      data = padded,
      minimum = minimum,
      maximum = maximum,
      average = average,
    }
    if progress then progress:value(math.floor((processIndex / #LOG_COLUMNS) * 100)) end
    processIndex = processIndex + 1
  end

  renderView = function(fileName)
    if disposed or not selectedFolder then return end
    clearViewState()
    mode = "view"
    selectedFile = fileName
    form.clear()
    buildHeader((selectedTitle or selectedFolder) .. " / " .. extractShortTimestamp(fileName))

    local w, h = lcd.getWindowSize()
    local headerBottom = form.height()
    local sliderH = 38
    local bottomPad = 8
    local keyWidth = math.max(155, math.floor(w * 0.28))
    graphPos = {
      x = 0,
      y = headerBottom + 6,
      w = w - keyWidth - 10,
      h = h - headerBottom - sliderH - bottomPad - 14,
      keyX = w - keyWidth,
      keyW = keyWidth,
      sliderY = h - sliderH - bottomPad,
    }

    sliderPosition = 1
    sliderOld = 1
    zoomLevel = 1
    zoomCount = 1
    fileHandle = io.open(logPath(selectedFolder, fileName), "rb")
    if not fileHandle then
      addCenteredMessage("@i18n(app.modules.logs.msg_open_failed)@")
      return
    end

    local slider = form.addSliderField(nil, {x = graphPos.x, y = graphPos.sliderY, w = graphPos.w - 8, h = sliderH}, 1, 100, function()
      return sliderPosition
    end, function(value)
      sliderPosition = value
    end)
    slider:step(1)

    local buttonW = math.floor((graphPos.keyW - 14) / 2)
    local minusButton, plusButton
    minusButton = form.addButton(nil, {x = graphPos.keyX, y = graphPos.sliderY, w = buttonW, h = sliderH}, {
      text = "-",
      options = FONT_S + CENTERED,
      press = function()
        if zoomLevel > 1 then
          zoomLevel = zoomLevel - 1
          updatePaintCache()
          updateZoomButtons(minusButton, plusButton)
          lcd.invalidate()
        end
      end,
    })
    plusButton = form.addButton(nil, {x = graphPos.keyX + buttonW + 10, y = graphPos.sliderY, w = buttonW, h = sliderH}, {
      text = "+",
      options = FONT_S + CENTERED,
      press = function()
        if zoomLevel < zoomCount then
          zoomLevel = zoomLevel + 1
          updatePaintCache()
          updateZoomButtons(minusButton, plusButton)
          lcd.invalidate()
        end
      end,
    })
    updateZoomButtons(minusButton, plusButton)

    progress = form.openProgressDialog({
      title = "@i18n(app.modules.logs.name)@",
      message = "@i18n(app.modules.logs.loading)@",
      close = function() end,
      wakeup = function() end,
    })
    if progress then
      progress:value(0)
      progress:closeAllowed(false)
    end

    wakeupHandler = function()
      if fileHandle and not readComplete then
        readNextChunk()
        if progress then progress:value(math.min(80, math.floor(readOffset / LOG_CHUNK_SIZE))) end
        return
      end
      if readComplete and not processed then
        processNextColumn(minusButton, plusButton)
        return
      end
      if processed and sliderPosition ~= sliderOld then
        sliderOld = sliderPosition
        updatePaintCache()
        lcd.invalidate()
      end
    end

    paintHandler = function()
      if not processed or not graphPos or not graph.points or not graph.laneHeight then return end
      for lane = 1, #graph.points do
        local laneData = graph.points[lane]
        local laneY = graphPos.y + (lane - 1) * graph.laneHeight
        drawGraph(laneData.points, laneData.meta.color, laneData.meta.pen, graphPos.x, laneY, graphPos.w, graph.laneHeight, laneData.minimum, laneData.maximum)
        drawKey(laneData.meta, laneData.minimum, laneData.maximum, graphPos.keyX, laneY, graphPos.keyW)
        local linePos = map(sliderPosition, 1, 100, graphPos.x + 1, graphPos.x + graphPos.w - 10)
        if lane == 1 then
          lcd.color(COLOR_WHITE)
          lcd.drawLine(linePos, graphPos.y, linePos, graphPos.y + graphPos.h)
          local currentSeconds = math.floor(map(sliderPosition, 1, 100, 0, math.max(0, logLineCount - LOG_PADDING)))
          lcd.drawText(linePos + 4, graphPos.y + graphPos.h - 18, formatTime(currentSeconds), SMALL_LEFT)
        end
        local value = getValueAtPercentage(laneData.points, sliderPosition)
        if laneData.meta.keyfloor then value = math.floor(value) end
        lcd.color(laneData.meta.color or COLOR_WHITE)
        lcd.drawText(graphPos.keyX + 5, laneY + 39, tostring(value) .. (laneData.meta.keyunit or ""), SMALL_LEFT)
      end
    end

    if opts.setWakeupHandler then opts.setWakeupHandler(wakeupHandler) end
    if opts.setPaintHandler then opts.setPaintHandler(paintHandler) end
  end

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        if mode == "view" then
          renderLogs()
          return true
        elseif mode == "logs" then
          renderFolders()
          return true
        end
        cleanup()
        if opts.onBack then opts.onBack() end
        return true
      end
      return false
    end)
  end

  if opts.setCleanupHandler then opts.setCleanupHandler(cleanup) end
  renderFolders()
end

return {open = open}
