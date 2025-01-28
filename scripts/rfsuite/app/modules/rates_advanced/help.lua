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
local data = {}

data['help'] = {}

data['help']['default'] = {
        "Rates type: Choose the rate type you prefer flying with. Raceflight and Actual are the most straightforward.",
        "Dynamics: Applied regardless of rates type. Typically left on defaults but can be adjusted to smooth heli movements, like with scale helis."
}

data['fields'] = {
    profilesRatesDynamicsTime = {t = "Increase or decrease the response time of the rate to smooth heli movements."},
    profilesRatesDynamicsAcc = {t = "Maximum acceleration of the craft in response to a stick movement."},
}

return data
