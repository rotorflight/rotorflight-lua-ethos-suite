--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local data = {}

data['help'] = {}

data['help']['default'] = {"@i18n(app.modules.fbusout.help_default_p1)@", "@i18n(app.modules.fbusout.help_default_p2)@", "@i18n(app.modules.fbusout.help_default_p3)@", "@i18n(app.modules.fbusout.help_default_p4)@", "@i18n(app.modules.fbusout.help_default_p5)@"}

data['fields'] = {fbusOutSource = {t = "@i18n(app.modules.fbusout.help_fields_source)@"}, fbusOutMin = {t = "@i18n(app.modules.fbusout.help_fields_min)@"}, fbusOutMax = {t = "@i18n(app.modules.fbusout.help_fields_max)@"}}

return data
