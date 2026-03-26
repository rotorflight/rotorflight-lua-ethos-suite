--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local helper = {}

local PAGE_FIELDS = {
    basic = {
        "flight_mode",
        "rotation",
        "bec_voltage",
        "lipo_cell_count",
        "volt_cutoff_type",
        "cutoff_voltage"
    },
    advanced = {
        "gov_p_gain",
        "gov_i_gain",
        "startup_time",
        "restart_time",
        "auto_restart"
    },
    other = {
        "timing",
        "startup_power",
        "active_freewheel",
        "brake_type",
        "brake_force"
    }
}

local TABLES = {
    rotation = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_ccw)@"},
    rotation_hw1128 = {"Forward", "@i18n(api.ESC_PARAMETERS_HW5.tbl_reverse)@", "4D", "4D Reverse"},
    lipo_3_to_14 = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_autocalculate)@", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "11S", "12S", "13S", "14S"},
    lipo_3_to_8 = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_autocalculate)@", "3S", "4S", "5S", "6S", "7S", "8S"},
    lipo_even_6_to_14 = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_autocalculate)@", "6S", "8S", "10S", "12S", "14S"},
    lipo_2_to_4 = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_autocalculate)@", "2S", "3S", "4S"},
    cutoff_28_to_38 = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "2.8V", "2.9V", "3.0V", "3.1V", "3.2V", "3.3V", "3.4V", "3.5V", "3.6V", "3.7V", "3.8V"},
    cutoff_25_to_38 = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "2.5V", "2.6V", "2.7V", "2.8V", "2.9V", "3.0V", "3.1V", "3.2V", "3.3V", "3.4V", "3.5V", "3.6V", "3.7V", "3.8V"},
    bec_50_to_84 = {"5.0V", "5.1V", "5.2V", "5.3V", "5.4V", "5.5V", "5.6V", "5.7V", "5.8V", "5.9V", "6.0V", "6.1V", "6.2V", "6.3V", "6.4V", "6.5V", "6.6V", "6.7V", "6.8V", "6.9V", "7.0V", "7.1V", "7.2V", "7.3V", "7.4V", "7.5V", "7.6V", "7.7V", "7.8V", "7.9V", "8.0V", "8.1V", "8.2V", "8.3V", "8.4V"},
    bec_54_to_84 = {"5.4V", "5.5V", "5.6V", "5.7V", "5.8V", "5.9V", "6.0V", "6.1V", "6.2V", "6.3V", "6.4V", "6.5V", "6.6V", "6.7V", "6.8V", "6.9V", "7.0V", "7.1V", "7.2V", "7.3V", "7.4V", "7.5V", "7.6V", "7.7V", "7.8V", "7.9V", "8.0V", "8.1V", "8.2V", "8.3V", "8.4V"},
    bec_50_to_120 = {"5.0V", "5.1V", "5.2V", "5.3V", "5.4V", "5.5V", "5.6V", "5.7V", "5.8V", "5.9V", "6.0V", "6.1V", "6.2V", "6.3V", "6.4V", "6.5V", "6.6V", "6.7V", "6.8V", "6.9V", "7.0V", "7.1V", "7.2V", "7.3V", "7.4V", "7.5V", "7.6V", "7.7V", "7.8V", "7.9V", "8.0V", "8.1V", "8.2V", "8.3V", "8.4V", "8.5V", "8.6V", "8.7V", "8.8V", "8.9V", "9.0V", "9.1V", "9.2V", "9.3V", "9.4V", "9.5V", "9.6V", "9.7V", "9.8V", "9.9V", "10.0V", "10.1V", "10.2V", "10.3V", "10.4V", "10.5V", "10.6V", "10.7V", "10.8V", "10.9V", "11.0V", "11.1V", "11.2V", "11.3V", "11.4V", "11.5V", "11.6V", "11.7V", "11.8V", "11.9V", "12.0V"},
    brake_full = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_proportional)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_reverse)@"},
    brake_no_prop = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_reverse)@"},
    brake_basic = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_normal)@"}
}

local PROFILES = {
    default = {
        tables = {
            rotation = TABLES.rotation,
            lipo_cell_count = TABLES.lipo_3_to_14,
            cutoff_voltage = TABLES.cutoff_28_to_38,
            bec_voltage = TABLES.bec_50_to_84,
            brake_type = TABLES.brake_full
        }
    },
    HW1104_V100456NB = {
        tables = {
            lipo_cell_count = TABLES.lipo_even_6_to_14,
            bec_voltage = TABLES.bec_50_to_120,
            brake_type = TABLES.brake_basic
        }
    },
    HW1104_V100456NB_PL_OPTO = {
        tables = {
            lipo_cell_count = TABLES.lipo_even_6_to_14,
            brake_type = TABLES.brake_basic
        },
        pages = {
            basic = {
                "flight_mode",
                "rotation",
                "lipo_cell_count",
                "volt_cutoff_type",
                "cutoff_voltage"
            }
        }
    },
    HW1106_V100456NB = {
        tables = {
            lipo_cell_count = TABLES.lipo_3_to_8,
            bec_voltage = TABLES.bec_54_to_84
        }
    },
    HW1106_V200456NB = {
        tables = {
            lipo_cell_count = TABLES.lipo_3_to_8,
            bec_voltage = TABLES.bec_50_to_120,
            brake_type = TABLES.brake_no_prop
        }
    },
    HW1106_V300456NB = {
        tables = {
            lipo_cell_count = TABLES.lipo_3_to_8,
            bec_voltage = TABLES.bec_50_to_120,
            brake_type = TABLES.brake_no_prop
        }
    },
    HW1121_V100456NB = {
        tables = {
            lipo_cell_count = TABLES.lipo_3_to_8,
            bec_voltage = TABLES.bec_50_to_120,
            brake_type = TABLES.brake_no_prop
        }
    },
    HW1128_V100456NB = {
        tables = {
            rotation = TABLES.rotation_hw1128,
            lipo_cell_count = TABLES.lipo_2_to_4,
            cutoff_voltage = TABLES.cutoff_25_to_38,
            brake_type = TABLES.brake_no_prop
        },
        pages = {
            basic = {
                "rotation",
                "lipo_cell_count",
                "volt_cutoff_type",
                "cutoff_voltage"
            },
            advanced = {},
            other = {
                "timing",
                "startup_power",
                "active_freewheel",
                "brake_type",
                "brake_force"
            }
        }
    },
    ["HW198_V1.00456NB"] = {
        tables = {
            lipo_cell_count = TABLES.lipo_even_6_to_14,
            bec_voltage = TABLES.bec_50_to_120,
            brake_type = TABLES.brake_basic
        }
    }
}

local function trim(text)
    if type(text) ~= "string" then return nil end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function buildLookup(list)
    local lookup = {}
    for i = 1, #list do
        lookup[list[i]] = true
    end
    return lookup
end

local function getPageAllowed(profile, pageKey)
    local pageFields = PAGE_FIELDS[pageKey]
    if not pageFields then return nil end

    local override = profile.pages and profile.pages[pageKey]
    if override == nil then
        return buildLookup(pageFields)
    end

    return buildLookup(override)
end

local function getProfileKey()
    local escDetails = rfsuite.session and rfsuite.session.escDetails or {}
    local version = trim(escDetails.version) or "default"
    local model = string.upper(trim(escDetails.model) or "")
    local firmware = string.upper(trim(escDetails.firmware) or "")

    if version ~= "default" and (model:find("OPTO", 1, true) or firmware:find("OPTO", 1, true)) then
        return version .. "_PL_OPTO"
    end

    return version
end

function helper.getProfile()
    local key = getProfileKey()
    return PROFILES[key] or PROFILES.default, key
end

function helper.configurePage(apidata, pageKey)
    if type(apidata) ~= "table" or type(apidata.formdata) ~= "table" then return end
    local fields = apidata.formdata.fields
    if type(fields) ~= "table" then return end

    local profile = helper.getProfile()
    local allowed = getPageAllowed(profile, pageKey)
    local tables = profile.tables or {}

    for i = #fields, 1, -1 do
        local field = fields[i]
        local apikey = field and field.apikey
        if apikey and allowed and not allowed[apikey] then
            table.remove(fields, i)
        elseif apikey and tables[apikey] then
            field.table = tables[apikey]
            field.tableIdxInc = -1
        end
    end
end

function helper.postLoad(pageKey)
    local profile = helper.getProfile()
    local allowed = getPageAllowed(profile, pageKey)
    local tables = profile.tables or {}
    local page = rfsuite.app and rfsuite.app.Page
    local fields = page and page.apidata and page.apidata.formdata and page.apidata.formdata.fields
    local formFields = rfsuite.app and rfsuite.app.formFields
    local convertPageValueTable = rfsuite.app and rfsuite.app.utils and rfsuite.app.utils.convertPageValueTable

    if type(fields) ~= "table" or type(formFields) ~= "table" or type(convertPageValueTable) ~= "function" then
        return
    end

    for i = 1, #fields do
        local field = fields[i]
        local formField = formFields[i]
        if field and formField and field.apikey then
            local values = tables[field.apikey]
            if values and formField.values then
                formField:values(convertPageValueTable(values, -1))
            end
            if allowed and formField.enable then
                formField:enable(allowed[field.apikey] == true)
            end
        end
    end
end

return helper
