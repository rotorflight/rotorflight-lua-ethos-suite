-- display vars
local res = system.getVersion()
local LCD_W = res.lcdWidth
local LCD_H = res.lcdHeight

local graphPos = {}
graphPos['menu_offset'] = rfsuite.app.radio.logGraphMenuOffset
graphPos['height_offset'] = rfsuite.app.radio.logGraphHeightOffset or 0
graphPos['x_start'] = 0
graphPos['y_start'] = 0 + graphPos['menu_offset']
graphPos['width'] = math.floor(LCD_W * rfsuite.app.radio.logGraphWidthPercentage)
graphPos['height'] = LCD_H - graphPos['menu_offset'] - graphPos['menu_offset'] - 40 + graphPos['height_offset']
graphPos['slider_y'] = LCD_H - (graphPos['menu_offset'] + 30) + graphPos['height_offset']

local triggerOverRide = false
local triggerOverRideAll = false
local lastServoCountTime = os.clock()
local enableWakeup = false
local wakeupScheduler = os.clock()
local activeLogFile
local logPadding = 1
local armTime
local currentDisplayMode

local logDataRaw
local logDataRawReadComplete = false
local readNextChunk
local logData = {}
local maxMinData = {}
local progressLoader
local logLineCount

local logColumns = rfsuite.bg.logging.getLogTable()

local sliderPosition = 1
local sliderPositionOld = 1

local processedLogData = false
local currentDataIndex = 1

function format_time(seconds)
    -- Calculate minutes and remaining seconds
    local minutes = math.floor(seconds / 60)
    local seconds_remainder = seconds % 60

    -- Format the time string
    return string.format("%02d:%02d", minutes, seconds_remainder)
end

local function calculate_time_coverage(dates)

    if #dates == 0 then
        return "00:00" -- If the table is empty, return 00:00
    end

    local timestamps = {}

    -- Convert each date string to a timestamp
    for _, date in ipairs(dates) do
        local year, month, day, hour, min, sec = date:match("(%d+)-(%d+)-(%d+)_(%d+):(%d+):(%d+)")
        local timestamp = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec)})
        table.insert(timestamps, timestamp)
    end

    -- Find the minimum and maximum timestamps
    local min_time = math.min(table.unpack(timestamps))
    local max_time = math.max(table.unpack(timestamps))

    -- Calculate the time difference in seconds
    local time_diff = max_time - min_time

    -- Convert seconds to minutes and seconds
    local minutes = math.floor(time_diff / 60)
    local seconds = time_diff % 60

    -- Format as mm:ss
    return string.format("%02d:%02d", minutes, seconds)
end

function calculateSeconds(totalSeconds, sliderValue)
    -- Ensure sliderValue is within the range 1-100
    if sliderValue < 1 or sliderValue > 100 then error("Slider value must be between 1 and 100") end

    -- Calculate the seconds passed
    local secondsPassed = (sliderValue / 100) * totalSeconds
    return secondsPassed
end

function paginate_table(data, step_size, position)
    -- Validate inputs
    if type(data) ~= "table" or type(step_size) ~= "number" or type(position) ~= "number" then error("Invalid arguments: data must be a table, step_size and position must be numbers.") end

    -- Adjust position to be within valid bounds
    if position < 1 then
        position = 1
    elseif position > #data then
        position = #data
    end

    -- Calculate start and end indices
    local start_index = position
    local end_index = math.min(start_index + step_size - 1, #data)

    -- Create a new table for the page
    local page = {}
    for i = start_index, end_index do table.insert(page, data[i]) end

    return page
end

function padTable(tbl, padCount)
    -- Get the first and last values of the table
    local first = tbl[1]
    local last = tbl[#tbl]

    -- Create a new table for the padded result
    local paddedTable = {}

    -- Add the padding elements at the beginning
    for i = 1, padCount do table.insert(paddedTable, first) end

    -- Add the original table elements
    for _, value in ipairs(tbl) do table.insert(paddedTable, value) end

    -- Add the padding elements at the end
    for i = 1, padCount do table.insert(paddedTable, last) end

    return paddedTable
end

function loadFileToMemory(filename)
    local file, err = io.open(filename, "rb")
    if not file then return nil, "Error opening file: " .. err end

    local content = {}
    local chunk
    repeat
        chunk = file:read(1024) -- Read 1KB at a time
        if chunk then table.insert(content, chunk) end
    until not chunk

    file:close()
    return table.concat(content) -- Join all chunks into a single string
end

-- This function returns another function to read 10KB at a time
-- This function returns another function to read 10KB at a time
function createFileReader(filename)
    local file, err = io.open(filename, "rb")
    if not file then return nil, "Error opening file: " .. err end

    local file_pos = 0
    local content = ""

    -- Return the function to read the next chunk of 10KB
    return function()
        -- Seek to the current position in the file
        if rfsuite.config.ethosRunningVersion > 1600 then
            file:seek("set", file_pos)  -- Explicitly set the seek mode
        else
            file:seek(file_pos)
        end

        -- Read the next 10KB chunk
        local chunk = file:read(10 * 1024)

        if chunk then
            -- Append the chunk to the content
            content = content .. chunk
            file_pos = file_pos + #chunk -- Update the position in the file
        end

        -- Return the current content and whether the file has ended
        if not chunk then
            file:close()
            return content, true -- Finished reading the file
        else
            return content, false -- Continue reading
        end
    end
end

function map(x, in_min, in_max, out_min, out_max)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function calculate_optimal_records_per_page(total_records, range_min, range_max)
    -- Define the target range for records per page
    local min_records_per_page = range_min or 50
    local max_records_per_page = range_max or 100

    -- Initialize variables to track the best option
    local best_records_per_page
    local best_page_count_difference = math.huge -- Start with a large number

    -- Loop through the possible number of records per page within the range
    for records_per_page = min_records_per_page, max_records_per_page do
        -- Calculate the total pages needed for this number of records per page
        local total_pages = math.ceil(total_records / records_per_page)

        -- Calculate the difference in the number of pages compared to the mid-point
        local page_count_difference = math.abs(total_pages - (total_records / records_per_page))

        -- If this option is better (i.e., fewer steps or more balanced), update the best option
        if page_count_difference < best_page_count_difference then
            best_records_per_page = records_per_page
            best_page_count_difference = page_count_difference
            optimal_steps = total_pages -- Store the number of steps (pages)
        end
    end

    return best_records_per_page, optimal_steps
end

-- Efficient function to get a specific column from CSV
function getColumn(csvData, colIndex)
    local column = {}
    local start = 1
    local len = #csvData

    while start <= len do
        -- Find the position of the next newline
        local newlinePos = csvData:find("\n", start)
        if not newlinePos then
            newlinePos = len + 1 -- End of string
        end

        -- Extract row data
        local row = csvData:sub(start, newlinePos - 1)

        -- Extract the column by scanning through the row
        local colStart = 1
        local colEnd = 1
        local colCount = 0
        while true do
            colEnd = row:find(",", colStart)
            if not colEnd then colEnd = #row + 1 end

            colCount = colCount + 1
            if colCount == colIndex then
                table.insert(column, row:sub(colStart, colEnd - 1))
                break
            end

            colStart = colEnd + 1
            if colEnd == #row + 1 then break end
        end

        -- Move the start position to the next row
        start = newlinePos + 1
    end

    return column
end

local function cleanColumn(data)
    local out = {}
    for i, v in ipairs(data) do
        if i ~= 1 then -- skip the header
            out[i - 1] = tonumber(v)
        end
    end
    return out
end

local function trimHeader(data)
    local out = {}
    for i, v in ipairs(data) do
        if i ~= 1 then -- skip the header
            out[i - 1] = v
        end
    end
    return out
end

local function getLogDir()

    local logs_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and "logs/" or (rfsuite.config.suiteDir .. "/logs/")

    return logs_path .. "telemetry/"

end

function getValueAtPercentage(array, percentage)
    -- Ensure percentage is between 0 and 100
    if percentage < 0 or percentage > 100 then error("Percentage must be between 0 and 100") end

    -- Calculate the index based on the percentage
    local arraySize = #array
    if arraySize == 0 then error("Array cannot be empty") end

    -- Calculate the 1-based index
    local index = math.ceil((percentage / 100) * arraySize)
    return array[index]
end

local function extractShortTimestamp(filename)
    -- Match the date and time components in the filename, ignoring the prefix
    local date, time = filename:match(".-(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)")
    if date and time then
        -- Replace dashes with slashes or colons for a compact format
        return date:gsub("%-", "/") .. " " .. time:gsub("%-", ":")
    end
    return nil -- Return nil if the pattern doesn't match
end

local function drawGraph(points, color, pen, x_start, y_start, width, height, min_val, max_val)
    -- Sanity check: Ensure all points are numbers
    for i, v in ipairs(points) do if type(v) ~= "number" then error("Point at index " .. i .. " is not a number") end end

    -- Use provided min and max values, or calculate from points
    min_val = min_val or math.min(table.unpack(points))
    max_val = max_val or math.max(table.unpack(points))

    -- Handle edge case: If max_val equals min_val, avoid divide-by-zero error
    if max_val == min_val then
        max_val = max_val + 1
        min_val = min_val - 1
    end

    if color ~= nil then
        lcd.color(color)
    else
        lcd.color(COLOR_GREY)
    end
    if pen ~= nil then
        lcd.pen(pen)
    else
        lcd.pen(DOTTED)
    end

    -- Calculate scales to fit the graph within the display area
    local x_scale = width / (#points - 1) -- Width spread across the number of points
    local y_scale = height / (max_val - min_val) -- Height scaled to the value range

    -- Draw lines between consecutive points
    for i = 1, #points - 1 do
        -- Calculate coordinates for two consecutive points
        local x1 = x_start + (i - 1) * x_scale
        local y1 = y_start + height - (points[i] - min_val) * y_scale
        local x2 = x_start + i * x_scale
        local y2 = y_start + height - (points[i + 1] - min_val) * y_scale

        -- Draw the line
        lcd.drawLine(x1, y1, x2, y2)
    end
end

local function drawTime(armTime)
    if armTime == nil then return end

    local tw, th = lcd.getTextSize(armTime)
    lcd.color(COLOR_WHITE)

    local y = graphPos['height'] + graphPos['menu_offset'] - th
    local x = graphPos['width'] - tw - 10
    lcd.drawText(x, y, armTime, LEFT)
end

local function drawKey(name, keyindex, keyunit, keyminmax, keyfloor, color, minimum, maximum)

    local w = LCD_W - graphPos['width'] - 10
    local h = rfsuite.app.radio.logGraphKeyHeight
    local h_height = h / 2
    local x = graphPos['width']
    local y = (graphPos['y_start'] + (keyindex * h)) - h

    if keyfloor == true then
        minimum = math.floor(minimum)
        maximum = math.floor(maximum)
    end

    -- draw the header box
    lcd.pen(solid)
    lcd.drawFilledRectangle(x, y, w, h_height)

    -- put text into the box
    lcd.color(COLOR_BLACK)
    lcd.font(rfsuite.app.radio.logKeyFont)
    local tw, th = lcd.getTextSize(name)
    local ty = (h_height / 2 - th / 2) + y
    lcd.drawText(x + 5, ty, name, LEFT)

    -- show min and max values
    lcd.color(COLOR_WHITE)
    lcd.font(rfsuite.app.radio.logKeyFont)
    local mm_str
    if keyminmax == 1 then
        mm_str = "Min: " .. minimum .. keyunit .. " " .. "Max: " .. maximum .. keyunit
    else
        mm_str = "Max: " .. maximum .. keyunit
    end
    local tw, th = lcd.getTextSize(mm_str)
    local ty = (h_height / 2 - th / 2) + y + h_height
    lcd.drawText(x + 5, ty, mm_str, LEFT)

end

local function drawCurrentIndex(points, position, totalPoints, keyindex, keyunit, keyfloor, name, color)

    if position < 1 then position = 1 end

    local w = graphPos['width']
    local h = 35
    local h_height = 30
    local x = 0
    local y = (keyindex * h) - h_height / 2
    local idx_w = 100

    local linePos = map(position, 1, 100, 1, w - 10)

    if linePos < 1 then linePos = 0 end

    -- which side of line we display the index
    local idxPos
    local textAlign
    if (position > 50) then
        idxPos = linePos - 15
        textAlign = RIGHT
    else
        idxPos = linePos + 5
        textAlign = LEFT
    end

    local current_s = calculateSeconds(totalPoints, position)
    local time_str = format_time(math.floor(current_s))

    -- work out the current values based on position
    local value = getValueAtPercentage(points, position)
    if keyfloor == true then value = math.floor(value) end
    value = value .. keyunit

    -- draw the vertical line
    lcd.color(COLOR_WHITE)
    lcd.drawLine(linePos, graphPos['menu_offset'] - 5, linePos, graphPos['height'] + graphPos['menu_offset'])

    -- show value
    lcd.font(FONT_BOLD)
    local tw, th = lcd.getTextSize(value)
    lcd.color(color)
    -- local ty = (h_height / 2 - th / 2) + y + (h_height*2)    
    local ty = (graphPos['menu_offset'] + (th * keyindex)) - keyindex
    lcd.drawText(idxPos + 5, ty, value, textAlign)

    -- display time
    local tw, th = lcd.getTextSize(time_str)
    local ty = (LCD_H - 70)
    if linePos >= tw / 4 then lcd.drawText(idxPos, ty, time_str, textAlign) end

end

function findMaxNumber(numbers)
    local max = numbers[1] -- Assume the first number is the largest initially
    for i = 2, #numbers do -- Iterate through the table starting from the second element
        if numbers[i] > max then max = numbers[i] end
    end
    return max
end

function addMaxMinToTable(tbl, value_start, value_end)
    -- Insert the value at the beginning
    table.insert(tbl, 1, value_start)
    -- Insert the value at the end
    table.insert(tbl, value_end)
end

function findMinNumber(numbers)
    local min = numbers[1] -- Assume the first number is the smallest initially
    for i = 2, #numbers do -- Iterate through the table starting from the second element
        if numbers[i] < min then min = numbers[i] end
    end
    return min
end

function findAverage(numbers)
    local sum = 0
    for i = 1, #numbers do -- Iterate through the table
        sum = sum + numbers[i]
    end
    local average = sum / #numbers -- Divide the sum by the number of elements
    return average
end

local function openPage(pidx, title, script, logfile, displaymode)

    currentDisplayMode = displaymode

    rfsuite.bg.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    local w, h = rfsuite.utils.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding
    local sc
    local panel

    rfsuite.app.ui.fieldHeader("Logs - " .. extractShortTimestamp(logfile))
    activeLogFile = logfile

    -- initialise the log file reader
    -- this is a bit complex as it reads in chunks on each Loop
    -- to help with loading large files.
    readNextChunk = createFileReader(getLogDir() .. "/" .. logfile)

    rfsuite.app.ui.progressDisplayClose()

    enableWakeup = true
    return
end

local function event(event, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.Page.onNavMenu(self)
        return true
    end
    --[[
    if value == KEY_ROTARY_RIGHT then
        print("here")
        sliderPosition = sliderPosition + 1
        return false
    end

    if value == KEY_ROTARY_LEFT then
        sliderPosition = sliderPosition - 1
        return false   
    end    
    ]] --

    return false
end

local function wakeup()
    if not enableWakeup then
        return -- Exit early if wakeup is disabled
    end

    if sliderPosition ~= sliderPositionOld then
        lcd.invalidate()
        sliderPositionOld = sliderPosition
    end

    if not logDataRawReadComplete then
        -- Read chunks of the file until complete
        logDataRaw, logDataRawReadComplete = readNextChunk()
        return
    end

    if not processedLogData then

        -- Show progress dialog if starting
        if currentDataIndex == 1 then
            progressLoader = form.openProgressDialog("Processing", "Please be patient - we have some work to do.")
            progressLoader:closeAllowed(false)

            armTime = calculate_time_coverage(trimHeader(getColumn(logDataRaw, currentDataIndex)))
        else
            -- Update progress dialog
            local percentage = (currentDataIndex / #logColumns) * 100
            progressLoader:value(percentage)
        end

        -- Process the column and store the cleaned data

        logData[currentDataIndex] = {}
        logData[currentDataIndex]['data'] = padTable(cleanColumn(getColumn(logDataRaw, currentDataIndex + 1)), logPadding) -- Note. We + 1 the currentDataIndex because  rfsuite.bg.logging.getLogTable does not return the 1st column        
        logData[currentDataIndex]['name'] = logColumns[currentDataIndex].name
        logData[currentDataIndex]['color'] = logColumns[currentDataIndex].color
        logData[currentDataIndex]['pen'] = logColumns[currentDataIndex].pen
        logData[currentDataIndex]['keyindex'] = logColumns[currentDataIndex].keyindex
        logData[currentDataIndex]['keyname'] = logColumns[currentDataIndex].keyname
        logData[currentDataIndex]['keyunit'] = logColumns[currentDataIndex].keyunit
        logData[currentDataIndex]['keyminmax'] = logColumns[currentDataIndex].keyminmax
        logData[currentDataIndex]['keyfloor'] = logColumns[currentDataIndex].keyfloor
        logData[currentDataIndex]['graph'] = logColumns[currentDataIndex].graph
        logData[currentDataIndex]['maximum'] = findMaxNumber(logData[currentDataIndex]['data'])
        logData[currentDataIndex]['minimum'] = findMinNumber(logData[currentDataIndex]['data'])
        logData[currentDataIndex]['average'] = findAverage(logData[currentDataIndex]['data'])

        -- Close progress loader when all columns are processed
        if currentDataIndex >= #logColumns then

            -- put slider at bottom of form
            local posField = {x = graphPos['x_start'], y = graphPos['slider_y'], w = graphPos['width'] - 10, h = 40}
            rfsuite.app.formFields[1] = form.addSliderField(nil, posField, 0, 100, function()
                return sliderPosition
            end, function(newValue)
                sliderPosition = newValue
            end)

            -- set log line count only once!
            logLineCount = #logData[currentDataIndex]['data']

            progressLoader:close()
            processedLogData = true
        end

        currentDataIndex = currentDataIndex + 1

        return
    end

    -- Logic for paging and navigation can go here when data processing is complete
end

local function paint()

    local menu_offset = graphPos['menu_offset']
    local x_start = graphPos['x_start']
    local y_start = graphPos['y_start']
    local width = graphPos['width'] - 10
    local height = graphPos['height']

    drawTime(armTime)

    if enableWakeup == true and processedLogData == true then

        if logData ~= nil then
            local optimal_records_per_page, optimal_steps = calculate_optimal_records_per_page(logLineCount, 40, 80)

            local step_size = optimal_records_per_page

            local position = math.floor(map(sliderPosition, 1, 100, 1, logLineCount - step_size))
            if position < 1 then position = 1 end

            for i, v in ipairs(logData) do

                if logData[i].graph == true then
                    local points = paginate_table(logData[i].data, step_size, position)
                    local color = logData[i].color
                    local pen = logData[i].pen
                    local name = logData[i].name
                    local minimum = logData[i].minimum
                    local maximum = logData[i].maximum
                    local average = logData[i].average
                    local keyindex = logData[i].keyindex
                    local keyname = logData[i].keyname
                    local keyunit = logData[i].keyunit
                    local keyminmax = logData[i].keyminmax
                    local keyfloor = logData[i].keyfloor
                    drawGraph(points, color, pen, x_start, y_start, width, height, minimum, maximum)
                    drawKey(keyname, keyindex, keyunit, keyminmax, keyfloor, color, minimum, maximum)
                    drawCurrentIndex(points, sliderPosition, logLineCount + logPadding, keyindex, keyunit, keyfloor, name, color)

                end

            end

        end
    end

end

local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()

    if currentDisplayMode == 1 then
        rfsuite.app.ui.openPage(1, rfsuite.app.lastTitle, "logs/logs.lua", 1)
    else
        rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "logs/logs.lua")
    end

end

return {
    title = "Logs",
    event = event,
    openPage = openPage,
    wakeup = wakeup,
    paint = paint,
    onNavMenu = onNavMenu,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = false,
        help = true
    },
    API = {},
}
