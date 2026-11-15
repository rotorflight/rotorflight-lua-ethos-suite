-- NovaFly-Theme-Menue: die Farbe des Cockpits, gemerkt je Modell wie jede rfsuite-Theme-Einstellung
local rf = package.loaded.rfsuite
if rf == nil and type(package.loaded["rfsuite.lib.require"]) == "function" then
    local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
    if ok then rf = r end
end
local DEUTSCH = tostring((system.getLocale and system.getLocale()) or ""):sub(1, 2) == "de"
local FARBEN = DEUTSCH and {{"Blau", 1}, {"Magenta", 2}, {"Gruen", 3}, {"Orange", 4}, {"Gelb", 5}, {"Carbon", 6}, {"Carbon gruen", 7}, {"Carbon violett", 8}, {"Carbon rot", 9}}
                        or {{"Blue", 1}, {"Magenta", 2}, {"Green", 3}, {"Orange", 4}, {"Yellow", 5}, {"Carbon", 6}, {"Carbon green", 7}, {"Carbon violet", 8}, {"Carbon red", 9}}
local wahl = 1

local function dash() return rf and rf.widgets and rf.widgets.dashboard end

local function configure()
    local d = dash()
    wahl = tonumber(d and d.getPreference and d.getPreference("farbe")) or 1
    local zeile = form.addLine(DEUTSCH and "Farbe" or "Colour")
    form.addChoiceField(zeile, nil, FARBEN, function() return wahl end, function(v) wahl = v end)
end

local function write()
    local d = dash()
    if d and d.savePreference then d.savePreference("farbe", wahl) end
end

return {configure = configure, write = write}
