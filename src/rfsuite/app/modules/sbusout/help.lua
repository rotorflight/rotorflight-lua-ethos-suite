--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local data = {}

data['help'] = {}

data['help']['default'] = {"@i18n(app.modules.sbusout.help_default_p1)@", "@i18n(app.modules.sbusout.help_default_p2)@", "@i18n(app.modules.sbusout.help_default_p3)@", "@i18n(app.modules.sbusout.help_default_p4)@", "@i18n(app.modules.sbusout.help_default_p5)@"}

data['fields'] = {sbusOutSource = {t = "@i18n(app.modules.sbusout.help_fields_source)@"}, sbusOutMin = {t = "@i18n(app.modules.sbusout.help_fields_min)@"}, sbusOutMax = {t = "@i18n(app.modules.sbusout.help_fields_max)@"}}

return data
