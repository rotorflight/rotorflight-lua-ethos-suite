-- YGE forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_yge"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_yge"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local ESC_MODE = {{"Freew.", 0}, {"Ext Gov", 1}, {"Heli Gov", 2}, {"Heli Store", 3}, {"Glider", 4}, {"Airplane", 5}, {"F3A", 6}}
local ROTATION = {{"Normal", 0}, {"Reverse", 1}}
local CUTOFF = {{"Off", 0}, {"Slowdown", 1}, {"Cutoff", 2}}
local CUTOFF_VOLTAGE = {{"2.9 V", 0}, {"3.0 V", 1}, {"3.1 V", 2}, {"3.2 V", 3}, {"3.3 V", 4}, {"3.4 V", 5}}
local OFF_ON = {{"Off", 0}, {"On", 1}}
local THROTTLE_RESPONSE = {{"Slow", 0}, {"Medium", 1}, {"Fast", 2}, {"Custom", 3}}
-- The Motor Timing row is drawn from list positions, because that is what the
-- choice widget takes. Those positions are NOT the ESC's words: the ESC spells
-- the four automatic modes 16..19 and the six fixed advance angles 1..6, with 0
-- a second spelling of the first automatic mode, and 7..15 and everything above
-- 19 are values it does not define. The word is therefore decoded on the way in
-- and encoded again on the way out.
local TIMING = {{"Auto Norm", 0}, {"Auto Eff", 1}, {"Auto Power", 2}, {"Auto Extr", 3}, {"0 deg", 4}, {"6 deg", 5}, {"12 deg", 6}, {"18 deg", 7}, {"24 deg", 8}, {"30 deg", 9}}
local MOTOR_TIMING_TO_UI = {
  [0] = 0, [1] = 4, [2] = 5, [3] = 6, [4] = 7, [5] = 8, [6] = 9,
  [16] = 0, [17] = 1, [18] = 2, [19] = 3
}
local MOTOR_TIMING_FROM_UI = {
  [0] = 0, [1] = 17, [2] = 18, [3] = 19, [4] = 1,
  [5] = 2, [6] = 3, [7] = 4, [8] = 5, [9] = 6
}
local FREEWHEEL = {{"Off", 0}, {"Auto", 1}, {"Unused", 2}, {"Always On", 3}}

-- Both halves of the same mapping, and both needed: decode() has to turn the
-- ESC's word into a row the widget can show, and encode() has to turn the row
-- back into a word the ESC understands. Without them a pilot picking "Auto
-- Efficient" commands wire 1, which the ESC reads as a fixed 0-degree advance.
local function motorTimingToUi(raw)
  return MOTOR_TIMING_TO_UI[raw] or 0
end

-- `raw` is the word the ESC itself sent, kept in `data.timing_raw` by decode().
-- A row still standing on the entry that word decoded to writes that word back
-- rather than the canonical spelling of the same entry, so a save that changed
-- nothing changes nothing in the ESC. The table is indexed rather than decoded
-- here on purpose: an undefined word decodes to the first automatic mode like
-- everything else the ESC does not define, and keeping it would mean a pilot who
-- deliberately picks that mode leaves the undefined word in place on a page that
-- says he changed it.
local function motorTimingFromUi(value, raw)
  if raw ~= nil and MOTOR_TIMING_TO_UI[raw] == value then return raw end
  return MOTOR_TIMING_FROM_UI[value] or 0
end

-- One entry per model, carrying every fact this suite knows about it. The name,
-- the BEC voltage and the 12 V capability are deliberately NOT separate lists:
-- they used to be, upstream, and a model added to one of them was invisible in
-- the others. That is not hypothetical -- [4691] was missing from the name list
-- this file carried until 2026-10-03, and it is one of the five 12 V models.
--
-- `bec12v` is what raises the BEC Voltage field's ceiling from 8.4 V to 12.0 V.
-- It is a property of the MODEL rather than of the flags word: the flag says
-- what the ESC is set to, this says what it can be set to.
--
-- The 12 V capability below is the EdgeTX table's, confirmed by the hardware
-- owner on 2026-10-03: seven models, and the three non-v2 ones (165 HVT, 205 HVT
-- v2, 205 HVT BEC) are included. rotorflight-lua-edgetx-suite
-- .../escmfg/yge/init.lua:17-39 is therefore not a guess imported from a
-- neighbouring suite but the value he confirmed, and `verify_yge_bec12v.lua`
-- asserts the two tables agree on all 21 entries, so the parity cannot rot
-- unnoticed.
--
-- Nothing in any Rotorflight repository settles it -- rotorflight-firmware has no
-- YGE model table at all and ESC forward-programming is a pass-through -- which
-- is why this is the hardware owner's answer and not an inference from the model
-- names. Do not "correct" the three HVT entries away: they were already in
-- hvt12vTypes in the EdgeTX page.lua before its own one-table commit (9ad7ae14,
-- 2026-08-28), each with its model name beside it, and the owner has now said so
-- a second time.
--
-- [8272] is spelled "YGE 205 HVT v2" here. The EdgeTX table calls it
-- "YGE 205 HVT", which is the only NAME difference between the two tables; the
-- owner gave the v2 spelling (2026-10-03). The id, and its 12 V capability, are
-- EdgeTX's.
--
-- `bec` is a THIRD fact and not the negation of `bec12v`, because "cannot reach
-- 12 V" and "has no BEC at all" are different answers and need different UI:
-- `bec = false` hides the BEC Voltage row.
--
-- THE FACT, not a reading of the name: an Opto ESC has no BEC. There is no
-- voltage on one to set, so a BEC voltage is not a setting that can be written,
-- and the row is hidden rather than capped (Björn, 2026-10-03).
--
-- The name is what that fact looks like in a datasheet and in the EdgeTX table,
-- and it is why the five ids are listed here rather than filtered at runtime: a
-- new Opto is a new line in THIS table, not a rule that spots the word. Nothing
-- reads the name -- the six entries below marked "BEC" and the five marked "Opto"
-- are the author's statement, and the other sixteen Björn confirmed per model on
-- 2026-10-03, including the ten whose name says neither BEC nor Opto. Those ten
-- are his answer and not an inference.
local ESC_MODELS = {
  -- Named BEC in the table; Björn confirmed a BEC on each.
  [848] = {name = "YGE 35 LVT BEC", bec = true, bec12v = false},
  [1616] = {name = "YGE 65 LVT BEC", bec = true, bec12v = false},
  [2128] = {name = "YGE 85 LVT BEC", bec = true, bec12v = false},
  [2384] = {name = "YGE 95 LVT BEC", bec = true, bec12v = false},
  [4944] = {name = "YGE 135 LVT BEC", bec = true, bec12v = false},
  [8273] = {name = "YGE 205 HVT BEC", bec = true, bec12v = true},
  -- Opto: no BEC at all. These five ids ARE the fact, not a name filter.
  [2304] = {name = "YGE 90 HVT Opto", bec = false, bec12v = false},
  [4608] = {name = "YGE 120 HVT Opto", bec = false, bec12v = false},
  [4928] = {name = "YGE Opto 135", bec = false, bec12v = false},
  [9552] = {name = "YGE Opto 255", bec = false, bec12v = false},
  [16464] = {name = "YGE Opto 405", bec = false, bec12v = false},
  -- Name says neither. Björn answered the BEC on 2026-10-03, per model; the 12 V comes from the EdgeTX table, which he confirmed the same day.
  [4177] = {name = "YGE Aureus 105", bec = true, bec12v = false},
  [4179] = {name = "YGE Aureus 105v2", bec = true, bec12v = true},
  [4689] = {name = "YGE Saphir 125", bec = true, bec12v = false},
  [4691] = {name = "YGE Saphir 125v2", bec = true, bec12v = true},
  [5025] = {name = "YGE Aureus 135", bec = true, bec12v = false},
  [5027] = {name = "YGE Aureus 135v2", bec = true, bec12v = true},
  [5457] = {name = "YGE Saphir 155", bec = true, bec12v = false},
  [5459] = {name = "YGE Saphir 155v2", bec = true, bec12v = true},
  [5712] = {name = "YGE 165 HVT", bec = true, bec12v = true},
  [8272] = {name = "YGE 205 HVT v2", bec = true, bec12v = true},
}

-- The BEC Voltage field carries tenths of a volt, which is why the 12 V ceiling
-- is 120 and not 12.
local BEC_VOLTAGE_MIN = 55
local BEC_VOLTAGE_MAX_8V = 84
local BEC_VOLTAGE_MAX_12V = 120

-- Bit 3 of the flags byte, the one this page has no row for. It is what tells
-- the ESC to run its HV BEC, so it cannot be left to a row that does not exist.
local FLAG_BIT_BEC12V = 3

local FIELD_META = {
  governor = {choices = ESC_MODE},
  lv_bec_voltage = {min = BEC_VOLTAGE_MIN, max = BEC_VOLTAGE_MAX_8V, decimals = 1, suffix = "v"},
  timing = {choices = TIMING},
  acceleration = {min = 0, max = 65535, default = 0},
  gov_p = {min = 1, max = 10, default = 5},
  gov_i = {min = 1, max = 10, default = 5},
  throttle_response = {choices = THROTTLE_RESPONSE},
  auto_restart_time = {choices = CUTOFF},
  cell_cutoff = {choices = CUTOFF_VOLTAGE},
  active_freewheel = {choices = FREEWHEEL},
  stick_zero_us = {min = 900, max = 1900, suffix = "us"},
  stick_range_us = {min = 600, max = 1500, suffix = "us"},
  motor_pole_pairs = {min = 1, max = 100},
  pinion_teeth = {min = 1, max = 255},
  main_teeth = {min = 1, max = 1800},
  min_start_power = {min = 0, max = 26, suffix = "%"},
  max_start_power = {min = 0, max = 31, suffix = "%"},
  current_limit = {min = 1, max = 65500, decimals = 2, suffix = "A"},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
  {"esc_model", "u8"},
  {"esc_version", "u8"},
  {"governor", "u16"},
  {"lv_bec_voltage", "u16"},
  {"timing", "u16"},
  {"acceleration", "u16"},
  {"gov_p", "u16"},
  {"gov_i", "u16"},
  {"throttle_response", "u16"},
  {"auto_restart_time", "u16"},
  {"cell_cutoff", "u16"},
  {"active_freewheel", "u16"},
  {"esc_type", "u16"},
  {"firmware_version", "u32"},
  {"serial_number", "u32"},
  {"unknown_1", "u16"},
  {"stick_zero_us", "u16"},
  {"stick_range_us", "u16"},
  {"unknown_2", "u16"},
  {"motor_pole_pairs", "u16"},
  {"pinion_teeth", "u16"},
  {"main_teeth", "u16"},
  {"min_start_power", "u16"},
  {"max_start_power", "u16"},
  {"unknown_3", "u16"},
  {"flags", "u8"},
  {"unknown_4", "u8"},
  {"current_limit", "u16"},
}

local EDIT_FIELDS = {
  "governor",
  "lv_bec_voltage",
  "timing",
  "gov_p",
  "gov_i",
  "throttle_response",
  "auto_restart_time",
  "cell_cutoff",
  "active_freewheel",
  "stick_zero_us",
  "stick_range_us",
  "motor_pole_pairs",
  "pinion_teeth",
  "main_teeth",
  "min_start_power",
  "max_start_power",
  "current_limit",
}

local SIMULATOR_RESPONSE = {
  165, 0, 32, 0,
  3, 0, -- governor
  55, 0, -- lv_bec_voltage
  0, 0, -- timing
  0, 0, -- acceleration
  4, 0, -- gov_p
  3, 0, -- gov_i
  1, 0, -- throttle_response
  1, 0, -- auto_restart_time
  2, 0, -- cell_cutoff
  3, 0, -- active_freewheel
  80, 3, -- esc_type
  131, 148, 1, 0, -- firmware_version
  30, 170, 0, 0, -- serial_number
  3, 0, -- unknown_1
  86, 4, -- stick_zero_us
  22, 3, -- stick_range_us
  163, 15, -- unknown_2
  1, 0, -- motor_pole_pairs
  2, 0, -- pinion_teeth
  2, 0, -- main_teeth
  20, 0, -- min_start_power
  20, 0, -- max_start_power
  0, 0, -- unknown_3
  0, -- flags
  0, -- unknown_4
  2, 19 -- current_limit
}

local function readValue(buf, wireType)
  if wireType == "u8" then return mspcodec.readU8(buf) end
  if wireType == "u16" then return mspcodec.readU16(buf) end
  return mspcodec.readU32(buf)
end

local function writeValue(payload, wireType, value)
  value = value or 0
  if wireType == "u8" then
    mspcodec.writeU8(payload, value)
  elseif wireType == "u16" then
    mspcodec.writeU16(payload, value)
  else
    mspcodec.writeU32(payload, value)
  end
end

local function decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2])
  end
  -- The two fields the page translates rather than showing raw, each kept beside
  -- the value it was read with. See motorTimingFromUi() for the timing one and
  -- beforeSave() for the voltage one; both exist so a save that changed neither
  -- changes neither.
  data.timing_raw = data.timing
  data.lv_bec_voltage_raw = data.lv_bec_voltage
  data.timing = motorTimingToUi(data.timing)
  return data
end

local function encode(data)
  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    local value = data and data[field[1]] or 0
    if field[1] == "timing" then
      value = motorTimingFromUi(value, data and data.timing_raw)
    end
    writeValue(payload, field[2], value)
  end
  return payload
end

local function typeLabel(value)
  local model = ESC_MODELS[value or 0]
  return (model and model.name) or ("YGE ESC (" .. tostring(value or 0) .. ")")
end

-- What the connected model can be set to, as opposed to what it is set to.
-- An id this file has never heard of reports false: the range then stays at the
-- 8.4 V every model shares, which is the safe direction -- a pilot is not offered
-- a voltage this suite cannot vouch for.
local function supportsBec12v(data)
  local model = data and ESC_MODELS[data.esc_type or 0]
  return model ~= nil and model.bec12v == true
end

-- Whether the BEC Voltage row is shown at all. It reports false only for the five
-- Opto models: an Opto ESC has no BEC, so there is no voltage to set and the row is
-- hidden rather than capped (Björn, 2026-10-03).
--
-- That is a fact about the ESC, NOT something read off the name. The name is only the
-- label that fact carries in a datasheet, and the five ids in ESC_MODELS are where a
-- new Opto is added -- no code inspects the string. So a model called "YGE Opto" with
-- `bec = true` above would be a wrong table, not a wrong filter.
--
-- Every other model reports true, including the ten whose name says neither BEC nor
-- Opto -- that is Björn's answer per model, not an inference from a name -- and an id
-- this file has never seen also reports true, so the row stays rather than
-- disappearing on hardware nothing is known about.
local function hasBec(data)
  local model = data and ESC_MODELS[data.esc_type or 0]
  return model == nil or model.bec ~= false
end

local function becMax(data)
  return supportsBec12v(data) and BEC_VOLTAGE_MAX_12V or BEC_VOLTAGE_MAX_8V
end

-- Arithmetic bit ops, the same spelling and the same reasoning as
-- app/field_layout.lua's setBit() (field_layout.lua:123-133), which is the code
-- that otherwise owns this same byte. It is kept local rather than exported from
-- there because that module's helper is part of a pooled-slot design and this is
-- not one of its callers.
local function setBit(value, bit, bitValue)
  value = value or 0
  local mask = 2 ^ bit
  local currentlySet = math.floor(value / mask) % 2 == 1
  if bitValue ~= 0 and not currentlySet then
    return value + mask
  elseif bitValue == 0 and currentlySet then
    return value - mask
  end
  return value
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 165,
  FIELD_META = FIELD_META,
  EDIT_FIELDS = EDIT_FIELDS,
  TITLE = "YGE",
}

function msp.summaryFor(data)
  return string.format("%s / %.5f",
    typeLabel(data and data.esc_type),
    (tonumber(data and data.firmware_version) or 0) / 100000)
end

-- The ceiling of the BEC Voltage field, for the page to hand to the field spec.
function msp.becVoltageMax(data)
  return becMax(data)
end

-- Whether the BEC Voltage row is shown at all. False only for the five Opto models,
-- which have no BEC (Björn, 2026-10-03) -- a fact about the ESC, not a reading of the
-- name. See hasBec() above.
function msp.hasBec(data)
  return hasBec(data)
end

-- The flags byte's HV-BEC bit is not a row on this page -- three other bits share
-- the byte and two of them have rows -- so nothing else would ever set it, and a
-- pilot selecting 12.0 V would command the voltage without the mode that makes it
-- 12 V. Enforced here rather than in a row because it is not the pilot's to choose
-- independently: the flag and the voltage are one decision.
--
-- Two rules, and the second is the one that is easy to get wrong:
--
--   1. When the pilot MOVED the voltage, the bit becomes `voltage == 120`. Not
--      "is 12 V or above": 12.0 V is the mode, and 11.9 V is the same slider one
--      step below it, so asserting the bit for it would tell the ESC to switch to
--      HV and then hand it a voltage the bit does not mean. The consequence a
--      pilot can see: any voltage below 12.0 V clears the bit.
--
--   2. When the pilot did NOT move it, the bit is left exactly as the ESC
--      reported it -- not forced to the invariant. An ESC that reports 8.4 V with
--      the bit set is in a state this page never put it in, and a save that
--      changed the governor gain has no business silently clearing a BEC setting
--      nobody looked at. That is the same rule the timing translation follows
--      (motorTimingFromUi writes the ESC's own word back for an untouched row),
--      and the harness asserts both halves of it.
--
-- Runs from page_runtime's beforeSave hook (app/page_runtime.lua:640-642), after
-- the confirmation and before any MSP_SET_* is built -- the same place and the
-- same shape as msp_esc_parameters_scorpion.lua's.
function msp.beforeSave(runtime)
  local data = runtime and runtime.data
  if not data then return end
  if data.lv_bec_voltage == data.lv_bec_voltage_raw then return end
  data.flags = setBit(data.flags, FLAG_BIT_BEC12V, data.lv_bec_voltage == BEC_VOLTAGE_MAX_12V and 1 or 0)
end

function msp.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf) onData(decode(buf)) end,
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

package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = msp
return msp
