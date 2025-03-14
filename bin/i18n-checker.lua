-- Lua script to check missing translation keys in language files
-- Accepts a folder parameter instead of scanning automatically

local function normalize_path(path)
    return path:gsub("\\", "/")  -- Normalize Windows backslashes to Unix-style slashes
end

local function get_language_files(directory)
    local lang_files = {}
    local p = io.popen('ls -1 "' .. directory .. '" 2>/dev/null || dir /b "' .. directory .. '"')
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
            local nested_keys = extract_keys(value, full_key .. ".")
            for _, nested_key in ipairs(nested_keys) do
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
    
    -- If the result is a table, use it
    if type(result) == "table" then
        return result
    end
    
    -- If not, try to find the correct named table (e.g., 'en', 'de', 'es')
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
        print("\nChecking missing keys for:", full_path, "\n") -- Improved file path clarity
        local lang_translations = load_translation(full_path)
        if lang_translations then
            local missing_keys = {}
            for _, key in ipairs(reference_keys) do
                if not key_exists(lang_translations, key) then
                    table.insert(missing_keys, "    " .. key) -- Indent missing keys for readability
                end
            end
            if #missing_keys > 0 then
                print(table.concat(missing_keys, "\n"))
            else
                print("    All keys present.")
            end
        else
            print("Warning: Missing or unreadable translation file:", full_path)
        end
    end
end

-- Get directory from command-line argument
local folder = arg[1]
if not folder then
    print("Usage: lua script.lua <folder-path>")
    os.exit(1)
end
check_translations(normalize_path(folder))
