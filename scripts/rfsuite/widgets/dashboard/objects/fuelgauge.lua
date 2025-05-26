local render = {}

local baseDir = rfsuite.config.baseDir or "default"
local gaugeObj = assert(rfsuite.compiler.loadfile("SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/gauge.lua"))()

-- Fuel Gauge Box: Easy, ready-to-use fuel gauge for end users.
function render.fuelgauge(x, y, w, h, box, telemetry)

    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    -- Default parameters for fuel gauge
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

    -- Allow box to override defaults if user provided (for flexibility)
    local fuelBox = {}
    for k,v in pairs(defaults) do fuelBox[k] = v end
    for k,v in pairs(box or {}) do fuelBox[k] = v end

    -- Use the existing gaugeBox rendering logic (re-uses your existing styling)
    return gaugeObj.gauge(x, y, w, h, fuelBox, telemetry)
end

return render