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
local i18n = {}

-- Default language
local defaultLocale = 'en'

-- Path to language files
local folder = 'languages'

-- Loaded translations table
local translations = {}

-- Current locale (defaulted to system locale, can be overridden later)
--local locale = system.getLocale() or defaultLocale

-- Set the folder to read language files from
function i18n.setFolder(path)
    folder = path
    rfsuite.utils.log("i18n: Folder set to: " .. folder, "info")
end

-- Set (or override) the locale
function i18n.setLocale(newLocale)
    locale = newLocale
    rfsuite.utils.log("i18n: Locale set to: " .. locale, "info")
end

-- Load a language file, returns the table inside (or empty if file not found)
local function loadLangFile(lang)
    local filepath = string.format("%s/%s.lua", folder, lang)
    local chunk = loadfile(filepath)

    if not chunk then
        rfsuite.utils.log("i18n: Language file not found: " .. filepath, "info")
        return {} -- No file found, fallback to empty table
    end

    rfsuite.utils.log("i18n: Loaded language file: " .. filepath, "info")
    return chunk()
end

-- Load and merge language, falling back to English if keys are missing
function i18n.load(locale)
    rfsuite.utils.log("i18n: Loading translations for locale: " .. locale, "info")

    translations = loadLangFile(defaultLocale) -- Start with English base

    if locale ~= defaultLocale then
        local override = loadLangFile(locale)
        for k, v in pairs(override) do
            translations[k] = v -- overwrite English with target language
        end
    end

    rfsuite.utils.log("i18n: Translations loaded for locale: " .. locale, "info")
end

-- Lookup function to get a translation
function i18n.get(key)
    if translations[key] then
        return translations[key]
    else
        rfsuite.utils.log("i18n: Missing translation for key: " .. key, "info")
        return key -- fallback to the key itself if missing
    end
end

return i18n
