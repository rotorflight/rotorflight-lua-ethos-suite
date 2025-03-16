-- Lua script to recursively check missing translation keys in language files
-- Scans all subdirectories for i18n files and processes them
-- Usage: lua i18n-checker.lua <root-folder>

local function normalize_path(path)
    return path:gsub("\\", "/"):gsub("//", "/")  -- Normalize slashes
end

local function print_divider()
    print("----------------------------------------------------------------------------------------------------")
end

local function get_subdirectories(directory)
    local subdirs = {}
    local command = package.config:sub(1,1) == "\\" 
        and ('dir /b /ad "%s" 2>nul'):format(directory)  -- Windows
        or ('ls -1 "%s" 2>/dev/null'):format(directory)  -- Linux/macOS

    local p = io.popen(command)
    if p then
        for dir in p:lines() do
            local full_path = normalize_path(directory .. "/" .. dir)
            if full_path ~= "." and full_path ~= ".." then
                table.insert(subdirs, full_path)
            end
        end
        p:close()
    end
    return subdirs
end

local function get_language_files(directory)
    local lang_files = {}
    local command = package.config:sub(1,1) == "\\" 
        and ('dir /b "%s" 2>nul'):format(directory)  -- Windows
        or ('ls -1 "%s" 2>/dev/null'):format(directory)  -- Linux/macOS

    local p = io.popen(command)
    if p then
        for file in p:lines() do
            if file:match("%.lua$") and file ~= "en.lua" then
                table.insert(lang_files, file)
            end
        end
        p:close()
    end
    return lang_files
end

local function extract_keys(tbl, prefix)
    local keys = {}
    prefix = prefix or ""
    for key, value in pairs(tbl) do
        local full_key = prefix .. key
        if type(value) == "table" then
            for _, nested_key in ipairs(extract_keys(value, full_key .. ".")) do
                table.insert(keys, nested_key)
            end
        else
            table.insert(keys, full_key)
        end
    end
    return keys
end

local function key_exists(tbl, key_path)
    local current = tbl
    for segment in key_path:gmatch("[^%.]+") do
        if type(current) ~= "table" or current[segment] == nil then
            return false
        end
        current = current[segment]
    end
    return true
end

local function get_translation(tbl, key_path)
    local current = tbl
    for segment in key_path:gmatch("[^%.]+") do
        if type(current) ~= "table" or current[segment] == nil then
            return nil
        end
        current = current[segment]
    end
    return current
end

local function load_translation(file_path)
    local env = {}
    local chunk, err = loadfile(file_path, "t", env)
    if not chunk then
        print("Error loading", file_path, err)
        return nil
    end
    
    local success, result = pcall(chunk)
    if not success then
        print("Error executing", file_path, result)
        return nil
    end
    
    if type(result) == "table" then
        return result
    end
    
    local lang_code = file_path:match("([^/]+)%.lua$")
    if lang_code and env[lang_code] and type(env[lang_code]) == "table" then
        return env[lang_code]
    end
    
    print("Warning: No valid translation table found in:", file_path)
    return nil
end

local function check_translations(directory)
    local reference_file = normalize_path(directory .. "/en.lua")
    local reference_translations = load_translation(reference_file)
    if not reference_translations then
        print("Skipping directory: Failed to load en.lua in", directory)
        return
    end

    local reference_keys = extract_keys(reference_translations)
    local lang_files = get_language_files(directory)
    
    for _, lang_file in ipairs(lang_files) do
        local full_path = normalize_path(directory .. "/" .. lang_file)
        io.write("[OK] Checking: " .. full_path:gsub("^%.%./", "") .. "  -> ")

        local lang_translations = load_translation(full_path)
        if lang_translations then
            local missing_keys = {}
            for _, key in ipairs(reference_keys) do
                if not key_exists(lang_translations, key) then
                    local en_text = get_translation(reference_translations, key)
                    local en_display = en_text and (' (English: "' .. tostring(en_text) .. '")') or ""
                    table.insert(missing_keys, "    " .. key .. en_display)
                end
            end
            if #missing_keys > 0 then
                print("\n[WARNING] Missing keys:\n" .. table.concat(missing_keys, "\n"))
            else
                print("All keys present.")
            end
        else
            print("[WARNING] Missing or unreadable translation file.")
        end
    end
end

local function scan_for_translation_dirs(root_folder)
    for _, dir in ipairs(get_subdirectories(root_folder)) do
        local en_file = dir .. "/en.lua"
        local f = io.open(en_file, "r")
        if f then
            f:close()
            print_divider()
            print("[INFO] Processing translation folder: " .. dir:gsub("^%.%./", ""))
            print_divider()
            check_translations(dir)
        else
            scan_for_translation_dirs(dir)  -- Recursively scan deeper
        end
    end
end

-- Get root directory from command-line argument
local root_folder = arg[1]
if not root_folder then
    print("Usage: lua i18n-checker.lua <root-folder>")
    os.exit(1)
end

scan_for_translation_dirs(normalize_path(root_folder))
