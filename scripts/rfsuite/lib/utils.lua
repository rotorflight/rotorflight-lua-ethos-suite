--[[

 * Copyright (C) Rotorflight Project
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
 
]] --

local utils = {}
local i18n  = rfsuite.i18n.get
local compiler = rfsuite.compiler 

local arg    = {...}
local config = arg[1]

-- Sets up the initial session var state.
-- Function is called on startup of the script and whenever tasks.lua detects the heli has been disconnected.
function utils.session()
    rfsuite.session = {
        -- Modes
        tailMode            = nil,
        swashMode           = nil,
        rateProfile         = nil,
        governorMode        = nil,

        -- Profiles
        activeProfile       = nil,
        activeRateProfile   = nil,
        activeProfileLast   = nil,
        activeRateLast      = nil,

        -- Servo
        servoCount          = nil,
        servoOverride       = nil,

        -- Versions / IDs
        apiVersion          = nil,
        fcVersion           = nil,
        rfVersion           = nil,
        ethosRunningVersion = nil,
        mspSignature        = nil,
        mcu_id              = nil,

        -- Connection State
        isConnected         = false,
        isConnectedHigh     = false,
        isConnectedMedium   = false,
        isConnectedLow      = false,
        isArmed             = false,

        -- Telemetry
        telemetryState       = nil,
        telemetryType        = nil,
        telemetryTypeChanged = nil,
        telemetrySensor      = nil,
        telemetryModule      = nil,
        telemetryModelChanged = nil,

        -- Sensors / Repair
        repairSensors       = false,

        -- Battery Config (nil means not yet loaded)
        batteryConfig       = nil,

        -- Locale / System
        locale              = system.getLocale(),
        lastMemoryUsage     = nil,
        bblSize             = nil,
        bblUsed             = nil,

        -- Timers
        timer = {
            start     = nil,
            live      = nil,
            lifetime  = nil,
            session   = 0
        },
        flightCounted = false,

        -- Connection hooks
        onConnect = {
            tasks  = {},
            high   = false,
            medium = false,
            low    = false
        },

        -- RX mapping
        rx = {
            map    = {},
            values = {}
        },

        -- Files / Preferences
        modelPreferences     = nil,
        modelPreferencesFile = nil,

        -- Clock / Reset
        clockSet   = nil,
        resetMSP   = nil
    }
end


--- Checks if the RX map is ready by verifying the presence of required channel mappings.
-- The function returns true if the `rfsuite.session.rx.map` table exists and at least one of the following fields is present:
-- `collective`, `elevator`, `throttle`, or `rudder`.
-- @return boolean True if the RX map is ready, false otherwise.
function utils.rxmapReady()
    if rfsuite.session.rx and rfsuite.session.rx.map and (rfsuite.session.rx.map.collective or rfsuite.session.rx.map.elevator or rfsuite.session.rx.map.throttle or rfsuite.session.rx.map.rudder) then
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
-- @return arr Array of tables, each containing the value and its index: {value, index}.
function utils.msp_version_array_to_indexed()
    local arr = {}
    local tbl = rfsuite.config.supportedMspApiVersion or {"12.06", "12.07", "12.08"}
    for i, v in ipairs(tbl) do
        arr[#arr+1] = { v, i }
    end
    return arr
end

--- Converts arming disable flags into a human-readable string representation.
---
--- Iterates through bits of `flags` and appends corresponding localized strings.
--- Returns localized "OK" if no flags are set or flags is nil.
---
--- @param flags number Bitfield representing arming disable flags.
--- @return string Uppercased, comma-separated descriptions or "OK".
function utils.armingDisableFlagsToString(flags)
    if flags == nil then
        return i18n("app.modules.status.ok"):upper()
    end

    local names = {}
    for i = 0, 25 do
        if (flags & (1 << i)) ~= 0 then
            local key  = "app.modules.status.arming_disable_flag_" .. i
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

-- Get the governor text from the value
function utils.getGovernorState(value)
    local returnvalue

    if not rfsuite.tasks.telemetry then
        return i18n("widgets.governor.UNKNOWN")
    end

    --[[
        Checks if the provided value exists as a key in the 'map' table.
        If the key exists, returns the mapped value; otherwise returns localized "UNKNOWN".
    ]]
    local map = {
        [0]   = i18n("widgets.governor.OFF"),
        [1]   = i18n("widgets.governor.IDLE"),
        [2]   = i18n("widgets.governor.SPOOLUP"),
        [3]   = i18n("widgets.governor.RECOVERY"),
        [4]   = i18n("widgets.governor.ACTIVE"),
        [5]   = i18n("widgets.governor.THROFF"),
        [6]   = i18n("widgets.governor.LOSTHS"),
        [7]   = i18n("widgets.governor.AUTOROT"),
        [8]   = i18n("widgets.governor.BAILOUT"),
        [100] = i18n("widgets.governor.DISABLED"),
        [101] = i18n("widgets.governor.DISARMED")
    }

    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.utils.apiVersionCompare(">", "12.07") then
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
        If armdisableflags is present, prefer its human-readable explanation over governor text.
    ]]
    local armdisableflags = rfsuite.tasks.telemetry.getSensor("armdisableflags")
    if armdisableflags ~= nil then
        armdisableflags = math.floor(armdisableflags)
        local armstring = utils.armingDisableFlagsToString(armdisableflags)
        if armstring ~= "OK" then
            returnvalue = armstring
        end
    end

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
        "  /:   _..__   ''  \":\"\"\"\"'[] |\"\"`\\",
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

function utils.dir_exists(base, name)
    base = base or "./"
    rfsuite.utils.log("Checking if directory exists: " .. base .. name, "debug")
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
    rfsuite.utils.log("Checking if file exists: " .. name, "debug")
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
    local wavUser    = "SCRIPTS:/rfsuite.user/audio/user/" .. pkg .. "/" .. file
    local wavLocale  = "SCRIPTS:/rfsuite.user/audio/" .. av .. "/" .. pkg .. "/" .. file
    local wavDefault = "SCRIPTS:/rfsuite/audio/en/default/" .. pkg .. "/" .. file

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

-- Compare the current system version with a target version
function utils.ethosVersionAtLeast(targetVersion)
    local env            = system.getVersion()
    local currentVersion = { env.major, env.minor, env.revision }

    -- Fallback to default config if targetVersion is not provided
    if targetVersion == nil then
        if rfsuite and rfsuite.config and rfsuite.config.ethosVersion then
            targetVersion = rfsuite.config.ethosVersion
        else
            -- Fail-safe: if no targetVersion is provided and config is missing
            return false
        end
    elseif type(targetVersion) == "number" then
        rfsuite.utils.log("WARNING: utils.ethosVersionAtLeast() called with a number instead of a table (" .. targetVersion .. ")", 2)
        return false
    end

    -- Ensure the targetVersion has three components (major, minor, revision)
    for i = 1, 3 do
        targetVersion[i] = targetVersion[i] or 0
    end

    -- Compare major, minor, and revision explicitly
    for i = 1, 3 do
        if currentVersion[i] > targetVersion[i] then
            return true
        elseif currentVersion[i] < targetVersion[i] then
            return false
        end
    end

    return true -- Versions are equal (>= condition met)
end

function utils.round(num, places)
    if num == nil then return nil end

    local places = places or 2
    if places == 0 then
        return math.floor(num + 0.5) -- integer (no .0)
    else
        local mult = 10^places
        return math.floor(num * mult + 0.5) / mult
    end
end

function utils.joinTableItems(tbl, delimiter)
    if not tbl or #tbl == 0 then return "" end

    delimiter  = delimiter or ""
    local sIdx = tbl[0] and 0 or 1

    -- Pre-pad all fields once before joining
    local padded = {}
    for i = sIdx, #tbl do
        padded[i] = tostring(tbl[i]) .. string.rep(" ", math.max(0, 3 - #tostring(tbl[i])))
    end

    -- Join the padded table items
    return table.concat(padded, delimiter, sIdx, #tbl)
end

--[[
    Logs a message with a specified log level.
    @param msg   string: The message to log.
    @param level string (optional): The log level (e.g., "debug", "info", "warn", "error"). Defaults to "debug".
]]
function utils.log(msg, level)
    if rfsuite.tasks and rfsuite.tasks.logger then
        rfsuite.tasks.logger.add(msg, level or "debug")
    end
end

-- Print a table to the debug console in a readable format.
-- @param node         The table to be printed.
-- @param maxDepth     (optional) Max depth to traverse; default 5.
-- @param currentDepth (optional) Current depth; default 0.
-- @return string      A string representation of the table.
function utils.print_r(node, maxDepth, currentDepth)
    maxDepth     = maxDepth or 5
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
        local key   = type(k) == "string" and ('["' .. k .. '"]') or ("[" .. tostring(k) .. "]")
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

    Scans the "app/modules/" directory for subdirectories containing an "init.lua".
    Loads each and expects it to return a table with a "script" field. Valid modules
    are pushed into the returned list.

    @return table A list of loaded module configurations.
]]
function utils.findModules()
    local modulesList  = {}
    local moduledir    = "app/modules/"
    local modules_path = moduledir

    for _, v in pairs(system.listFiles(modules_path)) do
        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = modules_path .. v .. '/init.lua'

            local func, err = compiler.loadfile(init_path)
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

    Scans for subdirectories containing an "init.lua" and expects it to return a
    configuration table with a required "key". Valid configs are returned with
    an added "folder" field.

    @return table A list of valid widget configuration tables.
]]
function utils.findWidgets()
    local widgetsList  = {}
    local widgetdir    = "widgets/"
    local widgets_path = widgetdir

    for _, v in pairs(system.listFiles(widgets_path)) do
        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = widgets_path .. v .. '/init.lua'

            local func, err = compiler.loadfile(init_path)
            if not func then
                rfsuite.utils.log("Failed to load widget init " .. init_path .. ": " .. err, "debug")
            else
                local ok, wconfig = pcall(func)
                if not ok then
                    rfsuite.utils.log("Error executing widget init " .. init_path .. ": " .. wconfig, "debug")
                elseif type(wconfig) ~= "table" or not wconfig.key then
                    rfsuite.utils.log("Invalid configuration in " .. init_path, "debug")
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

    Attempts to load an image from provided image paths or Bitmap objects.
    Checks for the existence of the image in multiple directories and supports
    both PNG and BMP formats.
]]

-- caches for loadImage
utils._imagePathCache   = {}
utils._imageBitmapCache = {}

function utils.loadImage(image1, image2, image3)
    -- Resolve & cache bitmaps to avoid repeated fs checks
    local function getCachedBitmap(key, tryPaths)
        if not key then return nil end
        if utils._imageBitmapCache[key] then
            return utils._imageBitmapCache[key]
        end

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

    -- Build candidate paths for each image string
    local function candidates(img)
        if type(img) ~= "string" then return {} end
        local out = { img, "BITMAPS:" .. img, "SYSTEM:" .. img }
        if img:match("%.png$") then
            out[#out+1] = img:gsub("%.png$", ".bmp")
        elseif img:match("%.bmp$") then
            out[#out+1] = img:gsub("%.bmp$", ".png")
        end
        return out
    end

    -- Try in order
    return getCachedBitmap(image1, candidates(image1))
        or getCachedBitmap(image2, candidates(image2))
        or getCachedBitmap(image3, candidates(image3))
end

--[[
    Function: utils.simSensors

    Loads and executes a telemetry Lua script based on the provided ID.
]]
function utils.simSensors(id)
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/sensors")

    if id == nil then return 0 end

    local filepath = "sim/sensors/" .. id .. ".lua"

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

--- Logs MSP (Multiwii Serial Protocol) commands if logging is enabled in the configuration.
-- @param cmd     The MSP command to log.
-- @param rwState The read/write state of the command.
-- @param buf     The buffer containing the command data.
-- @param err     Any error associated with the command.
function utils.logMsp(cmd, rwState, buf, err)
    if rfsuite.preferences.developer.logmsp then
        local payload = rfsuite.utils.joinTableItems(buf, ", ")
        rfsuite.utils.log(rwState .. " [" .. cmd .. "]{" .. payload .. "}", "info")
        if err then
            rfsuite.utils.log("Error: " .. err, "info")
        end
    end
end

function utils.reportMemoryUsage(location)
    if not rfsuite.preferences.developer.memstats then return end
    location = location or "Unknown"

    local memInfo = system.getMemoryUsage() or {}
    local mainStackKB     = (memInfo.mainStackAvailable or 0) / 1024
    local ramKB           = (memInfo.ramAvailable or 0) / 1024
    local luaRamKB        = (memInfo.luaRamAvailable or 0) / 1024
    local luaBitmapsRamKB = (memInfo.luaBitmapsRamAvailable or 0) / 1024

    rfsuite.utils.log(string.format("[%s] Main stack available: %.2f KB", location, mainStackKB), "info")
    rfsuite.utils.log(string.format("[%s] System RAM available: %.2f KB", location, ramKB), "info")
    rfsuite.utils.log(string.format("[%s] Lua RAM available: %.2f KB", location, luaRamKB), "info")
    rfsuite.utils.log(string.format("[%s] Lua Bitmap RAM available: %.2f KB", location, luaBitmapsRamKB), "info")
end




function utils.onReboot()
    rfsuite.session.resetSensors    = true
    rfsuite.session.resetTelemetry  = true
    rfsuite.session.resetMSP        = true
    rfsuite.session.resetMSPSensors = true
end

--- Parses a version string into a table of numbers.
-- Splits by numeric components and returns a table where each element is a number from the version string.
-- The table starts with 0 as the first element.
-- @param versionString string: The version string to parse (e.g., "1.2.3").
-- @return table|nil: A table of numbers representing the version, or nil if the input is nil.
function utils.splitVersionStringToNumbers(versionString)
    if not versionString then return nil end

    local parts = { 0 } -- start with 0
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

-- advanced compare function for version strings that should avoid issues
-- with floating point roundings
-- apiVersionCompare(op, req)
-- op:  one of ">", "<", ">=", "<=", "==", "!=", "~="
-- req: required version ("12.09", 12.09, or "12.9.1")
function utils.apiVersionCompare(op, req)
    local function parts(x)
        local t = {}
        for n in tostring(x):gmatch("(%d+)") do
            t[#t+1] = tonumber(n)
        end
        return t
    end

    local a, b = parts(rfsuite.session.apiVersion or 12.06), parts(req)
    if #a == 0 or #b == 0 then return false end

    -- pad shorter list with zeros
    local len = math.max(#a, #b)
    local cmp = 0
    for i = 1, len do
        local ai = a[i] or 0
        local bi = b[i] or 0
        if ai ~= bi then
            cmp = (ai > bi) and 1 or -1
            break
        end
    end

    if op == ">"  then return cmp == 1 end
    if op == "<"  then return cmp == -1 end
    if op == ">=" then return cmp >= 0 end
    if op == "<=" then return cmp <= 0 end
    if op == "==" then return cmp == 0 end
    if op == "!=" or op == "~=" then return cmp ~= 0 end

    return false -- unknown operator
end


return utils
