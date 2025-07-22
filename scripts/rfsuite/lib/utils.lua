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
local i18n = rfsuite.i18n.get


local arg = {...}
local config = arg[1]

-- sets up the initial session var state.
-- function is called on startup of the script  and
-- whenever the tasks.lua detects the heli has been disconnected
function utils.session()
    rfsuite.session = {}
    rfsuite.session.tailMode = nil
    rfsuite.session.swashMode = nil
    rfsuite.session.activeProfile = nil
    rfsuite.session.activeRateProfile = nil
    rfsuite.session.activeProfileLast = nil
    rfsuite.session.activeRateLast = nil
    rfsuite.session.servoCount = nil
    rfsuite.session.servoOverride = nil
    rfsuite.session.clockSet = nil
    rfsuite.session.apiVersion = nil
    rfsuite.session.fcVersion = nil
    rfsuite.session.activeProfile = nil
    rfsuite.session.activeRateProfile = nil
    rfsuite.session.activeProfileLast = nil
    rfsuite.session.activeRateLast = nil
    rfsuite.session.servoCount = nil
    rfsuite.session.resetMSP = nil
    rfsuite.session.servoOverride = nil
    rfsuite.session.clockSet = nil
    rfsuite.session.tailMode = nil
    rfsuite.session.swashMode = nil
    rfsuite.session.rateProfile = nil
    rfsuite.session.governorMode = nil
    rfsuite.session.servoOverride = nil
    rfsuite.session.ethosRunningVersion = nil
    rfsuite.session.mspSignature = nil
    rfsuite.session.telemetryState = nil
    rfsuite.session.telemetryType = nil
    rfsuite.session.telemetryTypeChanged = nil
    rfsuite.session.telemetrySensor = nil
    rfsuite.session.repairSensors = false
    rfsuite.session.locale = system.getLocale()
    rfsuite.session.lastMemoryUsage = nil
    rfsuite.session.mcu_id = nil
    rfsuite.session.isConnected = false
    rfsuite.session.isConnectedHigh = false
    rfsuite.session.isConnectedMedium = false
    rfsuite.session.isConnectedLow = false
    rfsuite.session.isArmed = false
    rfsuite.session.bblSize = nil
    rfsuite.session.bblUsed = nil
    rfsuite.session.batteryConfig = nil
    -- keep rfsuite.session.batteryConfig nil as it is used to determine if the battery config has been loaded
    -- rfsuite.session.batteryConfig  will end up containing the following:
        -- batteryCapacity = nil
        -- batteryCellCount = nil
        -- vbatwarningcellvoltage = nil
        -- vbatmincellvoltage = nil
        -- vbatmaxcellvoltage = nil
        -- vbatfullcellvoltage = nil
        -- lvcPercentage = nil
        -- consumptionWarningPercentage = nil
    rfsuite.session.modelPreferences = nil -- this is used to store the model preferences
    rfsuite.session.modelPreferencesFile = nil -- this is used to store the model preferences file path
    rfsuite.session.timer = {}
    rfsuite.session.timer.start = nil -- this is used to store the start time of the timer
    rfsuite.session.timer.live = nil -- this is used to store the live timer value while inflight
    rfsuite.session.timer.lifetime = nil -- this is used to store the total flight time of a model and store it in the user ini file
    rfsuite.session.timer.session = 0 -- this is used to track flight time for the session
    rfsuite.session.flightCounted = false
    rfsuite.session.onConnect = {} -- this is used to store the onConnect tasks that need to be run
    rfsuite.session.onConnect.high = false
    rfsuite.session.onConnect.low = false
    rfsuite.session.onConnect.medium = false
    rfsuite.session.rx = {}
    rfsuite.session.rx.map = {}
    rfsuite.session.rx.values = {} -- this is used to store the rx values for the rxmap task
end

--- Checks if the RX map is ready by verifying the presence of required channel mappings.
-- The function returns true if the `rfsuite.session.rxmap` table exists and at least one of the following fields is present:
-- `collective`, `elevator`, `throttle`, or `rudder`.
-- @return boolean True if the RX map is ready, false otherwise.
function utils.rxmapReady()
    -- Check if the RX map is ready
    if rfsuite.session.rx and rfsuite.session.rx.map  and (rfsuite.session.rx.map.collective or rfsuite.session.rx.map.elevator or rfsuite.session.rx.map.throttle or rfsuite.session.rx.map.rudder) then
        return true
    end
    return false
end

--- Checks if the current flight mode is "inflight".
-- @return boolean Returns true if the flight mode is "inflight", false otherwise.
function utils.inFlight()
    if rfsuite.flightmode.current == "inflight" then
        return true
    end
    return false
end

--- Converts a version array into an indexed array of tables.
-- Each element in the input table is paired with its zero-based index in a new table.
-- @param tbl Table containing version elements.
-- @return arr Array of tables, each containing the value and its zero-based index: {value, index}.
function utils.msp_version_array_to_indexed()
    local arr = {}
    local tbl = rfsuite.config.supportedMspApiVersion or {"12.06", "12.07","12.08"} 
    for i, v in ipairs(tbl) do
        arr[#arr+1] = {v, i}
    end
    return arr
end

--- Converts arming disable flags into a human-readable string representation.
---
--- This function iterates through the bits of the provided `flags` integer and checks
--- which flags are set. For each set flag, it appends the corresponding localized
--- string to the result. If no flags are set, it returns a localized "OK" message.
---
--- @param flags number The bitfield representing arming disable flags.
--- @return string A comma-separated string of human-readable flag descriptions, or "OK" if no flags are set.
function utils.armingDisableFlagsToString(flags)
    if flags == nil then
        return i18n("app.modules.status.ok"):upper()
    end

    local names = {}
    for i = 0, 25 do
        if (flags & (1 << i)) ~= 0 then
            local key = "app.modules.status.arming_disable_flag_" .. i
            local name = i18n(key)
            if name and name ~= "" then
                table.insert(names, name)
            end
        end
    end

    if #names == 0 then
        return i18n("app.modules.status.ok"):upper()
    end

    return table.concat(names, ", "):upper()
end

-- get the governor text from the value
function utils.getGovernorState(value)

    local returnvalue

    if not rfsuite.tasks.telemetry then
        return i18n("widgets.governor.UNKNOWN")
    end

    --[[
    Checks if the provided value exists as a key in the 'map' table.
    If the key exists, assigns the corresponding value from 'map' to 'returnvalue'.
    If the key does not exist, assigns a localized "UNKNOWN" string to 'returnvalue' using 'i18n'.
    ]]    
    local map = {     
        [0] =  i18n("widgets.governor.OFF"),
        [1] =  i18n("widgets.governor.IDLE"),
        [2] =  i18n("widgets.governor.SPOOLUP"),
        [3] =  i18n("widgets.governor.RECOVERY"),
        [4] =  i18n("widgets.governor.ACTIVE"),
        [5] =  i18n("widgets.governor.THROFF"),
        [6] =  i18n("widgets.governor.LOSTHS"),
        [7] =  i18n("widgets.governor.AUTOROT"),
        [8] =  i18n("widgets.governor.BAILOUT"),
        [100] = i18n("widgets.governor.DISABLED"),
        [101] = i18n("widgets.governor.DISARMED")
    }

    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.session.apiVersion > 12.07 then
        local armflags = rfsuite.tasks.telemetry.getSensor("armflags")
        if armflags == 0 or armflags == 2 then
            value = 101
        end
    end

    if map[value] then
        returnvalue = map[value]
    else
        returnvalue = i18n("widgets.governor.UNKNOWN")
    end    

    --[[
        Checks the value of the "armdisableflags" telemetry sensor. If the sensor value is available,
        it is floored to the nearest integer and converted to a human-readable string using
        utils.armingDisableFlagsToString(). If the resulting string is not "OK",
        the function sets 'returnvalue' to this string, indicating a reason why arming is disabled.
    --]]
    local armdisableflags = rfsuite.tasks.telemetry.getSensor("armdisableflags")
    if armdisableflags ~= nil then
        armdisableflags = math.floor(armdisableflags)
        local armstring = utils.armingDisableFlagsToString(armdisableflags )
        if armstring ~= "OK" then
            returnvalue =  armstring
        end   
    end    

    --- Returns the value stored in `returnvalue`.
    -- @return The value of `returnvalue`.
    return returnvalue
end


function utils.createCacheFile(tbl, path, options)

    os.mkdir("cache")

    path = "cache/" .. path

    local f, err = io.open(path, "w")
    if not f then
        rfsuite.utils.log("Error creating cache file: " .. err, "info")
        return
    end

    local function serialize(value, indent)
        indent = indent or ""
        local t = type(value)

        if t == "string" then
            return string.format("%q", value)
        elseif t == "number" or t == "boolean" then
            return tostring(value)
        elseif t == "table" then
            local result = "{\n"
            for k, v in pairs(value) do
                local keyStr
                if type(k) == "string" and k:match("^%a[%w_]*$") then
                    keyStr = k .. " = "
                else
                    keyStr = "[" .. serialize(k) .. "] = "
                end
                result = result .. indent .. "  " .. keyStr .. serialize(v, indent .. "  ") .. ",\n"
            end
            result = result .. indent .. "}"
            return result
        else
            error("Cannot serialize type: " .. t)
        end
    end

    f:write("return ", serialize(tbl), "\n")
    f:close()
end



function utils.logRotorFlightBanner()
    local version = rfsuite.version().version or "Unknown Version"

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
        " For more information, visit rotorflight.org",
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
    local av = system.getAudioVoice():gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", ""):gsub("audio/", "")
    
    -- Ensure av does not start with a slash
    if av:sub(1, 1) == "/" then
        av = av:sub(2)
    end

    -- Construct file paths
    local wavUser   = "SCRIPTS:/rfsuite.user/audio/user/"      .. pkg .. "/" .. file
    local wavLocale = "SCRIPTS:/rfsuite.user/audio/" .. av .. "/" .. pkg .. "/" .. file
    local wavDefault= "SCRIPTS:/rfsuite/audio/en/default/"    .. pkg .. "/" .. file

    -- Determine which file to play: user → locale → default
    local path
    if rfsuite.utils.file_exists(wavUser) then
        path = wavUser
    elseif rfsuite.utils.file_exists(wavLocale) then
        path = wavLocale
    else
        path = wavDefault
    end

    system.playFile(path)
end


function utils.playFileCommon(file)
    system.playFile("audio/" .. file)
end


-- this is used in multiple places - just gives easy way
-- to grab activeProfile or activeRateProfile in tmp var
-- you MUST set it to nil after you get it!
function utils.getCurrentProfile()


    local pidProfile = rfsuite.tasks.telemetry.getSensor("pid_profile")
    local rateProfile = rfsuite.tasks.telemetry.getSensor("rate_profile")

    if (pidProfile ~= nil and rateProfile ~= nil) then

        rfsuite.session.activeProfileLast = rfsuite.session.activeProfile
        local p = pidProfile
        if p ~= nil then
            rfsuite.session.activeProfile = math.floor(p)
        else
            rfsuite.session.activeProfile = nil
        end

        rfsuite.session.activeRateProfileLast = rfsuite.session.activeRateProfile
        local r = rateProfile
        if r ~= nil then
            rfsuite.session.activeRateProfile = math.floor(r)
        else
            rfsuite.session.activeRateProfile = nil
        end

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
    if num == nil then 
        return nil 
    end

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
    if rfsuite.tasks and rfsuite.tasks.logger then
        rfsuite.tasks.logger.add(msg, level or "debug")
    end
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

        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = modules_path .. v .. '/init.lua'

            local func, err = rfsuite.compiler.loadfile(init_path)
            if not func then
                rfsuite.utils.log("Failed to load module init " .. init_path .. ": " .. err, "info")
            else
                local ok, mconfig = pcall(func)
                if not ok then
                    rfsuite.utils.log("Error executing " .. init_path .. ": " .. mconfig, "info")
                elseif type(mconfig) ~= "table" or not mconfig.script then
                    rfsuite.utils.log("Invalid configuration in " .. init_path, "info")
                else
                    rfsuite.utils.log("Loading module " .. v, "debug")
                    mconfig.folder = v
                    table.insert(modulesList, mconfig)
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

        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = widgets_path .. v .. '/init.lua'
            -- try loading directly
            local func, err = rfsuite.compiler.loadfile(init_path)
            if not func then
                rfsuite.utils.log(
                  "Failed to load widget init " .. init_path .. ": " .. err,
                  "debug"
                )
            else
                local ok, wconfig = pcall(func)
                if not ok then
                    rfsuite.utils.log(
                      "Error executing widget init " .. init_path .. ": " .. wconfig,
                      "debug"
                    )
                elseif type(wconfig) ~= "table" or not wconfig.key then
                    rfsuite.utils.log(
                      "Invalid configuration in " .. init_path,
                      "debug"
                    )
                else
                    wconfig.folder = v
                    table.insert(widgetsList, wconfig)
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
-- caches for loadImage
utils._imagePathCache   = {}
utils._imageBitmapCache = {}
function utils.loadImage(image1, image2, image3)
    -- Resolve & cache bitmaps to avoid repeated fs checks
    local function getCachedBitmap(key, tryPaths)
        -- already loaded?
        -- nothing to do if no key
        if not key then
            return nil
        end
        -- already loaded?
        if utils._imageBitmapCache[key] then
            return utils._imageBitmapCache[key]
        end

        -- find or reuse resolved path
        local path = utils._imagePathCache[key]
        if not path then
            for _, p in ipairs(tryPaths) do
                if rfsuite.utils.file_exists(p) then
                    path = p
                    break
                end
            end
            utils._imagePathCache[key] = path
        end

        if not path then return nil end
        local bmp = lcd.loadBitmap(path)
        utils._imageBitmapCache[key] = bmp
        return bmp
    end

    -- build candidate paths for each image string
    local function candidates(img)
        if type(img) ~= "string" then return {} end
        local out = { img, "BITMAPS:"..img, "SYSTEM:"..img }
        if img:match("%.png$") then
            -- direct array-style append instead of table.insert
            out[#out+1] = img:gsub("%.png$",".bmp")
        elseif img:match("%.bmp$") then
            out[#out+1] = img:gsub("%.bmp$",".png")
        end
        return out
    end

    -- try in order
    return getCachedBitmap(image1, candidates(image1))
        or getCachedBitmap(image2, candidates(image2))
        or getCachedBitmap(image3, candidates(image3)) 
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
        1. "LOGS:/rfsuite/sensors/<id>.lua"
        2. "lib/sim/sensors/<id>.lua"
        
        It first checks if the file exists at the local path. If not, it checks the fallback path.
        If the file is found, it attempts to load and execute the script. If any error occurs
        during loading or execution, it prints an error message and returns 0.
--]]
function utils.simSensors(id)
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/sensors")

    if id == nil then return 0 end

    local filepath = "sim/sensors/" .. id .. ".lua"

    -- loadfile will fail gracefully if file doesn't exist or has errors
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
    if rfsuite.preferences.developer.logmsp then
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

function utils.reportMemoryUsage(location)

    if rfsuite.preferences.developer.memstats == false then
        return
    end

    -- Get current memory usage in bytes and convert to KB
    local currentMemoryUsage = system.getMemoryUsage().luaRamAvailable / 1024

    -- Retrieve the last memory usage from the session (convert it to KB if it exists)
    local lastMemoryUsage = rfsuite.session.lastMemoryUsage

    -- Ensure location is not nil or empty
    location = location or "Unknown"

    -- Construct the log message
    local logMessage

    if lastMemoryUsage then
        lastMemoryUsage = lastMemoryUsage / 1024  -- Convert last recorded memory to KB
        local difference = currentMemoryUsage - lastMemoryUsage
        if difference > 0 then
            logMessage = string.format("[%s] Memory usage decreased by %.2f KB (Available: %.2f KB)", location, difference, currentMemoryUsage)
        elseif difference < 0 then
            logMessage = string.format("[%s] Memory usage increased by %.2f KB (Available: %.2f KB)", location, -difference, currentMemoryUsage)
        else
            logMessage = string.format("[%s] Memory usage unchanged (Available: %.2f KB)", location, currentMemoryUsage)
        end
    else
        logMessage = string.format("[%s] Initial memory usage: %.2f KB", location, currentMemoryUsage)
    end

    -- Log the message
    rfsuite.utils.log(logMessage, "info")

    -- Store the current memory usage in bytes for future calls (convert back to bytes)
    rfsuite.session.lastMemoryUsage = system.getMemoryUsage().luaRamAvailable
end


function utils.onReboot()
    rfsuite.session.resetSensors = true
    rfsuite.session.resetTelemetry = true
    rfsuite.session.resetMSP = true
    rfsuite.session.resetMSPSensors = true
end

--- Parses a version string into a table of numbers.
-- The function splits the input version string by numeric components and returns a table
-- where each element is a number from the version string. The table starts with 0 as the first element.
-- @param versionString string: The version string to parse (e.g., "1.2.3").
-- @return table|nil: A table of numbers representing the version, or nil if the input is nil.
function utils.splitVersionStringToNumbers(versionString)
    if not versionString then return nil end

    local parts = {0} -- start with 0
    for num in versionString:gmatch("%d+") do
        table.insert(parts, tonumber(num))
    end
    return parts
end

function utils.keys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

return utils
