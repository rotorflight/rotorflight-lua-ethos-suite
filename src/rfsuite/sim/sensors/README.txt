--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


The lua files in this folder are the 'default' files that will be used
if you do not have an external simtelemetry folder

If you want the ability to dynamically change sensors - you can copy the
contents of this folder to:

/scripts/rfsuite.sim/sensors/

you would expect for example to see:

/scripts/rfsuite.sim/sensors/voltage.lua
etc..

If the file does not load.. you get the one in this folder instead!