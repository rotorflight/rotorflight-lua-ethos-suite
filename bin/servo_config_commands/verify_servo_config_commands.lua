-- Behaviour check for the servo command numbers (#2444).
--
-- Run it:
--     lua5.4 bin/servo_config_commands/verify_servo_config_commands.lua
--     lua5.4 bin/servo_config_commands/verify_servo_config_commands.lua --self-test
--
-- What it drives:
--   * lib/msp_servo_config.lua: the read message (125), the packed write (212)
--     and the raw write (124), with their payloads.
--   * lib/msp_servo_center.lua (213) and lib/msp_servo_override.lua (193).
--
-- The numbers are the firmware's, from rotorflight-firmware @ 30923b5f:
--   src/main/msp/msp_protocol.h:174-175 (124, 125), :193, :213, :260 (212).
-- The check reads them off the messages the modules build, so a renamed constant
-- that still holds the wrong number is caught as well as a wrong constant name.
--
-- --self-test first requires the unmodified modules to pass, then swaps one
-- command number in a copy of a module, once per entry in MUTATIONS, and requires
-- the check to go red each time. A green run without a red control proves nothing.

local SELF_TEST = arg and arg[1] == "--self-test"

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local LIB = ROOT .. "/src/rfsuite/lib/"

-- Modules resolve their requires through lib/require.lua relative to the working
-- directory. Load the memoizer and the codec from the repo root, so the harness
-- works from any directory.
local requireModule = assert(loadfile(LIB .. "require.lua"))()
package.loaded["rfsuite.lib.require"] = requireModule
package.loaded["rfsuite.lib.mspcodec"] = assert(loadfile(LIB .. "mspcodec.lua"))()

local failures = 0
local checks = 0

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

-- Loads one module fresh: from its file, or from mutated source text.
local function loadModule(name, text)
  package.loaded["rfsuite.lib." .. name] = nil
  local chunk, err
  if text then
    chunk, err = load(text, "@" .. name .. ".lua")
  else
    chunk, err = loadfile(LIB .. name .. ".lua")
  end
  assert(chunk, err)
  return chunk()
end

local function readSource(name)
  local f = assert(io.open(LIB .. name .. ".lua", "r"))
  local text = f:read("a")
  f:close()
  return text
end

-- The payload as a comma-separated string, so a mismatch prints what was sent.
local function bytes(payload)
  return table.concat(payload, ",")
end

-- Pins the command numbers and the payload layout. Returns how many checks failed.
local function pinCommands(cfg, center, override)
  local before = failures
  local data = {mid = 1301, min = -700, max = 700, rneg = 500, rpos = 500,
    rate = 333, speed = 0, flags = 0}

  print("Command numbers")
  check("read is MSP_GET_SERVO_CONFIG (125)", cfg.READ_COMMAND == 125,
    "got " .. tostring(cfg.READ_COMMAND))
  check("raw write is MSP_SET_SERVO_CONFIG (124)", cfg.WRITE_RAW_COMMAND == 124,
    "got " .. tostring(cfg.WRITE_RAW_COMMAND))
  check("packed write is MSP_SET_SERVO_CONFIGURATION (212)", cfg.WRITE_PACKED_COMMAND == 212,
    "got " .. tostring(cfg.WRITE_PACKED_COMMAND))
  check("centre is MSP_SET_SERVO_CENTER (213)", center.WRITE_COMMAND == 213,
    "got " .. tostring(center.WRITE_COMMAND))
  check("override is MSP_SET_SERVO_OVERRIDE (193)", override.WRITE_COMMAND == 193,
    "got " .. tostring(override.WRITE_COMMAND))

  print("Messages")
  local read = cfg.buildReadMessage(12, function() end, function() end)
  check("the read message sends 125 with raw index 12",
    read.command == 125 and bytes(read.payload) == "12",
    string.format("command %s, payload %s", tostring(read.command), bytes(read.payload)))

  local packed = cfg.buildWriteMessage(12, data, nil, nil)
  check("the packed write sends 212 and passes its index through unchanged",
    packed.command == 212 and packed.payload[1] == 12,
    string.format("command %s, index %s", tostring(packed.command), tostring(packed.payload[1])))

  local raw = cfg.buildRawWriteMessage(12, data, nil, nil)
  check("the raw write sends 124 and passes its index through unchanged",
    raw.command == 124 and raw.payload[1] == 12,
    string.format("command %s, index %s", tostring(raw.command), tostring(raw.payload[1])))
  check("raw and packed writes carry the same 17 bytes (index + 8 U16)",
    #raw.payload == 17 and bytes(raw.payload) == bytes(packed.payload),
    string.format("raw %s / packed %s", bytes(raw.payload), bytes(packed.payload)))
  check("mid 1301 is little-endian at payload bytes 2-3 (21, 5)",
    packed.payload[2] == 21 and packed.payload[3] == 5,
    string.format("got %s, %s", tostring(packed.payload[2]), tostring(packed.payload[3])))

  local c = center.buildWriteMessage(12, 1301)
  check("the centre message sends 213 with index 12 and mid 1301",
    c.command == 213 and bytes(c.payload) == "12,21,5",
    string.format("command %s, payload %s", tostring(c.command), bytes(c.payload)))

  local o = override.buildWriteMessage(12, 1500)
  check("the override message sends 193 with index 12 and value 1500",
    o.command == 193 and bytes(o.payload) == "12,220,5",
    string.format("command %s, payload %s", tostring(o.command), bytes(o.payload)))

  print("Factory forIndex")
  local inst = cfg.forIndex(12)
  local fiRead = inst.buildReadMessage(function() end, function() end)
  check("forIndex buildReadMessage delegates to 125 with bound index 12",
    fiRead.command == 125 and bytes(fiRead.payload) == "12",
    string.format("command %s, payload %s", tostring(fiRead.command), bytes(fiRead.payload)))

  local fiPacked = inst.buildWriteMessage(data, nil, nil)
  check("forIndex buildWriteMessage delegates to 212 with bound index 12",
    fiPacked.command == 212 and fiPacked.payload[1] == 12,
    string.format("command %s, index %s", tostring(fiPacked.command), tostring(fiPacked.payload[1])))

  local fiRaw = inst.buildRawWriteMessage(data, nil, nil)
  check("forIndex buildRawWriteMessage delegates to 124 with bound index 12",
    fiRaw.command == 124 and fiRaw.payload[1] == 12,
    string.format("command %s, index %s", tostring(fiRaw.command), tostring(fiRaw.payload[1])))

  return failures - before
end

-- Each entry swaps one command number in one module. Every swap must be caught.
local MUTATIONS = {
  {file = "msp_servo_config", from = "local WRITE_PACKED_COMMAND = 212",
    to = "local WRITE_PACKED_COMMAND = 124", what = "the packed write sent as the raw command"},
  {file = "msp_servo_config", from = "local READ_COMMAND = 125",
    to = "local READ_COMMAND = 124", what = "the read sent as the raw write"},
  {file = "msp_servo_config", from = "local WRITE_RAW_COMMAND = 124",
    to = "local WRITE_RAW_COMMAND = 212", what = "the raw write sent as the packed command"},
  {file = "msp_servo_center", from = "local WRITE_COMMAND = 213",
    to = "local WRITE_COMMAND = 212", what = "the centre sent as the bulk command"},
  {file = "msp_servo_override", from = "local WRITE_COMMAND = 193",
    to = "local WRITE_COMMAND = 196", what = "the override sent as the all-servos command"},
}

-- Source text of one module with exactly one plain-text replacement.
local function mutatedSource(mutation)
  local text = readSource(mutation.file)
  local s, e = text:find(mutation.from, 1, true)
  assert(s and not text:find(mutation.from, e + 1, true),
    "self-test could not find exactly one '" .. mutation.from .. "'")
  return text:sub(1, s - 1) .. mutation.to .. text:sub(e + 1)
end

-- Loads the three modules, with one of them replaced by its mutated copy if given,
-- and runs the pin. Returns the number of failed checks.
local function runWith(mutation)
  local texts = {}
  if mutation then texts[mutation.file] = mutatedSource(mutation) end
  local cfg = loadModule("msp_servo_config", texts.msp_servo_config)
  local center = loadModule("msp_servo_center", texts.msp_servo_center)
  local override = loadModule("msp_servo_override", texts.msp_servo_override)
  return pinCommands(cfg, center, override)
end

if not SELF_TEST then
  local failed = runWith(nil)
  print(string.format("\n%d checks, %d failed", checks, failures))
  os.exit(failed == 0 and 0 or 1)
end

print("self-test: the unmodified modules must pass first")
local baseline = runWith(nil)
print(string.format("baseline: %s", baseline == 0 and "green" or "RED"))

local caughtCount = 0
for _, mutation in ipairs(MUTATIONS) do
  print(string.format("\nself-test: %s (%s -> %s)", mutation.what, mutation.from, mutation.to))
  local failed = runWith(mutation)
  if failed > 0 then
    caughtCount = caughtCount + 1
    print("self-test: caught")
  else
    print("self-test: NOT caught")
  end
end

print(string.format("\nself-test: baseline %s, %d of %d mutations caught",
  baseline == 0 and "green" or "RED", caughtCount, #MUTATIONS))
os.exit((baseline == 0 and caughtCount == #MUTATIONS) and 0 or 1)
