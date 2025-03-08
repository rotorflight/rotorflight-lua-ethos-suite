--[[
 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 
]] --

--[[ 
 * i18n System for Rotorflight Project
 * Centralized i18n system supporting 3-level nested keys
]]--

local i18n = {}

-- Default language
local defaultLocale = 'en'

-- Centralized language folder
local folder = 'i18n'

-- Loaded translations table
local translations = {}

-- Set the locale
function i18n.setLocale(newLocale)
    locale = newLocale
    rfsuite.utils.log("i18n: Locale set to: " .. locale, "info")
end

-- Load a language file, returns the table inside (or empty if file not found)
local function loadLangFile(lang)
    local filepath = string.format("%s/%s.lua", folder, lang)
    local chunk,err = assert(loadfile(filepath))

    -- hard error or we get no debug info
    if err then
        error("i18n: Error loading language file: " .. err)
    end

    if not chunk then
        rfsuite.utils.log("i18n: Language file not found: " .. filepath, "info")
        return {} -- No file found, fallback to empty table
    end

    rfsuite.utils.log("i18n: Loaded language file: " .. filepath, "info")
    return chunk()
end

-- Load translations, ensuring missing keys fall back to English
function i18n.load(locale)

    -- use default if not set
    if locale == nil then
        locale = system.getLocale()
    end

    rfsuite.utils.log("i18n: Loading translations for locale: " .. locale, "info")

    -- Load default English translations first
    translations = loadLangFile(defaultLocale)

    -- Merge with selected locale if different
    if locale ~= defaultLocale then
        local override = loadLangFile(locale)
        for k, v in pairs(override) do
            translations[k] = v -- Overwrite English with target language
        end
    end

    rfsuite.utils.log("i18n: Translations loaded for locale: " .. locale, "info")
end

-- Lookup function to get translations, supporting 3-level keys (e.g., "widgets.governor.OFF")
function i18n.get(key)
    local value = translations
    for part in string.gmatch(key, "([^%.]+)") do
        value = value and value[part] -- Drill down into nested tables
    end

    if not value then
        rfsuite.utils.log("i18n: Missing translation for key: " .. key, "info")
        return key -- Fallback to key itself if missing
    end

    return value
end

return i18n
