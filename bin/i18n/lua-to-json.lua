local json = dofile("dkjson.lua")

local rawRoot = "raw"
local outRoot = "json"

-- Detect OS
local isWindows = package.config:sub(1, 1) == "\\"

-- Get list of files in a directory
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

-- Check if path is directory
local function isDir(path)
    local test = isWindows
        and ('if exist "%s\\" (echo d)'):format(path)
        or ('[ -d "%s" ] && echo d'):format(path)
    local pipe = io.popen(test)
    local result = pipe:read("*a")
    pipe:close()
    return result:match("d")
end

-- Flatten nested tables
local function flatten(tbl, prefix, out)
    out = out or {}
    prefix = prefix or ""
    for k, v in pairs(tbl) do
        local key = prefix .. (prefix ~= "" and "." or "") .. k
        if type(v) == "table" then
            flatten(v, key, out)
        else
            out[key] = v
        end
    end
    return out
end

-- Load Lua table from file
local function loadTable(filepath)
    local ok, result = pcall(dofile, filepath)
    if ok and type(result) == "table" then
        return result
    else
        print("⚠️  Failed to load:", filepath)
        return {}
    end
end

-- Recursively walk the raw/ tree
local function scanDir(path, rel)
    rel = rel or ""
    local fullPath = path .. (rel ~= "" and "/" .. rel or "")
    for _, entry in ipairs(listDir(fullPath)) do
        local entryPath = rel ~= "" and (rel .. "/" .. entry) or entry
        local fullEntryPath = fullPath .. "/" .. entry
        if isDir(fullEntryPath) then
            scanDir(path, entryPath)
        elseif entry:match("^(%w+)%.lua$") and not entry:match("^en%.lua$") then
            local lang = entry:match("^(%w+)%.lua$")
            local dir = entryPath:match("(.+)/" .. lang .. "%.lua$") or ""
            local enPath = path .. "/" .. dir .. "/en.lua"
            local trPath = path .. "/" .. entryPath
            local outPath = outRoot .. "/" .. dir .. "/" .. lang .. ".json"

            local en = flatten(loadTable(enPath))
            local tr = flatten(loadTable(trPath))
            local combined = {}

            for k, v in pairs(en) do
                combined[k] = {
                    english = v,
                    translation = tr[k] or ""
                }
            end

            -- Ensure output folder exists
            local mkdirCmd = isWindows
                and ('mkdir "%s" >nul 2>nul'):format(outRoot .. "/" .. dir)
                or ('mkdir -p "%s" 2>/dev/null'):format(outRoot .. "/" .. dir)
            os.execute(mkdirCmd)

            local outFile = io.open(outPath, "w")
            outFile:write(json.encode(combined, { indent = true }))
            outFile:close()

            print("✅ Wrote", outPath)
        end
    end
end

-- Start from raw/
scanDir(rawRoot)
