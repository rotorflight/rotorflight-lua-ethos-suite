--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false
local triggerSave = false

-- sore loaded directions here to ensure writeback consistency
local AIL_DIRECTION
local ELE_DIRECTION
local COL_DIRECTION

local FIELDS = {
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


local apidata = {
    api = {
    },
    formdata = {
        labels = {             
        },
        fields = {
            [FIELDS.CYCLIC_CALIBRATION] = {t = "@i18n(app.modules.mixer.cyclic_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"  },           -- MIXER_INPUT_INDEXED_PITCH
            [FIELDS.COLLECTIVE_CALIBRATION] = {t = "@i18n(app.modules.mixer.collective_calibration)@",    default = 400, step = 1, decimals = 1, min = 200, max = 2000, unit = "%"   },  -- MIXER_INPUT_INDEXED_COLLECTIVE
            [FIELDS.GEO_CORRECTION] = {t = "@i18n(app.modules.mixer.geo_correction)@",                     },                                                                            -- MIXER_CONFIG
            [FIELDS.CYCLIC_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.cyclic_pitch_limit)@", unit = "°"  ,  default = 20, decimals = 1 , min = 0, max = 20       },                    -- MIXER_INPUT_INDEXED_PITCH
            [FIELDS.COLLECTIVE_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.collective_pitch_limit)@",  unit = "°" , default = 20, decimals = 1 , min = 0, max = 20     },               -- MIXER_INPUT_INDEXED_COLLECTIVE  
            [FIELDS.SWASH_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.swash_pitch_limit)@", unit = "°" , default = 200,    decimals = 1 , min = 0, max = 360      },                    -- MIXER_CONFIG
            [FIELDS.SWASH_PHASE] = {t = "@i18n(app.modules.mixer.swash_phase)@",                     },                                                                                  -- MIXER_CONFIG
            [FIELDS.COL_TILT_COR_POS] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_pos)@",    unit = "%", apiversiongte = 12.08},                                          -- MIXER_CONFIG
            [FIELDS.COL_TILT_COR_NEG] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_neg)@",    unit = "%", apiversiongte = 12.08},                                          -- MIXER_CONFIG
        }
    }
}


local function getFieldInfoFromApiStructure(fieldName, structure)
    for i, v in ipairs(structure) do
        if v.field == fieldName then
            return v
        end
    end
end

local function mspToUi(v, fi)
    if v == nil then return nil end

    local value = v

    -- scale (API scale is divisor)
    if fi.scale and fi.scale ~= 0 then
        value = value / fi.scale
    end

    -- mult (UI multiplier)
    if fi.mult then
        value = value * fi.mult
    end

    -- decimals handled by widget, do NOT multiply here
    return value
end

local function injectField(fieldIdx, apikey, API, opts)
    opts = opts or {}

    local app        = rfsuite.app
    local fields     = app.Page.apidata.formdata.fields
    local formFields = app.formFields
    local structure  = API.data().structure

    local f  = fields[fieldIdx]
    local ff = formFields[fieldIdx]
    if not f or type(ff) ~= "userdata" then
        return false
    end

    local fieldInfo = getFieldInfoFromApiStructure(apikey, structure)
    if not fieldInfo then
        return false
    end

    local raw = API.readValue(apikey)

    -- Metadata used by save path / renderer
    f.scale = fieldInfo.scale
    f.mult  = fieldInfo.mult
    f.step  = fieldInfo.step
    f.unit  = fieldInfo.unit
    f.help  = fieldInfo.help
    f.decimals = fieldInfo.decimals

    -- Value
    if opts.valueOverride ~= nil then
        f.value = mspToUi(opts.valueOverride, fieldInfo)
    else
        f.value = mspToUi(raw, fieldInfo)
    end

    print(apikey .." " .. f.value)


    if raw == nil and opts.disableIfNil ~= false then
        ff:enable(false)
        return true
    end

    -- UI constraints
    if fieldInfo.min ~= nil then ff:minimum(fieldInfo.min) end
    if fieldInfo.max ~= nil then ff:maximum(fieldInfo.max) end
    if fieldInfo.decimals ~= nil then ff:decimals(fieldInfo.decimals) end
    if fieldInfo.default ~= nil then ff:default(fieldInfo.default) end
    if fieldInfo.unit ~= nil then ff:suffix(fieldInfo.unit) end
    if fieldInfo.help ~= nil then ff:help(fieldInfo.help) end
    if fieldInfo.step ~= nil then ff:step(fieldInfo.step) end

    return true
end

local function u16_to_s16(u)
    if u >= 0x8000 then
        return u - 0x10000
    else
        return u
    end
end

local function loadDataComplete()
   rfsuite.app.triggers.closeProgressLoader = true
end

local function loadDataStep4()

        -- fetch the mixer config data via MSP
        local API = rfsuite.tasks.msp.api.load("MIXER_INPUT_INDEXED_COLLECTIVE")
        API.setCompleteHandler(function(self, buf)

            local structure = API.data().structure
            local fields = rfsuite.app.Page.apidata.formdata.fields
            local formFields = rfsuite.app.formFields
            local collective_calibration
            local collective_pitch_limit

            -- get just one field
            local rate_stabilized_collective = API.readValue("rate_stabilized_collective")
            local min_stabilized_collective = API.readValue("min_stabilized_collective")
            local max_stabilized_collective = API.readValue("max_stabilized_collective")

            -- store the direction for later use         
            COL_DIRECTION = (rate_stabilized_collective < 0) and 0 or 1

            -- convert the value to the expected signed value
            collective_calibration = u16_to_s16(rate_stabilized_collective)
            collective_calibration = math.abs(collective_calibration) 
            if collective_calibration >= 2000 then collective_calibration = 2000  end
            if collective_calibration <= 200 then collective_calibration = 200 end

            collective_pitch_limit = u16_to_s16(max_stabilized_collective)

            collective_pitch_limit = collective_pitch_limit * 12/100  
            collective_pitch_limit = math.floor(collective_pitch_limit + 0.5)
            collective_pitch_limit = math.abs(collective_pitch_limit)  -- force positive

            -- transform into something we can use for cyclic calibration
            injectField(FIELDS.COLLECTIVE_CALIBRATION, "rate_stabilized_collective", API, {valueOverride = collective_calibration})
            injectField(FIELDS.COLLECTIVE_PITCH_LIMIT, "max_stabilized_collective", API, {valueOverride = collective_pitch_limit})

            -- store the raw data for later use
            rfsuite.tasks.msp.api.apidata.values["MIXER_INPUT_INDEXED_COLLECTIVE"] = API.data().parsed
            rfsuite.tasks.msp.api.apidata.structure["MIXER_INPUT_INDEXED_COLLECTIVE"] = API.data().structure
            rfsuite.tasks.msp.api.apidata.receivedBytes["MIXER_INPUT_INDEXED_COLLECTIVE"] = API.data().buffer
            rfsuite.tasks.msp.api.apidata.receivedBytesCount["MIXER_INPUT_INDEXED_COLLECTIVE"] = API.data().receivedBytesCount
            rfsuite.tasks.msp.api.apidata.positionmap["MIXER_INPUT_INDEXED_COLLECTIVE"] = API.data().positionmap
            rfsuite.tasks.msp.api.apidata.other["MIXER_INPUT_INDEXED_COLLECTIVE"] = API.data().other or {}


            loadDataComplete()

        end)
        API.setUUID("d8163617-1496-4886-8b81-61sd6d6ed92")
        API.read()
end


local function loadDataStep3()
        -- fetch the mixer config data via MSP
        local API = rfsuite.tasks.msp.api.load("MIXER_INPUT_INDEXED_ROLL")
        API.setCompleteHandler(function(self, buf)

            local structure = API.data().structure
            local fields = rfsuite.app.Page.apidata.formdata.fields
            local formFields = rfsuite.app.formFields
            local cyclic_calibration 
            local cyclic_pitch_limit

            -- get just one field
            local rate_stabilized_roll = API.readValue("rate_stabilized_roll")

            -- store the direction for later use
            AIL_DIRECTION = (rate_stabilized_roll < 0) and 0 or 1            

            -- bump to next step
            loadDataStep4()

        end)
        API.setUUID("e7163617-2496-4886-8b81-61sd6d7ed82")
        API.read()

end


local function loadDataStep2()
        -- fetch the mixer config data via MSP
        local API = rfsuite.tasks.msp.api.load("MIXER_INPUT_INDEXED_PITCH")
        API.setCompleteHandler(function(self, buf)

            local structure = API.data().structure
            local fields = rfsuite.app.Page.apidata.formdata.fields
            local formFields = rfsuite.app.formFields
            local cyclic_calibration 
            local cyclic_pitch_limit

            -- get just one field
            local rate_stabilized_pitch = API.readValue("rate_stabilized_pitch")
            local min_stabilized_pitch = API.readValue("min_stabilized_pitch")
            local max_stabilized_pitch = API.readValue("max_stabilized_pitch")

            -- store the direction for later use
            ELE_DIRECTION = (rate_stabilized_pitch < 0) and 0 or 1

            -- convert the value to the expected signed value
            cyclic_calibration = u16_to_s16(rate_stabilized_pitch)
            cyclic_calibration = math.abs(cyclic_calibration)
            if cyclic_calibration >= 2000 then cyclic_calibration = 2000  end
            if cyclic_calibration <= 200 then cyclic_calibration = 200 end

            cyclic_pitch_limit = u16_to_s16(max_stabilized_pitch)
            cyclic_pitch_limit = cyclic_pitch_limit * 12/100  
            cyclic_pitch_limit = math.floor(cyclic_pitch_limit + 0.5)
            cyclic_pitch_limit = math.abs(cyclic_pitch_limit)  -- force positive

            -- transform into something we can use for cyclic calibration
            injectField(FIELDS.CYCLIC_CALIBRATION, "rate_stabilized_pitch", API, {valueOverride = cyclic_calibration})
            injectField(FIELDS.CYCLIC_PITCH_LIMIT, "max_stabilized_pitch", API, {valueOverride = cyclic_pitch_limit})

            -- store the raw data for later use
            rfsuite.tasks.msp.api.apidata.values["MIXER_INPUT_INDEXED_PITCH"] = API.data().parsed
            rfsuite.tasks.msp.api.apidata.structure["MIXER_INPUT_INDEXED_PITCH"] = API.data().structure
            rfsuite.tasks.msp.api.apidata.receivedBytes["MIXER_INPUT_INDEXED_PITCH"] = API.data().buffer
            rfsuite.tasks.msp.api.apidata.receivedBytesCount["MIXER_INPUT_INDEXED_PITCH"] = API.data().receivedBytesCount
            rfsuite.tasks.msp.api.apidata.positionmap["MIXER_INPUT_INDEXED_PITCH"] = API.data().positionmap
            rfsuite.tasks.msp.api.apidata.other["MIXER_INPUT_INDEXED_PITCH"] = API.data().other or {}

            -- bump to next step
            loadDataStep3()

        end)
        API.setUUID("b91s3647-1496-4886-8b81-61sd6d7ed82")
        API.read()

end

local function loadDataStep1()
        -- fetch the mixer config data via MSP
        local API = rfsuite.tasks.msp.api.load("MIXER_CONFIG")
        API.setCompleteHandler(function(self, buf)

            local structure = API.data().structure
            local fields = rfsuite.app.Page.apidata.formdata.fields
            local formFields = rfsuite.app.formFields

            local swash_pitch_limit = API.readValue("swash_pitch_limit")
            total_pitch_limit= swash_pitch_limit * 12/1000  
            total_pitch_limit = math.floor(total_pitch_limit + 0.5)
            total_pitch_limit = math.abs(total_pitch_limit)  -- force positive      
            
            rfsuite.utils.log("Converted swash pitch limit value: " .. tostring(total_pitch_limit),"info")

            injectField(FIELDS.GEO_CORRECTION, "swash_geo_correction", API)
            injectField(FIELDS.SWASH_PITCH_LIMIT, "swash_pitch_limit", API, {valueOverride = total_pitch_limit})
            injectField(FIELDS.SWASH_PHASE, "swash_phase", API)
            injectField(FIELDS.COL_TILT_COR_POS, "collective_tilt_correction_pos", API)
            injectField(FIELDS.COL_TILT_COR_NEG, "collective_tilt_correction_neg", API)

            -- store the raw data for later use
            rfsuite.tasks.msp.api.apidata.values["MIXER_CONFIG"] = API.data().parsed
            rfsuite.tasks.msp.api.apidata.structure["MIXER_CONFIG"] = API.data().structure
            rfsuite.tasks.msp.api.apidata.receivedBytes["MIXER_CONFIG"] = API.data().buffer
            rfsuite.tasks.msp.api.apidata.receivedBytesCount["MIXER_CONFIG"] = API.data().receivedBytesCount
            rfsuite.tasks.msp.api.apidata.positionmap["MIXER_CONFIG"] = API.data().positionmap
            rfsuite.tasks.msp.api.apidata.other["MIXER_CONFIG"] = API.data().other or {}

            -- bump to next step
            loadDataStep2()

        end)
        API.setUUID("d8163617-1496-4886-8b81-61sd6d7ed81")
        API.read()

end

local function saveDataStep1()
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


local function onNavMenu(self)
    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")
end

local function postLoad(self)
    enableWakeup = true
    loadDataStep1()
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
        saveDataStep1()
        triggerSave = false
    end   

end

local function onReloadMenu() rfsuite.app.triggers.triggerReloadFull = true end


return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu, onSaveMenu = onSaveMenu, postLoad = postLoad, wakeup = wakeup, onReloadMenu = onReloadMenu}