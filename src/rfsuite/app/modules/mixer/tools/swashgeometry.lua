--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local triggerSave = false
local triggerOverRide = false
local inOverRide = false
local saveBusy = false
local lastChangeTime = os.clock()
local lastAppliedDigest
local lastAppliedFields
local pendingApplyDigest
local pendingApplyFields
local liveWriteStartedAt
local activeSaveSequence
local LIVE_BASE_INTERVAL = 0.2
local LIVE_INTERVAL_MIN = 0.12
local LIVE_INTERVAL_MAX = 0.90
local LIVE_INTERVAL_STEP_RELAX = 0.02
local LIVE_INTERVAL_STEP_BUSY = 0.08
local LIVE_INTERVAL_STEP_FAIL = 0.12
local liveUpdateInterval = LIVE_BASE_INTERVAL
local MIXER_OVERRIDE_OFF = 2501
local MIXER_OVERRIDE_ON = 0
local MIXER_OVERRIDE_PASSTHROUGH = 2502

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
        COLLECTIVE_PITCH_LIMIT   = 5,   -- GET_MIXER_INPUT_COLLECTIVE
        SWASH_PITCH_LIMIT        = 6,   -- MIXER_CONFIG
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


local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function formDigest()
    local digest = {}
    for i = 1, LAYOUTINDEX.COL_TILT_COR_NEG do
        digest[#digest + 1] = tostring(FORMDATA[i] or "")
    end
    return table.concat(digest, "|")
end

local function snapshotFormFields()
    local snapshot = {}
    for i = 1, LAYOUTINDEX.COL_TILT_COR_NEG do
        snapshot[i] = FORMDATA[i]
    end
    return snapshot
end

local function clearPendingApplyState()
    pendingApplyDigest = nil
    pendingApplyFields = nil
    activeSaveSequence = nil
end

local function applyPendingApplyState()
    if pendingApplyDigest ~= nil then
        lastAppliedDigest = pendingApplyDigest
    end
    if pendingApplyFields ~= nil then
        lastAppliedFields = pendingApplyFields
    end
    clearPendingApplyState()
end

local function clamp(v, minv, maxv)
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local function adaptLiveIntervalFromQueue(ok, reason, pending)
    if ok then
        if reason == "queued_busy" or ((pending or 0) > 1) then
            liveUpdateInterval = clamp(liveUpdateInterval + LIVE_INTERVAL_STEP_BUSY, LIVE_INTERVAL_MIN, LIVE_INTERVAL_MAX)
        elseif reason == "queued" then
            liveUpdateInterval = clamp(liveUpdateInterval - LIVE_INTERVAL_STEP_RELAX, LIVE_INTERVAL_MIN, LIVE_INTERVAL_MAX)
        end
        return
    end

    if reason == "busy" then
        liveUpdateInterval = clamp(liveUpdateInterval + LIVE_INTERVAL_STEP_BUSY, LIVE_INTERVAL_MIN, LIVE_INTERVAL_MAX)
    else
        liveUpdateInterval = clamp(liveUpdateInterval + LIVE_INTERVAL_STEP_FAIL, LIVE_INTERVAL_MIN, LIVE_INTERVAL_MAX)
    end
end

local function mixerOverrideOnValue()
    if rfsuite.utils and rfsuite.utils.apiVersionCompare and rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
        return MIXER_OVERRIDE_PASSTHROUGH
    end
    return MIXER_OVERRIDE_ON
end

local function isPassthroughMixerOverride()
    return mixerOverrideOnValue() == MIXER_OVERRIDE_PASSTHROUGH
end

local function setMixerOverrideAudio(enabled)
    local audio = rfsuite.app and rfsuite.app.audio
    if not audio then return end

    if isPassthroughMixerOverride() then
        if enabled then
            audio.playMixerPassthroughOverideEnable = true
        else
            audio.playMixerPassthroughOverideDisable = true
        end
        return
    end

    if enabled then
        audio.playMixerOverideEnable = true
    else
        audio.playMixerOverideDisable = true
    end
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


local function mixerOn()

    setMixerOverrideAudio(true)

    local overrideValue = mixerOverrideOnValue()
    for i = 1, 4 do
        local message = {command = 191, payload = {i}}
        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, overrideValue)
        queueDirect(message, string.format("mixer.override.%d.on", i))
    end

    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function mixerOff()

    setMixerOverrideAudio(false)

    for i = 1, 4 do
        local message = {command = 191, payload = {i}}
        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, MIXER_OVERRIDE_OFF)
        queueDirect(message, string.format("mixer.override.%d.off", i))
    end

    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
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
  lastAppliedDigest = formDigest()
  lastAppliedFields = snapshotFormFields()
  clearPendingApplyState()
  liveWriteStartedAt = nil
  liveUpdateInterval = LIVE_BASE_INTERVAL
  lastChangeTime = os.clock()
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

local function markChangedApisForField(fieldIndex, changedApis)
    if fieldIndex == LAYOUTINDEX.CYCLIC_CALIBRATION or fieldIndex == LAYOUTINDEX.CYCLIC_PITCH_LIMIT then
        changedApis["GET_MIXER_INPUT_PITCH"] = true
        changedApis["GET_MIXER_INPUT_ROLL"] = true
        return
    end

    if fieldIndex == LAYOUTINDEX.COLLECTIVE_CALIBRATION or fieldIndex == LAYOUTINDEX.COLLECTIVE_PITCH_LIMIT then
        changedApis["GET_MIXER_INPUT_COLLECTIVE"] = true
        return
    end

    changedApis["MIXER_CONFIG"] = true
end

local function buildLiveSaveSequence()
    if not lastAppliedFields then
        local sequence = {}
        for i = 1, #SAVE_SEQUENCE do
            sequence[#sequence + 1] = SAVE_SEQUENCE[i]
        end
        return sequence
    end

    local changedApis = {}
    for i = 1, LAYOUTINDEX.COL_TILT_COR_NEG do
        if FORMDATA[i] ~= lastAppliedFields[i] then
            markChangedApisForField(i, changedApis)
        end
    end

    local sequence = {}
    for i = 1, #SAVE_SEQUENCE do
        local apikey = SAVE_SEQUENCE[i]
        if changedApis[apikey] then
            sequence[#sequence + 1] = apikey
        end
    end
    return sequence
end

local function writeNext(i, commitToEeprom)
    local sequence = activeSaveSequence or SAVE_SEQUENCE
    local apikey = sequence[i]
    if not apikey then
        if commitToEeprom then
            local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
            EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
            EAPI.setCompleteHandler(function(self)
                rfsuite.utils.log("Writing to EEPROM", "info")
                applyPendingApplyState()
                liveWriteStartedAt = nil
                if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.setPageDirty then
                    rfsuite.app.ui.setPageDirty(false)
                end
                saveBusy = false
                rfsuite.app.triggers.closeProgressLoader = true
            end)
            local ok = EAPI.write()
            if ok == false then
                saveBusy = false
                clearPendingApplyState()
                liveWriteStartedAt = nil
                rfsuite.app.triggers.closeProgressLoader = true
            end
        else
            applyPendingApplyState()
            if liveWriteStartedAt then
                local elapsed = os.clock() - liveWriteStartedAt
                local target = clamp(elapsed * 0.75, LIVE_INTERVAL_MIN, LIVE_INTERVAL_MAX)
                liveUpdateInterval = clamp((liveUpdateInterval * 0.7) + (target * 0.3), LIVE_INTERVAL_MIN, LIVE_INTERVAL_MAX)
            end
            liveWriteStartedAt = nil
            saveBusy = false
        end
        return
    end

    local API = rfsuite.tasks.msp.api.load(apikey)
    API.setRebuildOnWrite(true)

    API.setCompleteHandler(function(self, buf)
        writeNext(i + 1, commitToEeprom)
    end)

    -- Apply only the fields present in the payload table.
    local payload = APIDATA[apikey].values
    if payload then
        for k, v in pairs(payload) do
            API.setValue(k, v)
        end
    end

    API.setUUID("d8163617-1496-4886-8b81-write-" .. apikey)
    local ok, reason, _, pending = API.write()
    if not commitToEeprom then
        adaptLiveIntervalFromQueue(ok, reason, pending)
    end
    if ok == false then
        saveBusy = false
        clearPendingApplyState()
        liveWriteStartedAt = nil
        lastChangeTime = os.clock()
        if commitToEeprom then
            rfsuite.app.triggers.closeProgressLoader = true
        end
    end
end

function save.start(commitToEeprom)
    if saveBusy then
        return false
    end

    local commit = (commitToEeprom ~= false)
    local sequence
    if commit then
        sequence = SAVE_SEQUENCE
    else
        sequence = buildLiveSaveSequence()
        if #sequence == 0 then
            return false
        end
    end

    if not copyFormToApiValues() then
        return false
    end

    saveBusy = true
    activeSaveSequence = {}
    for i = 1, #sequence do
        activeSaveSequence[i] = sequence[i]
    end
    pendingApplyDigest = formDigest()
    pendingApplyFields = snapshotFormFields()
    if not commit then
        liveWriteStartedAt = os.clock()
    else
        liveWriteStartedAt = nil
    end
    writeNext(1, commit)
    return true
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
    triggerOverRide = false
    inOverRide = false
    saveBusy = false
    lastAppliedDigest = nil
    lastAppliedFields = nil
    clearPendingApplyState()
    liveWriteStartedAt = nil
    liveUpdateInterval = LIVE_BASE_INTERVAL

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
        if formFields[i].enableInstantChange then formFields[i]:enableInstantChange(true) end
        if f.help then formFields[i]:help(f.help or "") end       
    end


    -- start msp load sequence
    load.start()
    enableWakeup = true
end



local function disableOverrideForExit(showDialog)
    if not inOverRide then
        return
    end
    inOverRide = false
    if showDialog then
        rfsuite.app.ui.progressDisplay("@i18n(app.modules.mixer.swash_override)@", "@i18n(app.modules.mixer.swash_override_disabling)@")
    end
    mixerOff()
end

local function onNavMenu(self)
    disableOverrideForExit(true)
    pageRuntime.openMenuContext()
end

local function onToolMenu(self)

    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()
                triggerOverRide = true
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    local message
    local title
    if inOverRide == false then
        title = "@i18n(app.modules.mixer.enable_swash_override)@"
        message = "@i18n(app.modules.mixer.enable_swash_override_message)@"
    else
        title = "@i18n(app.modules.mixer.disable_swash_override)@"
        message = "@i18n(app.modules.mixer.disable_swash_override_message)@"
    end

    form.openDialog({width = nil, title = title, message = message, buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
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

local function wakeup(self)
    if not enableWakeup then
        return
    end 

    if triggerOverRide == true then
        triggerOverRide = false

        if inOverRide == false then

            rfsuite.app.ui.progressDisplay("@i18n(app.modules.mixer.swash_override)@", "@i18n(app.modules.mixer.swash_override_enabling)@")
            mixerOn()
            inOverRide = true
            lastAppliedDigest = formDigest()
            lastAppliedFields = snapshotFormFields()
        else

            rfsuite.app.ui.progressDisplay("@i18n(app.modules.mixer.swash_override)@", "@i18n(app.modules.mixer.swash_override_disabling)@")
            mixerOff()
            inOverRide = false
        end
    end

    if triggerSave then
        if saveBusy then
            return
        end
        rfsuite.app.ui.progressDisplay("@i18n(app.msg_saving_settings)@","@i18n(app.msg_saving_to_fbl)@")
        if save.start(true) then
            triggerSave = false
        end
    end

    if inOverRide == true then
        local now = os.clock()
        local currentDigest = formDigest()
        if currentDigest ~= lastAppliedDigest and not saveBusy and (now - lastChangeTime) >= liveUpdateInterval and rfsuite.tasks.msp.mspQueue:isProcessed() then
            if save.start(false) then
                lastChangeTime = now
            end
        end
    end   

end

local function onReloadMenu(self)
    disableOverrideForExit(true)
    rfsuite.app.triggers.triggerReloadFull = true
end

local function close(self)
    disableOverrideForExit(false)
end


return {
    openPage = openPage, 
    onNavMenu=onNavMenu, 
    onSaveMenu = onSaveMenu, 
    onToolMenu = onToolMenu,
    mixerOn = mixerOn,
    mixerOff = mixerOff,
    postLoad = postLoad, 
    wakeup = wakeup, 
    onReloadMenu = onReloadMenu,
    close = close,
    navButtons = {
        menu = true, 
        save = true, 
        reload = true, 
        tool = true, 
        help = false
    }
}
