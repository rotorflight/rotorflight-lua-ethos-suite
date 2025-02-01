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
--[[

* This task triggers every 5 seconds and will only execute if config.apiTester is == true
* The purpose of this task is to allow easy testing of read/write api files from a developer 
* point of view.
*
* Templates for creating a new MSP api can be found in:
*  rfsuite/tasks/msp/api/template/*.lua
*
* choose a read or write api and customise it to suite.

]]--

local arg = {...}
local config = arg[1]

local apitester = {}


function apitester.wakeup()

    -- quick exit if we have not enabled apiTester mode
    if config.apiTester == nil or config.apiTester == false then
        return
    end

    -- add in test functions below


    --[[  EXAMPLE READ
            local API = rfsuite.bg.msp.api.load("MSP_GOVERNOR_CONFIG")
            API.read()  
            if API.readComplete() then
                    local value = API.readValue("gov_mode")
                    local data = API.data()

                    rfsuite.utils.print_r(data)
            end     
            
            or 

            local API = rfsuite.bg.msp.api.load("MSP_GOVERNOR_CONFIG")
            API.setCompleteHandler(function(self, buf) 
                    local data = API.data()

                    rfsuite.utils.print_r(data)
            end
            API.setErrorHandler(function(self, buf) 
                    local data = API.data()

                    rfsuite.utils.print_r(data)
            end    
            )   
            API.read()  
    ]]--

    --[[  EXAMPLE WRITE
            local API = rfsuite.bg.msp.api.load("MSP_SET_RTC")
            API.write()  
            if API.writeComplete() then
                rfsuite.config.clockSet = true
                rfsuite.utils.log("Sync clock: " .. os.clock())
            end        

            or

            local API = rfsuite.bg.msp.api.load("MSP_SET_RTC")
            API.setCompleteHandler(function(self, buf) 
                print("error")
            end
            API.setErrorHandler(function(self, buf) 
                print("error")
            end               
            API.write()  
  

    ]]--

    --local API = rfsuite.bg.msp.api.load("MSP_PID_TUNING")
    --API.read()  
    --if API.readComplete() then
    --        local data = API.data()
    --        --rfsuite.utils.print_r(data['processed'])
    --        rfsuite.utils.print_r(data)
    --end   


  


end    

return apitester
