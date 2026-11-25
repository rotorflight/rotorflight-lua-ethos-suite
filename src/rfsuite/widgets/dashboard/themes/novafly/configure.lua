-- NovaFly theme menu: the colour of the cockpit and the mode (dark or light), kept per model like every theme setting of the suite
local rf = package.loaded.rfsuite
if rf == nil and type(package.loaded["rfsuite.lib.require"]) == "function" then
    local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
    if ok then rf = r end
end
local GERMAN = tostring((system.getLocale and system.getLocale()) or ""):sub(1, 2) == "de"
local COLORS = GERMAN and {{"Blau", 1}, {"Magenta", 2}, {"Gruen", 3}, {"Orange", 4}, {"Gelb", 5}, {"Carbon", 6}, {"Carbon gruen", 7}, {"Carbon violett", 8}, {"Carbon rot", 9}}
                        or {{"Blue", 1}, {"Magenta", 2}, {"Green", 3}, {"Orange", 4}, {"Yellow", 5}, {"Carbon", 6}, {"Carbon green", 7}, {"Carbon violet", 8}, {"Carbon red", 9}}
local MODES = GERMAN and {{"Dunkel", 1}, {"Hell", 2}} or {{"Dark", 1}, {"Light", 2}}
local color, mode = 1, 1

local function dash() return rf and rf.widgets and rf.widgets.dashboard end

local function configure()
    local d = dash()
    color = tonumber(d and d.getPreference and d.getPreference("color")) or 1   -- English keys (the maintainers' rule)
    mode = tonumber(d and d.getPreference and d.getPreference("mode")) or 1
    local line = form.addLine(GERMAN and "Farbe" or "Colour")
    form.addChoiceField(line, nil, COLORS, function() return color end, function(v) color = v end)
    line = form.addLine(GERMAN and "Modus" or "Mode")
    form.addChoiceField(line, nil, MODES, function() return mode end, function(v) mode = v end)
end

local function write()
    local d = dash()
    if d and d.savePreference then
        d.savePreference("color", color)
        d.savePreference("mode", mode)
    end
end

return {configure = configure, write = write}
