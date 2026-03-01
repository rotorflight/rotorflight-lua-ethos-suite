--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

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
local LAYOUTINDEX = {
        SWASH_TYPE       = 1,   -- MIXER_CONFIG
        ROTOR_DIRECTION  = 2,   -- MIXER_CONFIG
        AIL_DIRECTION    = 3,   -- GET_MIXER_INPUT_ROLL
        ELE_DIRECTION    = 4,   -- GET_MIXER_INPUT_PITCH
        COL_DIRECTION    = 5,   -- GET_MIXER_INPUT_COLLECTIVE
    }

local LAYOUT = {
        [LAYOUTINDEX.SWASH_TYPE] = {t = "@i18n(app.modules.mixer.swash_type)@",   table = {"None", "Direct", "CPPM 120", "CPPM 135", "CPPM 140", "FPM 90 L", "FPM 90 V"}, tableIdxInc = -1, onChange = function() needsReboot = true end},   -- MIXER_CONFIG
        [LAYOUTINDEX.ROTOR_DIRECTION] = {t = "@i18n(app.modules.mixer.main_rotor_dir)@",   table = {[0] = "@i18n(api.MIXER_CONFIG.tbl_cw)@", [1] = "@i18n(api.MIXER_CONFIG.tbl_ccw)@"}},           -- MIXER_CONFIG
        [LAYOUTINDEX.AIL_DIRECTION] = {t = "@i18n(app.modules.mixer.aileron_direction)@",   table = {[0] = "@i18n(api.MIXER_INPUT.tbl_reversed)@", [1] = "@i18n(api.MIXER_INPUT.tbl_normal)@"}},   -- GET_MIXER_INPUT_ROLL
        [LAYOUTINDEX.ELE_DIRECTION] = {t = "@i18n(app.modules.mixer.elevator_direction)@",    table = {[0] = "@i18n(api.MIXER_INPUT.tbl_reversed)@", [1] = "@i18n(api.MIXER_INPUT.tbl_normal)@"}}, -- GET_MIXER_INPUT_PITCH
        [LAYOUTINDEX.COL_DIRECTION] = {t = "@i18n(app.modules.mixer.collective_direction)@",  table = {[0] = "@i18n(api.MIXER_INPUT.tbl_reversed)@", [1] = "@i18n(api.MIXER_INPUT.tbl_normal)@"}}, -- GET_MIXER_INPUT_COLLECTIVE
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
    local SWASH_TYPE = APIDATA["MIXER_CONFIG"]["values"].swash_type
    local ROTOR_DIRECTION = APIDATA["MIXER_CONFIG"]["values"].main_rotor_dir

    -- determine directions
    COL_DIRECTION = rateToDir(APIDATA["GET_MIXER_INPUT_COLLECTIVE"]["values"].rate_stabilized_collective)
    ELE_DIRECTION = rateToDir(APIDATA["GET_MIXER_INPUT_PITCH"]["values"].rate_stabilized_pitch)
    AIL_DIRECTION = rateToDir(APIDATA["GET_MIXER_INPUT_ROLL"]["values"].rate_stabilized_roll)
 

    -- store processed data into form data table
    FORMDATA[LAYOUTINDEX.SWASH_TYPE] = SWASH_TYPE
    FORMDATA[LAYOUTINDEX.ROTOR_DIRECTION] = ROTOR_DIRECTION
    FORMDATA[LAYOUTINDEX.AIL_DIRECTION] = AIL_DIRECTION
    FORMDATA[LAYOUTINDEX.ELE_DIRECTION] = ELE_DIRECTION
    FORMDATA[LAYOUTINDEX.COL_DIRECTION] = COL_DIRECTION

end

-- the reverse of apiDataToFormData: take the values from FORMDATA and convert them back into raw API values
function copyFormToApiValues()
    local apiValues = APIDATA
    if not apiValues then return false end

    -- helper: your stored dirs are 0/1; convert to -1/+1
    local function dirSign(d)
        return (d == 0) and -1 or 1
    end

    local function applyDirectionToRate(u16rate, dir01)
        if u16rate == nil then return nil end
        local s = u16_to_s16(u16rate)
        local mag = math.abs(s)
        local signed = mag * dirSign(dir01)
        return s16_to_u16(signed)
    end

    -- ----------------------------
    -- MIXER_CONFIG payload
    -- ----------------------------
    local mixerCfg = apiValues["MIXER_CONFIG"].values
    if not mixerCfg then return false end

    -- GEO_CORRECTION: forward was (raw/5)*10  => raw*2 ; reverse raw=form/2
    mixerCfg["swash_type"] = FORMDATA[LAYOUTINDEX.SWASH_TYPE]
    mixerCfg["main_rotor_dir"] = FORMDATA[LAYOUTINDEX.ROTOR_DIRECTION]

    -- ----------------------------
    -- Directions: flip sign of the existing rates
    -- (keep current magnitudes; only change direction)
    -- ----------------------------
    local pitch = apiValues["GET_MIXER_INPUT_PITCH"] and apiValues["GET_MIXER_INPUT_PITCH"].values
    local roll  = apiValues["GET_MIXER_INPUT_ROLL"] and apiValues["GET_MIXER_INPUT_ROLL"].values
    local coll  = apiValues["GET_MIXER_INPUT_COLLECTIVE"] and apiValues["GET_MIXER_INPUT_COLLECTIVE"].values

    if pitch then
        pitch["rate_stabilized_pitch"] =
            applyDirectionToRate(pitch["rate_stabilized_pitch"], FORMDATA[LAYOUTINDEX.ELE_DIRECTION])
    end
    if roll then
        roll["rate_stabilized_roll"] =
            applyDirectionToRate(roll["rate_stabilized_roll"], FORMDATA[LAYOUTINDEX.AIL_DIRECTION])
    end
    if coll then
        coll["rate_stabilized_collective"] =
            applyDirectionToRate(coll["rate_stabilized_collective"], FORMDATA[LAYOUTINDEX.COL_DIRECTION])
    end

    -- keep globals aligned (optional, but helps consistency if reused)
    AIL_DIRECTION = FORMDATA[LAYOUTINDEX.AIL_DIRECTION]
    ELE_DIRECTION = FORMDATA[LAYOUTINDEX.ELE_DIRECTION]
    COL_DIRECTION = FORMDATA[LAYOUTINDEX.COL_DIRECTION]

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

        if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.setPageDirty then
            rfsuite.app.ui.setPageDirty(false)
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
local function openPage(opts)

    local idx = opts.idx
    local title = opts.title
    local script = opts.script

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

    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

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
    pageRuntime.openMenuContext()
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
