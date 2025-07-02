local utils = {}

--- Resolves model name from telemetry folder's configuration file
-- @param foldername string: Name of the telemetry folder (nil returns "Unknown")
-- @return string: Model name if found in logs.ini, otherwise "Unknown"
function utils.resolveModelName(foldername)
    if foldername == nil then 
        return "Unknown" 
    end

    local iniName = "LOGS:rfsuite/telemetry/" .. foldername .. "/logs.ini"
    local iniData = rfsuite.ini.load_ini_file(iniName) or {}

    if iniData["model"] and iniData["model"].name then
        return iniData["model"].name
    end
    return "Unknown"
end


function utils.hasModelName(foldername)
    if foldername == nil then 
        return false
    end

    local iniName = "LOGS:rfsuite/telemetry/" .. foldername .. "/logs.ini"
    local iniData = rfsuite.ini.load_ini_file(iniName) or {}

    if iniData["model"] and iniData["model"].name then
        return true
    end
    return false
end

--- Retrieves and manages CSV log files in a directory
-- 1. Lists all CSV files in directory
-- 2. Extracts timestamps from filenames (YYYY-MM-DD_HH-MM-SS_ format)
-- 3. Sorts entries by timestamp (newest first)
-- 4. Keeps only 50 most recent files, deletes older ones
-- 5. Returns list of recent filenames
-- @param logDir string: Path to log directory
-- @return table: List of recent log filenames
function utils.getLogs(logDir)
    local files = system.listFiles(logDir)
    local entries = {}
    
    -- Process CSV files with valid timestamps
    for _, fname in ipairs(files) do
        if fname:match("%.csv$") then
            local date, time = fname:match("(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)_")
            if date and time then
                table.insert(entries, {
                    name = fname, 
                    ts = date .. 'T' .. time  -- ISO 8601 format for sorting
                })
            end
        end
    end

    -- Sort by timestamp (newest first)
    table.sort(entries, function(a, b) 
        return a.ts > b.ts 
    end)
    
    -- Cleanup old files (keep max 50)
    local maxEntries = 50
    for i = maxEntries + 1, #entries do
        os.remove(logDir .. "/" .. entries[i].name)
    end
    
    -- Prepare result list
    local result = {}
    for i = 1, math.min(#entries, maxEntries) do
        table.insert(result, entries[i].name)
    end
    return result
end

--- Ensures base log directory structure exists
-- @return string: Path to active log directory (if set) or base telemetry directory
function utils.getLogPath()
    -- Create directory hierarchy
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    
    -- Return active directory if available
    if rfsuite.app.activeLogDir then
        return string.format("LOGS:/rfsuite/telemetry/%s/", rfsuite.app.activeLogDir)
    end
    return "LOGS:/rfsuite/telemetry/"
end

--- Gets or creates a specific log directory
-- @param dirname string|nil: Optional subdirectory name
-- @return string: Full path to requested directory
function utils.getLogDir(dirname)
    -- Ensure base directories exist
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    
    -- Handle default case (MCU ID directory)
    if not dirname then
        local defaultDir = "LOGS:/rfsuite/telemetry/" .. rfsuite.session.mcu_id .. "/"
        os.mkdir(defaultDir)
        return defaultDir
    end

    -- Return requested directory
    return "LOGS:/rfsuite/telemetry/" .. dirname .. "/" 
end

--- Lists non-hidden subdirectories in a directory
-- @param logDir string: Path to scan
-- @return table: List of directory entries { foldername = "name" }
function utils.getLogsDir(logDir)
    local files = system.listFiles(logDir)
    local dirs = {}
    for _, name in ipairs(files) do
        -- Exclude ".", "..", names like ".log", and names ending in ".xyz"
        if not (name == "." or name == ".." or 
                name:match("^%.%w%w%w$") or 
                name:match("%.%w%w%w$")) then

                if utils.hasModelName(name) then
                    dirs[#dirs + 1] = {foldername = name}
                end    
        end
    end
    return dirs
end

return utils