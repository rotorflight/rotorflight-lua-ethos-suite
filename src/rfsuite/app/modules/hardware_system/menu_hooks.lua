--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local GOV_RULES = {
    {">=", "12.09", "governor/governor.lua", loaderspeed = "FAST"},
    {"<", "12.09", "governor/governor_legacy.lua", loaderspeed = "SLOW"}
}

return {
    title = "@i18n(app.modules.hardware_system.name)@",
    pages = {
        {name = "@i18n(app.modules.failsafe.name)@", script = "failsafe/failsafe.lua", image = "app/modules/failsafe/failsafe.png"},
        {name = "Modes", script = "modes/modes.lua", image = "app/modules/modes/modes.png", loaderspeed = 0.05},
        {name = "@i18n(app.modules.adjustments.name)@", script = "adjustments/adjustments.lua", image = "app/modules/adjustments/adjustments.png", loaderspeed = 0.1},
        {name = "@i18n(app.modules.filters.name)@", script = "filters/filters.lua", image = "app/modules/filters/filters.png"},
        {name = "@i18n(app.modules.power.name)@", script = "power/power.lua", image = "app/modules/power/power.png"},
        {name = "@i18n(app.modules.governor.name)@", script = "governor/governor.lua", image = "app/modules/governor/governor.png", script_by_mspversion = GOV_RULES}
    },
    navOptions = {defaultSection = "hardware", showProgress = true},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false}
}
