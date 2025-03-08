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

-- Load a language file safely, returns the table or nil on error
local function loadLangFile(lang)
    local filepath = string.format("%s/%s.lua", folder, lang)
    local chunk, err = loadfile(filepath)

    if not chunk then
        rfsuite.utils.log("i18n: ERROR - Language file missing or unreadable: " .. filepath, "error")
        return nil -- Return nil instead of an empty table so we can detect failures
    end

    local success, result = pcall(chunk)
    if not success or type(result) ~= "table" then
        rfsuite.utils.log("i18n: ERROR - Language file is corrupted or does not return a table: " .. filepath, "error")
        return nil
    end

    rfsuite.utils.log("i18n: Successfully loaded language file: " .. filepath, "info")
    return result
end

-- Load translations, ensuring missing keys fall back to English
function i18n.load(locale)
    -- Use system locale if none is provided
    if not locale then
        locale = system.getLocale() or defaultLocale
    end

    rfsuite.utils.log("i18n: Attempting to load translations for locale: " .. locale, "info")

    -- Load English first
    local baseTranslations = loadLangFile(defaultLocale)
    if not baseTranslations then
        rfsuite.utils.log("i18n: CRITICAL ERROR - Default language file ('en.lua') could not be loaded. Fallback not possible!", "error")
        return
    end

    translations = baseTranslations -- Start with English as the base

    -- Try to load the selected locale, but only overwrite if valid
    if locale ~= defaultLocale then
        local overrideTranslations = loadLangFile(locale)
        if overrideTranslations then
            for k, v in pairs(overrideTranslations) do
                translations[k] = v -- Overwrite English values with the target language
            end
            rfsuite.utils.log("i18n: Successfully merged translations for locale: " .. locale, "info")
        else
            rfsuite.utils.log("i18n: WARNING - Falling back to English. Could not load requested locale: " .. locale, "warn")
        end
    end
end

-- Lookup function to get translations, supporting 3-level keys (e.g., "widgets.governor.OFF")
function i18n.get(key)
    local value = translations
    for part in string.gmatch(key, "([^%.]+)") do
        value = value and value[part] -- Drill down into nested tables
    end

    if not value then
        rfsuite.utils.log("i18n: WARNING - Missing translation for key: " .. key, "warn")
        return key -- Fallback to key itself if missing
    end

    return value
end

return i18n

