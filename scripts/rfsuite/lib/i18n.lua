local i18n = {}

-- Default language
local defaultLocale = "en"

-- Centralized language folder
local folder = "i18n"

-- Loaded translations table
local translations = {}

local function deepMerge(base, new)
    for k, v in pairs(new) do
        if type(v) == "table" and type(base[k]) == "table" then
            deepMerge(base[k], v)
        else
            base[k] = v
        end
    end
end

-- Load a language file safely
local function loadLangFile(filepath)
    rfsuite.utils.log("i18n: Attempting to load file: " .. filepath, "debug")

    if not rfsuite.utils.file_exists(filepath) then
        rfsuite.utils.log("i18n: ERROR - File does not exist: " .. filepath, "debug")
        return nil
    end

    local chunk, err = loadfile(filepath)
    if not chunk then
        rfsuite.utils.log("i18n: ERROR - Could not load language file: " .. filepath, "debug")
        return nil
    end

    local success, result = pcall(chunk)
    if not success or type(result) ~= "table" then
        rfsuite.utils.log("i18n: ERROR - Corrupted or invalid language file: " .. filepath, "debug")
        return nil
    end

    return result
end

-- Recursively search for en.lua inside subdirectories
-- Recursively search for en.lua inside subdirectories
local function loadLangFiles(langCode, basePath, parentKey)
    local langData = {}

    local items = system.listFiles(basePath) or {}
    for _, item in ipairs(items) do

        if item == "." or item == ".." then
            goto continue
        end

        local subPath = basePath .. "/" .. item

        -- Ensure it's a directory before checking inside
        if rfsuite.utils.dir_exists(basePath, item) then
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


-- Load translations, ensuring missing keys fall back to English
-- Load translations, strictly using requested language or English if missing
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




-- Get translation by key (supports nested lookup)
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
