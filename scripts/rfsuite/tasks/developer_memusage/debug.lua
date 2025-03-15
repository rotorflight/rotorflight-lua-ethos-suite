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

 * This task is a developer debug tool.  It simply runs a schedule 
 * task to print current memory usage to the console.

 * This can be done by setting the ENABLE_TASK flag to true or false.

 * It can be usefull when using the task to enable the config.logMSP 
 * flag in main.lua. This will print out the msp request and response.

]] --

local arg = {...}

local  debug = {}

local prevluaRamAvailable = 0
local prevluaBitmapsRamAvailable = 0

function debug.wakeup()
    -- quick exit - this is the normal behaviour
    if system:getVersion().simulation == false then
        return
    end

    local mem = system.getMemoryUsage()

    -- Calculate differences
    local ramChange = mem.luaRamAvailable - prevluaRamAvailable
    local bmpChange = mem.luaBitmapsRamAvailable - prevluaBitmapsRamAvailable

    -- Function to log ASCII sad face for negative values
    local function logNegativeChange(name, value)
        if value < 0 then
            rfsuite.utils.log(name .. " WARNING: Memory Decreased!", "info")
            rfsuite.utils.log("     .-\"\"\"\"\"\"-.     ", "info")
            rfsuite.utils.log("   .'          '.   ", "info")
            rfsuite.utils.log("  |  O      O   |  ", "info")
            rfsuite.utils.log("  |    .--.     |  ", "info")
            rfsuite.utils.log("   '.  .__.   .'   ", "info")
            rfsuite.utils.log("     '-.....-'     ", "info")
            rfsuite.utils.log(name .. " Change: " .. string.format("%.2fkB", value / 1000), "info")
            rfsuite.utils.log("-------------------------------------------------------", "info")
        end
    end

    -- Store previous values
    prevluaRamAvailable = mem.luaRamAvailable
    prevluaBitmapsRamAvailable = mem.luaBitmapsRamAvailable

    -- Log only if memory decreased
    logNegativeChange("luaRamAvailable", ramChange)
    logNegativeChange("luaBitmapsRamAvailable", bmpChange)
end





return debug
