--[[
  Aegis dashboard theme configuration
  GPLv3
]] --

local rfsuite = require("rfsuite")
local tonumber = tonumber
local floor = math.floor
local pairs = pairs

local config = {}

local DEFAULTS = {
    rpm_max = 2500,
    bec_min = 6.5,
    bec_warn = 7.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function getPref(key)
    return rfsuite.widgets.dashboard.getPreference(key)
end

local function setPref(key, value)
    rfsuite.widgets.dashboard.savePreference(key, value)
end

local function loadConfig()
    for key, default in pairs(DEFAULTS) do
        config[key] = tonumber(getPref(key)) or default
    end

    -- Migrate the original 8.0 V default, which is too high for a normal
    -- 7.2 V BEC. User-entered values other than exactly 8.0 V are preserved.
    if config.bec_warn == 8 then config.bec_warn = DEFAULTS.bec_warn end

    config.rpm_max = clamp(config.rpm_max, 100, 20000)
    config.bec_min = clamp(config.bec_min, 2.0, 14.8)
    config.bec_warn = clamp(config.bec_warn, config.bec_min + 0.1, 15.0)
    config.esc_warn = clamp(config.esc_warn, 0, 199)
    config.esc_max = clamp(config.esc_max, config.esc_warn + 1, 200)
    config.fuel_warn = clamp(config.fuel_warn, 1, 99)
    config.link_warn = clamp(config.link_warn, 1, 99)
end

local function addField(line, lo, hi, getter, setter, step, suffix, decimals)
    local field = form.addNumberField(line, nil, lo, hi, getter, setter, step)
    if decimals then field:decimals(decimals) end
    if suffix then field:suffix(suffix) end
    return field
end

local function configure()
    loadConfig()

    local flight = form.addExpansionPanel("Flight instruments")
    flight:open(true)

    addField(
        flight:addLine("Maximum headspeed"),
        100, 20000,
        function() return config.rpm_max end,
        function(v) config.rpm_max = clamp(tonumber(v) or DEFAULTS.rpm_max, 100, 20000) end,
        10, "rpm"
    )

    local power = form.addExpansionPanel("Power system")
    power:open(false)

    addField(
        power:addLine("BEC critical"),
        20, 150,
        function() return floor(config.bec_min * 10 + 0.5) end,
        function(v)
            config.bec_min = clamp((tonumber(v) or 20) / 10, 2.0, config.bec_warn - 0.1)
        end,
        nil, "V", 1
    )

    addField(
        power:addLine("BEC caution below"),
        20, 150,
        function() return floor(config.bec_warn * 10 + 0.5) end,
        function(v)
            config.bec_warn = clamp((tonumber(v) or 150) / 10, config.bec_min + 0.1, 15.0)
        end,
        nil, "V", 1
    )

    addField(
        power:addLine("Fuel warning"),
        1, 99,
        function() return config.fuel_warn end,
        function(v) config.fuel_warn = clamp(tonumber(v) or DEFAULTS.fuel_warn, 1, 99) end,
        1, "%"
    )

    local thermal = form.addExpansionPanel("Thermal limits")
    thermal:open(false)

    addField(
        thermal:addLine("ESC warning"),
        0, 199,
        function() return config.esc_warn end,
        function(v)
            config.esc_warn = clamp(tonumber(v) or DEFAULTS.esc_warn, 0, config.esc_max - 1)
        end,
        1, "°C"
    )

    addField(
        thermal:addLine("ESC maximum"),
        1, 200,
        function() return config.esc_max end,
        function(v)
            config.esc_max = clamp(tonumber(v) or DEFAULTS.esc_max, config.esc_warn + 1, 200)
        end,
        1, "°C"
    )

    local radio = form.addExpansionPanel("Radio link")
    radio:open(false)

    addField(
        radio:addLine("Link warning"),
        1, 99,
        function() return config.link_warn end,
        function(v) config.link_warn = clamp(tonumber(v) or DEFAULTS.link_warn, 1, 99) end,
        1, "%"
    )
end

local function write()
    for key in pairs(DEFAULTS) do
        setPref(key, config[key])
    end
end

return {configure = configure, write = write}
