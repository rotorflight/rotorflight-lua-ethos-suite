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

local i18n = {}

local locale = system.getLocale()

function i18n.wakeup()

    rfsuite.session.locale = system.getLocale()

    -- lets reload the language file
    if rfsuite.session.locale ~= locale then
        rfsuite.utils.log("i18n: Switching locale to: " .. rfsuite.session.locale, "info")
        rfsuite.i18n.load(rfsuite.session.locale)
        locale = rfsuite.session.locale

        -- step through and fire language swap events
        for i,v in pairs(rfsuite.widgets) do
            if v.i18n then
                rfsuite.utils.log("i18n: Running i18n event for widget: " .. i, "info")
                v.i18n()
            end
        end



    end

   rfsuite.i18n.wakeup()

end

return i18n
