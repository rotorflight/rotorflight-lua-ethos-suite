-- The speed controller's health, in words, from the two bytes the flight controller publishes for
-- it: ESC1 Status (the status word) and ESC1 Model (the signature byte). Issue #2354.
--
-- The firmware keeps one status word and one signature per speed controller (`escSensorData_t`
-- `.status` and `.id` in src/main/sensors/esc_sensor.c). The signature says which protocol
-- answered, and each protocol lays out its status word differently, so the word cannot be read
-- without it. The signature values below are the firmware's own ESC_SIG_* defines.
--
-- Lazy: the bit layout of a protocol lives in lib/esc_status_families/ and is loaded only when a
-- controller of that protocol is read. A controller on the bench or in flight loads one layout.
--
-- Nothing here reads a sensor or a file. It is a pure function of the two bytes.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local TEXT = requireModule("lib/esc_status_text.lua")

local M = {}

-- What a verdict is worth. A caller colours the line from this. Numbers rise with severity so
-- that "worst" is a comparison. Nothing to report at all is a nil verdict, not a level.
M.LEVEL_OK = 1
M.LEVEL_WARNING = 2
M.LEVEL_ERROR = 3

local SIG_NONE = 0x00
local SIG_RESTART = 0xFF

local FAMILY_DIR = "lib/esc_status_families/"

-- signature -> protocol. `file` names the layout module; a protocol without one either fills no
-- status word (its word is zero and means nothing) or fills one whose layout the firmware does not
-- document (`opaque`: all that can be said is whether it reports something).
local FAMILIES = {
  [0xC8] = {name = "BLHeli32"},
  [0x9B] = {name = "Hobbywing V4"},
  [0x4B] = {name = "Kontronik", file = FAMILY_DIR .. "kontronik.lua"},
  [0xD0] = {name = "OMP Hobby", opaque = true},
  [0xDD] = {name = "ZTW", opaque = true},
  [0xA0] = {name = "APD", file = FAMILY_DIR .. "apd.lua"},
  [0xFD] = {name = "Hobbywing V5", file = FAMILY_DIR .. "hobbywing_v5.lua"},
  [0x53] = {name = "Scorpion", file = FAMILY_DIR .. "scorpion.lua"},
  [0xA5] = {name = "OpenYGE", file = FAMILY_DIR .. "openyge.lua"},
  [0xA6] = {name = "XDFly", opaque = true},
  [0x73] = {name = "FlyRotor", opaque = true},
  [0xC0] = {name = "Graupner", file = FAMILY_DIR .. "graupner.lua"},
  [0xC1] = {name = "BLHeli_S"},
  [0xC2] = {name = "AM32"},
  [0xCC] = {name = "Castle"},
}

-- The status word arrives as a signed integer; a 32-bit word with its top bit set comes back
-- negative, so it is read back as unsigned.
local function toWord(value)
  local number = tonumber(value)
  if number == nil then return nil end
  number = math.floor(number)
  if number < 0 then number = number + 4294967296 end
  return number
end

local function toSignature(value)
  local number = tonumber(value)
  if number == nil then return nil end
  number = math.floor(number)
  if number < 0 or number > 255 then return nil end
  return number
end

-- Bit test by arithmetic, so it does not depend on which bit library the radio's Lua has.
local function isBitSet(word, bitIndex)
  return (word % (2 ^ (bitIndex + 1))) >= (2 ^ bitIndex)
end

-- The worst condition the word reports, and nothing else: a tile has room for one line, and a
-- second fault behind the first changes nothing a pilot does. Ties go to the lower bit, which is
-- the order the protocol lists them in.
local function worstBit(word, bits, highestBit)
  local bestText, bestLevel = nil, nil
  for bitIndex = 0, highestBit do
    local entry = bits[bitIndex]
    if entry ~= nil and isBitSet(word, bitIndex) then
      if bestLevel == nil or entry[2] > bestLevel then
        bestText, bestLevel = entry[1], entry[2]
        if bestLevel >= M.LEVEL_ERROR then break end
      end
    end
  end
  return bestText, bestLevel
end

-- The layout module of a protocol, loaded now and only now.
local function layoutOf(family)
  if family.file == nil then return nil end
  return requireModule(family.file)
end

--- Reads the two bytes into one verdict.
--
-- @param signature the ESC1 Model byte: the protocol that answered
-- @param word      the ESC1 Status word
-- @return nil where no speed controller answered, otherwise a table:
--         `text`      what to show, a build marker until the install is packaged
--         `level`     one of the M.LEVEL_* values
--         `word`      the status word as read, unsigned, or nil where there is none
--         `family`    the protocol's name, or nil where the signature is not one we know
--         `transient` true where the next telemetry frame withdraws the verdict, so a caller
--                     must not remember it
function M.decode(signature, word)
  local sig = toSignature(signature)
  if sig == nil or sig == SIG_NONE then return nil end

  -- Not a manufacturer. The firmware writes this signature when the controller must be restarted
  -- before parameters just written to it take effect; the next frame writes the real one back.
  if sig == SIG_RESTART then
    return {text = TEXT.restart, level = M.LEVEL_WARNING, word = nil, family = nil, transient = true}
  end

  local family = FAMILIES[sig]
  if family == nil then
    return {text = TEXT.unknown, level = M.LEVEL_OK, word = nil, family = nil, transient = false}
  end

  local raw = toWord(word)
  local layout = layoutOf(family)
  local hasLayout = (layout ~= nil) or (family.opaque == true)
  if raw == nil or not hasLayout then
    return {text = TEXT.no_status, level = M.LEVEL_OK, word = raw, family = family.name, transient = false}
  end

  if layout and layout.reader then
    local text, level = layout.reader(raw)
    return {text = text, level = level, word = raw, family = family.name, transient = false}
  end

  if family.opaque then
    local text = (raw == 0) and TEXT.ok or TEXT.fault
    local level = (raw == 0) and M.LEVEL_OK or M.LEVEL_WARNING
    return {text = text, level = level, word = raw, family = family.name, transient = false}
  end

  local masked = raw
  if layout.ignore then
    for bitIndex in pairs(layout.ignore) do
      if isBitSet(masked, bitIndex) then
        masked = masked - math.floor(2 ^ bitIndex + 0.5)
      end
    end
  end

  -- Nothing set is the answer on almost every reading, and needs no walk at all.
  local text, level = nil, nil
  if masked ~= 0 then
    text, level = worstBit(masked, layout.bits, layout.highest)
  end
  if text == nil then
    text, level = TEXT.ok, M.LEVEL_OK
  end
  return {text = text, level = level, word = raw, family = family.name, transient = false}
end

--- The protocol name for a signature byte, where it is one we know.
function M.familyName(signature)
  local sig = toSignature(signature)
  local family = sig and FAMILIES[sig] or nil
  return family and family.name or nil
end

return M
