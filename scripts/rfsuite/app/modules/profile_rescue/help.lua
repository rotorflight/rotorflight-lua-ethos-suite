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

data['help']['default'] = {"Flip to upright: Flip the heli upright when rescue is activated.", "Pull-up: How much collective and for how long to arrest the fall.", "Climb: How much collective to maintain a steady climb - and how long.", "Hover: How much collective to maintain a steady hover.", "Flip: How long to wait before aborting because the flip did not work.",
                           "Gains: How hard to fight to keep heli level when engaging rescue mode.", "Rate and Accel: Max rotation and acceleration rates when leveling during rescue."}

data['fields'] = {
    profilesRescueFlipMode = {t = "If rescue is activated while inverted, flip to upright - or remain inverted."},
    profilesRescuePullupCollective = {t = "Collective value for pull-up climb."},
    profilesRescuePullupTime = {t = "When rescue is activated, helicopter will apply pull-up collective for this time period before moving to flip or climb stage."},
    profilesRescueClimbCollective = {t = "Collective value for rescue climb."},
    profilesRescueClimbTime = {t = "Length of time the climb collective is applied before switching to hover."},
    profilesRescueHoverCollective = {t = "Collective value for hover."},
    profilesRescueFlipTime = {t = "If the helicopter is in rescue and is trying to flip to upright and does not within this time, rescue will be aborted."},
    profilesRescueExitTime = {t = "This limits rapid application of negative collective if the helicopter has rolled during rescue."},
    profilesRescueLevelGain = {t = "Determine how agressively the heli levels during rescue."},
    profilesRescueFlipGain = {t = "Determine how agressively the heli flips during inverted rescue."},
    profilesRescueMaxRate = {t = "Limit rescue roll/pitch rate. Larger helicopters may need slower rotation rates."},
    profilesRescueMaxAccel = {t = "Limit how fast the helicopter accelerates into a roll/pitch. Larger helicopters may need slower acceleration."}
}

return data
