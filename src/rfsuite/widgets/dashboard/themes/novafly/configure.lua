-- NovaFly theme menu: the colour of the cockpit and the mode (dark or light), kept per model like every theme setting of the suite
local rf = package.loaded.rfsuite
if rf == nil and type(package.loaded["rfsuite.lib.require"]) == "function" then
    local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
    if ok then rf = r end
end
local COLORS = {{"@i18n(widgets.dashboard.novafly.blue)@", 1}, {"@i18n(widgets.dashboard.novafly.magenta)@", 2}, {"@i18n(widgets.dashboard.novafly.green)@", 3}, {"@i18n(widgets.dashboard.novafly.orange)@", 4}, {"@i18n(widgets.dashboard.novafly.yellow)@", 5},
                {"@i18n(widgets.dashboard.novafly.carbon)@", 6}, {"@i18n(widgets.dashboard.novafly.carbon_green)@", 7}, {"@i18n(widgets.dashboard.novafly.carbon_violet)@", 8}, {"@i18n(widgets.dashboard.novafly.carbon_red)@", 9}}
local MODES = {{"@i18n(widgets.dashboard.novafly.dark)@", 1}, {"@i18n(widgets.dashboard.novafly.light)@", 2}}
local color, mode = 1, 1

local function dash() return rf and rf.widgets and rf.widgets.dashboard end

local function configure()
    local d = dash()
    color = tonumber(d and d.getPreference and d.getPreference("color")) or 1   -- English keys (the maintainers' rule)
    mode = tonumber(d and d.getPreference and d.getPreference("mode")) or 1
    local line = form.addLine("@i18n(widgets.dashboard.novafly.colour)@")
    form.addChoiceField(line, nil, COLORS, function() return color end, function(v) color = v end)
    line = form.addLine("@i18n(widgets.dashboard.novafly.mode)@")
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
