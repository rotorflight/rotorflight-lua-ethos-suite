local render = {}

local baseDir = rfsuite.config.baseDir or "default"
local gaugeObj = assert(rfsuite.compiler.loadfile("SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/gauge.lua"))()

-- Default parameters for voltage gauge (only declared once)
local defaults = {
    source = "voltage",
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
                return cells * minV * 1.2
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

function render.wakeup(box, telemetry)
    -- Combine defaults with user box, evaluate functions
    local voltBox = {}
    for k, v in pairs(defaults) do voltBox[k] = v end
    for k, v in pairs(box or {}) do voltBox[k] = v end

    -- Evaluate gaugemin/gaugemax if functions
    if type(voltBox.gaugemin) == "function" then
        voltBox.gaugemin = voltBox.gaugemin()
    end
    if type(voltBox.gaugemax) == "function" then
        voltBox.gaugemax = voltBox.gaugemax()
    end

    -- Evaluate thresholds' .value if function, so they're cached per-wakeup
    if type(voltBox.thresholds) == "table" then
        for i, t in ipairs(voltBox.thresholds) do
            if type(t.value) == "function" then
                voltBox.thresholds[i] = {}
                for k,v in pairs(t) do voltBox.thresholds[i][k] = v end
                voltBox.thresholds[i].value = t.value()
            end
        end
    end

    box._cache = voltBox
end

function render.paint(x, y, w, h, box, telemetry)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local voltBox = box._cache or box -- fallback for legacy/compat
    return gaugeObj.gauge(x, y, w, h, voltBox, telemetry)
end

return render
