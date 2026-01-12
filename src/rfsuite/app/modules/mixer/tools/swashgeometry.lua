--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false
local triggerSave = false

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
local LAYOUTINDEX = {
        CYCLIC_CALIBRATION       = 1,   -- GET_MIXER_INPUT_PITCH
        COLLECTIVE_CALIBRATION   = 2,   -- GET_MIXER_INPUT_COLLECTIVE
        GEO_CORRECTION           = 3,   -- MIXER_CONFIG
        CYCLIC_PITCH_LIMIT       = 4,   -- GET_MIXER_INPUT_PITCH
        COLLECTIVE_PITCH_LIMIT   = 5,   -- MIXER_CONFIG
        SWASH_PITCH_LIMIT        = 6,   -- GET_MIXER_INPUT_COLLECTIVE
        SWASH_PHASE              = 7,   -- MIXER_CONFIG
        COL_TILT_COR_POS         = 8,   -- MIXER_CONFIG
        COL_TILT_COR_NEG         = 9,   -- MIXER_CONFIG
    }

local LAYOUT = {
        [LAYOUTINDEX.CYCLIC_CALIBRATION] = {t = "@i18n(app.modules.mixer.cyclic_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"  },           -- GET_MIXER_INPUT_PITCH
        [LAYOUTINDEX.COLLECTIVE_CALIBRATION] = {t = "@i18n(app.modules.mixer.collective_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"   },  -- GET_MIXER_INPUT_COLLECTIVE
        [LAYOUTINDEX.GEO_CORRECTION] = {t = "@i18n(app.modules.mixer.geo_correction)@",  unit = "%", step = 2, default = 0, min = -250, max = 250, decimals = 1    },                     -- MIXER_CONFIG
        [LAYOUTINDEX.CYCLIC_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.cyclic_pitch_limit)@", unit = "°"  ,  default = 20, decimals = 1 , min = 0, max = 200       },                   -- GET_MIXER_INPUT_PITCH
        [LAYOUTINDEX.COLLECTIVE_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.collective_pitch_limit)@",  unit = "°" , default = 20, decimals = 1 , min = 0, max = 200     },              -- GET_MIXER_INPUT_COLLECTIVE  
        [LAYOUTINDEX.SWASH_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.swash_pitch_limit)@", unit = "°" , default = 200,    decimals = 1 , min = 0, max = 360      },                    -- MIXER_CONFIG
        [LAYOUTINDEX.SWASH_PHASE] = {t = "@i18n(app.modules.mixer.swash_phase)@", unit = "°",  min = -1800, max = 1800 , decimals = 1,                   },                               -- MIXER_CONFIG
        [LAYOUTINDEX.COL_TILT_COR_POS] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_pos)@",    unit = "%", min = -100, max = 100},                                          -- MIXER_CONFIG
        [LAYOUTINDEX.COL_TILT_COR_NEG] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_neg)@",    unit = "%", min = -100, max = 100},                                          -- MIXER_CONFIG
    }


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
    local CYCLIC_CALIBRATION = APIDATA["GET_MIXER_INPUT_PITCH"]["values"].rate_stabilized_pitch
    local COLLECTIVE_CALIBRATION = APIDATA["GET_MIXER_INPUT_COLLECTIVE"]["values"].rate_stabilized_collective
    local GEO_CORRECTION = APIDATA["MIXER_CONFIG"]["values"].swash_geo_correction
    local CYCLIC_PITCH_LIMIT = APIDATA["GET_MIXER_INPUT_PITCH"]["values"].max_stabilized_pitch
    local SWASH_PITCH_LIMIT= APIDATA["MIXER_CONFIG"]["values"].swash_pitch_limit
    local COLLECTIVE_PITCH_LIMIT = APIDATA["GET_MIXER_INPUT_COLLECTIVE"]["values"].max_stabilized_collective
    local SWASH_PHASE = APIDATA["MIXER_CONFIG"]["values"].swash_phase
    local COL_TILT_COR_POS = APIDATA["MIXER_CONFIG"]["values"].collective_tilt_correction_pos
    local COL_TILT_COR_NEG = APIDATA["MIXER_CONFIG"]["values"].collective_tilt_correction_neg

    -- determine directions
    COL_DIRECTION = rateToDir(APIDATA["GET_MIXER_INPUT_COLLECTIVE"]["values"].rate_stabilized_collective)
    ELE_DIRECTION = rateToDir(APIDATA["GET_MIXER_INPUT_PITCH"]["values"].rate_stabilized_pitch)
    AIL_DIRECTION = rateToDir(APIDATA["GET_MIXER_INPUT_ROLL"]["values"].rate_stabilized_roll)

    -- transform raw data into form data

    -- cyclic
    CYCLIC_CALIBRATION = u16_to_s16(CYCLIC_CALIBRATION) 
    CYCLIC_CALIBRATION = math.abs(CYCLIC_CALIBRATION)

    -- collective
    COLLECTIVE_CALIBRATION = u16_to_s16(COLLECTIVE_CALIBRATION)
    COLLECTIVE_CALIBRATION = math.abs(COLLECTIVE_CALIBRATION)

    -- geo correction
    GEO_CORRECTION = (GEO_CORRECTION / 5) * 10

    -- cyclic pitch limit
    CYCLIC_PITCH_LIMIT = u16_to_s16(CYCLIC_PITCH_LIMIT)
    CYCLIC_PITCH_LIMIT = CYCLIC_PITCH_LIMIT * 12/100
    CYCLIC_PITCH_LIMIT = math.abs(CYCLIC_PITCH_LIMIT)
    CYCLIC_PITCH_LIMIT = math.floor(CYCLIC_PITCH_LIMIT + 0.5)

    -- collective pitch limit
    COLLECTIVE_PITCH_LIMIT = u16_to_s16(COLLECTIVE_PITCH_LIMIT)
    COLLECTIVE_PITCH_LIMIT = COLLECTIVE_PITCH_LIMIT * 12/100
    COLLECTIVE_PITCH_LIMIT = math.abs(COLLECTIVE_PITCH_LIMIT)    
    COLLECTIVE_PITCH_LIMIT = math.floor(COLLECTIVE_PITCH_LIMIT + 0.5)

    -- swash pitch limit
    SWASH_PITCH_LIMIT = SWASH_PITCH_LIMIT * 12/100
    SWASH_PITCH_LIMIT = math.floor(SWASH_PITCH_LIMIT + 0.5)   

    -- store processed data into form data table
    FORMDATA[LAYOUTINDEX.CYCLIC_CALIBRATION] = CYCLIC_CALIBRATION
    FORMDATA[LAYOUTINDEX.COLLECTIVE_CALIBRATION] = COLLECTIVE_CALIBRATION
    FORMDATA[LAYOUTINDEX.GEO_CORRECTION] = GEO_CORRECTION
    FORMDATA[LAYOUTINDEX.CYCLIC_PITCH_LIMIT] = CYCLIC_PITCH_LIMIT
    FORMDATA[LAYOUTINDEX.COLLECTIVE_PITCH_LIMIT] = COLLECTIVE_PITCH_LIMIT
    FORMDATA[LAYOUTINDEX.SWASH_PITCH_LIMIT] = SWASH_PITCH_LIMIT
    FORMDATA[LAYOUTINDEX.SWASH_PHASE] = SWASH_PHASE
    FORMDATA[LAYOUTINDEX.COL_TILT_COR_POS] = COL_TILT_COR_POS
    FORMDATA[LAYOUTINDEX.COL_TILT_COR_NEG] = COL_TILT_COR_NEG
 
end

-- the reverse of apiDataToFormData: take the values from FORMDATA and convert them back into raw API values
function copyFormToApiValues()
    local apiValues = APIDATA
    if not apiValues then return false end

    -- helper: your stored dirs are 0/1; convert to -1/+1
    local function dirSign(d)
        return (d == 0) and -1 or 1
    end

    -- form values (already "normalized"/absolute in the UI)
    local cyclicRate_ui = round(FORMDATA[LAYOUTINDEX.CYCLIC_CALIBRATION] or 0)    
    local collRate_ui   = round(FORMDATA[LAYOUTINDEX.COLLECTIVE_CALIBRATION] or 0)

    -- limits in degrees -> raw (reverse of: raw * 12/100)
    local cyclicMax_raw = round((FORMDATA[LAYOUTINDEX.CYCLIC_PITCH_LIMIT] or 0) * 100 / 12)
    local collMax_raw   = round((FORMDATA[LAYOUTINDEX.COLLECTIVE_PITCH_LIMIT] or 0) * 100 / 12)

    -- ----------------------------
    -- MIXER_CONFIG payload
    -- ----------------------------
    local mixerCfg = apiValues["MIXER_CONFIG"].values
    if not mixerCfg then return false end

    -- GEO_CORRECTION: forward was (raw/5)*10  => raw*2 ; reverse raw=form/2
    mixerCfg["swash_geo_correction"] = round((FORMDATA[LAYOUTINDEX.GEO_CORRECTION] or 0) / 2)

    -- SWASH_PITCH_LIMIT: forward raw*12/100 ; reverse raw=deg*100/12
    mixerCfg["swash_pitch_limit"] = round((FORMDATA[LAYOUTINDEX.SWASH_PITCH_LIMIT] or 0) * 100 / 12)

    -- SWASH_PHASE: currently treated as raw in apiDataToFormData()
    mixerCfg["swash_phase"] = (FORMDATA[LAYOUTINDEX.SWASH_PHASE] or 0)

    mixerCfg["collective_tilt_correction_pos"] = (FORMDATA[LAYOUTINDEX.COL_TILT_COR_POS] or 0)
    mixerCfg["collective_tilt_correction_neg"] = (FORMDATA[LAYOUTINDEX.COL_TILT_COR_NEG] or 0)

    -- ----------------------------
    -- GET_MIXER_INPUT_PITCH (cyclic pitch)
    -- ----------------------------
    local pitch = apiValues["GET_MIXER_INPUT_PITCH"].values
    local v = cyclicRate_ui * dirSign(ELE_DIRECTION)
    pitch["rate_stabilized_pitch"] = s16_to_u16(v)
    pitch["max_stabilized_pitch"] = s16_to_u16( math.abs(cyclicMax_raw) )
    pitch["min_stabilized_pitch"] = s16_to_u16( -math.abs(cyclicMax_raw) )

    -- ----------------------------
    -- GET_MIXER_INPUT_ROLL (cyclic roll) 
    -- ----------------------------
    local roll = apiValues["GET_MIXER_INPUT_ROLL"].values
    local v = cyclicRate_ui * dirSign(AIL_DIRECTION)
    roll["rate_stabilized_roll"] = s16_to_u16(v)
    roll["max_stabilized_roll"] = s16_to_u16( math.abs(cyclicMax_raw) )
    roll["min_stabilized_roll"] = s16_to_u16( -math.abs(cyclicMax_raw) )

    -- ----------------------------
    -- GET_MIXER_INPUT_COLLECTIVE
    -- ----------------------------
    local coll = apiValues["GET_MIXER_INPUT_COLLECTIVE"].values

    local v = collRate_ui * dirSign(COL_DIRECTION)
    coll["rate_stabilized_collective"] = s16_to_u16(v)
    coll["max_stabilized_collective"] = s16_to_u16( math.abs(collMax_raw) )
    coll["min_stabilized_collective"] = s16_to_u16( -math.abs(collMax_raw) )

    return true
end



-- -------------------------------------------------------
-- -- Load functions
-- -------------------------------------------------------

local LOAD_SEQUENCE = {
  "MIXER_CONFIG",
  "GET_MIXER_INPUT_PITCH",
  "GET_MIXER_INPUT_ROLL",
  "GET_MIXER_INPUT_COLLECTIVE",
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
    "GET_MIXER_INPUT_PITCH",
    "GET_MIXER_INPUT_ROLL",
    "GET_MIXER_INPUT_COLLECTIVE",
}

local function writeNext(i)
    local apikey = SAVE_SEQUENCE[i]
    if not apikey then

        -- commit the change
        local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
        EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
        EAPI.setCompleteHandler(function(self)
            rfsuite.utils.log("Writing to EEPROM", "info")
        end)
        EAPI.write()

        -- all done
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

        -- display field
        formLines[app.formLineCnt] = form.addLine(f.t)
        formFields[i] = form.addNumberField(formLines[app.formLineCnt], 
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
                                FORMDATA[i] = value
                            end
                        )
        if f.unit then formFields[i]:suffix(f.unit or "") end
        if f.step then formFields[i]:step(f.step or 1) end
        if f.decimals then formFields[i]:decimals(f.decimals or 0)   end
        if f.help then formFields[i]:help(f.help or "") end       
    end


    -- start msp load sequence
    load.start()
    enableWakeup = true
end



local function onNavMenu(self)
    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")
end

local function onSaveMenu()
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