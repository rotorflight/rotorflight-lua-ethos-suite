local fields = {}
local rows = {}
local cols = {}

local total_bytes = rfsuite.preferences.mspExpBytes

local function uint8_to_int8(value)
    -- Ensure the value is within uint8 range
    if value < 0 or value > 255 then error("Value out of uint8 range") end

    -- Convert to int8
    if value > 127 then
        return value - 256
    else
        return value
    end
end

local function int8_to_uint8(value)
    -- Convert signed 8-bit to unsigned 8-bit
    return value & 0xFF
end

function update_int8()
    -- update the uint8 fields
    for i,v in ipairs(rfsuite.app.Page.fields) do
        if v.isINT8 then
            -- we now have to update the value in the associated field
            -- that has the same label id number
            for j,w in ipairs(rfsuite.app.Page.fields) do
                if w.isUINT8 and w.label == v.label then
                    v.value = uint8_to_int8(w.value)
                end
            end
        end
    end
end

function update_uint8()
    -- update the uint8 fields
    for i,v in ipairs(rfsuite.app.Page.fields) do
        if v.isUINT8 then
            -- we now have to update the value in the associated field
            -- that has the same label id number
            for j,w in ipairs(rfsuite.app.Page.fields) do
                if w.isINT8 and w.label == v.label then
                    v.value = int8_to_uint8(w.value)
                end
            end
        end
    end
end

function generateMSPAPI(numLabels)
    local mspapi = {
        api = {
            [1] = 'EXPERIMENTAL',
        },
        formdata = {
            labels = {},
            fields = {}
        }
    }

    for i = 1, numLabels do
        -- Add a label
        table.insert(mspapi.formdata.labels, {t = tostring(i), inline_size = 17, label = i})

        -- Add corresponding fields for this label
        table.insert(mspapi.formdata.fields, {
            t = "UINT8", isUINT8 = true, label = i, inline = 2, mspapi = 1, apikey = "exp_uint" .. i,
            min = 0, max = 255, onChange = function(i) return update_int8() end 
        })

        table.insert(mspapi.formdata.fields, {
            t = "INT8", isINT8 = true, label = i, inline = 1, mspapi = 1, apikey = "exp_int" .. i,
            min = -128, max = 127, onChange = function(i) return update_uint8() end
        })
    end

    return mspapi
end



local mspapi = generateMSPAPI(rfsuite.preferences.mspExpBytes)

local function postLoad(self)


    --trigger a full reload if the number of bytes has changed
    if total_bytes ~= rfsuite.app.Page.mspapi.receivedBytesCount['EXPERIMENTAL'] then
        print("Number of bytes has changed, reloading page")

        rfsuite.preferences.mspExpBytes = rfsuite.app.Page.mspapi.receivedBytesCount['EXPERIMENTAL']

        rfsuite.app.triggers.reloadFull = true
    end

    -- update all the fields as msp only supports uint8
    update_int8()

    rfsuite.app.triggers.closeProgressLoader = true
end


return {
    mspapi  = mspapi,
    title = "Experimental",
    navButtons = {menu = true, save = true, reload = true, help = true},
    eepromWrite = true,
    postLoad = postLoad,
    API = {},
}
