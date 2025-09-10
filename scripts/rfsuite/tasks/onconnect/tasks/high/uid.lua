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

local uid = {}

local mspCallMade = false

function uid.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if (rfsuite.session.mcu_id == nil and mspCallMade == false)  then


        mspCallMade = true

        local API = rfsuite.tasks.msp.api.load("UID")
        API.setCompleteHandler(function(self, buf)
            local U_ID_0 = API.readValue("U_ID_0")
            local U_ID_1 = API.readValue("U_ID_1")
            local U_ID_2 = API.readValue("U_ID_2")
        
            if U_ID_0 and U_ID_1 and U_ID_2 then
                local function u32_to_hex_le(u32)
                    local b1 = u32 & 0xFF
                    local b2 = (u32 >> 8) & 0xFF
                    local b3 = (u32 >> 16) & 0xFF
                    local b4 = (u32 >> 24) & 0xFF
                    return string.format("%02x%02x%02x%02x", b1, b2, b3, b4)
                end
            
                local uid = u32_to_hex_le(U_ID_0) .. u32_to_hex_le(U_ID_1) .. u32_to_hex_le(U_ID_2)
                if uid then
                    rfsuite.utils.log("MCU ID: " .. uid, "info")
                end
                rfsuite.session.mcu_id = uid
            end


        end)
        API.setUUID("a3e5f2d7-9c4b-4e6a-b8f1-3d7e2c9a1f45")
        API.read()  
    end

end

function uid.reset()
    rfsuite.session.mcu_id = nil
    mspCallMade = false
end

function uid.isComplete()
    if rfsuite.session.mcu_id ~= nil  then
        return true
    end
end

return uid