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

local fblinfo = {}

function fblinfo.wakeup()

    -- we defer to FBL_CONFIG api to retrieve this
    local apiVersion = tonumber(rfsuite.session.apiVersion)
    if apiVersion == nil or apiVersion <= 12.08 then
        return
    end

    if (rfsuite.session.fblinfoMode == nil) then
        local API = rfsuite.tasks.msp.api.load("FBL_CONFIG")
        API.setCompleteHandler(function(self, buf)

            -- Retrieve governor mode
            local governorMode = API.readValue("gov_mode")
            if governorMode then
                rfsuite.utils.log("Governor mode: " .. governorMode, "info")
            end
            rfsuite.session.governorMode = governorMode

            -- Retrieve FC version and RF version
            rfsuite.session.fcVersion = API.readVersion()
            rfsuite.session.rfVersion = API.readRfVersion()
            if rfsuite.session.fcVersion then
                rfsuite.utils.log("FC version: " .. rfsuite.session.fcVersion, "info")
                rfsuite.utils.log("RF version: " .. rfsuite.session.rfVersion, "info")
            end

            -- Retrieve MCU ID
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

            -- read the rxmap info
            local aileron = API.readValue("aileron")
            local elevator = API.readValue("elevator")
            local rudder = API.readValue("rudder")
            local collective = API.readValue("collective")
            local throttle = API.readValue("throttle")
            local aux1 = API.readValue("aux1")
            local aux2 = API.readValue("aux2")
            local aux3 = API.readValue("aux3")

            
            rfsuite.session.rx.map.aileron = aileron
            rfsuite.session.rx.map.elevator = elevator
            rfsuite.session.rx.map.rudder = rudder
            rfsuite.session.rx.map.collective = collective
            rfsuite.session.rx.map.throttle = throttle
            rfsuite.session.rx.map.aux1 = aux1
            rfsuite.session.rx.map.aux2 = aux2
            rfsuite.session.rx.map.aux3 = aux3

            rfsuite.utils.log(
                "RX Map: Aileron: " .. aileron ..
                ", Elevator: " .. elevator ..
                ", Rudder: " .. rudder ..
                ", Collective: " .. collective ..
                ", Throttle: " .. throttle ..
                ", Aux1: " .. aux1 ..
                ", Aux2: " .. aux2 ..
                ", Aux3: " .. aux3,
                "info"
            )            

            -- servos
            rfsuite.session.servoCount = API.readValue("servo_count")
            if rfsuite.session.servoCount then
                rfsuite.utils.log("Servo count: " .. rfsuite.session.servoCount, "info")
            end        

            -- Tail and Swash Mode
            rfsuite.session.tailMode = API.readValue("tail_rotor_mode")
            rfsuite.session.swashMode = API.readValue("swash_type")
            if rfsuite.session.tailMode and rfsuite.session.swashMode then
                rfsuite.utils.log("Tail mode: " .. rfsuite.session.tailMode, "info")
                rfsuite.utils.log("Swash mode: " .. rfsuite.session.swashMode, "info")
            end

        end)
        API.setUUID("47163617-1486-4889-8b81-7a1dd6d7edd1")
        API.read()
    end    

end

function fblinfo.reset()

    local apiVersion = tonumber(rfsuite.session.apiVersion)
    if apiVersion == nil or apiVersion <= 12.08 then
        return
    end

    rfsuite.session.governorMode = nil
    rfsuite.session.fcVersion = nil
    rfsuite.session.rfVersion = nil
    rfsuite.session.mcu_id = nil

    if rfsuite.session.rx and rfsuite.session.rx.map then
        for _, key in ipairs({
            "aileron", "elevator", "rudder", "collective", "throttle",
            "aux1", "aux2", "aux3"
        }) do
            rfsuite.session.rx.map[key] = nil
        end
    end
    rfsuite.session.rxmap = {}
    rfsuite.session.rxvalues = {}    

    rfsuite.session.tailMode = nil
    rfsuite.session.swashMode = nil

    rfsuite.session.craftName = nil

    rfsuite.session.servoCount = nil

end

function fblinfo.isComplete()

    local apiVersion = tonumber(rfsuite.session.apiVersion)
    if apiVersion == nil then
        return
    end

    if apiVersion <= 12.08 then
        return true
    end

    local isOk = 
        rfsuite.session.governorMode and
        rfsuite.session.fcVersion and
        rfsuite.session.rfVersion and
        rfsuite.session.mcu_id and
        rfsuite.session.tailMode and
        rfsuite.session.swashMode and
        rfsuite.session.craftName and
        rfsuite.session.servoCount and
        rfsuite.utils.rxmapReady()

    if isOk then
        return true
    end


end

return fblinfo