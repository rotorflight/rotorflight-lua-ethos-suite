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
-- Constants for MSP Commands
local API_NAME = "ESC_PARAMETERS_HW5" -- API name (must be same as filename)
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 
local MSP_SIGNATURE = 0xFD
local MSP_HEADER_BYTES = 2

-- some tables used in structure below
local flightMode = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_fixedwing)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_heliext)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_heligov)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_helistore)@"}
local rotation = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_ccw)@"}
local lipoCellCount = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_autocalculate)@", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "11S", "12S", "13S", "14S"}
local cutoffType = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_softcutoff)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_hardcutoff)@"}
local cutoffVoltage = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "2.8", "2.9", "3.0", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8"}
local restartTime = {"1s", "1.5s", "2s", "2.5s", "3s"}
local startupPower = {"1", "2", "3", "4", "5", "6", "7"}
local enabledDisabled = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_enabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@"}
local brakeType = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_proportional)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_reverse)@"}


-- Lookup table of model number to supported voltages
local voltage_lookup = {
    ["HW1104_V100456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW1106_V100456NB"] = {"5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4"},
    ["HW1106_V200456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW1106_V300456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW1121_V100456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW198_V1.00456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["default"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4"} -- Default voltage values
}

voltages = voltage_lookup["default"] -- Default voltage values

local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",       type = "U8", apiVersion = 12.07, simResponse = {253}, help = "@i18n(api.ESC_PARAMETERS_HW5.esc_signature)@"},
    {field = "esc_command",         type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_HW5.esc_command)@"},
    {field = "firmware_version",    type = "U128", apiVersion = 12.07, simResponse = {32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32}, help = "@i18n(api.ESC_PARAMETERS_HW5.firmware_version)@"},      
    {field = "hardware_version",    type = "U128", apiVersion = 12.07, simResponse = {72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66}, help = "@i18n(api.ESC_PARAMETERS_HW5.hardware_version)@"},    
    {field = "esc_type",            type = "U128", apiVersion = 12.07, simResponse = {80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32}, help = "@i18n(api.ESC_PARAMETERS_HW5.esc_type)@"},   
    {field = "com_version",         type = "U120", apiVersion = 12.07, simResponse = {80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32}, help = "@i18n(api.ESC_PARAMETERS_HW5.com_version)@"},  
    {field = "flight_mode",         type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #flightMode, tableIdxInc = -1, table = flightMode, help = "@i18n(api.ESC_PARAMETERS_HW5.flight_mode)@"},
    {field = "lipo_cell_count",     type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #lipoCellCount, tableIdxInc = -1, table = lipoCellCount, help = "@i18n(api.ESC_PARAMETERS_HW5.lipo_cell_count)@"},
    {field = "volt_cutoff_type",    type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #cutoffType, tableIdxInc = -1, table = cutoffType, help = "@i18n(api.ESC_PARAMETERS_HW5.volt_cutoff_type)@"},
    {field = "cutoff_voltage",      type = "U8", apiVersion = 12.07, simResponse = {3}, default = 3, min = 0, max = #cutoffVoltage, tableIdxInc = -1, table = cutoffVoltage, help = "@i18n(api.ESC_PARAMETERS_HW5.cutoff_voltage)@"},
    {field = "bec_voltage",         type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #voltages, tableIdxInc = -1, table = voltages, help = "@i18n(api.ESC_PARAMETERS_HW5.bec_voltage)@"},
    {field = "startup_time",        type = "U8", apiVersion = 12.07, simResponse = {11}, default = 0, min = 4, max = 25, unit = "s", help = "@i18n(api.ESC_PARAMETERS_HW5.startup_time)@"},
    {field = "gov_p_gain",          type = "U8", apiVersion = 12.07, simResponse = {6}, default = 0, min = 0, max = 9, help = "@i18n(api.ESC_PARAMETERS_HW5.gov_p_gain)@"},
    {field = "gov_i_gain",          type = "U8", apiVersion = 12.07, simResponse = {5}, default = 0, min = 0, max = 9, help = "@i18n(api.ESC_PARAMETERS_HW5.gov_i_gain)@"},
    {field = "auto_restart",        type = "U8", apiVersion = 12.07, simResponse = {25}, default = 25, units = "s", min = 0, max = 90, help = "@i18n(api.ESC_PARAMETERS_HW5.auto_restart)@"},
    {field = "restart_time",        type = "U8", apiVersion = 12.07, simResponse = {1}, default = 1, tableIdxInc = -1, min = 0, max = #restartTime, table = restartTime, help = "@i18n(api.ESC_PARAMETERS_HW5.restart_time)@"},
    {field = "brake_type",          type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #brakeType, xvals = {76}, table = brakeType, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_HW5.brake_type)@"},
    {field = "brake_force",         type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = 100, help = "@i18n(api.ESC_PARAMETERS_HW5.brake_force)@"},
    {field = "timing",              type = "U8", apiVersion = 12.07, simResponse = {24}, default = 0, min = 0, max = 30, help = "@i18n(api.ESC_PARAMETERS_HW5.timing)@"},
    {field = "rotation",            type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #rotation, tableIdxInc = -1, table = rotation, help = "@i18n(api.ESC_PARAMETERS_HW5.rotation)@"},
    {field = "active_freewheel",    type = "U8", apiVersion = 12.07, simResponse = {0}, min = 0, max = #enabledDisabled, table = enabledDisabled, tableIdxInc = -1, default = 0, help = "@i18n(api.ESC_PARAMETERS_HW5.active_freewheel)@"},
    {field = "startup_power",       type = "U8", apiVersion = 12.07, simResponse = {2}, default = 2, min = 0, max = #startupPower, tableIdxInc = -1, table = startupPower, help = "@i18n(api.ESC_PARAMETERS_HW5.startup_power)@"},
}

-- Process structure in one pass
local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE =
    rfsuite.tasks.msp.api.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- set read structure
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

-- Variable to store parsed MSP data
local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.tasks.msp.api.createHandlers()

-- Variables to store optional the UUID and timeout for payload
local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

-- Function to initiate MSP read operation
local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_READ,
        processReply = function(self, buf)
            local structure = MSP_API_STRUCTURE_READ
            rfsuite.tasks.msp.api.parseMSPData(buf, structure, nil, voltage_lookup, function(result) -- note.  we pass the voltage lookup table to the parseMSPData function to return as
                mspData = result
                if #buf >= MSP_MIN_BYTES then
                    local completeHandler = handlers.getCompleteHandler()
                    if completeHandler then completeHandler(self, buf) end
                end
            end)
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = suppliedPayload or rfsuite.tasks.msp.api.buildWritePayload(API_NAME, payloadData,MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE),
        processReply = function(self, buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end
            mspWriteComplete = true
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    payloadData[fieldName] = value
end

-- Function to check if the read operation is complete
local function readComplete()
    return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES
end

-- Function to check if the write operation is complete
local function writeComplete()
    return mspWriteComplete
end

-- Function to reset the write completion status
local function resetWriteStatus()
    mspWriteComplete = false
end

-- Function to return the parsed MSP data
local function data()
    return mspData
end

-- set the UUID for the payload
local function setUUID(uuid)
    MSP_API_UUID = uuid
end

-- set the timeout for the payload
local function setTimeout(timeout)
    MSP_API_MSG_TIMEOUT = timeout
end
-- Return the module's API functions
return {
    read = read,
    write = write,
    readComplete = readComplete,
    writeComplete = writeComplete,
    readValue = readValue,
    setValue = setValue,
    resetWriteStatus = resetWriteStatus,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout,
    mspSignature = MSP_SIGNATURE,
    mspHeaderBytes = MSP_HEADER_BYTES,
    simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    voltageTable = voltage_lookup,
}
