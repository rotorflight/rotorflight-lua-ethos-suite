--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local utils = {}

local arg = {...}
local config = arg[1]


function utils.logRotorFlightBanner()
    local version = rfsuite.config.Version or "Unknown Version"

    local banner = {
        "===============================================",
        "    ROTORFLIGHT RFSUITE - Version: " .. version,
        "===============================================",
        "   ______.........--=T=--.........______",
        "      .             |:|",
        " :-. //           /\"\"\"\"\"\"-.",
        " ': '-._____..--\"\"(\"\"\"\"\"\")()`---.__",
        "  /:   _..__   ''  \":\"\"\"\"'[] |\"\"`\\\\",
        "  ': :'     `-.     _:._     '\"\"\"\" :",
        "   ::          '--=:____:.___....-\"",
        "                     O\"       O\"",
        "===============================================",
        "  Rotorflight is free software licensed under",
        "  the GNU General Public License version 3.0",
        "  https://www.gnu.org/licenses/gpl-3.0.en.html",
        "                                              ",
        " For more information, visit rotorflight.com",
        "==============================================="
    }

    for _, line in ipairs(banner) do
        rfsuite.utils.log(line, "info")
    end
end

function utils.sanitize_filename(str)
    if not str then return nil end
    return str:match("^%s*(.-)%s*$"):gsub('[\\/:"*?<>|]', '')
end

function utils.dir_exists(base, name)
    base = base or "./"
    local list = system.listFiles(base)
    if list == nil then return false end
    for i = 1, #list do
        if list[i] == name then
            return true
        end
    end
    return false
end

function utils.file_exists(name)
    local f = io.open(name, "r")
    if f then
        io.close(f)
        return true
    end
    return false
end

function utils.playFile(pkg, file)
    -- Get and clean audio voice path
    local av = system.getAudioVoice():gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", "")

    -- Pre-define the base directory paths
    local soundPack = rfsuite.preferences.soundPack
    local audioPath = soundPack and ("/audio/" .. soundPack) or av

    -- Construct file paths
    local wavLocale = audioPath .. "/" .. pkg .. "/" .. file
    local wavDefault = "audio/en/default/" .. pkg .. "/" .. file

    -- Check if locale file exists, else use the default
    system.playFile(rfsuite.utils.file_exists(wavLocale) and wavLocale or wavDefault)
end

function utils.playFileCommon(file)
    system.playFile("audio/" .. file)
end


-- this is used in multiple places - just gives easy way
-- to grab activeProfile or activeRateProfile in tmp var
-- you MUST set it to nil after you get it!
function utils.getCurrentProfile()

    if (rfsuite.tasks.telemetry.getSensorSource("pid_profile") ~= nil and rfsuite.tasks.telemetry.getSensorSource("rate_profile") ~= nil) then

        rfsuite.session.activeProfileLast = rfsuite.session.activeProfile
        local p = rfsuite.tasks.telemetry.getSensorSource("pid_profile"):value()
        if p ~= nil then
            rfsuite.session.activeProfile = math.floor(p)
        else
            rfsuite.session.activeProfile = nil
        end

        rfsuite.session.activeRateProfileLast = rfsuite.session.activeRateProfile
        local r = rfsuite.tasks.telemetry.getSensorSource("rate_profile"):value()
        if r ~= nil then
            rfsuite.session.activeRateProfile = math.floor(r)
        else
            rfsuite.session.activeRateProfile = nil
        end

    else
        -- msp call to get data
        
                local message = {
                    command = 101, -- MSP_SERVO_CONFIGURATIONS
                    uuid = "getProfile",
                    processReply = function(self, buf)

                        if #buf >= 30 then

                            buf.offset = 24
                            local activeProfile = rfsuite.tasks.msp.mspHelper.readU8(buf)
                            buf.offset = 26
                            local activeRate = rfsuite.tasks.msp.mspHelper.readU8(buf)

                            rfsuite.session.activeProfileLast = rfsuite.session.activeProfile
                            rfsuite.session.activeRateProfileLast = rfsuite.session.activeRateProfile

                            rfsuite.session.activeProfile = activeProfile + 1
                            rfsuite.session.activeRateProfile = activeRate + 1

                        end
                    end,
                    simulatorResponse = {240, 1, 124, 0, 35, 0, 0, 0, 0, 0, 0, 224, 1, 10, 1, 0, 26, 0, 0, 0, 0, 0, 2, 0, 6, 0, 6, 1, 4, 1}

                }
                rfsuite.tasks.msp.mspQueue:add(message)

    end
end

-- Function to compare the current system version with a target version
-- Function to compare the current system version with a target version
function utils.ethosVersionAtLeast(targetVersion)
    local env = system.getVersion()
    local currentVersion = {env.major, env.minor, env.revision}

    -- Fallback to default config if targetVersion is not provided
    if targetVersion == nil then 
        if rfsuite and rfsuite.config and rfsuite.config.ethosVersion then
            targetVersion = rfsuite.config.ethosVersion
        else
            -- Fail-safe: if no targetVersion is provided and config is missing
            return false
        end
    elseif type(targetVersion) == "number" then
        rfsuite.utils.log("WARNING: utils.ethosVersionAtLeast() called with a number instead of a table (" .. targetVersion .. ")",2)
        return false    
    end

    -- Ensure the targetVersion has three components (major, minor, revision)
    for i = 1, 3 do
        targetVersion[i] = targetVersion[i] or 0  -- Default to 0 if not provided
    end

    -- Compare major, minor, and revision explicitly
    for i = 1, 3 do
        if currentVersion[i] > targetVersion[i] then
            return true  -- Current version is higher
        elseif currentVersion[i] < targetVersion[i] then
            return false -- Current version is lower
        end
    end

    return true  -- Versions are equal (>= condition met)
end

function utils.titleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function utils.stringInArray(array, s)
    for i, value in ipairs(array) do if value == s then return true end end
    return false
end

function utils.round(num, places)
    local places = places or 2
    if places == 0 then
        return math.floor(num + 0.5)  -- return integer (no .0)
    else
        local mult = 10^places
        return math.floor(num * mult + 0.5) / mult
    end
end


function utils.roughlyEqual(a, b, tolerance)
    return math.abs(a - b) < (tolerance or 0.0001)  -- Allows a tiny margin of error
end

-- return current window size
function utils.getWindowSize()
    return lcd.getWindowSize()
end

function utils.joinTableItems(tbl, delimiter)
    if not tbl or #tbl == 0 then return "" end

    delimiter = delimiter or ""
    local startIndex = tbl[0] and 0 or 1

    -- Pre-pad all fields once before joining
    local paddedTable = {}
    for i = startIndex, #tbl do
        paddedTable[i] = tostring(tbl[i]) .. string.rep(" ", math.max(0, 3 - #tostring(tbl[i])))
    end

    -- Join the padded table items
    return table.concat(paddedTable, delimiter, startIndex, #tbl)
end

--[[
    Logs a message with a specified log level.
    
    @param msg string: The message to log.
    @param level string (optional): The log level (e.g., "debug", "info", "warn", "error"). Defaults to "debug".
]]
function utils.log(msg, level)
    rfsuite.log.log(msg, level or "debug")
end

-- Function to print a table to the debug console in a readable format.
-- @param node The table to be printed.
-- @param maxDepth (optional) The maximum depth to traverse the table. Default is 5.
-- @param currentDepth (optional) The current depth of traversal. Default is 0.
-- @return A string representation of the table.
-- print a table out to debug console
function utils.print_r(node, maxDepth, currentDepth)
    maxDepth = maxDepth or 5  -- Reasonable depth limit to avoid runaway recursion
    currentDepth = currentDepth or 0

    if currentDepth > maxDepth then
        return "{...} -- Max Depth Reached"
    end

    if type(node) ~= "table" then
        return tostring(node) .. " (" .. type(node) .. ")"
    end

    local result = {}

    table.insert(result, "{")

    for k, v in pairs(node) do
        local key = type(k) == "string" and ('["' .. k .. '"]') or ("[" .. tostring(k) .. "]")
        local value

        if type(v) == "table" then
            value = utils.print_r(v, maxDepth, currentDepth + 1)
        else
            value = tostring(v)
            if type(v) == "string" then
                value = '"' .. value .. '"'
            end
        end

        table.insert(result, key .. " = " .. value .. ",")
    end

    table.insert(result, "}")

    return table.concat(result, " ")
end


--[[
    Finds and loads modules from the specified directory.

    This function scans the "app/modules/" directory for subdirectories containing an "init.lua" file.
    It attempts to load each "init.lua" file as a Lua chunk and expects it to return a table with a "script" field.
    If the "init.lua" file is successfully loaded and returns a valid configuration table, the module is added to the modules list.

    @return table A list of loaded module configurations. Each configuration is a table containing the module's details.
]]
function utils.findModules()
    local modulesList = {}

    local moduledir = "app/modules/"
    local modules_path = moduledir

    for _, v in pairs(system.listFiles(modules_path)) do

        if v ~= ".." then
            local init_path = modules_path .. v .. '/init.lua'

            local f = io.open(init_path, "r")
            if f then
                io.close(f)
                local func, err = loadfile(init_path)
                if err then
                    rfsuite.utils.log("Error loading " .. init_path, "info")
                    rfsuite.utils.log(err, "info")
                end
                if func then
                    local mconfig = func()
                    if type(mconfig) ~= "table" or not mconfig.script then
                        rfsuite.utils.log("Invalid configuration in " .. init_path,"info")
                    else
                        rfsuite.utils.log("Loading module " .. v, "debug")
                        mconfig['folder'] = v
                        table.insert(modulesList, mconfig)
                    end
                else
                    rfsuite.utils.log("Error loading " .. init_path, "info")    
                end 
            end
        end    
    end

    return modulesList
end

--[[
    Finds and loads widget configurations from the "widgets/" directory.

    This function scans the "widgets/" directory for subdirectories containing an "init.lua" file.
    It attempts to load each "init.lua" file as a Lua chunk and expects it to return a table with widget configuration.
    The configuration table must contain a "key" field to be considered valid.
    If valid, the configuration table is added to the widgets list with an additional "folder" field indicating the widget's directory.

    @return table A list of valid widget configuration tables.
]]
function utils.findWidgets()
    local widgetsList = {}

    local widgetdir = "widgets/"
    local widgets_path = widgetdir

    for _, v in pairs(system.listFiles(widgets_path)) do

        if v ~= ".." then
            local init_path = widgets_path .. v .. '/init.lua'
            local f = io.open(init_path, "r")
            if f then
                io.close(f)

                local func, err = loadfile(init_path)

                if func then
                    local wconfig = func()
                    if type(wconfig) ~= "table" or not wconfig.key then
                        rfsuite.utils.log("Invalid configuration in " .. init_path,"debug")
                    else
                        wconfig['folder'] = v
                        table.insert(widgetsList, wconfig)
                    end
                end
            end
        end    
    end

    return widgetsList
end

--[[
    utils.loadImage(image1, image2, image3)

    This function attempts to load an image from a list of provided image paths or Bitmap objects.
    It checks for the existence of the image in multiple directories and supports both PNG and BMP formats.

    Parameters:
        image1 (string|Bitmap): The primary image path or Bitmap object to load.
        image2 (string|Bitmap): The secondary image path or Bitmap object to load if the primary is not found.
        image3 (string|Bitmap): The tertiary image path or Bitmap object to load if neither the primary nor secondary are found.

    Returns:
        Bitmap: The loaded Bitmap object if an image path is found and successfully loaded.
        Bitmap: The first existing Bitmap object from the provided parameters if no image path is found.
        nil: If no valid image path or Bitmap object is found.

    Helper Functions:
        find_image_in_directories(img):
            Checks if the image file exists in different directories and returns the valid path if found.

        resolve_image(image):
            Resolves the image path by checking its existence and attempting to switch between PNG and BMP formats if necessary.
--]]
function utils.loadImage(image1, image2, image3)
    -- Helper function to check file in different locations
    local function find_image_in_directories(img)
        if rfsuite.utils.file_exists(img) then
            return img
        elseif rfsuite.utils.file_exists("BITMAPS:" .. img) then
            return "BITMAPS:" .. img
        elseif rfsuite.utils.file_exists("SYSTEM:" .. img) then
            return "SYSTEM:" .. img
        else
            return nil
        end
    end

    -- Function to check and return a valid image path
    local function resolve_image(image)
        if type(image) == "string" then
            local image_path = find_image_in_directories(image)
            if not image_path then
                if image:match("%.png$") then
                    image_path = find_image_in_directories(image:gsub("%.png$", ".bmp"))
                elseif image:match("%.bmp$") then
                    image_path = find_image_in_directories(image:gsub("%.bmp$", ".png"))
                end
            end
            return image_path
        end
        return nil
    end

    -- Resolve images in order of precedence
    local image_path = resolve_image(image1) or resolve_image(image2) or resolve_image(image3)

    -- If an image path is found, load and return the bitmap
    if image_path then return lcd.loadBitmap(image_path) end

    -- If no valid image path was found, return the first existing Bitmap in order
    if type(image1) == "Bitmap" then return image1 end
    if type(image2) == "Bitmap" then return image2 end
    if type(image3) == "Bitmap" then return image3 end

    -- If nothing was found, return nil
    return nil
end

--[[
    Function: utils.simSensors

    Loads and executes a telemetry Lua script based on the provided ID.

    Parameters:
        id (string): The identifier for the telemetry script to load.

    Returns:
        number: The result of the executed telemetry script, or 0 if an error occurs.

    Description:
        This function attempts to load a telemetry Lua script from two possible paths:
        1. "../rfsuite.sim/sensors/<id>.lua"
        2. "lib/sim/sensors/<id>.lua"
        
        It first checks if the file exists at the local path. If not, it checks the fallback path.
        If the file is found, it attempts to load and execute the script. If any error occurs
        during loading or execution, it prints an error message and returns 0.
--]]
function utils.simSensors(id)

    if id == nil then return 0 end

    local localPath = "../rfsuite.sim/sensors/" .. id .. ".lua"
    local fallbackPath = "sim/sensors/" .. id .. ".lua"

    local filepath

    if rfsuite.utils.file_exists(localPath) then
        filepath = localPath
    elseif rfsuite.utils.file_exists(fallbackPath) then
        filepath = fallbackPath
    else
        return 0
    end

    local chunk, err = loadfile(filepath)
    if not chunk then
        print("Error loading telemetry file: " .. err)
        return 0
    end

    local success, result = pcall(chunk)

    if not success then
        print("Error executing telemetry file: " .. result)
        return 0
    end

    return result
end

-- Splits a given string into a table of substrings based on a specified separator.
-- @param input The string to be split.
-- @param sep The separator used to split the string.
-- @return A table containing the substrings.
function utils.splitString(input, sep)
    local result = {}

    -- Lua's gmatch needs plain `sep`, so if you want to handle "%s*" or patterns, use this
    for item in input:gmatch("([^" .. sep .. "]+)") do
        table.insert(result, item)
    end

    return result
end


--- Logs MSP (Multiwii Serial Protocol) commands if logging is enabled in the configuration.
-- @param cmd The MSP command to log.
-- @param rwState The read/write state of the command.
-- @param buf The buffer containing the command data.
-- @param err Any error associated with the command.
-- @usage
-- utils.logMsp("MSP_STATUS", "read", {0x01, 0x02, 0x03}, nil)
function utils.logMsp(cmd, rwState, buf, err)
    if rfsuite.config.logMSP then
        local payload = rfsuite.utils.joinTableItems(buf, ", ")
        rfsuite.utils.log(rwState .. " [" .. cmd .. "]" .. " {" .. payload .. "}", "info")
        if err then
            rfsuite.utils.log("Error: " .. err, "info")
        end
    end
end


function utils.truncateText(str, maxWidth)
    lcd.font(bestFont)
    local tsizeW, _ = lcd.getTextSize(str)

    if tsizeW <= maxWidth then
        return str  -- Fits, no need to truncate
    end

    -- Start truncating
    local ellipsis = "..."
    local truncatedStr = str
    while tsizeW > maxWidth and #truncatedStr > 1 do
        truncatedStr = string.sub(truncatedStr, 1, #truncatedStr - 1)
        tsizeW, _ = lcd.getTextSize(truncatedStr .. ellipsis)
    end
    return truncatedStr .. ellipsis
end

return utils
