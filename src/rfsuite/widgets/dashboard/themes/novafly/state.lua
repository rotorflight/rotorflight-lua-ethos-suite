-- NovaFly cockpit: one box over the whole screen; cockpit.lua is loaded once and serves all three flight phases
local rf = nil
if type(package.loaded["rfsuite.lib.require"]) == "function" then
    local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
    if ok then rf = r end
end
local cfg = rf and rf.config or {}
local userDir = "SCRIPTS:/" .. tostring(cfg.preferences or "rfsuite.user") .. "/dashboard/novafly/"
local suiteDir = "SCRIPTS:/" .. tostring(cfg.baseDir or "rfsuite") .. "/widgets/dashboard/themes/novafly/"
local choice = rf and rf.preferences and rf.preferences.dashboard   -- the suite's choice: user/novafly is the pilot's copy, otherwise the shipped theme runs
local isUser = false
if type(choice) == "table" then
    for _, k in ipairs({"theme_preflight", "theme_inflight", "theme_postflight", "theme"}) do
        if choice[k] == "user/novafly" then isUser = true end
    end
end
local dirs = isUser and {userDir, suiteDir} or {suiteDir, userDir}
local cockpit = package.loaded["novafly.cockpit"]
if cockpit == nil or cockpit.dir ~= dirs[1] then   -- none yet, or the other copy's: the chosen one first, the other only when the chosen one is missing
    for _, dir in ipairs(dirs) do
        if cockpit ~= nil and cockpit.dir == dir then break end
        local chunk = loadfile(dir .. "cockpit.lua")
        if chunk then
            local ok, mod = pcall(chunk, dir)
            if ok and type(mod) == "table" then cockpit = mod break end
        end
    end
    package.loaded["novafly.cockpit"] = cockpit
end
if cockpit then return cockpit.state() end
return {layout = {cols = 1, rows = 1, padding = 0}, boxes = {}}
