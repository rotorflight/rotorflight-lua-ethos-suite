-- Behaviour check for the speed controller's status words (issue #2354).
--
-- Run it:
--     lua5.4 bin/esc_status/verify_esc_status.lua
--
-- What it drives, and why:
--   * lib/esc_status.lua and its layout modules, real, through decode() with the two bytes the
--     flight controller publishes (ESC1 Model, the signature, and ESC1 Status, the word).
--   * The signature values are the firmware's ESC_SIG_* defines (src/main/sensors/esc_sensor.c).
--     The bit layouts are the ones the firmware's own protocol comments document: Kontronik "Error
--     flags", APD "Status flags", Hobbywing V5 "Fault code bits", Scorpion "Error Code bits",
--     Graupner "Warning flags" and the OpenYGE state and warning nibbles.
--   * The laziness of the design: a protocol's layout is loaded only when a controller of that
--     protocol is read.
--
-- Against unpatched master there is no lib/esc_status.lua, so the harness stops at its first require.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function describe(v)
  if v == nil then return "nil" end
  return tostring(v.text) .. " / level " .. tostring(v.level)
end

local ESC = requireModule("lib/esc_status.lua")
local T = requireModule("lib/esc_status_text.lua")
local OK, WRN, ERR = ESC.LEVEL_OK, ESC.LEVEL_WARNING, ESC.LEVEL_ERROR

local FAMILY_FILES = {
  "lib/esc_status_families/kontronik.lua",
  "lib/esc_status_families/apd.lua",
  "lib/esc_status_families/hobbywing_v5.lua",
  "lib/esc_status_families/scorpion.lua",
  "lib/esc_status_families/graupner.lua",
  "lib/esc_status_families/openyge.lua",
}

local function familyLoaded(file)
  local key = "rfsuite." .. file:gsub("%.lua$", ""):gsub("/", ".")
  return package.loaded[key] ~= nil
end

-- ---------------------------------------------------------------------------
-- 1. Laziness: no layout is loaded until a controller of that protocol is read
-- ---------------------------------------------------------------------------

print("laziness")
ESC.decode(0x9B, 5)   -- Hobbywing V4: fills no status word
ESC.decode(0xC8, 0)   -- BLHeli32: fills no status word
ESC.decode(0xD0, 0)   -- OMP Hobby: opaque, no layout file
local anyLoaded = false
for _, file in ipairs(FAMILY_FILES) do
  if familyLoaded(file) then anyLoaded = true end
end
check("protocols without a layout file load no layout", not anyLoaded)

ESC.decode(0xA0, 0)   -- APD
check("reading an APD controller loads the APD layout", familyLoaded("lib/esc_status_families/apd.lua"))
check("and not the layouts of other protocols",
  not familyLoaded("lib/esc_status_families/kontronik.lua")
    and not familyLoaded("lib/esc_status_families/openyge.lua"))

-- ---------------------------------------------------------------------------
-- 2. Signatures: the firmware's ESC_SIG_* values name the protocol
-- ---------------------------------------------------------------------------

print("signatures")
local SIGNATURES = {
  {0xC8, "BLHeli32"}, {0x9B, "Hobbywing V4"}, {0x4B, "Kontronik"}, {0xD0, "OMP Hobby"},
  {0xDD, "ZTW"}, {0xA0, "APD"}, {0xFD, "Hobbywing V5"}, {0x53, "Scorpion"}, {0xA5, "OpenYGE"},
  {0xA6, "XDFly"}, {0x73, "FlyRotor"}, {0xC0, "Graupner"}, {0xC1, "BLHeli_S"}, {0xC2, "AM32"},
  {0xCC, "Castle"},
}
for _, pair in ipairs(SIGNATURES) do
  check(string.format("0x%02X is %s", pair[1], pair[2]), ESC.familyName(pair[1]) == pair[2],
    "got " .. tostring(ESC.familyName(pair[1])))
end

-- ---------------------------------------------------------------------------
-- 3. Nothing to report, and the states that are not a manufacturer
-- ---------------------------------------------------------------------------

print("no verdict, restart, unknown")
check("no signature: no verdict", ESC.decode(nil, 0) == nil)
check("signature 0x00 (no speed controller): no verdict", ESC.decode(0x00, 0) == nil)
check("a signature above 255 is not one", ESC.decode(300, 0) == nil)

local restart = ESC.decode(0xFF, 0)
check("0xFF asks for a restart, as a warning", restart and restart.text == T.restart and restart.level == WRN,
  describe(restart))
check("the restart verdict is transient (the next frame withdraws it)", restart and restart.transient == true)

local unknown = ESC.decode(0x05, 0)
check("an unknown signature reads UNKNOWN, not an error", unknown and unknown.text == T.unknown and unknown.level == OK,
  describe(unknown))

local hw4 = ESC.decode(0x9B, 5)
check("a controller that fills no status word reads NO STATUS", hw4 and hw4.text == T.no_status and hw4.level == OK,
  describe(hw4))
check("and names its protocol", hw4 and hw4.family == "Hobbywing V4")

-- ---------------------------------------------------------------------------
-- 4. Kontronik: 24 bits, worst first, bit 17 is information
-- ---------------------------------------------------------------------------

print("Kontronik (src/main/sensors/esc_sensor.c, Error flags)")
local function kon(word) return ESC.decode(0x4B, word) end
check("no bit set reads OK", kon(0) and kon(0).text == T.ok and kon(0).level == OK, describe(kon(0)))
check("bit 0 is undervoltage, an error", kon(1).text == T.undervoltage and kon(1).level == ERR, describe(kon(1)))
check("bit 3 is current warning, a warning", kon(8).text == T.current_warning and kon(8).level == WRN, describe(kon(8)))
check("bit 23 is capacity limit, a warning", kon(2 ^ 23).text == T.capacity_limit and kon(2 ^ 23).level == WRN,
  describe(kon(2 ^ 23)))
check("bit 17 (programming still permitted) is shown as information, not a fault",
  kon(2 ^ 17).text == T.programming_open and kon(2 ^ 17).level == OK, describe(kon(2 ^ 17)))
check("an error beats a warning set alongside it",
  kon(2 ^ 0 + 2 ^ 3).text == T.undervoltage and kon(2 ^ 0 + 2 ^ 3).level == ERR, describe(kon(2 ^ 0 + 2 ^ 3)))
check("a tie at the same level goes to the lower bit",
  kon(2 ^ 1 + 2 ^ 0).text == T.undervoltage, describe(kon(2 ^ 1 + 2 ^ 0)))
check("a bit above the protocol's 24 is ignored", kon(2 ^ 24).text == T.ok, describe(kon(2 ^ 24)))
check("a word with the top bit set (negative on the wire) is read unsigned, bit 31 ignored",
  kon(-2147483648).text == T.ok, describe(kon(-2147483648)))

-- ---------------------------------------------------------------------------
-- 5. APD: bit 0 is "motor started", a running motor and not a fault
-- ---------------------------------------------------------------------------

print("APD (src/main/sensors/esc_sensor.c, Status Flags)")
local function apd(word) return ESC.decode(0xA0, word) end
check("motor started alone reads OK (the masked bit is not a fault)", apd(1).text == T.ok and apd(1).level == OK,
  describe(apd(1)))
check("bit 1 is motor saturation, a warning", apd(2).text == T.motor_saturated and apd(2).level == WRN, describe(apd(2)))
check("bit 4 is undervoltage, an error", apd(16).text == T.undervoltage and apd(16).level == ERR, describe(apd(16)))
check("bit 5 is startup failure, an error", apd(32).text == T.startup and apd(32).level == ERR, describe(apd(32)))

-- ---------------------------------------------------------------------------
-- 6. Hobbywing V5, Scorpion, Graupner: flag layouts
-- ---------------------------------------------------------------------------

print("Hobbywing V5, Scorpion, Graupner")
check("V5 bit 0 is motor locked, an error", ESC.decode(0xFD, 1).text == T.motor_locked
  and ESC.decode(0xFD, 1).level == ERR, describe(ESC.decode(0xFD, 1)))
check("V5 bit 7 is motor wiring, an error", ESC.decode(0xFD, 128).text == T.motor_wiring, describe(ESC.decode(0xFD, 128)))
check("Scorpion bit 0 is not assigned and reads OK", ESC.decode(0x53, 1).text == T.ok, describe(ESC.decode(0x53, 1)))
check("Scorpion bit 7 is throttle, an error", ESC.decode(0x53, 128).text == T.throttle
  and ESC.decode(0x53, 128).level == ERR, describe(ESC.decode(0x53, 128)))
check("Scorpion bit 2 is temperature (overheat), an error", ESC.decode(0x53, 4).text == T.overheat
  and ESC.decode(0x53, 4).level == ERR, describe(ESC.decode(0x53, 4)))
check("Graupner bit 0 is low voltage, a warning (the protocol warns, it does not raise)",
  ESC.decode(0xC0, 1).text == T.undervoltage and ESC.decode(0xC0, 1).level == WRN, describe(ESC.decode(0xC0, 1)))
check("Graupner bit 4 is RPM below limit, a warning", ESC.decode(0xC0, 16).text == T.rpm_low
  and ESC.decode(0xC0, 16).level == WRN, describe(ESC.decode(0xC0, 16)))

-- ---------------------------------------------------------------------------
-- 7. OpenYGE: one byte, state in the low nibble, warning in the high nibble
-- ---------------------------------------------------------------------------

print("OpenYGE (src/main/sensors/esc_sensor.c, Motor states and Warning/error codes)")
local function oyge(word) return ESC.decode(0xA5, word) end
check("power cut with no warning is an overvoltage, an error", oyge(0x01).text == T.overvoltage
  and oyge(0x01).level == ERR, describe(oyge(0x01)))
check("running with no warning reads OK", oyge(0x0E).text == T.ok and oyge(0x0E).level == OK, describe(oyge(0x0E)))
check("undervoltage while fast-starting (state 2 < STARTING) is an error", oyge(0x12).text == T.undervoltage
  and oyge(0x12).level == ERR, describe(oyge(0x12)))
check("undervoltage while starting (state 8) is only a warning", oyge(0x18).text == T.undervoltage
  and oyge(0x18).level == WRN, describe(oyge(0x18)))
check("overtemperature during a power cut is an error", oyge(0x21).text == T.overheat
  and oyge(0x21).level == ERR, describe(oyge(0x21)))
check("overtemperature while running is a warning", oyge(0x2E).text == T.overheat
  and oyge(0x2E).level == WRN, describe(oyge(0x2E)))
check("BEC undervoltage (device bit set) reads as BEC", oyge(0x90).text == T.bec_undervoltage, describe(oyge(0x90)))
check("setpoint noise (0xC0) is its own warning", oyge(0xC0).text == T.setpoint_noise
  and oyge(0xC0).level == WRN, describe(oyge(0xC0)))
check("an unassigned warning code is reported as a fault, a warning", oyge(0x30).text == T.fault
  and oyge(0x30).level == WRN, describe(oyge(0x30)))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
