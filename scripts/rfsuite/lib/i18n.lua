-- Simplified i18n.lua (compatible with merged per-language Lua files)

local i18n = {}

-- Config
local defaultLocale = "en"
local folder = "i18n"  -- where en.lua, fr.lua etc. are stored

-- Translation state
local translations = {}
local keyCache = {}

-- Helper: load a single Lua translation file
local function loadLangFile(filepath)
    local chunk, err = loadfile(filepath)
    if not chunk then return nil end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then return nil end
    return result
end

-- Load locale (fallback to English if necessary)
function i18n.load(locale)
    keyCache = {}
    locale = locale or system.getLocale() or defaultLocale

    local filePath = folder .. "/" .. locale .. ".lua"
    translations = loadLangFile(filePath)

    if not translations then
        rfsuite.utils.log("i18n: Locale '" .. locale .. "' not found, falling back to '" .. defaultLocale .. "'", "info")
        translations = loadLangFile(folder .. "/" .. defaultLocale .. ".lua") or {}
    end
end

-- Get value from nested table using dot notation
function i18n.get(key)
    if keyCache[key] ~= nil then return keyCache[key] end

    local value = translations
    for part in string.gmatch(key, "[^%.]+") do
        if type(value) ~= "table" then
            keyCache[key] = key
            return key
        end
        value = value[part]
    end

    if value == nil then
        keyCache[key] = key
        return key
    end

    keyCache[key] = value
    return value
end

return i18n
