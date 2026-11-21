-- NovaFly-Cockpit: ein Feld ueber den ganzen Schirm; cockpit.lua wird einmal geladen und dient allen drei Flugphasen
local rf = package.loaded.rfsuite
if rf == nil and type(package.loaded["rfsuite.lib.require"]) == "function" then
    local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
    if ok then rf = r end
end
local cfg = rf and rf.config or {}
local benutzerOrt = "SCRIPTS:/" .. tostring(cfg.preferences or "rfsuite.user") .. "/dashboard/novafly/"
local suiteOrt = "SCRIPTS:/" .. tostring(cfg.baseDir or "rfsuite") .. "/widgets/dashboard/themes/novafly/"
local wahl = rf and rf.preferences and rf.preferences.dashboard   -- die Auswahl der Suite: user/novafly ist die Kopie des Piloten, sonst laeuft die mitgelieferte Fassung
local benutzer = false
if type(wahl) == "table" then
    for _, k in ipairs({"theme_preflight", "theme_inflight", "theme_postflight", "theme"}) do
        if wahl[k] == "user/novafly" then benutzer = true end
    end
end
local orte = benutzer and {benutzerOrt, suiteOrt} or {suiteOrt, benutzerOrt}
local cockpit = package.loaded["novafly.cockpit"]
if cockpit == nil or cockpit.ort ~= orte[1] then   -- noch keins, oder das der anderen Fassung: die gewaehlte zuerst, die andere nur, wenn es die gewaehlte nicht gibt
    for _, ort in ipairs(orte) do
        if cockpit ~= nil and cockpit.ort == ort then break end
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
