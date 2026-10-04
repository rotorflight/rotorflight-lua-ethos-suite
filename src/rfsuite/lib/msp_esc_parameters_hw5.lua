-- Hobbywing V5 forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_hw5"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_hw5"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local FLIGHT_MODE = {{"Fixed Wing", 0}, {"Heli Ext Gov", 1}, {"Heli Gov", 2}, {"Heli Store", 3}}
local ROTATION = {{"CW", 0}, {"CCW", 1}}
local LIPO_CELLS = {{"Auto", 0}, {"3S", 1}, {"4S", 2}, {"5S", 3}, {"6S", 4}, {"7S", 5}, {"8S", 6}, {"9S", 7}, {"10S", 8}, {"11S", 9}, {"12S", 10}, {"13S", 11}, {"14S", 12}}
local CUTOFF_TYPE = {{"Soft", 0}, {"Hard", 1}}
local CUTOFF_VOLTAGE = {{"Disabled", 0}, {"2.8V", 1}, {"2.9V", 2}, {"3.0V", 3}, {"3.1V", 4}, {"3.2V", 5}, {"3.3V", 6}, {"3.4V", 7}, {"3.5V", 8}, {"3.6V", 9}, {"3.7V", 10}, {"3.8V", 11}}
local RESTART_TIME = {{"1s", 0}, {"1.5s", 1}, {"2s", 2}, {"2.5s", 3}, {"3s", 4}}
local RESPONSE_TIME = {{"1", 0}, {"2", 1}, {"3", 2}, {"4", 3}, {"5", 4}, {"6", 5}, {"7", 6}, {"8", 7}, {"9", 8}, {"10", 9}}
local STARTUP_POWER = {{"1", 0}, {"2", 1}, {"3", 2}, {"4", 3}, {"5", 4}, {"6", 5}, {"7", 6}}
local ENABLED_DISABLED = {{"Enabled", 0}, {"Disabled", 1}}
local BRAKE_TYPE = {{"Disabled", 0}, {"Normal", 1}, {"Proportional", 2}, {"Reverse", 3}}

local function choices(labels)
  local result = {}
  for i = 1, #labels do
    result[i] = {labels[i], i - 1}
  end
  return result
end

local TABLES = {
  rotation = ROTATION,
  rotation_hw1128 = choices({"Forward", "Reverse", "4D", "4D Reverse"}),
  lipo_3_to_14 = LIPO_CELLS,
  lipo_3_to_8 = choices({"Auto", "3S", "4S", "5S", "6S", "7S", "8S"}),
  lipo_even_6_to_14 = choices({"Auto", "6S", "8S", "10S", "12S", "14S"}),
  lipo_2_to_4 = choices({"Auto", "2S", "3S", "4S"}),
  cutoff_28_to_38 = CUTOFF_VOLTAGE,
  cutoff_25_to_38 = choices({"Disabled", "2.5V", "2.6V", "2.7V", "2.8V", "2.9V", "3.0V", "3.1V", "3.2V", "3.3V", "3.4V", "3.5V", "3.6V", "3.7V", "3.8V"}),
  bec_50_to_84 = choices({"5.0V", "5.1V", "5.2V", "5.3V", "5.4V", "5.5V", "5.6V", "5.7V", "5.8V", "5.9V", "6.0V", "6.1V", "6.2V", "6.3V", "6.4V", "6.5V", "6.6V", "6.7V", "6.8V", "6.9V", "7.0V", "7.1V", "7.2V", "7.3V", "7.4V", "7.5V", "7.6V", "7.7V", "7.8V", "7.9V", "8.0V", "8.1V", "8.2V", "8.3V", "8.4V"}),
  bec_54_to_84 = choices({"5.4V", "5.5V", "5.6V", "5.7V", "5.8V", "5.9V", "6.0V", "6.1V", "6.2V", "6.3V", "6.4V", "6.5V", "6.6V", "6.7V", "6.8V", "6.9V", "7.0V", "7.1V", "7.2V", "7.3V", "7.4V", "7.5V", "7.6V", "7.7V", "7.8V", "7.9V", "8.0V", "8.1V", "8.2V", "8.3V", "8.4V"}),
  bec_60_74_84 = choices({"6.0V", "7.4V", "8.4V"}),
  bec_50_to_120 = choices({"5.0V", "5.1V", "5.2V", "5.3V", "5.4V", "5.5V", "5.6V", "5.7V", "5.8V", "5.9V", "6.0V", "6.1V", "6.2V", "6.3V", "6.4V", "6.5V", "6.6V", "6.7V", "6.8V", "6.9V", "7.0V", "7.1V", "7.2V", "7.3V", "7.4V", "7.5V", "7.6V", "7.7V", "7.8V", "7.9V", "8.0V", "8.1V", "8.2V", "8.3V", "8.4V", "8.5V", "8.6V", "8.7V", "8.8V", "8.9V", "9.0V", "9.1V", "9.2V", "9.3V", "9.4V", "9.5V", "9.6V", "9.7V", "9.8V", "9.9V", "10.0V", "10.1V", "10.2V", "10.3V", "10.4V", "10.5V", "10.6V", "10.7V", "10.8V", "10.9V", "11.0V", "11.1V", "11.2V", "11.3V", "11.4V", "11.5V", "11.6V", "11.7V", "11.8V", "11.9V", "12.0V"}),
  brake_full = BRAKE_TYPE,
  brake_no_prop = choices({"Disabled", "Normal", "Reverse"}),
  brake_basic = choices({"Disabled", "Normal"}),
  response_time = RESPONSE_TIME,
}

local FIELD_META = {
  flight_mode = {choices = FLIGHT_MODE},
  lipo_cell_count = {choices = LIPO_CELLS},
  volt_cutoff_type = {choices = CUTOFF_TYPE},
  cutoff_voltage = {choices = CUTOFF_VOLTAGE},
  bec_voltage = {choices = TABLES.bec_50_to_84},
  startup_time = {min = 4, max = 25, default = 11, suffix = "s"},
  response_time = {choices = RESPONSE_TIME},
  gov_p_gain = {min = 0, max = 9, default = 6},
  gov_i_gain = {min = 0, max = 9, default = 5},
  auto_restart = {min = 0, max = 90, default = 25},
  restart_time = {choices = RESTART_TIME},
  brake_type = {choices = BRAKE_TYPE},
  brake_force = {min = 0, max = 100, default = 0, suffix = "%"},
  timing = {min = 0, max = 30, default = 24},
  rotation = {choices = ROTATION},
  active_freewheel = {choices = ENABLED_DISABLED},
  startup_power = {choices = STARTUP_POWER},
}

local EDIT_FIELDS = {
  "flight_mode",
  "lipo_cell_count",
  "volt_cutoff_type",
  "cutoff_voltage",
  "bec_voltage",
  "startup_time",
  "response_time",
  "gov_p_gain",
  "gov_i_gain",
  "auto_restart",
  "restart_time",
  "brake_type",
  "brake_force",
  "timing",
  "rotation",
  "active_freewheel",
  "startup_power",
}

local DEFAULT_ITEMS = {
  flight_mode = 1,
  lipo_cell_count = 2,
  volt_cutoff_type = 3,
  cutoff_voltage = 4,
  bec_voltage = 5,
  startup_time = 6,
  gov_p_gain = 7,
  gov_i_gain = 8,
  auto_restart = 9,
  restart_time = 10,
  brake_type = 11,
  brake_force = 12,
  timing = 13,
  rotation = 14,
  active_freewheel = 15,
  startup_power = 16,
}

local OPTO_ITEMS = {
  flight_mode = 1,
  lipo_cell_count = 2,
  volt_cutoff_type = 3,
  cutoff_voltage = 4,
  startup_time = 5,
  gov_p_gain = 6,
  gov_i_gain = 7,
  auto_restart = 8,
  restart_time = 9,
  brake_type = 10,
  brake_force = 11,
  timing = 12,
  rotation = 13,
  active_freewheel = 14,
  startup_power = 15,
}

local HW1128_ITEMS = {
  lipo_cell_count = 1,
  volt_cutoff_type = 2,
  cutoff_voltage = 3,
  brake_type = 5,
  brake_force = 6,
  timing = 7,
  rotation = 8,
  active_freewheel = 9,
  startup_power = 10,
}

local HW1132_ITEMS = {
  lipo_cell_count = 1,
  volt_cutoff_type = 2,
  cutoff_voltage = 3,
  bec_voltage = 4,
  response_time = 5,
  timing = 6,
  rotation = 7,
  active_freewheel = 8,
  startup_power = 9,
}

local PROFILES = {
  default = {
    tables = {
      rotation = TABLES.rotation,
      lipo_cell_count = TABLES.lipo_3_to_14,
      cutoff_voltage = TABLES.cutoff_28_to_38,
      bec_voltage = TABLES.bec_50_to_84,
      brake_type = TABLES.brake_full,
    },
    items = DEFAULT_ITEMS,
  },
  HW1104_V100456NB = {
    tables = {
      lipo_cell_count = TABLES.lipo_even_6_to_14,
      bec_voltage = TABLES.bec_50_to_120,
      brake_type = TABLES.brake_basic,
    },
    items = DEFAULT_ITEMS,
  },
  HW1104_V100456NB_PL_OPTO = {
    tables = {
      lipo_cell_count = TABLES.lipo_even_6_to_14,
      brake_type = TABLES.brake_basic,
    },
    items = OPTO_ITEMS,
  },
  HW1106_V100456NB = {
    tables = {
      lipo_cell_count = TABLES.lipo_3_to_8,
      bec_voltage = TABLES.bec_54_to_84,
    },
    items = DEFAULT_ITEMS,
  },
  HW1106_V200456NB = {
    tables = {
      lipo_cell_count = TABLES.lipo_3_to_8,
      bec_voltage = TABLES.bec_50_to_120,
      brake_type = TABLES.brake_no_prop,
    },
    items = DEFAULT_ITEMS,
  },
  HW1106_V300456NB = {
    tables = {
      lipo_cell_count = TABLES.lipo_3_to_8,
      bec_voltage = TABLES.bec_50_to_120,
      brake_type = TABLES.brake_no_prop,
    },
    items = DEFAULT_ITEMS,
  },
  HW1121_V100456NB = {
    tables = {
      lipo_cell_count = TABLES.lipo_3_to_8,
      bec_voltage = TABLES.bec_50_to_120,
      brake_type = TABLES.brake_no_prop,
    },
    items = DEFAULT_ITEMS,
  },
  HW1121_V00456NB = {
    tables = {
      lipo_cell_count = TABLES.lipo_3_to_8,
      bec_voltage = TABLES.bec_50_to_120,
      brake_type = TABLES.brake_no_prop,
    },
    items = DEFAULT_ITEMS,
  },
  HW1132_V100456NB = {
    tables = {
      lipo_cell_count = TABLES.lipo_2_to_4,
      bec_voltage = TABLES.bec_60_74_84,
      response_time = TABLES.response_time,
    },
    items = HW1132_ITEMS,
  },
  HW1128_V100456NB = {
    tables = {
      rotation = TABLES.rotation_hw1128,
      lipo_cell_count = TABLES.lipo_2_to_4,
      cutoff_voltage = TABLES.cutoff_25_to_38,
      brake_type = TABLES.brake_no_prop,
    },
    items = HW1128_ITEMS,
  },
  ["HW198_V1.00456NB"] = {
    tables = {
      lipo_cell_count = TABLES.lipo_even_6_to_14,
      bec_voltage = TABLES.bec_50_to_120,
      brake_type = TABLES.brake_basic,
    },
    items = DEFAULT_ITEMS,
  },
}

local SIMULATOR_RESPONSE = {
  253, 0,
  32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32,
  72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66,
  80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32,
  80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32,
  0, 0, 0, 3, 0, 11, 6, 5, 25, 1, 0, 0, 24, 0, 0, 2
}

local function readString(buf, start, length)
  local chars = {}
  for i = 0, length - 1 do
    local byte = buf[start + i] or 0
    if byte ~= 0 and byte ~= 32 then chars[#chars + 1] = string.char(byte) end
  end
  return table.concat(chars)
end

local function trim(text)
  if type(text) ~= "string" then return "" end
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function hasToken(text, token)
  return type(text) == "string" and text:upper():find(token, 1, true) ~= nil
end

-- Is this an OPTO ESC?
--
-- An OPTO ESC has no BEC, and its parameter block carries one byte fewer for
-- that: OPTO_ITEMS drops bec_voltage at item 5, so every field from item 5 up
-- sits one byte LOWER than it does on a model with a BEC. Getting that layout
-- wrong therefore does not merely show a row that should be hidden -- it reads
-- and writes every field after the fourth off the wrong byte, which is what
-- turned an innocuous BEC Voltage row into shifted Auto Restart and governor
-- values.
--
-- All three descriptive strings are searched, not one. The block carries the
-- model twice -- bytes 35..50 as `esc_type` and bytes 51..65 as `mode_name`, the
-- same name spelled with spaces instead of underscores -- plus the firmware
-- version in bytes 3..18. Which of the three a given ESC puts "OPTO" in is not
-- something this file can know, so all three are asked. The EdgeTX codec
-- concatenates the two model strings for exactly this reason
-- (esc_parameters_hw5.lua:119, :251).
local function isOpto(data)
  return hasToken(trim(data and data.esc_type), "OPTO")
    or hasToken(trim(data and data.mode_name), "OPTO")
    or hasToken(trim(data and data.firmware_version), "OPTO")
end

-- The version profile on its own, with no regard for the variant. The CHOICE
-- LISTS are a property of the model -- which cell counts it offers, which brake
-- modes it has -- and an ESC being OPTO does not change any of them, so an OPTO
-- model still takes its lists from here.
local function versionProfileFor(version)
  if version == nil or version == "" then return PROFILES.default end
  local profile = PROFILES[version]
  if profile then return profile end
  local upper = version:upper()
  if upper:find("HW1132", 1, true) then
    return PROFILES.HW1132_V100456NB
  elseif upper:find("HW1128", 1, true) then
    return PROFILES.HW1128_V100456NB
  elseif upper:find("HW1121", 1, true) then
    return PROFILES.HW1121_V100456NB
  end
  return PROFILES.default
end

-- One merged profile per version, built on first use.
--
-- Before this, the variant was part of the PROFILE KEY -- profileKey() returned
-- `<version>_PL_OPTO` -- which only works for a version that happens to have
-- such an entry. PROFILES carried exactly one, HW1104_V100456NB_PL_OPTO, so
-- every OTHER OPTO model missed the lookup and fell through to PROFILES.default:
-- a BEC row, and active_freewheel at item 15 instead of 14. Measured on the
-- pre-fix codec, an OPTO HW1106 read startup_time 11 where the byte says 4,
-- gov_p_gain 6 where the byte says 11, gov_i_gain 5 for 6, auto_restart 25 for 5,
-- restart_time 1 for 25, brake_type 0 for 1, timing 24 for 0, rotation 0 for 24
-- and startup_power 2 for 0 -- 9 of the 15 fields on the OPTO layout a byte out,
-- from a page that looked entirely normal. The six that coincide are four fields
-- ahead of the missing byte and two that happen to carry equal bytes on either
-- side of it, which is luck and not a property of the fix.
--
-- The variant belongs to the LAYOUT, not to the key. So the lookup is by
-- version, the layout is chosen by the variant, and an explicit
-- `<version>_PL_OPTO` entry still wins where one exists -- its tables may
-- differ, and HW1104's do not.
--
-- Memoised because profileFor() is reached once per field per page build through
-- isFieldAvailable(), and a fresh two-field table per call would be an
-- allocation on a hot-ish path for a value that never changes. The key is a
-- 16-byte string off the wire, so the table is bounded by the models a pilot has
-- connected, not by anything an attacker controls.
local OPTO_PROFILES = {}

local function optoProfileFor(version)
  local cached = OPTO_PROFILES[version]
  if cached then return cached end
  local explicit = version ~= "" and PROFILES[version .. "_PL_OPTO"] or nil
  local base = explicit or versionProfileFor(version)
  cached = {tables = base and base.tables, items = OPTO_ITEMS}
  OPTO_PROFILES[version] = cached
  return cached
end

local function profileFor(data)
  local version = trim(data and data.hardware_version)
  if not isOpto(data) then
    return versionProfileFor(version)
  end
  return optoProfileFor(version)
end

local function itemLayoutFor(data)
  return (profileFor(data).items) or DEFAULT_ITEMS
end

-- One field is not stored as the number the page shows.
--
-- startup_time declares min 4, max 25, default 11 in FIELD_META above, and the raw
-- byte runs 0..21 -- so decode() used to hand the page numbers the row's own range
-- says cannot happen, and a pilot with the ESC set to its shortest start saw "0s"
-- on a row that begins at 4. That contradiction is inside this file and needs no
-- outside authority to establish.
--
-- Which side of it was wrong is settled by the EdgeTX codec, which is the reference
-- this suite has always taken the HW5 layouts from, and which says so four times
-- over:
--
--   * its own fixture comment:  11, -- item 6: startup_time (raw 11 -> 15s)
--     (tasks/msp/api/esc_parameters_hw5.lua:203)
--   * parse():                   out[fieldName] = rawVal + 4          (:263-265)
--   * buildWritePayload():       rawVal = math.max(0, math.min(21,
--                                (tonumber(val) or 4) - 4))             (:296-298)
--   * the page widget:           min = 4, max = 25, step = 1, suffix = "s"
--     (app/pages/.../escmfg/hw5/page.lua:617) -- and its initial ui.config value
--     startup_time = 15 (:38), which is the fixture's raw 11 plus four.
--
-- The arithmetic agrees, which is why this is a translation and not a patch: 4..25
-- is 22 values and 0..21 is 22 values. A range that is 22 long on the page and 22
-- long on the wire is one range counted from two ends.
--
-- The clamp is 0..21 and NOT 0..255, because that is the range of the byte. A wider
-- clamp would let a caller outside the page's own range write a raw value the row
-- says cannot exist; EdgeTX clamps to 21 for the same reason.
--
-- A table rather than another `if` in decode()/encode(): there is one such field
-- today, and a second copy of the rule in the two directions is a second thing to
-- forget when the next one is added.
local FIELD_OFFSETS = {
  startup_time = {offset = 4, min = 0, max = 21},
}

local function decode(buf)
  buf.offset = 1
  local data = {
    esc_signature = mspcodec.readU8(buf),
    esc_command = mspcodec.readU8(buf),
  }
  data.firmware_version = readString(buf, 3, 16)
  data.hardware_version = readString(buf, 19, 16)
  data.esc_type = readString(buf, 35, 16)
  data.mode_name = readString(buf, 51, 15)
  local layout = itemLayoutFor(data)
  for name, itemIndex in pairs(layout) do
    local rule = FIELD_OFFSETS[name]
    local raw = buf[65 + itemIndex] or 0
    data[name] = rule and (raw + rule.offset) or raw
  end
  return data
end

local function encode(data)
  local payload = {}
  local source = data and data._raw or SIMULATOR_RESPONSE
  local limit = #source > 0 and #source or #SIMULATOR_RESPONSE
  for i = 1, limit do payload[i] = source[i] or SIMULATOR_RESPONSE[i] or 0 end
  local layout = itemLayoutFor(data)
  for name, itemIndex in pairs(layout) do
    if data and data[name] ~= nil then
      local rule = FIELD_OFFSETS[name]
      if rule then
        -- Rounded rather than truncated, because a number field can be handed a
        -- fraction and a byte cannot hold one. Clamped to the byte's own range, and
        -- NOT with `% 256`: that would turn a raw value below the row's minimum into
        -- one near 255 -- a 252 where the pilot asked for something under 4s.
        -- The page's min/max already prevent that; this is for a table built by
        -- something else.
        local raw = math.floor(data[name] - rule.offset + 0.5)
        if raw < rule.min then raw = rule.min
        elseif raw > rule.max then raw = rule.max end
        payload[65 + itemIndex] = raw
      else
        payload[65 + itemIndex] = math.floor(data[name] + 0.5) % 256
      end
    end
  end
  return payload
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 253,
  FIELD_META = FIELD_META,
  EDIT_FIELDS = EDIT_FIELDS,
  TITLE = "Hobbywing V5",
}

function msp.isFieldAvailable(data, key)
  return itemLayoutFor(data)[key] ~= nil
end

function msp.choicesFor(data, key)
  local profile = profileFor(data)
  return profile.tables and profile.tables[key] or (FIELD_META[key] and FIELD_META[key].choices)
end

function msp.summaryFor(data)
  local parts = {}
  local escType = trim(data and data.esc_type)
  local firmware = trim(data and data.firmware_version)
  if escType ~= "" then parts[#parts + 1] = escType end
  if firmware ~= "" then parts[#parts + 1] = firmware end
  if #parts == 0 then return msp.TITLE end
  return table.concat(parts, " / ")
end

function msp.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local data = decode(buf)
      data._raw = buf
      onData(data)
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = encode(data),
    isWrite = true,
    processReply = function() if onWritten then onWritten() end end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_esc_parameters_hw5"] = msp
return msp
