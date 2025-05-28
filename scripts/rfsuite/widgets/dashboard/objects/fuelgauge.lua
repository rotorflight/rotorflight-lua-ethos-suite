local render = {}

local baseDir = rfsuite.config.baseDir or "default"
local gaugeObj = assert(rfsuite.compiler.loadfile("SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/gauge.lua"))()

local defaults = {
    source = "fuel",  -- Telemetry source
    gaugemin = 0,
    gaugemax = 100,
    gaugeorientation = "vertical",
    gaugepadding = 4,
    gaugebelowtitle = true,
    title = "FUEL",
    unit = "%",
    color = "white",
    valuealign = "center",
    titlealign = "center",
    titlepos = "bottom",
    titlecolor = "white",
    gaugecolor = "green",
    thresholds = {
        { value = 20,  color = "red",    textcolor = "white" },
        { value = 50,  color = "orange", textcolor = "black" }
    }
}

function render.wakeup(box)
    -- Merge defaults and user box (user overrides)
    local fuelBox = {}
    for k,v in pairs(defaults) do fuelBox[k] = v end
    for k,v in pairs(box or {}) do fuelBox[k] = v end

    -- If thresholds contain function values, evaluate now (not needed here, but for consistency):
    if type(fuelBox.thresholds) == "table" then
        for i, t in ipairs(fuelBox.thresholds) do
            if type(t.value) == "function" then
                fuelBox.thresholds[i] = {}
                for k,v in pairs(t) do fuelBox.thresholds[i][k] = v end
                fuelBox.thresholds[i].value = t.value()
            end
        end
    end

    box._cache = fuelBox
end

function render.paint(x, y, w, h, box, telemetry)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local fuelBox = box._cache or box -- fallback for legacy use
    return gaugeObj.gauge(x, y, w, h, fuelBox, telemetry)
end

return render
