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

The lua files in this folder are the 'default' files that will be used
if you do not have an external simtelemetry folder

If you want the ability to dynamically change sensors - you can copy the
contents of this folder to:

/scripts/rfsuite.simtelemetry/

you would expect for example to see:

/scripts/rfsuite.simtelemetry/voltage.lua
etc..

If the file does not load.. you get the one in this folder instead!