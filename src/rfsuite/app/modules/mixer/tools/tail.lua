--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false
local triggerSave = false
local needsReboot = false

-- containers for load/save steps
local load = {}
local save = {}

-- var to contain all fields we retrieve/store
local APIDATA = {}

-- var to contain our working form data
local FORMDATA = {}

-- store loaded directions here to ensure writeback consistency
local AIL_DIRECTION
local ELE_DIRECTION
local COL_DIRECTION

-- -------------------------------------------------------
-- -- Form layout
-- -------------------------------------------------------
local LAYOUTINDEX 
local LAYOUT 

-- handler for tail mode change
-- needs to be up here or we get a nil reference
local function tailChanged()

    rfsuite.session.tailMode = FORMDATA[LAYOUTINDEX.TAIL_ROTOR_MODE]

    needsReboot = true
end

if rfsuite.session.tailMode >= 1 then

    LAYOUTINDEX = {
        TAIL_ROTOR_MODE       = 1,   -- MIXER_CONFIG
        YAW_DIRECTION         = 2,   -- GET_MIXER_INPUT_YAW        
        TAIL_ROTOR_IDLE       = 3,   -- MIXER_CONFIG
        TAIL_CENTER_TRIM      = 4,   -- MIXER_CONFIG
        YAW_CALIBRATION       = 5,   -- GET_MIXER_INPUT_YAW
        YAW_CW_LIMIT          = 6,   -- GET_MIXER_INPUT_YAW
        YAW_CCW_LIMIT         = 7,   -- GET_MIXER_INPUT_YAW
    }

    LAYOUT = {
            [LAYOUTINDEX.TAIL_ROTOR_MODE] = {t = "@i18n(app.modules.mixer.tail_rotor_mode)@", table = {"@i18n(api.MIXER_CONFIG.tbl_tail_variable_pitch)@", "@i18n(api.MIXER_CONFIG.tbl_tail_motororized_tail)@", "@i18n(api.MIXER_CONFIG.tbl_tail_bidirectional)@"}, tableIdxInc = -1, onChange = function() tailChanged() end}, 
            [LAYOUTINDEX.YAW_DIRECTION] = {t = "@i18n(app.modules.mixer.yaw_direction)@",    table = {[0] = "@i18n(api.MIXER_INPUT.tbl_reversed)@", [1] = "@i18n(api.MIXER_INPUT.tbl_normal)@"}}, -- GET_MIXER_INPUT_YAW
            [LAYOUTINDEX.TAIL_CENTER_TRIM] = {t = "@i18n(app.modules.mixer.tail_center_offset)@",  unit = "%", default = 0, min = -500, max = 500, decimals = 1},

            [LAYOUTINDEX.YAW_CALIBRATION] = {t = "@i18n(app.modules.mixer.yaw_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"  },           -- GET_MIXER_INPUT_YAW
            [LAYOUTINDEX.YAW_CW_LIMIT] = {t = "@i18n(app.modules.mixer.yaw_cw_limit)@", unit = "%"  ,  default = 125, decimals = 1 , min = 0, max = 2000       },                         -- GET_MIXER_INPUT_YAW
            [LAYOUTINDEX.YAW_CCW_LIMIT] = {t = "@i18n(app.modules.mixer.yaw_ccw_limit)@",  unit = "%" , default = 125, decimals = 1 , min = 0, max = 2000     },                          -- GET_MIXER_INPUT_YAW 
            
            [LAYOUTINDEX.TAIL_ROTOR_IDLE] = {t = "@i18n(app.modules.mixer.tail_motor_idle)@", unit="%", min=0, max=250, step=1, decimals = 1},
        }
else

    LAYOUTINDEX = {
        TAIL_ROTOR_MODE       = 1,   -- MIXER_CONFIG
        TAIL_ROTOR_IDLE       = 2,   -- MIXER_CONFIG
        YAW_DIRECTION         = 3,   -- GET_MIXER_INPUT_YAW
        TAIL_CENTER_TRIM      = 4,   -- MIXER_CONFIG        
        YAW_CALIBRATION       = 5,   -- GET_MIXER_INPUT_YAW
        YAW_CW_LIMIT          = 6,   -- GET_MIXER_INPUT_YAW
        YAW_CCW_LIMIT         = 7,   -- GET_MIXER_INPUT_YAW
    }    

    LAYOUT = {
            [LAYOUTINDEX.TAIL_ROTOR_MODE] = {t = "@i18n(app.modules.mixer.tail_rotor_mode)@", table = {"@i18n(api.MIXER_CONFIG.tbl_tail_variable_pitch)@", "@i18n(api.MIXER_CONFIG.tbl_tail_motororized_tail)@", "@i18n(api.MIXER_CONFIG.tbl_tail_bidirectional)@"}, tableIdxInc = -1, onChange = function() tailChanged() end}, 
            [LAYOUTINDEX.YAW_DIRECTION] = {t = "@i18n(app.modules.mixer.yaw_direction)@",    table = {[0] = "@i18n(api.MIXER_INPUT.tbl_reversed)@", [1] = "@i18n(api.MIXER_INPUT.tbl_normal)@"}}, -- GET_MIXER_INPUT_YAW
            [LAYOUTINDEX.TAIL_CENTER_TRIM] = {t = "@i18n(app.modules.mixer.yaw_center_trim)@",  unit = "%", default = 0, min = -250, max = 250, decimals = 1},

            
            [LAYOUTINDEX.YAW_CALIBRATION] = {t = "@i18n(app.modules.mixer.yaw_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"  },           -- GET_MIXER_INPUT_YAW
            [LAYOUTINDEX.YAW_CW_LIMIT] = {t = "@i18n(app.modules.mixer.yaw_cw_limit)@", unit = "°"  ,  default = 20, decimals = 1 , min = 0, max = 600       },                         -- GET_MIXER_INPUT_YAW
            [LAYOUTINDEX.YAW_CCW_LIMIT] = {t = "@i18n(app.modules.mixer.yaw_ccw_limit)@",  unit = "°" , default = 20, decimals = 1 , min = 0, max = 600     },                          -- GET_MIXER_INPUT_YAW 
                

        }    
end

-- -------------------------------------------------------
-- -- Helper functions
-- -------------------------------------------------------

local function u16_to_s16(u)
    if u >= 0x8000 then
        return u - 0x10000
    else
        return u
    end
end

local function s16_to_u16(s)
    if s < 0 then return s + 0x10000 end
    return s
end

local function round(x)
    if x >= 0 then return math.floor(x + 0.5) end
    return math.ceil(x - 0.5)
end

local function rateToDir(u16rate)
    -- rate_stabilized_* comes from MSP as u16 encoding s16
    return (u16_to_s16(u16rate) < 0) and 0 or 1
end

-- we take the raw data from APIDATA and process it into FORMDATA for easier use in the form
-- the reverse is done in the save step
function apiDataToFormData() 

    -- get raw data from api table
    local TAIL_ROTOR_MODE = APIDATA["MIXER_CONFIG"]["values"].tail_rotor_mode
    local TAIL_ROTOR_IDLE = APIDATA["MIXER_CONFIG"]["values"].tail_motor_idle
    local TAIL_CENTER_TRIM = APIDATA["MIXER_CONFIG"]["values"].tail_center_trim
    local YAW_CALIBRATION = APIDATA["GET_MIXER_INPUT_YAW"]["values"].rate_stabilized_yaw
    local YAW_CW_LIMIT = APIDATA["GET_MIXER_INPUT_YAW"]["values"].min_stabilized_yaw
    local YAW_CCW_LIMIT = APIDATA["GET_MIXER_INPUT_YAW"]["values"].max_stabilized_yaw

    -- determine directions
    YAW_DIRECTION = rateToDir(APIDATA["GET_MIXER_INPUT_YAW"]["values"].rate_stabilized_yaw)

    -- transforms
    YAW_CALIBRATION = u16_to_s16(YAW_CALIBRATION)
    YAW_CALIBRATION = math.abs(YAW_CALIBRATION)    

    -- handle limits based on tail mode
    if rfsuite.session.tailMode >= 1 then
        YAW_CW_LIMIT = u16_to_s16(YAW_CW_LIMIT)
        YAW_CW_LIMIT = math.abs(YAW_CW_LIMIT)     

        YAW_CCW_LIMIT = YAW_CCW_LIMIT
    else
        YAW_CW_LIMIT = u16_to_s16(YAW_CW_LIMIT)
        YAW_CW_LIMIT = YAW_CW_LIMIT * 24/100
        YAW_CW_LIMIT = math.abs(YAW_CW_LIMIT)
        YAW_CW_LIMIT = math.floor(YAW_CW_LIMIT + 0.5)    

        YAW_CCW_LIMIT = u16_to_s16(YAW_CCW_LIMIT)
        YAW_CCW_LIMIT = YAW_CCW_LIMIT * 24/100
        YAW_CCW_LIMIT = math.abs(YAW_CCW_LIMIT)
        YAW_CCW_LIMIT = math.floor(YAW_CCW_LIMIT + 0.5)    

        TAIL_CENTER_TRIM = u16_to_s16(TAIL_CENTER_TRIM)
        TAIL_CENTER_TRIM = TAIL_CENTER_TRIM * 24/100
        TAIL_CENTER_TRIM = math.abs(TAIL_CENTER_TRIM)    
        TAIL_CENTER_TRIM = math.floor(TAIL_CENTER_TRIM + 0.5)
    end


    -- store processed data into form data table
    if rfsuite.session.tailMode >= 1 then
        FORMDATA[LAYOUTINDEX.TAIL_ROTOR_MODE] = TAIL_ROTOR_MODE
        FORMDATA[LAYOUTINDEX.TAIL_ROTOR_IDLE] = TAIL_ROTOR_IDLE
        FORMDATA[LAYOUTINDEX.YAW_DIRECTION] = YAW_DIRECTION
        FORMDATA[LAYOUTINDEX.TAIL_CENTER_TRIM] = TAIL_CENTER_TRIM
        FORMDATA[LAYOUTINDEX.YAW_CALIBRATION] = YAW_CALIBRATION
        FORMDATA[LAYOUTINDEX.YAW_CW_LIMIT] = YAW_CW_LIMIT
        FORMDATA[LAYOUTINDEX.YAW_CCW_LIMIT] = YAW_CCW_LIMIT
    else
        FORMDATA[LAYOUTINDEX.TAIL_ROTOR_MODE] = TAIL_ROTOR_MODE
        FORMDATA[LAYOUTINDEX.YAW_DIRECTION] = YAW_DIRECTION
        FORMDATA[LAYOUTINDEX.YAW_CALIBRATION] = YAW_CALIBRATION
        FORMDATA[LAYOUTINDEX.TAIL_CENTER_TRIM] = TAIL_CENTER_TRIM
        FORMDATA[LAYOUTINDEX.YAW_CW_LIMIT] = YAW_CW_LIMIT
        FORMDATA[LAYOUTINDEX.YAW_CCW_LIMIT] = YAW_CCW_LIMIT
    end

end

-- the reverse of apiDataToFormData: take the values from FORMDATA and convert them back into raw API values
function copyFormToApiValues()
    local apiValues = APIDATA
    if not apiValues then return false end

    -- helpers
    local function round(x)
        if x >= 0 then return math.floor(x + 0.5) end
        return math.ceil(x - 0.5)
    end

    local function dirSign(d)
        return (d == 0) and -1 or 1
    end

    -- -------------------------------------------------
    -- MIXER_CONFIG (tail-specific fields only)
    -- -------------------------------------------------
    local mixerCfg = apiValues["MIXER_CONFIG"] and apiValues["MIXER_CONFIG"].values
    if not mixerCfg then return false end

    -- tail rotor mode always writable
    mixerCfg["tail_rotor_mode"] = FORMDATA[LAYOUTINDEX.TAIL_ROTOR_MODE]

    -- tail motor idle only relevant for motor/variable tail
    if rfsuite.session.tailMode >= 1 then
        mixerCfg["tail_motor_idle"] = FORMDATA[LAYOUTINDEX.TAIL_ROTOR_IDLE]
    else
        -- fixed pitch tail: write center trim (UI scaled ±24deg)
        local trim_ui = round(FORMDATA[LAYOUTINDEX.TAIL_CENTER_TRIM] or 0)
        mixerCfg["tail_center_trim"] = s16_to_u16(
            round(trim_ui * 100 / 24)
        )
    end

    -- -------------------------------------------------
    -- GET_MIXER_INPUT_YAW
    -- -------------------------------------------------
    local yaw = apiValues["GET_MIXER_INPUT_YAW"]
        and apiValues["GET_MIXER_INPUT_YAW"].values
    if not yaw then return false end

    -- Yaw rate: UI is magnitude, direction from selector
    local yawRate_ui = round(FORMDATA[LAYOUTINDEX.YAW_CALIBRATION] or 0)
    yaw["rate_stabilized_yaw"] = s16_to_u16(
        yawRate_ui * dirSign(FORMDATA[LAYOUTINDEX.YAW_DIRECTION])
    )

    -- Yaw limits
    local cw_ui  = round(FORMDATA[LAYOUTINDEX.YAW_CW_LIMIT]  or 0)
    local ccw_ui = round(FORMDATA[LAYOUTINDEX.YAW_CCW_LIMIT] or 0)

    local cw_raw, ccw_raw
    if rfsuite.session.tailMode >= 1 then
        -- variable / motor tail: UI already matches raw magnitude
        cw_raw  = cw_ui
        ccw_raw = ccw_ui
    else
        -- fixed pitch tail: UI scaled by 24/100
        cw_raw  = round(cw_ui  * 100 / 24)
        ccw_raw = round(ccw_ui * 100 / 24)
    end

    -- API convention: min is negative, max is positive
    yaw["min_stabilized_yaw"] = s16_to_u16(-math.abs(cw_raw))
    yaw["max_stabilized_yaw"] = s16_to_u16( math.abs(ccw_raw))

    return true
end




-- -------------------------------------------------------
-- -- Load functions
-- -------------------------------------------------------

local LOAD_SEQUENCE = {
  "MIXER_CONFIG",
  "GET_MIXER_INPUT_YAW",
}

local function loadNext(i)
  local IDX = LOAD_SEQUENCE[i]
  if not IDX then
    load.complete()
    return
  end

  local API = rfsuite.tasks.msp.api.load(IDX)
  API.setCompleteHandler(function(self, buf)
        APIDATA[IDX] = {}

        local d = API.data()

        -- shallow-copy helper (snapshots tables so API internals can’t mutate our cache)
        local function copyTable(src)
            if type(src) ~= "table" then return src end
            local dst = {}
            for k, v in pairs(src) do
            dst[k] = v
            end
            return dst
        end

        APIDATA[IDX]['values']             = copyTable(d.parsed)
        APIDATA[IDX]['structure']          = copyTable(d.structure)
        APIDATA[IDX]['buffer']             = copyTable(d.buffer)
        APIDATA[IDX]['receivedBytesCount'] = d.receivedBytesCount
        APIDATA[IDX]['positionmap']        = copyTable(d.positionmap)
        APIDATA[IDX]['other']              = copyTable(d.other)

        loadNext(i + 1)
  end)

  -- Keep your UUID scheme, but fix concat operator:
  API.setUUID("d8163617-1496-4886-8b81-" .. IDX)
  API.read()
end

function load.start()
  loadNext(1)
end

function load.complete()
  apiDataToFormData()
  rfsuite.app.triggers.closeProgressLoader = true
end

-- -------------------------------------------------------
-- -- Save functions
-- -------------------------------------------------------
local SAVE_SEQUENCE = {
  "MIXER_CONFIG",
  "GET_MIXER_INPUT_YAW",
}

local function writeNext(i)
    local apikey = SAVE_SEQUENCE[i]
    if not apikey then
        -- all done

        -- commit the change
        local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
        EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
        EAPI.setCompleteHandler(function(self)
            rfsuite.utils.log("Writing to EEPROM", "info")
        end)
        EAPI.write()

        -- reboot if required
        if needsReboot then
            local RAPI = rfsuite.tasks.msp.api.load("REBOOT")
            RAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
            RAPI.setCompleteHandler(function(self)
                rfsuite.utils.log("Rebooting FC", "info")
                rfsuite.utils.onReboot()
            end)
            RAPI.write()
            needsReboot = false
        end

        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

    local API = rfsuite.tasks.msp.api.load(apikey)
    API.setRebuildOnWrite(true)

    API.setCompleteHandler(function(self, buf)
        -- continue to next write
        writeNext(i + 1)
    end)

    -- Apply only the fields present in the payload table.
    local payload = APIDATA[apikey].values
    if payload then
        for k, v in pairs(payload) do
            API.setValue(k, v)
        end
    end

    API.setUUID("d8163617-1496-4886-8b81-write-" .. apikey)
    API.write()
end

function save.start()
    copyFormToApiValues()
    writeNext(1)
end

-- -------------------------------------------------------
-- -- Page interface functions
-- -------------------------------------------------------
local function openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)

    local app = rfsuite.app
    local formLines = app.formLines
    local formFields = app.formFields

    -- setup page
    app.uiState = app.uiStatus.pages
    app.triggers.isReady = false
    app.lastLabel = nil
    app.lastIdx = idx
    app.lastTitle = title
    app.lastScript = script

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    -- build form
    form.clear()
    rfsuite.session.lastPage = script

    local pageTitle = app.Page.pageTitle or title
    app.ui.fieldHeader(pageTitle)


    for i, f in pairs(LAYOUT) do

        -- bump line count
        app.formLineCnt = i

        if f.table then
            local tbldata = f.table and app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}

            formLines[app.formLineCnt] = form.addLine(f.t)
            formFields[i] = form.addChoiceField(
                                formLines[app.formLineCnt], 
                                il,                     -- position on line
                                tbldata,                -- formated table
                                function()              -- get value
                                    local value = FORMDATA[i]
                                    if value == nil then
                                        return 0
                                    end
                                    return value
                                end, 
                                function(value)          -- set value
                                    if value ~= FORMDATA[i] then
                                        if f.onChange then 
                                            f.onChange() 
                                        end
                                    end
                                    FORMDATA[i] = value
                                end
                            )
        else
            -- display field
            formLines[app.formLineCnt] = form.addLine(f.t)
            formFields[i] = form.addNumberField(
                                formLines[app.formLineCnt], 
                                nil,                    -- position on line
                                f.min or 0,             -- min value
                                f.max or 0,             -- max value
                                function()              -- get value
                                    local value = FORMDATA[i]
                                    if value == nil then
                                        return 0
                                    end
                                    return value
                                end, 
                                function(value)          -- set value
                                    if value ~= FORMDATA[i] then
                                        if f.onChange then 
                                            f.onChange() 
                                        end
                                    end
                                    FORMDATA[i] = value
                                end
                            )
            if f.unit then formFields[i]:suffix(f.unit or "") end
            if f.step then formFields[i]:step(f.step or 1) end
            if f.decimals then formFields[i]:decimals(f.decimals or 0)   end
            if f.help then formFields[i]:help(f.help or "") end  
        end        
    end


    -- start msp load sequence
    load.start()
    enableWakeup = true
end



local function onNavMenu(self)
    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")
end

local function onSaveMenu()

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        triggerSave = true
        return
    end  

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                triggerSave = true
                return true
            end
        }, {
            label = "@i18n(app.btn_cancel)@",
            action = function()
                triggerSave = false
                return true
            end
        }
    }

    form.openDialog({width = nil, title = "@i18n(app.modules.profile_select.save_settings)@", message = "@i18n(app.modules.profile_select.save_prompt)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

    triggerSave = false
end

local function wakeup()
    if not enableWakeup then
        return
    end 

    -- we are compromised without this - go back to main
    if rfsuite.session.tailMode == nil then
        rfsuite.app.ui.openMainMenu()
        return
    end    

    if triggerSave then
        rfsuite.app.ui.progressDisplay("@i18n(app.msg_saving_settings)@","@i18n(app.msg_saving_to_fbl)@")
        save.start()
        triggerSave = false
    end   

end

local function onReloadMenu() rfsuite.app.triggers.triggerReloadFull = true end


return {
    openPage = openPage, 
    onNavMenu=onNavMenu, 
    onSaveMenu = onSaveMenu, 
    postLoad = postLoad, 
    wakeup = wakeup, 
    onReloadMenu = onReloadMenu,
    navButtons = {
        menu = true, 
        save = true, 
        reload = true, 
        tool = false, 
        help = false
    }
}