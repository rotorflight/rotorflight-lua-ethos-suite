--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


local data = {}

data['help'] = {}

local defaultHelp = {
    "@i18n(app.modules.profile_tailrotor.help_p1)@",
    "@i18n(app.modules.profile_tailrotor.help_p2)@",
    "@i18n(app.modules.profile_tailrotor.help_p3)@",
    "@i18n(app.modules.profile_tailrotor.help_p4)@"
}

if rfsuite.utils.apiVersionCompare("<=", {12, 0, 7}) then
    defaultHelp[#defaultHelp + 1] = "@i18n(app.modules.profile_tailrotor.help_p5)@"
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    defaultHelp[#defaultHelp + 1] = "@i18n(app.modules.profile_governor.help_p6)@"
end

data['help']['default'] = defaultHelp

data['fields'] = {}

return data
