local utils = {}

function utils.resolveModelName(foldername)
    if foldername == nil then return "Unknown" end

    local iniName = "LOGS:rfsuite/telemetry/" .. foldername .. "/logs.ini"
    local iniData = rfsuite.ini.load_ini_file(iniName) or {}

    if iniData["model"] and iniData["model"].name then
        return iniData["model"].name
    end
    return "Unknown"
end

function utils.getLogs(logDir)
    local files = system.listFiles(logDir)
    local entries = {}
    for _, fname in ipairs(files) do
        if fname:match("%.csv$") then
            local date, time = fname:match("(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)_")
            if date and time then
                table.insert(entries, {name = fname, ts = date .. 'T' .. time})
            end
        end
    end

    table.sort(entries, function(a, b) return a.ts > b.ts end)
    local maxEntries = 50
    for i = maxEntries + 1, #entries do
        os.remove(logDir .. "/" .. entries[i].name)
    end
    local result = {}
    for i = 1, math.min(#entries, maxEntries) do
        result[#result+1] = entries[i].name
    end
    return result
end

-- Ensures the log directory exists and returns its path
function utils.getLogPath()
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    if rfsuite.session.activeLogDir then
        return string.format("LOGS:/rfsuite/telemetry/%s/", rfsuite.session.activeLogDir)
    end
    return "LOGS:/rfsuite/telemetry/"
end

function utils.getLogDir(dirname)
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    if  not dirname  then
        os.mkdir("LOGS:/rfsuite/telemetry/" .. rfsuite.session.mcu_id)
        return "LOGS:/rfsuite/telemetry/" .. rfsuite.session.mcu_id .. "/"
    end

    return "LOGS:/rfsuite/telemetry/" .. dirname .. "/" 
end

-- Lists subdirectories in a log directory
function utils.getLogsDir(logDir)
    local files = system.listFiles(logDir)
    local dirs = {}
    for _, name in ipairs(files) do
        if not name:match('^%.') then
            dirs[#dirs+1] = {foldername = name}
        end
    end
    return dirs
end


return utils