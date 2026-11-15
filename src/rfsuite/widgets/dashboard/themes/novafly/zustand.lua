-- NovaFly-Cockpit: ein Feld ueber den ganzen Schirm; cockpit.lua wird einmal geladen und dient allen drei Flugphasen
local cockpit = package.loaded["novafly.cockpit"]
if cockpit == nil then
    local rf = package.loaded.rfsuite
    if rf == nil and type(package.loaded["rfsuite.lib.require"]) == "function" then
        local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
        if ok then rf = r end
    end
    local cfg = rf and rf.config or {}
    for _, ort in ipairs({"SCRIPTS:/" .. tostring(cfg.preferences or "rfsuite.user") .. "/dashboard/novafly/",
                          "SCRIPTS:/" .. tostring(cfg.baseDir or "rfsuite") .. "/widgets/dashboard/themes/novafly/"}) do
        local chunk = loadfile(ort .. "cockpit.lua")
        if chunk then
            local ok, modul = pcall(chunk, ort)
            if ok and type(modul) == "table" then cockpit = modul break end
        end
    end
    package.loaded["novafly.cockpit"] = cockpit
end
if cockpit then return cockpit.zustand() end
return {layout = {cols = 1, rows = 1, padding = 0}, boxes = {}}
