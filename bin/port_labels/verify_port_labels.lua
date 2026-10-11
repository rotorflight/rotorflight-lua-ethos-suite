-- Behaviour check for the Ports page's port labels (#2359).
--
-- Run it:
--     lua5.3 bin/port_labels/verify_port_labels.lua
--
-- What it drives:
--   * lib/port_labels.lua: lookup(boardDesign, uartIndex) against the table copied
--     from the Rotorflight Configurator. Expected values are the Configurator's own,
--     for F7B5 (VANTAC_RF007, board_design reported by a real RF007 dump).
--   * lib/msp_board_info.lua: parse() of MSP_BOARD_INFO replies, including the
--     truncated and generic-board cases, and the read message's error path.
--   * The two together: a reply that names F7B5 gives the Port A label on UART4.
--
-- Every check has a control that would fail if the lookup fell through to the
-- plain UART name, so a green run cannot come from "always UART N".

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local LIB = ROOT .. "/src/rfsuite/lib/"

-- Modules resolve their own requires through lib/require.lua relative to the
-- working directory. Load the memoizer and the codec from the repo root, so
-- the harness works from any directory.
assert(loadfile(LIB .. "require.lua"))()
package.loaded["rfsuite.lib.mspcodec"] = assert(loadfile(LIB .. "mspcodec.lua"))()

local port_labels = assert(loadfile(LIB .. "port_labels.lua"))()
local msp_board_info = assert(loadfile(LIB .. "msp_board_info.lua"))()

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

local function bytesOf(str)
  local out = {}
  for i = 1, #str do out[i] = str:byte(i) end
  return out
end

-- Builds an MSP_BOARD_INFO reply payload. Strings are length-prefixed as in
-- the firmware (msp.c) and the Configurator parser.
local function boardInfoReply(opts)
  local buf = {}
  for _, b in ipairs(bytesOf(opts.identifier or "RFLT")) do buf[#buf + 1] = b end
  local version = opts.version or 0
  buf[#buf + 1] = version % 256
  buf[#buf + 1] = math.floor(version / 256)
  buf[#buf + 1] = opts.boardType or 1
  buf[#buf + 1] = opts.caps or 0
  for _, field in ipairs({opts.targetName or "", opts.boardName or "", opts.boardDesign or ""}) do
    buf[#buf + 1] = #field
    for _, b in ipairs(bytesOf(field)) do buf[#buf + 1] = b end
  end
  return buf
end

local function truncate(buf, n)
  local out = {}
  for i = 1, n do out[i] = buf[i] end
  return out
end

-- ---------------------------------------------------------------------------
print("lookup: F7B5 (RF007), Configurator's own labels")
-- ---------------------------------------------------------------------------

check("UART4 (index 3) is Port A", port_labels.lookup("F7B5", 3) == "Port A",
  tostring(port_labels.lookup("F7B5", 3)))
check("UART1 (index 0) is S.BUS", port_labels.lookup("F7B5", 0) == "S.BUS",
  tostring(port_labels.lookup("F7B5", 0)))
check("UART3 (index 2) is Port C", port_labels.lookup("F7B5", 2) == "Port C",
  tostring(port_labels.lookup("F7B5", 2)))
check("UART6 (index 5) is Port B", port_labels.lookup("F7B5", 5) == "Port B",
  tostring(port_labels.lookup("F7B5", 5)))
check("UART5 (index 4) is Int.Rx", port_labels.lookup("F7B5", 4) == "Int.Rx",
  tostring(port_labels.lookup("F7B5", 4)))
check("UART2 (index 1) is TELEM", port_labels.lookup("F7B5", 1) == "TELEM",
  tostring(port_labels.lookup("F7B5", 1)))

-- Control: the label must differ from the plain UART name, otherwise the lookup
-- could be a no-op and still pass the checks above by accident.
check("control: label is not the plain UART name", port_labels.lookup("F7B5", 3) ~= "UART4")

-- ---------------------------------------------------------------------------
print("lookup: fallbacks")
-- ---------------------------------------------------------------------------

check("unknown design gives nil", port_labels.lookup("NO_SUCH_DESIGN", 3) == nil)
check("manufacturer name is not a reference design", port_labels.lookup("VANTAC_RF007", 3) == nil)
check("nil design gives nil", port_labels.lookup(nil, 3) == nil)
check("empty design gives nil", port_labels.lookup("", 3) == nil)
check("UART with no label gives nil (UART10 = index 9)", port_labels.lookup("F7B5", 9) == nil)

local designs, entries, complete = 0, 0, true
for _, table_ in pairs(port_labels.DESIGNS) do
  designs = designs + 1
  local n = 0
  for _ in pairs(table_) do n = n + 1 end
  entries = entries + n
  if n ~= 6 then complete = false end
end
check("16 reference designs", designs == 16, designs)
check("6 UART entries per design", complete and entries == 96, entries)

-- ---------------------------------------------------------------------------
print("parse: MSP_BOARD_INFO replies")
-- ---------------------------------------------------------------------------

check("READ_COMMAND is 4", msp_board_info.READ_COMMAND == 4)

local rf007 = boardInfoReply({targetName = "RF007", boardName = "VANTAC_RF007", boardDesign = "F7B5", version = 258})
local info = msp_board_info.parse(rf007)
check("parses boardDesign F7B5", info ~= nil and info.boardDesign == "F7B5",
  info and info.boardDesign or "nil")
check("parses boardName", info ~= nil and info.boardName == "VANTAC_RF007",
  info and info.boardName or "nil")

local generic = msp_board_info.parse(boardInfoReply({boardDesign = ""}))
check("empty design is a valid reply with boardDesign ''", generic ~= nil and generic.boardDesign == "")

check("truncated inside boardDesign gives nil",
  msp_board_info.parse(truncate(rf007, #rf007 - 1)) == nil)
check("truncated inside the header gives nil",
  msp_board_info.parse(truncate(rf007, 5)) == nil)
check("empty reply gives nil", msp_board_info.parse({}) == nil)

-- The read message: a malformed reply must reach the error path, not onData.
local dataCalls, errorCalls = 0, 0
local msg = msp_board_info.buildReadMessage(
  function() dataCalls = dataCalls + 1 end,
  function() errorCalls = errorCalls + 1 end)
msg.processReply(nil, {offset = 1, table.unpack(truncate(rf007, 6))})
check("truncated reply calls onError", errorCalls == 1 and dataCalls == 0,
  string.format("data=%d error=%d", dataCalls, errorCalls))

-- The simulator fixture must parse as a generic board, never as a real design.
local simFixture = msp_board_info.buildReadMessage(function() end, function() end).simulatorResponse
local simInfo = msp_board_info.parse({table.unpack(simFixture)})
check("simulator fixture is a generic board", simInfo ~= nil and simInfo.boardDesign == "")

-- ---------------------------------------------------------------------------
print("GOOSKY_F701: keyed by board_name, generic design RTFL")

check("F701 UART1 is Int. ELRS", port_labels.lookup("RTFL", 0, "GOOSKY_F701") == "Int. ELRS")
check("F701 UART2 is SBUS/DSMX", port_labels.lookup("RTFL", 1, "GOOSKY_F701") == "SBUS/DSMX")
check("F701 UART4 is AUX", port_labels.lookup("RTFL", 3, "GOOSKY_F701") == "AUX")
check("F701 UART5 is TLM", port_labels.lookup("RTFL", 4, "GOOSKY_F701") == "TLM")
check("F701 UART3 has no label (plain UART3)", port_labels.lookup("RTFL", 2, "GOOSKY_F701") == nil)
check("F701 UART6 has no label (plain UART6)", port_labels.lookup("RTFL", 5, "GOOSKY_F701") == nil)

-- Collision controls: the generic design must not answer for other boards.
check("RTFL without a board name gives nil", port_labels.lookup("RTFL", 0) == nil)
check("RTFL with an unlisted board name gives nil", port_labels.lookup("RTFL", 3, "SOME_OTHER_BOARD") == nil)
-- Name beats design: a board named GOOSKY_F701 never gets the RF007 design's labels.
check("name beats design: F701 name on F7B5 gives AUX", port_labels.lookup("F7B5", 3, "GOOSKY_F701") == "AUX")
check("RF007 still resolves by design when its name is not listed",
  port_labels.lookup("F7B5", 3, "VANTAC_RF007") == "Port A")

local f701 = msp_board_info.parse(boardInfoReply({
  boardName = "GOOSKY_F701", boardDesign = "RTFL", manufacturer = "GSKY"}))
check("parses board_name GOOSKY_F701 with design RTFL",
  f701 ~= nil and f701.boardName == "GOOSKY_F701" and f701.boardDesign == "RTFL")
check("F701 reply resolves Int. ELRS on UART1 end to end",
  f701 ~= nil and port_labels.lookup(f701.boardDesign, 0, f701.boardName) == "Int. ELRS")

print("end to end: reply names F7B5, Ports page label on UART4")
-- ---------------------------------------------------------------------------

local endToEnd = msp_board_info.parse(rf007)
check("RF007 reply resolves Port A on UART4",
  endToEnd ~= nil and port_labels.lookup(endToEnd.boardDesign, 3) == "Port A")
-- Ethos renders only ASCII from this table reliably (see the generator's note).
check("all label values are plain ASCII", (function()
  for _, design in pairs(port_labels.DESIGNS) do
    for _, value in pairs(design) do
      if not value:match("^[%g ]+$") then return false end
    end
  end
  return true
end)())
check("generic reply resolves to nil (plain UART name)",
  generic ~= nil and port_labels.lookup(generic.boardDesign, 3) == nil)

-- ---------------------------------------------------------------------------
print("")
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
