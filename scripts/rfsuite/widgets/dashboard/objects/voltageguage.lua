local render = {}

local baseDir = rfsuite.config.baseDir or "default"
local gaugeObj = assert(rfsuite.compiler.loadfile("SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/gauge.lua"))()

function render.voltagegauge(x, y, w, h, box, telemetry)

    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    -- Default parameters for voltage gauge
    local defaults = {
        source = "voltage",  -- Telemetry source
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        gaugemax = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        gaugebgcolor = "gray",
        gaugeorientation = "horizontal",
        gaugepadding = 4,
        gaugebelowtitle = true,
        title = "VOLTAGE",
        unit = "V",
        color = "black",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        gaugecolor = "green",
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2 -- 20% above minimum voltage
                end,
                color = "red", textcolor = "white"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                color = "orange", textcolor = "black"
            }
        }
    }

    -- Allow box to override defaults if provided
    local voltBox = {}
    for k,v in pairs(defaults) do voltBox[k] = v end
    for k,v in pairs(box or {}) do voltBox[k] = v end

    return gaugeObj.gauge(x, y, w, h, voltBox, telemetry)
end

return render