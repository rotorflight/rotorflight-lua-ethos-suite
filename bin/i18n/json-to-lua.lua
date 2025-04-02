local json = dofile("lib/dkjson.lua")

local jsonRoot = "json"
local rawRoot = "../../scripts/rfsuite/i18n"

local isWindows = package.config:sub(1, 1) == "\\"
local generatedEn = {}  -- Track dirs where en.lua has been written

-- List files
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

-- Is directory?
local function isDir(path)
    local cmd = isWindows
        and ('if exist "%s\\\" (echo d)'):format(path)
        or ('[ -d "%s" ] && echo d'):format(path)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result:match("d")
end

-- Create dir
local function ensureDir(path)
    local cmd = isWindows
        and ('mkdir "%s" >nul 2>nul'):format(path)
        or ('mkdir -p "%s" 2>/dev/null'):format(path)
    os.execute(cmd)
end

-- Unflatten keys
local function unflatten(flat)
    local nested = {}
    for key, value in pairs(flat) do
        local current = nested
        for part in string.gmatch(key, "[^%.]+") do
            if not current[part] then current[part] = {} end
            if part == key:match("[^%.]+$") then
                current[part] = value
            else
                current = current[part]
            end
        end
    end
    return nested
end

-- Lua table serializer
local function serializeLuaTable(tbl, indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    local parts = {"{\n"}
    for k, v in pairs(tbl) do
        local key = string.format("[%q]", k)
        if type(v) == "table" then
            table.insert(parts, string.format("%s%s = %s,\n", nextIndent, key, serializeLuaTable(v, nextIndent)))
        else
            table.insert(parts, string.format("%s%s = %q,\n", nextIndent, key, v))
        end
    end
    table.insert(parts, indent .. "}")
    return table.concat(parts)
end

-- Scan recursively
local function scanDir(path, rel)
    rel = rel or ""
    local fullPath = path .. (rel ~= "" and "/" .. rel or "")
    for _, entry in ipairs(listDir(fullPath)) do
        local entryPath = rel ~= "" and (rel .. "/" .. entry) or entry
        local fullEntryPath = fullPath .. "/" .. entry
        if isDir(fullEntryPath) then
            scanDir(path, entryPath)
        elseif entry:match("^(%w+)%.json$") then
            local lang = entry:match("^(%w+)%.json$")
            local inFile = path .. "/" .. entryPath
            local outPath = rawRoot .. "/" .. entryPath:gsub("%.json$", ".lua")
            local outDir = outPath:match("(.+)/[^/]+%.lua$")

            ensureDir(outDir)

            local file = io.open(inFile, "r")
            local content = file:read("*a")
            file:close()

            local parsed = json.decode(content)
            local flatTr = {}
            local flatEn = {}

            for k, v in pairs(parsed) do
                flatTr[k] = v.translation or ""
                flatEn[k] = v.english or ""
            end

            local nestedTr = unflatten(flatTr)
            local nestedEn = unflatten(flatEn)

            -- Write translation file
            local out = io.open(outPath, "w")
            out:write("return ")
            out:write(serializeLuaTable(nestedTr))
            out:close()
            print("✅ Wrote", outPath)

            -- Write English file (once per folder)
            if not generatedEn[outDir] then
                local enOutPath = outDir .. "/en.lua"
                local enOut = io.open(enOutPath, "w")
                enOut:write("return ")
                enOut:write(serializeLuaTable(nestedEn))
                enOut:close()
                print("✅ Wrote", enOutPath)
                generatedEn[outDir] = true
            end
        end
    end
end

-- Run
scanDir(jsonRoot)
