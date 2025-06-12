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

local rxmap = {}

local channelNames = {
    "aileron",
    "elevator",
    "collective",
    "rudder",
    "throttle",
    "aux1",
    "aux2",
    "aux3"
}

local channelSources = {} 

function rxmap.wakeup()

    if rfsuite.utils.rxmapReady() then

        -- Only populate channelSources once
        if next(channelSources) == nil then
            for i,v in ipairs(channelNames) do
                local src = system.getSource({category = CATEGORY_CHANNEL, member = (rfsuite.session.rx.map[v]), options = 0})
                if src then
                    channelSources[v] = src
                end
            end
        end

        for v, src in pairs(channelSources) do
            local channelValue = src:value()
            if channelValue ~= nil then
                rfsuite.session.rx.values[v] = channelValue
            end
        end
    end

end

function rxmap.reset()
    -- Clear all stored stats and force a full rebuild on next wakeup()
end

return rxmap
