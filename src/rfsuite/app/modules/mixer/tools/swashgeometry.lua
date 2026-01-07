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
        CYCLIC_CALIBRATION       = 1,   -- MIXER_INPUT_INDEXED_PITCH
        COLLECTIVE_CALIBRATION   = 2,   -- MIXER_INPUT_INDEXED_COLLECTIVE
        GEO_CORRECTION           = 3,   -- MIXER_CONFIG
        CYCLIC_PITCH_LIMIT       = 4,   -- MIXER_INPUT_INDEXED_PITCH
        COLLECTIVE_PITCH_LIMIT   = 5,   -- MIXER_CONFIG
        SWASH_PITCH_LIMIT        = 6,   -- MIXER_INPUT_INDEXED_COLLECTIVE
        SWASH_PHASE              = 7,   -- MIXER_CONFIG
        COL_TILT_COR_POS         = 8,   -- MIXER_CONFIG
        COL_TILT_COR_NEG         = 9,   -- MIXER_CONFIG
    }

local LAYOUT = {
        [LAYOUTINDEX.CYCLIC_CALIBRATION] = {t = "@i18n(app.modules.mixer.cyclic_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"  },           -- MIXER_INPUT_INDEXED_PITCH
        [LAYOUTINDEX.COLLECTIVE_CALIBRATION] = {t = "@i18n(app.modules.mixer.collective_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"   },  -- MIXER_INPUT_INDEXED_COLLECTIVE
        [LAYOUTINDEX.GEO_CORRECTION] = {t = "@i18n(app.modules.mixer.geo_correction)@",  unit = "%", step = 2, default = 0, min = -250, max = 250, decimals = 1    },                     -- MIXER_CONFIG
        [LAYOUTINDEX.CYCLIC_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.cyclic_pitch_limit)@", unit = "°"  ,  default = 20, decimals = 1 , min = 0, max = 20       },                    -- MIXER_INPUT_INDEXED_PITCH
        [LAYOUTINDEX.COLLECTIVE_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.collective_pitch_limit)@",  unit = "°" , default = 20, decimals = 1 , min = 0, max = 20     },               -- MIXER_INPUT_INDEXED_COLLECTIVE  
        [LAYOUTINDEX.SWASH_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.swash_pitch_limit)@", unit = "°" , default = 200,    decimals = 1 , min = 0, max = 360      },                    -- MIXER_CONFIG
        [LAYOUTINDEX.SWASH_PHASE] = {t = "@i18n(app.modules.mixer.swash_phase)@", unit = "°",  min = -1800, max = 1800 , decimals = 1,                   },                               -- MIXER_CONFIG
        [LAYOUTINDEX.COL_TILT_COR_POS] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_pos)@",    unit = "%", apiversiongte = 12.08},                                          -- MIXER_CONFIG
        [LAYOUTINDEX.COL_TILT_COR_NEG] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_neg)@",    unit = "%", apiversiongte = 12.08},                                          -- MIXER_CONFIG
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

-- we take the raw data from APIDATA and process it into FORMDATA for easier use in the form
-- the reverse is done in the save step
function apiDataToFormData() 

    -- get raw data from api table
    local CYCLIC_CALIBRATION = APIDATA["MIXER_INPUT_INDEXED_PITCH"]["values"].rate_stabilized_pitch
    local COLLECTIVE_CALIBRATION = APIDATA["MIXER_INPUT_INDEXED_COLLECTIVE"]["values"].rate_stabilized_collective
    local GEO_CORRECTION = APIDATA["MIXER_CONFIG"]["values"].swash_geo_correction
    local CYCLIC_PITCH_LIMIT = APIDATA["MIXER_INPUT_INDEXED_PITCH"]["values"].max_stabilized_pitch
    local SWASH_PITCH_LIMIT= APIDATA["MIXER_CONFIG"]["values"].swash_pitch_limit
    local COLLECTIVE_PITCH_LIMIT = APIDATA["MIXER_INPUT_INDEXED_COLLECTIVE"]["values"].max_stabilized_collective
    local SWASH_PHASE = APIDATA["MIXER_CONFIG"]["values"].swash_phase
    local COL_TILT_COR_POS = APIDATA["MIXER_CONFIG"]["values"].collective_tilt_correction_pos
    local COL_TILT_COR_NEG = APIDATA["MIXER_CONFIG"]["values"].collective_tilt_correction_neg

    -- determine directions
    COL_DIRECTION = (APIDATA["MIXER_INPUT_INDEXED_COLLECTIVE"]["values"].rate_stabilized_collective < 0) and 0 or 1
    ELE_DIRECTION = (APIDATA["MIXER_INPUT_INDEXED_PITCH"]["values"].rate_stabilized_pitch < 0) and 0 or 1
    AIL_DIRECTION = (APIDATA["MIXER_INPUT_INDEXED_ROLL"]["values"].rate_stabilized_roll < 0) and 0 or 1

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
    rfsuite.utils.log("SWASH_PITCH_LIMIT raw: "..tostring(SWASH_PITCH_LIMIT), "info")
    SWASH_PITCH_LIMIT = SWASH_PITCH_LIMIT * 12/100
    SWASH_PITCH_LIMIT = math.floor(SWASH_PITCH_LIMIT + 0.5)   
    rfsuite.utils.log("SWASH_PITCH_LIMIT scaled: "..tostring(SWASH_PITCH_LIMIT), "info")

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


-- -------------------------------------------------------
-- -- Load functions
-- -------------------------------------------------------

local LOAD_SEQUENCE = {
  "MIXER_CONFIG",
  "MIXER_INPUT_INDEXED_PITCH",
  "MIXER_INPUT_INDEXED_ROLL",
  "MIXER_INPUT_INDEXED_COLLECTIVE",
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
    APIDATA[IDX]['values']   = API.data().parsed
    APIDATA[IDX]['structure']   = API.data().structure
    APIDATA[IDX]['buffer']   = API.data().buffer
    APIDATA[IDX]['receivedBytesCount']   = API.data().receivedBytesCount
    APIDATA[IDX]['positionmap']   = API.data().positionmap
    APIDATA[IDX]['other']   = API.data().other
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
-- -- Save function
-- -------------------------------------------------------

function save.start()
  local app = rfsuite.app
  local formData = app.Page.apidata.formdata.fields

  -- use the stored payload
  local payload = rfsuite.tasks.msp.api.apidata.values["MIXER_CONFIG"]
  if not payload then return end

  -- gather values from the form
  payload["swash_geo_correction"] = formData[FIELDS.GEO_CORRECTION].value
  payload["swash_pitch_limit"]    = formData[FIELDS.SWASH_PITCH_LIMIT].value
  payload["swash_phase"]          = formData[FIELDS.SWASH_PHASE].value
  payload["collective_tilt_correction_pos"] = formData[FIELDS.COL_TILT_COR_POS].value
  payload["collective_tilt_correction_neg"] = formData[FIELDS.COL_TILT_COR_NEG].value

  -- write the data back via MSP
  local API = rfsuite.tasks.msp.api.load("MIXER_CONFIG")
  API.setRebuildOnWrite(true)
  API.setCompleteHandler(function(self, buf)
      app.triggers.closeProgressLoader = true
  end)

  for k, v in pairs(payload) do
    API.setValue(k, v)
  end

  API.write()
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
        rfsuite.app.ui.progressDisplay()
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