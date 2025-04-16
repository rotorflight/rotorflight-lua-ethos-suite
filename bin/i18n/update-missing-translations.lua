local json = dofile("lib/dkjson.lua")

local jsonRoot = "json"
local isWindows = package.config:sub(1,1) == "\\"

-- List directory contents
local function listDir(path)
    local cmd = isWindows
        and ('dir /b "%s" 2>nul'):format(path)
        or ('ls -1 "%s" 2>/dev/null'):format(path)
    local pipe = io.popen(cmd)
    local result = {}
    for line in pipe:lines() do
        table.insert(result, line)
    end
    pipe:close()
    return result
end

-- Check if path is a directory
local function isDir(path)
    local cmd = isWindows
        and ('if exist "%s\\" (echo d)'):format(path)
        or ('[ -d "%s" ] && echo d'):format(path)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result:match("d")
end

-- Recursively gather subdirectories
local function collectDirs(path, rel, dirs)
    rel = rel or ""
    dirs = dirs or {}
    local fullPath = path .. (rel ~= "" and "/" .. rel or "")
    for _, entry in ipairs(listDir(fullPath)) do
        local entryRel = rel ~= "" and (rel .. "/" .. entry) or entry
        local entryFull = fullPath .. "/" .. entry
        if isDir(entryFull) then
            table.insert(dirs, entryFull)
            collectDirs(path, entryRel, dirs)
        end
    end
    return dirs
end

-- Get sorted key order from table
local function getKeyOrder(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys) -- Remove if you prefer raw insertion order
    return keys
end

-- Rebuild translation table using ref structure and key order
local function buildOrderedTranslation(ref, target, order)
    local new = {}
    order = order or getKeyOrder(ref) -- 👈 ensure it's never nil
    for _, key in ipairs(order) do
        local refVal = ref[key]
        local tgtVal = target and target[key]
        if type(refVal) == "table" and refVal.english ~= nil and refVal.translation ~= nil then
            if type(tgtVal) == "table" and tgtVal.translation then
                new[key] = {
                    english = refVal.english,
                    translation = tgtVal.translation,
                    needs_translation = tgtVal.needs_translation or "false"
                }
            else
                new[key] = {
                    english = refVal.english,
                    translation = refVal.english,
                    needs_translation = "true"
                }
            end
        elseif type(refVal) == "table" then
            local subOrder = getKeyOrder(refVal)
            new[key] = buildOrderedTranslation(refVal, tgtVal or {}, subOrder)
        else
            new[key] = refVal
        end
    end
    return new
end

-- Process a translation directory
local function processDirectory(dirPath)
    local files = listDir(dirPath)
    local enFilePath = nil
    for _, filename in ipairs(files) do
        if filename == "en.json" then
            enFilePath = dirPath .. "/" .. filename
            break
        end
    end

    if not enFilePath then return end

    local f = io.open(enFilePath, "r")
    if not f then return end
    local enContent = f:read("*a")
    f:close()

    local enData, _, enOrder = json.decode(enContent, 1, nil)
    if not enData then
        print("Failed to decode", enFilePath)
        return
    end

    for _, filename in ipairs(files) do
        if filename:match("^(%w+)%.json$") and filename ~= "en.json" then
            local filePath = dirPath .. "/" .. filename
            local f2 = io.open(filePath, "r")
            if f2 then
                local content = f2:read("*a")
                f2:close()
                local data = json.decode(content) or {}

                local rebuilt = buildOrderedTranslation(enData, data, enOrder)

                local outFile = io.open(filePath, "w")
                if outFile then
                    outFile:write(json.encode(rebuilt, {
                        keyorder = enOrder,
                        indent = true,
                    }))
                    outFile:close()
                    print("Updated:", filePath)
                else
                    print("Could not open for writing:", filePath)
                end
            end
        end
    end
end

-- Run the updater
local function updateMissingTranslations()
    processDirectory(jsonRoot)
    local dirs = collectDirs(jsonRoot)
    for _, dir in ipairs(dirs) do
        processDirectory(dir)
    end
end

updateMissingTranslations()
