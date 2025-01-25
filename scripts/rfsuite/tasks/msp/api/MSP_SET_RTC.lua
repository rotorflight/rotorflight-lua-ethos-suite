--[[
 * Copyright (C) Rotorflight Project
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
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
]] --

--[[
 * MSP_SET_RTC Write API
 * --------------------
 * This module provides functions to set the real-time clock (RTC) using the MSP protocol.
 * The write function sends the current system time to the device, formatted as seconds since the epoch.
 *
 * Functions:
 * - write(): Initiates an MSP command to set the RTC.
 * - writeComplete(): Checks if the write operation is complete.
 * - resetWriteStatus(): Resets the write completion status.
 *
 * MSP Command Used:
 * - MSP_SET_RTC (Command ID: 246)
]] --


-- Constants for MSP Commands
local MSP_SET_RTC_CMD = 246  -- Command identifier for setting RTC

-- Define the MSP request data structure
local MSP_SET_RTC_STRUCTURE = {
    { field = "seconds", type = "U32" },  -- 32-bit seconds since epoch
    { field = "milliseconds", type = "U16" }  -- 16-bit milliseconds
}

-- Variable to track write completion
local mspWriteComplete = false

-- Function to initiate MSP write operation
local function write()
    local message = {
        command = MSP_SET_RTC_CMD,  -- Specify the MSP command
        payload = {},
        processReply = function(self, buf)
            mspWriteComplete = true
        end,
        simulatorResponse = {}
    }

    -- Get current time and format it for payload
    local now = os.time()
    rfsuite.bg.msp.mspHelper.writeU32(message.payload, now)  -- Write seconds
    rfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)    -- Placeholder for milliseconds

    -- Add the message to the processing queue
    rfsuite.bg.msp.mspQueue:add(message)
end

-- Function to check if the write operation is complete
local function writeComplete()
    return mspWriteComplete
end

-- Function to reset the write completion status
local function resetWriteStatus()
    mspWriteComplete = false
end

-- Return the module's API functions
return {
    write = write,
    writeComplete = writeComplete,
    resetWriteStatus = resetWriteStatus
}
