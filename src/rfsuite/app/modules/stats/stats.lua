--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apidata = {
  api = {
    [1] = "FLIGHT_STATS_INI"
  },
  formdata = {
    labels = {},
    fields = {
      { t = "@i18n(app.modules.stats.totalflighttime)@", mspapi = 1, apikey = "totalflighttime" },
      { t = "@i18n(app.modules.stats.flightcount)@", mspapi = 1, apikey = "flightcount" }
    }
  }
}

return {apidata = apidata, eepromWrite = false, reboot = false, API = {}}
