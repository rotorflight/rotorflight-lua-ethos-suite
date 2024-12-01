


local triggerOverRide = false
local triggerOverRideAll = false
local lastServoCountTime = os.clock()
local enableWakeup = false
local wakeupScheduler = os.clock()
local activeLogFile 

local logDataRaw
local logDataRawReadComplete = false
local readNextChunk 
local logData = {}
local maxMinData = {}
local progressLoader

local logColumns = {
    'timestamp',
    'voltage',
    'current',
    'rpm',
    'capacity',
    'governor',
    'tempESC',
    'rssi',
    'roll',
    'pitch',
    'yaw',
    'collective'
}
local logColours = {
    COLOR_BLACK,
    COLOR_GREEN,
    COLOR_BLUE,
    COLOR_CYAN,
    COLOR_MAGENTO,
    COLOR_WHITE,
    COLOR_YELLOW,
    COLOR_ORANGE,
    COLOR_WHITE,
    COLOR_GREEN,
    COLOR_BLUE,
    COLOR_ORANGE
}

local logColumnsCount = 12
local processedLogData = false
local currentDataIndex = 0
      
local LCD_W, LCD_H = rfsuite.utils.getWindowSize()

function paginate_table(data, step_size, position)

    -- Validate inputs
    if type(data) ~= "table" or type(step_size) ~= "number" or type(position) ~= "number" then
        error("Invalid arguments: data must be a table, step_size and position must be numbers.")
    end

    -- Calculate start and end indices
    local start_index = (position - 1) * step_size + 1
    local end_index = math.min(position * step_size, #data)

    -- Create a new table for the page
    local page = {}
    for i = start_index, end_index do
        table.insert(page, data[i])
    end

    return page
end

function loadFileToMemory(filename)
    local file, err = io.open(filename, "rb")
    if not file then
        return nil, "Error opening file: " .. err
    end

    local content = {}
    local chunk
    repeat
        chunk = file:read(1024)  -- Read 1KB at a time
        if chunk then
            table.insert(content, chunk)
        end
    until not chunk

    file:close()
    return table.concat(content)  -- Join all chunks into a single string
end

-- This function returns another function to read 10KB at a time
-- This function returns another function to read 10KB at a time
function createFileReader(filename)
    local file, err = io.open(filename, "rb")
    if not file then
        return nil, "Error opening file: " .. err
    end
    
    local file_pos = 0
    local content = ""

    -- Return the function to read the next chunk of 10KB
    return function()
        -- Seek to the current position in the file
        file:seek(file_pos)  -- This should work correctly now

        -- Read the next 10KB chunk
        local chunk = file:read(10 * 1024)
        
        if chunk then
            -- Append the chunk to the content
            content = content .. chunk
            file_pos = file_pos + #chunk  -- Update the position in the file
        end
        
        -- Return the current content and whether the file has ended
        if not chunk then
            file:close()
            return content, true  -- Finished reading the file
        else
            return content, false  -- Continue reading
        end
    end
end


function calculate_optimal_records_per_page(total_records,range_min,range_max)
    -- Define the target range for records per page
    local min_records_per_page = range_min or 50
    local max_records_per_page = range_max or 100
    
    -- Initialize variables to track the best option
    local best_records_per_page
    local best_page_count_difference = math.huge  -- Start with a large number
    
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
            optimal_steps = total_pages  -- Store the number of steps (pages)
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
            newlinePos = len + 1  -- End of string
        end

        -- Extract row data
        local row = csvData:sub(start, newlinePos - 1)
        
        -- Extract the column by scanning through the row
        local colStart = 1
        local colEnd = 1
        local colCount = 0
        while true do
            colEnd = row:find(",", colStart)
            if not colEnd then
                colEnd = #row + 1
            end
            
            colCount = colCount + 1
            if colCount == colIndex then
                table.insert(column, row:sub(colStart, colEnd - 1))
                break
            end

            colStart = colEnd + 1
            if colEnd == #row + 1 then
                break
            end
        end

        -- Move the start position to the next row
        start = newlinePos + 1
    end
    
    
    return column
end

local function cleanColumn(data)
    local out = {}
    for i,v in ipairs(data) do
        if i ~= 1 then  -- skip the header
                out[i-1] = tonumber(v)
        end
    end
    return out
end

local function getLogDir()
    local logdir
    logdir = string.gsub(model.name(), "%s+", "_")
    logdir = string.gsub(logdir, "%W", "_")
    
    local logs_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and "logs/" or (config.suiteDir .. "/logs/")
    
    return logs_path .. logdir
    
end


local function extractShortTimestamp(filename)
    -- Match the date and time components in the filename
    local date, time = filename:match("^(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)")
    if date and time then
        return date:gsub("%-", "/") .. " " .. time:gsub("%-", ":")
    end
    return nil
end



function drawGraph(points, color, x_start, y_start, width, height)
    -- Sanity check: Ensure all points are numbers
    for i, v in ipairs(points) do
        if type(v) ~= "number" then
            error("Point at index " .. i .. " is not a number")
        end
    end

    lcd.color(color)

    -- Calculate min and max values from the points
    local min_val = math.min(table.unpack(points))
    local max_val = math.max(table.unpack(points))
    
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



local function openPage(pidx, title, script,logfile)

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

    readNextChunk = createFileReader(getLogDir() .. "/" .. logfile)
    
    rfsuite.app.ui.progressDisplayClose()

    enableWakeup = true
    return
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.Page.onNavMenu(self)
        return true
    end

    return false
end

local function wakeup()
    if enableWakeup == true then

        --local now = os.clock()
        --if (now - wakeupScheduler) >= 0.5 then
        --    lcd.invalidate()
        --end   

        if logDataRawReadComplete == false then
            logDataRaw, logDataRawReadComplete =  readNextChunk()
        else
             if processedLogData == false then             
                currentDataIndex = currentDataIndex + 1
                
                if currentDataIndex == 1 then
                    progressLoader = form.openProgressDialog("Processing", "Please be patient - we have some work to do.")
                    progressLoader:closeAllowed(false)
                else      
                    local percentage = (currentDataIndex / (logColumnsCount+1)) * 100
                    progressLoader:value(percentage)
                end

                logData[logColumns[currentDataIndex]] = cleanColumn(getColumn(logDataRaw, currentDataIndex))

                if currentDataIndex >= logColumnsCount then      

                    progressLoader:close()
                    processedLogData = true
                end   

            end       
            
        end   
        
    
        
    end
end

local function paint()
    -- the graphs get drawn using the paint function
    --curve_data(5 + 1, widget.x_zoom, curves_y[1], widget.cursor_x_pointer, widget.cursor_x_max, COLOR_GREEN)
    
    if enableWakeup == true and processedLogData == true then

        if logData ~= nil then
        
            local menu_offset = 100
            local x_start = 0
            local y_start = 0 + menu_offset
            local width = LCD_W
            local height = LCD_H - menu_offset
            
            local optimal_records_per_page, optimal_steps = calculate_optimal_records_per_page(#logData['voltage'],40,80)
            
            local step_size = optimal_records_per_page
            local position = 1

            print ("Number of steps to page through: " .. optimal_steps)

            --voltage
            local points = paginate_table(logData['voltage'],step_size,position)  
            local color = COLOR_RED           
            drawGraph(points, color, x_start, y_start, width, height)

            --current
            local points = paginate_table(logData['current'],step_size,position)
            local color = COLOR_GREEN           
            drawGraph(points, color, x_start, y_start, width, height)

            --voltage
            local points = paginate_table(logData['rpm'],step_size,position)
            local color = COLOR_YELLOW           
            drawGraph(points, color, x_start, y_start, width, height)        

            --rssi
            local points = paginate_table(logData['rssi'],step_size,position)
            local color = COLOR_BLUE           
            drawGraph(points, color, x_start, y_start, width, height)                    

            --rssi
            local points = paginate_table(logData['tempESC'],step_size,position)
            local color = COLOR_CYAN           
            drawGraph(points, color, x_start, y_start, width, height)    

        
        end



    end
    
end
local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "logs.lua")

end


return {
    title = "Logs",
    event = event,
    openPage = openPage,
    wakeup = wakeup,
    paint = paint,
    onNavMenu = onNavMenu,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = true}
}
