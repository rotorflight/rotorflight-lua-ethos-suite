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

data['help']['default'] = {"PID Bandwidth: Overall bandwidth in HZ used by the PID loop.", "D-term cutoff: D-term cutoff frequency in HZ.", "B-term cutoff: B-term cutoff frequency in HZ."}

data['fields'] = {profilesPIDBandwidth = {t = "PID loop overall bandwidth in Hz."}, profilesPIDBandwidthDtermCutoff = {t = "D-term cutoff in Hz."}, profilesPIDBandwidthBtermCutoff = {t = "B-term cutoff in Hz."}}

return data
