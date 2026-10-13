-- Behaviour check for the Bluejay LED Control row (#2453).
--
-- Run it:
--     lua5.3 bin/bluejay_led_control/verify_bluejay_led_control.lua
--     lua5.3 bin/bluejay_led_control/verify_bluejay_led_control.lua --self-test
--
-- What the defect was:
--   app/pages/esc_forward_bluejay.lua declared an "LED Control" row and gated it on
--   msp.supportsLedControl(), which read _raw[67] and compared it against the five
--   ASCII letters that name Bluejay's five LED-capable pinouts. The MSP 217 reply
--   is 66 bytes -- two header bytes plus BLHELI_S_MSP_NUM_EEPROM_BYTES (0x40), see
--   bin/esc_raw_bytes/verify_esc_raw_bytes.lua:16-27 -- so _raw[67] is nil, the
--   comparison is false, and esc_forward_vendor.lua's fieldEnabled() (which requires
--   `== true`) dropped the row on every ESC, forever. A row that cannot be shown
--   cannot be seen by a pilot, a build, or a package step.
--
--   Nothing about the numbers is in doubt, and this harness measures rather than
--   asserts them: the reply is 66 bytes, byte 67 does not exist, and the block's
--   66 bytes are covered one for one by the codec's field list.
--
-- Why the row is gone rather than repaired:
--   What the row needed was the LED count, which is a property of the compiled
--   pinout. mathiasvr/bluejay lists all 26 supported ESCs with their LED counts in
--   Bluejay.asm:63-91 and exactly five carry one -- E_ 3, J_ 3, M_ 1, Q_ 2, U_ 3 --
--   while every other layout reads "_" in that column and Z_ reads "-". Those
--   letters are EQU constants of the build. The EEPROM segment at 1A00h
--   (Bluejay.asm:321-364) stores 41 parameter bytes and not one of them is a layout
--   letter; the only layout-related byte is Eep_Layout_Revision, written from the
--   firmware-wide EEPROM_LAYOUT_REVISION = 204 (Bluejay.asm:319), which every
--   layout shares. Byte 43 of the block IS the LED byte -- Eep_Pgm_LED_Control at
--   segment offset 0x28 -- so the byte can be written, but nothing on the wire says
--   whether writing it does anything.
--
--   And the row's choice list was BLHeli_S's, not Bluejay's: Bluejay drives one pin
--   per LED, two bits each, and lights a pin when its pair is non-zero
--   (Bluejay.asm:1525-1556; DEFAULT_PGM_LED_CONTROL's own comment at :131 reads
--   "2 bits per LED, 0=Off, 1=On"), so that list's "Green" is one LED on rather than
--   a colour. The row therefore stays out until it can be per-LED on/off, which is a
--   decision about the UI rather than a repair of this byte. Byte 43 is kept as the
--   name reserved_28 so the block still decodes and re-encodes all 66 bytes.
--
--   The same read survives in two other places, unchanged here because both are
--   other repositories: rotorflight/rotorflight-lua-edgetx-suite
--   (app/pages/setup/esc_motors/esc_tools/escmfg/bluejay/init.lua:24, the origin of
--   the byte-67 read) and WingFlight/wingflight-lua-ethos-suite, which is where this
--   suite's copy came from. The Rotorflight Configurator made the other choice and
--   documents it: tabs/esc_programming/manufacturers/bluejay.js:11-13 cites this
--   very function as the thing it chose NOT to replicate, and shows the row
--   unconditionally.
--
-- What this drives, and why:
--   * the real app/pages/esc_forward_bluejay.lua, loaded from its path, so the
--     fields and the criteria under test are the shipped ones and not a transcription.
--     The shared editor is stubbed at its open() because the rows it renders come
--     from the same FIELDS table this reads directly, and reaching the form would
--     only add stubs without adding a fact.
--   * the real lib/msp_esc_parameters_bluejay.lua for the decode, the encode and the
--     metadata.
--
-- Which checks are gates -- three, and --self-test proves all three go red:
--   * no criterion and no label on this page reads a byte the reply does not carry.
--     This is the defect class, stated so that it outlives this row: the reads are
--     traced through a metatable on _raw, so a criterion that reads past the reply
--     is caught wherever it sits, and a revision test like atLeast(209) -- which is
--     correctly false for a layout-204 ESC -- is not caught, because it reads
--     layout_revision, which decode() did produce.
--   * the page declares no LED Control row.
--   * the codec exports no LED capability function.
--     These two pin the decision, so putting the row back has to be a deliberate
--     change with its own evidence rather than an edit. A future correct LED row is
--     allowed to fail them; it then has to come with the criterion that makes it
--     reachable and this file has to be updated to say so.
--
-- Deliberately NOT gates, each for a stated reason:
--   * the reply is 66 bytes and byte 67 does not exist -- true before the fix as
--     well, so it cannot detect it. It is here because it is the fact the first gate
--     is built on, and because a block that ever grew a 67th byte would make the
--     whole question open again.
--   * byte 43 round-trips unchanged over all 256 of its values, and every one of the
--     66 positions still has exactly one owner with byte 43 among them named
--     reserved_28 -- also true before the fix. They are the guard on what the rename
--     could have broken: a dropped field entry would shorten the payload the flight
--     controller commits (msp.c's MSP_SET_ESC_PARAMETERS copies exactly
--     escGetParamBufferLength() bytes, 66 for this signature), so this is the
--     difference between removing a row and moving a byte.
--
-- --self-test splices the pre-fix row and the pre-fix criterion back into copies of
-- both files, proves each splice is the pre-fix code before letting it stand in for
-- one, and requires the three gates to turn red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local CODEC_SRC = PREFIX .. "lib/msp_esc_parameters_bluejay.lua"
local PAGE_SRC = PREFIX .. "app/pages/esc_forward_bluejay.lua"
local CODEC_KEY = "rfsuite.lib.msp_esc_parameters_bluejay"

local SELF_TEST = arg[1] == "--self-test"

-- The names of every check the splice has to turn red. Collected as they run so
-- the self-test cannot drift away from the checks as they are written.
local MUST_GO_RED = {}

local checks, failures = 0, 0
local failedLabels = {}
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    failedLabels[label] = true
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

-- Registers a check whose passing is only meaningful if it can fail.
local function gateCheck(label, ok, detail)
  MUST_GO_RED[#MUST_GO_RED + 1] = label
  check(label, ok, detail)
end

-- ---------------------------------------------------------------------------
-- Loading the shipped files
-- ---------------------------------------------------------------------------

local realLoadfile = loadfile

-- Set by the self-test: paths whose checked-out file stands in for a temp one.
local REDIRECTS = {}

-- requireModule() calls loadfile() with a path carrying no directory part; on the
-- radio the working directory is src/rfsuite. A redirect that never fires is
-- counted and reported, so pass 2 cannot quietly be a rerun of pass 1.
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    for i = 1, #REDIRECTS do
      if path:match(REDIRECTS[i].match) then
        REDIRECTS[i].hits = (REDIRECTS[i].hits or 0) + 1
        return realLoadfile(REDIRECTS[i].file, ...)
      end
    end
    return realLoadfile(PREFIX .. path, ...)
  end
  return realLoadfile(path, ...)
end

local function readFile(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end

local function writeTmp(text)
  local path = os.tmpname() .. ".lua"
  local handle = assert(io.open(path, "wb"))
  handle:write(text)
  handle:close()
  return path
end

-- The two dependencies of the page that decide nothing about the fields. Their
-- open() only hands the shared editor its config, and that config carries FIELDS,
-- which is what this reads -- so capturing it is the whole job.
local captured = {}
package.loaded["rfsuite.app.pages.esc_forward_vendor"] = {
  open = function(_, config) captured.vendor = config end,
}
package.loaded["rfsuite.app.pages.esc_forward_4way"] = {
  open = function(_, config) captured.fourway = config end,
}

-- Loads a shipped path, from the temp file the self-test redirects it to rather
-- than from the checked-out file. Both loaders below go through here: pass 2 has
-- to run the pre-fix code and not a mixture of the two trees, and the first
-- version of this harness got that wrong in the shape bin/esc_raw_bytes documents
-- -- loading the spliced codec by its temp path found the FIXED one already in
-- package.loaded, because the codec's own top-of-file guard returns whatever is
-- under its key without ever reading the file it was handed.
local function loadShipped(path)
  for i = 1, #REDIRECTS do
    if path:match(REDIRECTS[i].match) then
      REDIRECTS[i].hits = (REDIRECTS[i].hits or 0) + 1
      return assert(realLoadfile(REDIRECTS[i].file))()
    end
  end
  return assert(realLoadfile(path))()
end

local function loadCodec()
  package.loaded[CODEC_KEY] = nil
  return loadShipped(CODEC_SRC)
end

-- The page hands its FIELDS table to the shared editor, which is stubbed at its
-- open() because the rows it would render come from that same table.
local function captureFields(page)
  captured = {}
  page.open({})
  assert(type(captured.fourway) == "table", "the page did not hand off to the 4-way page")
  captured.fourway.openEditor({}, {label = "check"})
  assert(type(captured.vendor) == "table", "the page did not hand off to the shared editor")
  return captured.vendor.fields
end

-- The page binds its codec into a module-level local at its line 6, so it has to
-- be reloaded whenever the codec is. It carries no self-cache guard, so a plain
-- reload really does re-run its body.
local function loadPage()
  return captureFields(loadShipped(PAGE_SRC))
end

local function blockOf(source)
  local buf = {}
  for i = 1, #source do buf[i] = source[i] end
  return buf
end

-- ---------------------------------------------------------------------------
-- The checks
-- ---------------------------------------------------------------------------

local function runChecks()
  local codec = loadCodec()
  local fixture = blockOf(codec._simulatorResponse)
  local replyBytes = #fixture

  -- The fact the first gate stands on. Measured, not assumed.
  local decoded = codec._decode(blockOf(fixture))
  check(string.format("the reply is %d bytes and carries no byte %d", replyBytes, replyBytes + 1),
    replyBytes == 66 and #decoded._raw == replyBytes and decoded._raw[replyBytes + 1] == nil,
    string.format("fixture %d bytes, _raw %d, _raw[%d] %s",
      replyBytes, #decoded._raw, replyBytes + 1, tostring(decoded._raw[replyBytes + 1])))

  -- Every byte position, poked on its own, says which field owns it. That is a
  -- second source for the layout rather than a copy of WIRE_FIELDS.
  local owner = {}
  local zero = {}
  for i = 1, replyBytes do zero[i] = 0 end
  local zeroData = codec._decode(zero)
  for position = 1, replyBytes do
    local block = {}
    for i = 1, replyBytes do block[i] = 0 end
    block[position] = 200
    local data = codec._decode(block)
    local hits = {}
    for name, value in pairs(data) do
      if name ~= "_raw" and value ~= zeroData[name] then hits[#hits + 1] = name end
    end
    owner[position] = table.concat(hits, "+")
  end

  local fields = loadPage()

  -- Gate 1: the defect class. Reads of _raw are traced through a metatable, so a
  -- criterion that reaches past the reply is reported with the byte it reached for,
  -- and one that reads a decoded field is not.
  local function probeFor(data)
    local reads = {}
    local raw = {}
    for i = 1, #data._raw do raw[i] = data._raw[i] end
    setmetatable(raw, {__index = function(_, key)
      reads[#reads + 1] = key
      return nil
    end})
    local probe = {}
    for key, value in pairs(data) do
      if key ~= "_raw" then probe[key] = value end
    end
    probe._raw = raw
    return probe, reads
  end

  local pastReply, raised = {}, {}
  for i = 1, #fields do
    local field = fields[i]
    for _, what in ipairs({"enabledWhen", "label"}) do
      local fn = field[what]
      if type(fn) == "function" then
        local probe, reads = probeFor(decoded)
        local ok, err = pcall(fn, probe)
        if not ok then
          raised[#raised + 1] = string.format("%s (%s): %s", field.key or field.group or "?", what, err)
        end
        for _, key in ipairs(reads) do
          if type(key) == "number" and key > replyBytes then
            pastReply[#pastReply + 1] = string.format("%s (%s) reads byte %d of a %d byte reply",
              field.key or field.group or "?", what, key, replyBytes)
          end
        end
      end
    end
  end
  gateCheck("no field criterion or label reads a byte the reply does not carry",
    #pastReply == 0 and #raised == 0,
    table.concat(pastReply, "; ") .. table.concat(raised, "; "))

  -- Gate 2: the decision itself, so putting the row back is a deliberate change.
  local ledRows = {}
  for i = 1, #fields do
    local field = fields[i]
    local label = field.label
    if type(label) == "function" then
      local probe = select(1, probeFor(decoded))
      local ok, text = pcall(label, probe)
      label = ok and text or nil
    end
    local key = tostring(field.key or "")
    local text = tostring(label or "")
    if key == "led_control" or key:lower():find("led") or text:lower():find("led") then
      ledRows[#ledRows + 1] = string.format("%s / %s", key, text)
    end
  end
  gateCheck("the Bluejay page declares no LED Control row", #ledRows == 0,
    table.concat(ledRows, "; "))

  -- Gate 3: and the codec no longer answers a question it cannot answer.
  gateCheck("the codec exports no LED capability function",
    codec.supportsLedControl == nil and codec.FIELD_META.led_control == nil,
    string.format("supportsLedControl %s, FIELD_META.led_control %s",
      tostring(codec.supportsLedControl), tostring(codec.FIELD_META and codec.FIELD_META.led_control)))

  -- Byte 43 is the byte the rename touched, over every value it can carry. Three
  -- examples are enough to read; the count is the rest.
  local drifted, others = {}, 0
  local function drift(text)
    if #drifted < 3 then drifted[#drifted + 1] = text else others = others + 1 end
  end
  for value = 0, 255 do
    local block = blockOf(fixture)
    block[43] = value
    local payload = codec._encode(codec._decode(block))
    if type(payload) ~= "table" then
      drift(string.format("byte 43 = %d: encode() refused", value))
    elseif #payload ~= replyBytes then
      drift(string.format("byte 43 = %d: wrote %d bytes, expected %d",
        value, #payload, replyBytes))
    elseif payload[43] ~= value then
      drift(string.format("byte 43 = %d came back as %s", value, tostring(payload[43])))
    end
  end
  check("an untouched save writes all 66 bytes and byte 43 back unchanged",
    #drifted == 0, table.concat(drifted, "; ") .. (others > 0 and string.format("; and %d more", others) or ""))

  -- And the layout still covers every position exactly once.
  local gaps, duplicates = {}, {}
  for position = 1, replyBytes do
    if owner[position] == "" then
      gaps[#gaps + 1] = tostring(position)
    elseif owner[position]:find("+") then
      duplicates[#duplicates + 1] = string.format("%d -> %s", position, owner[position])
    end
  end
  check("every one of the 66 positions has exactly one owning field",
    #gaps == 0 and #duplicates == 0,
    "no owner: " .. table.concat(gaps, ",") .. "; more than one: " .. table.concat(duplicates, ","))
  check("byte 43 is the Bluejay LED byte, carried as reserved_28",
    owner[43] == "reserved_28", "byte 43 belongs to " .. tostring(owner[43]))
end

runChecks()
local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the pre-fix row and the pre-fix criterion
-- ---------------------------------------------------------------------------

-- The pre-fix page row, verbatim.
local PAGE_ROW = '  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.ledcontrol)@", key = "led_control", enabledWhen = function(data) return msp.supportsLedControl(data) end},'

-- The pre-fix criterion, verbatim, and the FIELD_META entry it needed.
local CODEC_HUNKS = {
  -- The choice list the row needed, and the metadata entry that pointed at it.
  ['local POWER_RATING = {{"1S", 1}, {"2S+", 2}}'] = table.concat({
    'local LED_CONTROL = {',
    '  {"Off", 0x00}, {"Blue", 0x03}, {"Green", 0x0c}, {"Red", 0x30},',
    '  {"Cyan", 0x0f}, {"Magenta", 0x33}, {"Yellow", 0x3c}, {"White", 0x3f},',
    '}',
    'local POWER_RATING = {{"1S", 1}, {"2S+", 2}}',
  }, "\n"),
  ['  braking_strength = {min = 0, max = 255},'] = table.concat({
    '  braking_strength = {min = 0, max = 255},',
    '  led_control = {choices = LED_CONTROL},',
  }, "\n"),
  -- The reserved_28 line is the anchor, not the brake_on_stop line before it:
-- anchoring one line earlier would ADD a field instead of renaming it, and the
-- "pre-fix" codec would then write 67 bytes -- a splice that differs from the
-- pre-fix code in a way the payload checks below report as a defect that #2453
-- never had. The 66-byte write is required of the splice for that reason.
  ['  {"reserved_28", "u8"},'] = '  {"led_control", "u8"},',
  ['local function choicesFor(data, key)'] = table.concat({
    'local function supportsLedControl(data)',
    '  local raw = data and data._raw',
    '  local prefix = raw and raw[67]',
    '  return prefix == string.byte("E") or prefix == string.byte("J") or prefix == string.byte("M")',
    '    or prefix == string.byte("Q") or prefix == string.byte("U")',
    'end',
    '',
    'local function choicesFor(data, key)',
  }, "\n"),
  ['function msp.choicesFor(data, key)'] = table.concat({
    'function msp.supportsLedControl(data)',
    '  return supportsLedControl(data)',
    'end',
    '',
    'function msp.choicesFor(data, key)',
  }, "\n"),
}

local function newlineOf(text)
  return text:find("\r\n", 1, true) and "\r\n" or "\n"
end

local function splicePage(original)
  local nl = newlineOf(original)
  local needle = '  {label = brakingStrengthLabel, key = "braking_strength", enabledWhen = atLeast(202)},'
  needle = needle:gsub("\n", nl)
  local at = original:find(needle, 1, true)
  if not at then return nil, "the braking_strength row is not where the pre-fix row followed it" end
  local spliced = original:sub(1, at + #needle - 1) .. nl .. (PAGE_ROW:gsub("\n", nl))
    .. original:sub(at + #needle)
  return spliced
end

local function spliceCodec(original)
  local nl = newlineOf(original)
  local text = original
  for needle, replacement in pairs(CODEC_HUNKS) do
    local from = needle:gsub("\n", nl)
    local to = replacement:gsub("\n", nl)
    local at = text:find(from, 1, true)
    if not at then
      return nil, string.format("no anchor for %q", from)
    end
    text = text:sub(1, at - 1) .. to .. text:sub(at + #from)
  end
  return text
end

-- A splice only stands in for the pre-fix code if it is a different file, reads
-- back from disk as written, loads, and then shows the behaviour it claims to
-- restore. Each of those is checked here rather than assumed.
local function verifySplice(label, original, spliced, file, looksPreFix, why)
  local problems = {}
  if not spliced then
    problems[#problems + 1] = "could not be built"
  else
    if spliced == original then problems[#problems + 1] = "the splice changed nothing" end
    if spliced and not spliced:find("led_control", 1, true) then
      problems[#problems + 1] = "does not mention led_control"
    end
    local tmp = spliced and writeTmp(spliced) or nil
    if tmp then
      if readFile(tmp) ~= spliced then
        problems[#problems + 1] = "does not read back as written"
      end
-- The codec guards itself at the top of its own body and hands back whatever
      -- is under its key without reading the file it was handed, so the key has to
      -- be clear BEFORE the load: a splice loaded while the real one is still
      -- memoized loads the real one and passes for the pre-fix code. Same reason
      -- for the page, whose requireModule() would otherwise find the real codec.
      package.loaded[CODEC_KEY] = nil
      local ok, module = pcall(assert(realLoadfile(tmp)))
      package.loaded[CODEC_KEY] = nil
      if not ok then
        problems[#problems + 1] = "does not load: " .. tostring(module):gsub(".*%.lua:%d+: ", "")
      else
        local recognised, detail = looksPreFix(module)
        if not recognised then problems[#problems + 1] = detail end
      end
    end
    return #problems == 0, table.concat(problems, "; ")
  end
  return false, table.concat(problems, "; ") .. why
end

-- What the pre-fix codec has to show: the capability function back, and false for
-- every reply it could be handed -- a criterion that reads past the block cannot
-- say yes to anything.
local function looksPreFixCodec(codec)
  if type(codec.supportsLedControl) ~= "function" then
    return false, "exports no supportsLedControl, so this is not the pre-fix codec"
  end
  if codec.FIELD_META.led_control == nil then
    return false, "carries no led_control metadata, so this is not the pre-fix codec"
  end
  -- Same 66 bytes as the shipped codec. A splice that got the layout wrong would
  -- otherwise pass as the pre-fix code and then fail the payload checks for a
  -- reason that has nothing to do with this issue.
  local payload = codec._encode(codec._decode(blockOf(codec._simulatorResponse)))
  if type(payload) ~= "table" or #payload ~= #codec._simulatorResponse then
    return false, string.format("writes %s bytes, the pre-fix codec writes %d",
      type(payload) == "table" and tostring(#payload) or "no", #codec._simulatorResponse)
  end
  for position = 1, #codec._simulatorResponse do
    for _, value in ipairs({string.byte("E"), string.byte("J"), string.byte("M"),
                            string.byte("Q"), string.byte("U"), 0, 200}) do
      local block = {}
      for i = 1, #codec._simulatorResponse do block[i] = codec._simulatorResponse[i] end
      block[position] = value
      if codec.supportsLedControl(codec._decode(block)) == true then
        return false, string.format(
          "says yes to a reply whose byte %d is %d, so this is not the pre-fix criterion",
          position, value)
      end
    end
  end
  return true
end

-- What the pre-fix page has to show: the row back, with the criterion on it, and
-- that criterion unable to say yes. Driven through open() rather than read off the
-- module, because the fields are what open() hands on.
local function looksPreFixPage(page)
  local ok, fields = pcall(captureFields, page)
  if not ok then return false, "does not reach the shared editor: " .. tostring(fields) end
  if type(fields) ~= "table" then return false, "no fields were captured" end
  for i = 1, #fields do
    if fields[i].key == "led_control" then
      if type(fields[i].enabledWhen) ~= "function" then
        return false, "the led_control row came back without its criterion"
      end
      local block = {}
      for j = 1, 66 do block[j] = 0 end
      block[1] = 193
      if fields[i].enabledWhen({_raw = block, layout_revision = 0}) == true then
        return false, "the led_control criterion says yes, so this is not the pre-fix page"
      end
      return true
    end
  end
  return false, "declares no led_control row, so this is not the pre-fix page"
end

if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the LED row checks must go red on the pre-fix page and codec")
  out(string.rep("=", 72))

  local originalPage = readFile(PAGE_SRC)
  local originalCodec = readFile(CODEC_SRC)
  local sabotagedPage = splicePage(originalPage)
  local sabotagedCodec = spliceCodec(originalCodec)

  local pageFile = writeTmp(sabotagedPage or "")
  local codecFile = writeTmp(sabotagedCodec or "")
  REDIRECTS = {
    {match = "msp_esc_parameters_bluejay%.lua$", file = codecFile},
    {match = "esc_forward_bluejay%.lua$", file = pageFile},
  }

  -- Proved before either is allowed to stand in for the pre-fix code. Loading the
  -- page splice needs its own codec in place, so the codec splice is verified first.
  local codecOk, codecDetail = verifySplice("codec", originalCodec, sabotagedCodec,
    codecFile, looksPreFixCodec)
  out(string.format("  %s  codec splice: %s", codecOk and "ok   " or "FAIL ",
    codecDetail ~= "" and codecDetail
      or "different file, reads back, loads, writes 66 bytes, and answers no reply with yes"))
  if not codecOk then os.exit(1) end

  local pageOk, pageDetail = verifySplice("page", originalPage, sabotagedPage,
    pageFile, looksPreFixPage)
  out(string.format("  %s  page splice: %s", pageOk and "ok   " or "FAIL ",
    pageDetail ~= "" and pageDetail
      or "different file, reads back, loads, and declares the unreachable row again"))
  if not pageOk then os.exit(1) end

  checks, failures = 0, 0
  failedLabels = {}
  local pass1Gates = {}
  for i = 1, #MUST_GO_RED do
    pass1Gates[MUST_GO_RED[i]] = (pass1Gates[MUST_GO_RED[i]] or 0) + 1
  end
  MUST_GO_RED = {}

  out("")
  out("pass 2: the same cases against the pre-fix page and codec")
  runChecks()

  local totalHits, served = 0, {}
  for i = 1, #REDIRECTS do
    totalHits = totalHits + (REDIRECTS[i].hits or 0)
    served[#served + 1] = string.format("%s %d", REDIRECTS[i].match, REDIRECTS[i].hits or 0)
  end
  out("")
  out(string.format("  (sabotaged files served %d time(s): %s)", totalHits, table.concat(served, ", ")))
  if totalHits == 0 then
    out("  FAIL  the sabotaged files never ran -- pass 2 proved nothing")
    os.exit(1)
  end

  -- Both passes have to have registered the same gates, or a case runs on one tree
  -- and not the other and the verdict compares two different files.
  local pass2Gates = {}
  for i = 1, #MUST_GO_RED do pass2Gates[MUST_GO_RED[i]] = (pass2Gates[MUST_GO_RED[i]] or 0) + 1 end
  local drift = {}
  for label, n in pairs(pass1Gates) do
    if pass2Gates[label] == nil then
      drift[#drift + 1] = "only in pass 1: " .. label
    elseif pass2Gates[label] ~= n then
      drift[#drift + 1] = string.format("registered %d times in pass 1 and %d in pass 2: %s",
        n, pass2Gates[label], label)
    end
  end
  for label in pairs(pass2Gates) do
    if pass1Gates[label] == nil then drift[#drift + 1] = "only in pass 2: " .. label end
  end
  if #drift > 0 then
    out("  FAIL  the two passes did not register the same gates:")
    for i = 1, #drift do out("        " .. drift[i]) end
    os.exit(1)
  end
  out(string.format("  both passes registered the same %d gates", #MUST_GO_RED))

  os.remove(pageFile)
  os.remove(codecFile)
  REDIRECTS = {}

  out("")
  out("self-test verdict:")
  local stayedGreen = {}
  for _, label in ipairs(MUST_GO_RED) do
    local red = failedLabels[label] == true
    out(string.format("  %s  %s", red and "goes red " or "STAYS GREEN", label))
    if not red then stayedGreen[#stayedGreen + 1] = label end
  end
  out("")
  if #stayedGreen > 0 then
    out(string.format(
      "SELF-TEST FAILED -- %d of %d checks cannot see the unreachable LED row", #stayedGreen, #MUST_GO_RED))
    os.exit(1)
  end
  out(string.format(
    "SELF-TEST PASSED -- all %d checks go red with the pre-fix row and criterion back",
    #MUST_GO_RED))
  out(string.format("pass 1 against the real tree: %d checks, %d failures",
    pass1Checks, pass1Failures))
end

-- The verdict below is pass 1's: without --self-test pass 2 never ran, and with it
-- pass 2's red is the expected outcome rather than a failure here.
checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 72))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end