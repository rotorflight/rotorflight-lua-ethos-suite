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

]] --

local i18n = {}

-- Default language
local defaultLocale = "en"

-- Centralized language folder
local folder = "i18n"

-- Loaded translations table
local translations = {}

--[[
    deepMerge - Recursively merges two tables.
    
    This function takes two tables, `base` and `new`, and merges the contents of `new` into `base`.
    If a key in `new` corresponds to a table in both `base` and `new`, the function will recursively
    merge the tables. Otherwise, the value from `new` will overwrite the value in `base`.

    @param base table: The base table that will be modified.
    @param new table: The table whose contents will be merged into the base table.
]]
local function deepMerge(base, new)
    for k, v in pairs(new) do
        if type(v) == "table" and type(base[k]) == "table" then
            deepMerge(base[k], v)
        else
            base[k] = v
        end
    end
end

--[[
    Attempts to load a language file from the specified filepath.

    Logs the process of loading the file at various stages for debugging purposes.

    @param filepath (string) - The path to the language file to be loaded.

    @return (table or nil) - Returns a table containing the language data if the file is successfully loaded and valid.
                             Returns nil if the file does not exist, cannot be loaded, or is corrupted/invalid.
]]
local function loadLangFile(filepath)
    rfsuite.utils.log("i18n: Attempting to load file: " .. filepath, "debug")

    local chunk, err = loadfile(filepath)
    if not chunk then
        rfsuite.utils.log("i18n: ERROR - Syntax error in language file: " .. filepath .. " - " .. err, "info")
        return nil
    end
    
    local success, result = pcall(chunk)
    if not success then
        rfsuite.utils.log("i18n: ERROR - Runtime error in language file: " .. filepath .. " - " .. result, "info")
        return nil
    end
    
    if type(result) ~= "table" then
        rfsuite.utils.log("i18n: ERROR - Invalid return type in language file: " .. filepath, "info")
        return nil
    end

    return result
end

--[[
    Loads language files for a given language code from a specified base path.

    @param langCode string: The language code to load (e.g., "en", "fr").
    @param basePath string: The base directory path to start searching for language files.
    @param parentKey string: The parent key used for nested directories (optional).

    @return table: A table containing the merged language data from all found language files.

    The function performs the following steps:
    1. Lists all files and directories in the base path.
    2. Iterates over each item in the directory.
    3. Skips the current (".") and parent ("..") directory entries.
    4. Constructs the sub-path for each item.
    5. Checks if the item is a directory.
    6. If it is a directory, constructs the path to the language file within that directory.
    7. Logs the path of the language file being checked.
    8. If the language file exists, loads its data and merges it into the language data table.
    9. Recursively checks deeper folders for additional language files.
    10. Merges any found sub-directory language data into the main language data table.
    11. Returns the final merged language data table.
--]]
local function loadLangFiles(langCode, basePath, parentKey)
    local langData = {}

    local items = system.listFiles(basePath) or {}
    for _, item in ipairs(items) do

        if item == "." or item == ".." then
            goto continue
        end

        local subPath = basePath .. "/" .. item

        -- Ensure it's a directory before checking inside
        if rfsuite.utils.dir_exists(basePath, item) and not item:match("%.lua$") then
            local langFile = subPath .. "/" .. langCode .. ".lua"

            rfsuite.utils.log("i18n: Checking for language file: " .. langFile, "debug")

            if rfsuite.utils.file_exists(langFile) then
                local fileData = loadLangFile(langFile)
                if fileData then
                    -- **Ensure this translation is placed in a subtable**
                    langData[item] = langData[item] or {}
                    deepMerge(langData[item], fileData)
                end
            end

            -- Recursively check deeper folders ONLY IF subPath is a directory
            local subLangData = loadLangFiles(langCode, subPath, item)
            if next(subLangData) then  -- Prevent empty tables
                langData[item] = langData[item] or {}
                deepMerge(langData[item], subLangData)
            end
        end

        ::continue::
    end

    return langData
end

--[[
    Loads translations for the specified locale or falls back to the default locale if not found.

    @param locale (string) - The locale to load translations for. If nil, the system locale or default locale will be used.

    The function performs the following steps:
    1. Determines the locale to use based on the provided argument, system locale, or default locale.
    2. Logs the locale being loaded.
    3. Attempts to load translations from a file corresponding to the locale.
    4. Attempts to load additional translations from subdirectories.
    5. If any translations are found, they are assigned to the `translations` table.
    6. If no translations are found for the requested locale, it falls back to the default locale (English).
    7. Logs a message if falling back to the default locale.
    8. Merges translations from the default locale file and subdirectories into the `translations` table.
--]]
function i18n.load(locale)
    locale = locale or system.getLocale() or defaultLocale
    rfsuite.utils.log("i18n: Loading translations for locale: " .. locale, "debug")

    local localeFile = folder .. "/" .. locale .. ".lua"
    local localeTranslations = loadLangFile(localeFile)

    local localeDirTranslations = loadLangFiles(locale, folder, "")

    if localeTranslations or next(localeDirTranslations) then
        -- Use requested language if any translations are found
        translations = localeTranslations or {}
        for k, v in pairs(localeDirTranslations) do
            translations[k] = v  -- Assign subdirectory translations without merging
        end
    else
        -- Fallback to English if the requested language is completely missing
        rfsuite.utils.log("i18n: Requested language not found, falling back to English", "debug")
        local baseFile = folder .. "/" .. defaultLocale .. ".lua"
        translations = loadLangFile(baseFile) or {}

        local baseDirTranslations = loadLangFiles(defaultLocale, folder, "")
        for k, v in pairs(baseDirTranslations) do
            translations[k] = v
        end
    end

end

--[[
    Retrieves a translation value for a given key.

    @param key (string) - The key to look up in the translations table.

    @return string: The translation value corresponding to the key, or the key itself if no translation is found.
]]
function i18n.get(key)
    local value = translations
    for part in string.gmatch(key, "([^%.]+)") do
        if type(value) ~= "table" then
            return key
        end
        value = value[part]
    end

    if value == nil then
        return key
    end

    return value
end

return i18n
