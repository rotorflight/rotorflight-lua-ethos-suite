--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "GOVERNOR_CONFIG"
local MSP_API_CMD_READ = 142
local MSP_API_CMD_WRITE = 143
local MSP_REBUILD_ON_WRITE = false

local MSP_API_STRUCTURE_READ_DATA

-- LuaFormatter off
if rfsuite.utils.apiVersionCompare(">=", "12.09") then
    local gov_modeTable = {
        [0] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_off)@",
        [1] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_limit)@",
        [2] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_direct)@",
        [3] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_electric)@",
        [4] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_nitro)@"
    }
    local throttleTypeTable = {
        [0] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_normal)@",
        [1] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_switch)@",
        [2] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_function)@",
    }

    MSP_API_STRUCTURE_READ_DATA = {
        {field = "gov_mode", type = "U8", apiVersion = 12.09, simResponse = {2}, min = 0, max = #gov_modeTable, table = gov_modeTable, help = "@i18n(api.GOVERNOR_CONFIG.gov_mode)@"},
        {field = "gov_startup_time", type = "U16", apiVersion = 12.09, simResponse = {200, 0}, min = 0, max = 600, unit = "", default = 200, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_startup_time)@"},
        {field = "gov_spoolup_time", type = "U16", apiVersion = 12.09, simResponse = {100, 0}, min = 0, max = 600, unit = "%/s", default = 100, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_spoolup_time)@"},
        {field = "gov_tracking_time", type = "U16", apiVersion = 12.09, simResponse = {20, 0}, min = 0, max = 100, unit = "%/s", default = 10, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_tracking_time)@"},
        {field = "gov_recovery_time", type = "U16", apiVersion = 12.09, simResponse = {20, 0}, min = 0, max = 100, unit = "%/s", default = 21, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_recovery_time)@"},
        {field = "gov_throttle_hold_timeout", type = "U16", apiVersion = 12.09, simResponse = {50, 0}, min = 0, max = 250, unit = "s", default = 5, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_throttle_hold_timeout)@"},
        {field = "spare_0", type = "U16", apiVersion = 12.09, simResponse = {0, 0}}, 
        {field = "gov_autorotation_timeout", type = "U16", apiVersion = 12.09, unit = "s", min = 0, max = 250, simResponse = {0, 0}, help = "@i18n(api.GOVERNOR_CONFIG.gov_autorotation_timeout)@"},  
        {field = "spare_1", type = "U16", apiVersion = 12.09, simResponse = {0, 0}},
        {field = "spare_2", type = "U16", apiVersion = 12.09, simResponse = {0, 0}},
        {field = "gov_handover_throttle", type = "U8", apiVersion = 12.09, simResponse = {20}, min = 0, max = 50, unit = "%", default = 20, help = "@i18n(api.GOVERNOR_CONFIG.gov_handover_throttle)@"},
        {field = "gov_pwr_filter", type = "U8", apiVersion = 12.09, simResponse = {20}, unit = "Hz", min = 0, max = 250, default = 20, help = "@i18n(api.GOVERNOR_CONFIG.gov_pwr_filter)@"},
        {field = "gov_rpm_filter", type = "U8", apiVersion = 12.09, simResponse = {20}, unit = "Hz", min = 0, max = 250, default = 20, help = "@i18n(api.GOVERNOR_CONFIG.gov_rpm_filter)@"},
        {field = "gov_tta_filter", type = "U8", apiVersion = 12.09, simResponse = {0}, unit = "Hz", min = 0, max = 250, default = 20, help = "@i18n(api.GOVERNOR_CONFIG.gov_tta_filter)@"},
        {field = "gov_ff_filter", type = "U8", apiVersion = 12.09, simResponse = {10}, unit = "Hz", min = 0, max = 25, default = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_ff_filter)@"},
        {field = "spare_3", type = "U8", apiVersion = 12.09, simResponse = {0}},
        {field = "gov_d_filter", type = "U8", apiVersion = 12.09, simResponse = {50}, unit = "Hz", min = 0, max = 250, default = 50, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_d_filter)@"},
        {field = "gov_spooldown_time", type = "U16", apiVersion = 12.09, simResponse = {30, 0}, min = 0, max = 600, unit = "%/s", default = 100, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_spooldown_time)@"},
        {field = "gov_throttle_type", type = "U8", apiVersion = 12.09, simResponse = {0}, min = 0, max = #throttleTypeTable, table = throttleTypeTable, help = "@i18n(api.GOVERNOR_CONFIG.gov_throttle_type)@"},
        {field = "spare_4", type = "S8", apiVersion = 12.09, simResponse = {0}},
        {field = "spare_5", type = "S8", apiVersion = 12.09, simResponse = {0}},
        {field = "governor_idle_throttle", type = "U8", apiVersion = 12.09, simResponse = {10}, min = 0, max = 250, scale = 10, decimals = 1, default = 0, unit = "%", help = "@i18n(api.GOVERNOR_CONFIG.governor_idle_throttle)@"},
        {field = "governor_auto_throttle", type = "U8", apiVersion = 12.09, simResponse = {10}, min = 0, max = 250, scale = 10, decimals = 1, default = 0, unit = "%", help = "@i18n(api.GOVERNOR_CONFIG.governor_auto_throttle)@"},
        {field = "gov_bypass_throttle_curve_1", type = "U8", apiVersion = 12.09, simResponse = {0}},
        {field = "gov_bypass_throttle_curve_2", type = "U8", apiVersion = 12.09, simResponse = {10}},
        {field = "gov_bypass_throttle_curve_3", type = "U8", apiVersion = 12.09, simResponse = {20}},
        {field = "gov_bypass_throttle_curve_4", type = "U8", apiVersion = 12.09, simResponse = {30}},
        {field = "gov_bypass_throttle_curve_5", type = "U8", apiVersion = 12.09, simResponse = {50}},
        {field = "gov_bypass_throttle_curve_6", type = "U8", apiVersion = 12.09, simResponse = {60}},
        {field = "gov_bypass_throttle_curve_7", type = "U8", apiVersion = 12.09, simResponse = {70}},
        {field = "gov_bypass_throttle_curve_8", type = "U8", apiVersion = 12.09, simResponse = {80}},
        {field = "gov_bypass_throttle_curve_9", type = "U8", apiVersion = 12.09, simResponse = {100}},
        
    }

else
    local gov_modeTable = {[0] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_off)@", "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_passthrough)@", "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_standard)@", "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_mode1)@", "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_mode2)@"}

    MSP_API_STRUCTURE_READ_DATA = {
        {field = "gov_mode", type = "U8", apiVersion = 12.06, simResponse = {3}, min = 0, max = #gov_modeTable, table = gov_modeTable, help = "@i18n(api.GOVERNOR_CONFIG.gov_mode)@"},
        {field = "gov_startup_time", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 600, unit = "s", default = 200, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_startup_time)@"},
        {field = "gov_spoolup_time", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 600, unit = "s", default = 100, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_spoolup_time)@"},
        {field = "gov_tracking_time", type = "U16", apiVersion = 12.06, simResponse = {20, 0}, min = 0, max = 100, unit = "s", default = 10, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_tracking_time)@"},
        {field = "gov_recovery_time", type = "U16", apiVersion = 12.06, simResponse = {20, 0}, min = 0, max = 100, unit = "s", default = 21, decimals = 1, scale = 10, help = "@i18n(api.GOVERNOR_CONFIG.gov_recovery_time)@"},
        {field = "gov_zero_throttle_timeout", type = "U16", apiVersion = 12.06, simResponse = {30, 0}, help = "@i18n(api.GOVERNOR_CONFIG.gov_zero_throttle_timeout)@"},
        {field = "gov_lost_headspeed_timeout", type = "U16", apiVersion = 12.06, simResponse = {10, 0}, help = "@i18n(api.GOVERNOR_CONFIG.gov_lost_headspeed_timeout)@"},
        {field = "gov_autorotation_timeout", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, help = "@i18n(api.GOVERNOR_CONFIG.gov_autorotation_timeout)@"},
        {field = "gov_autorotation_bailout_time", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, help = "@i18n(api.GOVERNOR_CONFIG.gov_autorotation_bailout_time)@"},
        {field = "gov_autorotation_min_entry_time", type = "U16", apiVersion = 12.06, simResponse = {50, 0}, help = "@i18n(api.GOVERNOR_CONFIG.gov_autorotation_min_entry_time)@"},
        {field = "gov_handover_throttle", type = "U8", apiVersion = 12.06, simResponse = {10}, min = 10, max = 50, unit = "%", default = 20, help = "@i18n(api.GOVERNOR_CONFIG.gov_handover_throttle)@"},
        {field = "gov_pwr_filter", type = "U8", apiVersion = 12.06, simResponse = {5}, help = "@i18n(api.GOVERNOR_CONFIG.gov_pwr_filter)@"},
        {field = "gov_rpm_filter", type = "U8", apiVersion = 12.06, simResponse = {10}, help = "@i18n(api.GOVERNOR_CONFIG.gov_rpm_filter)@"},
        {field = "gov_tta_filter", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.GOVERNOR_CONFIG.gov_tta_filter)@"},
        {field = "gov_ff_filter", type = "U8", apiVersion = 12.06, simResponse = {10}, help = "@i18n(api.GOVERNOR_CONFIG.gov_ff_filter)@"},
        {field = "gov_spoolup_min_throttle", type = "U8", apiVersion = 12.08, simResponse = {5}, min = 0, max = 50, unit = "%", default = 0, help = "@i18n(api.GOVERNOR_CONFIG.gov_spoolup_min_throttle)@"}
    }
end
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local lastWriteUUID = nil

local writeDoneRegistry = setmetatable({}, {__mode = "kv"})

local function processReplyStaticRead(self, buf)
    core.parseMSPData(API_NAME, buf, self.structure, nil, nil, function(result)
        mspData = result
        if #buf >= (self.minBytes or 0) then
            local getComplete = self.getCompleteHandler
            if getComplete then
                local complete = getComplete()
                if complete then complete(self, buf) end
            end
        end
    end)
end

local function processReplyStaticWrite(self, buf)
    mspWriteComplete = true

    if self.uuid then writeDoneRegistry[self.uuid] = true end

    local getComplete = self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function errorHandlerStatic(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete() return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
