-- Behaviour check for the SRXL2 ESC config codec (lib/msp_srxl2_esc_config.lua)
-- and the page and menu row that use it.
--
-- Run it:
--     lua5.4 bin/srxl2_esc_config/verify_srxl2_esc_config.lua
--
-- What it drives, and why:
--   * The codec is pure byte<->number code over lib/mspcodec.lua, so the whole
--     decode/encode path runs on a workstation through the real message
--     builders.
--   * The wire sizes are transcribed from the firmware handler
--     (rotorflight-firmware PR #537, msp.c): MSP2_GET_SRXL2_ESC_CONFIG replies
--     U8 version (1), U16 throttle_rate_hz, U8 telem_interval_frames,
--     U8 motor2_channel = 5 bytes; MSP2_SET_SRXL2_ESC_CONFIG takes the same
--     fields without the version byte, and the firmware rejects anything other
--     than exactly 4 bytes.
--   * The page saves by writing back what it read, so a reply in a layout this
--     suite does not know must be refused, not decoded into plausible numbers
--     that the next save would store.
--
-- Cases 3, 4 and 5 go red on the pre-fix codec, which read the version byte,
-- ignored it, and decoded any length. Every other case pins behaviour that has
-- to survive a change here.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local failures = 0
local checks = 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail ~= nil then print("        " .. tostring(detail)) end
  end
end

package.loaded["rfsuite.lib.require"] = function(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(SUITE .. "/" .. name)
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end

local requireModule = package.loaded["rfsuite.lib.require"]
local codec = requireModule("lib/msp_srxl2_esc_config.lua")

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

local function copy(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end

-- Decode through the real read message, so the case exercises the same
-- processReply/onError wiring the queue and page_runtime use.
local function read(buf)
  local got, reason, refused
  local errored = false
  codec.buildReadMessage(
    function(d) got = d end,
    function(r, ref) errored = true; reason = r; refused = ref end
  ).processReply(nil, copy(buf))
  return got, errored, reason, refused
end

-- throttle 333 Hz (0x014D), telemetry every 9 frames, motor 2 on channel 4
local REPLY = {1, 0x4D, 0x01, 9, 4}

-- ---------------------------------------------------------------------------
print("case 1: the sizes match the firmware handler")

check("PAYLOAD_VERSION is 1", codec.PAYLOAD_VERSION == 1, codec.PAYLOAD_VERSION)
check("REPLY_LENGTH is 5", codec.REPLY_LENGTH == 5, codec.REPLY_LENGTH)
local sim = codec.buildReadMessage(function() end, function() end).simulatorResponse
check("simulatorResponse is REPLY_LENGTH bytes", #sim == codec.REPLY_LENGTH, #sim)
check("simulatorResponse carries PAYLOAD_VERSION", sim[1] == codec.PAYLOAD_VERSION, sim[1])
local simData, simErrored = read(sim)
check("simulatorResponse decodes", simData ~= nil and not simErrored)

-- ---------------------------------------------------------------------------
print("case 2: decode/encode round-trip")

local data, errored = read(REPLY)
check("a valid reply reaches onData, not onError", data ~= nil and not errored)
if data then
  check("throttle_rate_hz", data.throttle_rate_hz == 333, data.throttle_rate_hz)
  check("telem_interval_frames", data.telem_interval_frames == 9, data.telem_interval_frames)
  check("motor2_channel", data.motor2_channel == 4, data.motor2_channel)
  local msg = codec.buildWriteMessage(data, function() end, function() end)
  local payload = msg.payload
  check("write uses MSP2_SET_SRXL2_ESC_CONFIG", msg.command == 0x5F17, msg.command)
  check("encode gives exactly 4 bytes", #payload == 4, #payload)
  local same = #payload == 4
  for i = 1, 4 do same = same and payload[i] == REPLY[i + 1] end
  check("encode is the reply without its version byte", same,
    table.concat(payload, ","))
end
check("encode of an empty table is still 4 bytes", #codec.encode({}) == 4, #codec.encode({}))

-- ---------------------------------------------------------------------------
print("case 3: a short reply is refused")

local short = {1, 0x4D, 0x01, 9}
local got, err, reason, refused = read(short)
check("4-byte reply does not reach onData", got == nil)
check("4-byte reply is reported through onError as refused", err and refused == true, reason)

-- ---------------------------------------------------------------------------
print("case 4: a reply of another payload version is refused")

local v2 = copy(REPLY); v2[1] = 2
got, err, reason, refused = read(v2)
check("version 2 does not reach onData", got == nil)
check("version 2 is reported through onError as refused", err and refused == true, reason)

-- ---------------------------------------------------------------------------
print("case 5: a long reply is refused")

local long = copy(REPLY); long[#long + 1] = 0
got, err, reason, refused = read(long)
check("6-byte reply does not reach onData", got == nil)
check("6-byte reply is reported through onError as refused", err and refused == true, reason)

-- ---------------------------------------------------------------------------
print("case 6: motor 2 channel choices")

local choices = codec.MOTOR2_CHANNEL_CHOICES
check("32 choices (Off + 1..31)", #choices == 32, #choices)
check("first choice is Off = 0",
  choices[1] and choices[1][1] == "@i18n(api.SRXL2_ESC_CONFIG.tbl_off)@" and choices[1][2] == 0)
local seq = true
for ch = 1, 31 do
  local c = choices[ch + 1]
  seq = seq and c ~= nil and c[2] == ch and c[1] == tostring(ch)
end
check("choices 2..32 are channels 1..31", seq)

-- ---------------------------------------------------------------------------
print("case 7: the page and its menu row")

local page = readFile(SUITE .. "/app/pages/esc_motors_srxl2.lua")
check("page file readable", page ~= nil)
if page then
  check("page reboots after save (settings latch at boot)",
    page:find("rebootAfterSave%s*=%s*true") ~= nil)
  check("page uses this codec", page:find("lib/msp_srxl2_esc_config.lua", 1, true) ~= nil)
end

local tool = readFile(SUITE .. "/app/tool.lua")
local row = tool and tool:match("[^\n]*app/pages/esc_motors_srxl2%.lua[^\n]*")
check("menu row present in app/tool.lua", row ~= nil)
if row then
  -- ESC_SENSOR_PROTO_SRXL2 in the firmware's pg/esc_sensor.h enum, and
  -- lib/msp_esc_sensor_config.lua's SRXL2 from API 12.10.
  check("menu row is gated on ESC telemetry protocol 14 (SRXL2)",
    row:find("escProtocolId%s*=%s*14[^%d]") ~= nil, row)
  local icon = row:match('lcd%.loadMask%("([^"]+)"%)')
  check("menu row icon exists", icon ~= nil and readFile(SUITE .. "/" .. icon) ~= nil, icon)
end
check("esc_motors_menu has an ESC protocol guard",
  tool ~= nil and tool:find("MENUS%.esc_motors_menu%.guard%s*=%s*ensureEscProtocolGuard%(%)") ~= nil)

-- ---------------------------------------------------------------------------

print("")
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
else
  print(string.format("%d of %d checks FAILED", failures, checks))
  os.exit(1)
end
