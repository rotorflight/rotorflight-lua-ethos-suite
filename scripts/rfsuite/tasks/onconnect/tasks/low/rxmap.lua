--[[
 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 
]] --

local rxmap = {}

function rxmap.wakeup()
    
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if (rfsuite.session.rxmap and not rfsuite.session.rxmap.collective) then
        local API = rfsuite.tasks.msp.api.load("RX_MAP")
        API.setCompleteHandler(function(self, buf)
            local aileron = API.readValue("aileron")
            local elevator = API.readValue("elevator")
            local collective = API.readValue("collective")
            local rudder = API.readValue("rudder")
            local aux1 = API.readValue("aux1")
            local throttle = API.readValue("throttle")
            local aux2 = API.readValue("aux2")
            local aux3 = API.readValue("aux3")

            rfsuite.session.rxmap = {
                aileron = aileron,
                elevator = elevator,
                collective = collective,
                rudder = rudder,
                aux1 = aux1,
                throttle = throttle,
                aux2 = aux2,
                aux3 = aux3
            }

            rfsuite.utils.log(
                "RX Map: Aileron: " .. aileron ..
                ", Elevator: " .. elevator ..
                ", Collective: " .. collective ..
                ", Rudder: " .. rudder ..
                ", Aux1: " .. aux1 ..
                ", Throttle: " .. throttle ..
                ", Aux2: " .. aux2 ..
                ", Aux3: " .. aux3,
                "info"
            )

        end)
        API.setUUID("b3e5c8a4-5f3e-4e2c-9f7d-2e7a1c4b8f21")
        API.read()
    end    

end

function rxmap.reset()
    rfsuite.session.rxmap = nil
end

function rxmap.isComplete()
    if rfsuite.session.rxmap and rfsuite.session.rxmap.collective then
        return true
    end
end

return rxmap