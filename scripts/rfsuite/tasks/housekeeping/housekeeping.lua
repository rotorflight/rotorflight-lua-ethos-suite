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
local arg = {...}

local housekeeping = {}


function housekeeping.wakeup()

        -- run app housekeeping if defined
        if rfsuite.app and rfsuite.app.housekeeping then
                rfsuite.app.housekeeping()
        end
        
        -- run widget housekeeping if defined
        if rfsuite.widgets then
                for i,v in pairs(rfsuite.widgets) do
                        if v.housekeeping then
                                v.housekeeping()
                        end
                end
        end

end

return housekeeping
