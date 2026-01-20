--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local rateprofile = {}

local runOnce = false

function rateprofile.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
      -- we use rotorflight rates for 12.09 and above
      rfsuite.config.defaultRateProfile = 6
      rfsuite.utils.log("Default Rate Profile: ROTORFLIGHT", "info")
      rfsuite.utils.log("Default Rate Profile: ROTORFLIGHT", "console")
    else
      -- we use actual rates for below 12.09
      rfsuite.config.defaultRateProfile = 4 
      rfsuite.utils.log("Default Rate Profile: ACTUAL", "info")
      rfsuite.utils.log("Default Rate Profile: ACTUAL", "console")
    end  

    runOnce = true

end

function rateprofile.reset() runOnce = false end

function rateprofile.isComplete() return runOnce end

return rateprofile
