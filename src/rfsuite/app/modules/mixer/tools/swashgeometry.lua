--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false
local triggerSave = false

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
            [FIELDS.CYCLIC_CALIBRATION] = {t = "@i18n(app.modules.mixer.cyclic_calibration)@",    default = 400, step = 1, scale = 10, decimals = 1, min = 200, max = 2000, unit = "%"  },
            [FIELDS.COLLECTIVE_CALIBRATION] = {t = "@i18n(app.modules.mixer.collective_calibration)@",    default = 400, step = 1, scale = 10, decimals = 1, min = 200, max = 2000, unit = "%"   },
            [FIELDS.GEO_CORRECTION] = {t = "@i18n(app.modules.mixer.geo_correction)@",  unit = "%"                   },
            [FIELDS.CYCLIC_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.cyclic_pitch_limit)@", unit = "°"            },
            [FIELDS.COLLECTIVE_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.collective_pitch_limit)@", unit = "°"        },
            [FIELDS.SWASH_PITCH_LIMIT] = {t = "@i18n(app.modules.mixer.swash_pitch_limit)@",  unit = "°" , scale = 10, decimals = 1 , step = 1                   },
            [FIELDS.SWASH_PHASE] = {t = "@i18n(app.modules.mixer.swash_phase)@",  unit = "°"                     },
            [FIELDS.COL_TILT_COR_POS] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_pos)@",    unit = "%", apiversiongte = 12.08},
            [FIELDS.COL_TILT_COR_NEG] = {t = "@i18n(app.modules.mixer.collective_tilt_correction_neg)@",    unit = "%", apiversiongte = 12.08},            
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

    -- Value
    if opts.valueOverride ~= nil then
        f.value = opts.valueOverride
    else
        f.value = raw
    end

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

local function loadDataStep3()

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

            -- convert the value to the expected signed value
            collective_calibration = u16_to_s16(rate_stabilized_collective)
            collective_calibration = math.abs(collective_calibration)
            if collective_calibration >= 200 then collective_calibration = 200  end
            if collective_calibration <= 20 then collective_calibration = 20 end

            collective_pitch_limit = u16_to_s16(max_stabilized_collective)
            collective_pitch_limit = math.abs(collective_pitch_limit)
            if collective_pitch_limit >= 200 then collective_pitch_limit = 200  end
            if collective_pitch_limit <= 20 then collective_pitch_limit = 20 end

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

            -- all done
            rfsuite.app.triggers.closeProgressLoader = true

        end)
        API.setUUID("d8163617-1496-4886-8b81-61sd6d6ed92")
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

            -- convert the value to the expected signed value
            cyclic_calibration = u16_to_s16(rate_stabilized_pitch)
            cyclic_calibration = math.abs(cyclic_calibration)
            if cyclic_calibration >= 200 then cyclic_calibration = 200 end
            if cyclic_calibration <= 20 then cyclic_calibration = 20 end

            cyclic_pitch_limit = u16_to_s16(max_stabilized_pitch)
            cyclic_pitch_limit = math.abs(cyclic_pitch_limit)
            if cyclic_pitch_limit >= 200 then cyclic_pitch_limit = 200  end
            if cyclic_pitch_limit <= 20 then cyclic_pitch_limit = 20 end

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
        API.setUUID("d8163617-1496-4886-8b81-61sd6d7ed82")
        API.read()

end

local function loadDataStep1()
        -- fetch the mixer config data via MSP
        local API = rfsuite.tasks.msp.api.load("MIXER_CONFIG")
        API.setCompleteHandler(function(self, buf)

            local structure = API.data().structure
            local fields = rfsuite.app.Page.apidata.formdata.fields
            local formFields = rfsuite.app.formFields

            local swash_geo_correction = API.readValue("swash_geo_correction")
            local swash_pitch_limit = API.readValue("swash_pitch_limit")
            local collective_tilt_correction_pos = API.readValue("collective_tilt_correction_pos")
            local collective_tilt_correction_neg = API.readValue("collective_tilt_correction_neg")
            local swash_phase = API.readValue("swash_phase")

            injectField(FIELDS.GEO_CORRECTION, "swash_geo_correction", API)
            injectField(FIELDS.SWASH_PITCH_LIMIT, "swash_pitch_limit", API)
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
      --rfsuite.utils.log("Swash Geometry: MIXER_CONFIG saved", "info")
      app.triggers.closeProgressLoader = true
  end)

  for k, v in pairs(payload) do
    --rfsuite.utils.log("Setting value for " .. k .. ": " .. tostring(v), "info")
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
        rfsuite.app.ui.progressDisplaySave()
        saveDataStep1()
        triggerSave = false
    end   

end


return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu, onSaveMenu = onSaveMenu, postLoad = postLoad, wakeup = wakeup}
