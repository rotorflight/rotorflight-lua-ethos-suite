--[[ 
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local arg = { ... }
local config = arg[1]

local bbl = {}



function bbl.wakeup()

    local totalSize = rfsuite.session.bblSize
    local usedSize  = rfsuite.session.bblUsed

    -- Set displayValue, Fallback if no value
    local displayValue
    local percentUsed
    if totalSize and usedSize then
        local usedMB  = usedSize  / (1024 * 1024)
        local totalMB = totalSize / (1024 * 1024)
        percentUsed = totalSize > 0 and (usedSize / totalSize) * 100 or 0

        local decimals = 1
        local transformedUsed  = usedMB
        local transformedTotal = totalMB
        displayValue = string.format("%." .. decimals .. "f/%." .. decimals .. "f %s",
            transformedUsed, transformedTotal, rfsuite.i18n.get("app.modules.fblstatus.megabyte"))
    else
        displayValue =  "-"
        percentUsed = nil
    end

    rfsuite.session.toolbox.bbl = displayValue

end


return bbl
