-- Behaviour check for #2704: the throttle range set over the ESC link (lib/esc_params.lua).
--
-- Run it (from the repository root):
--     lua5.4 bin/esc_range_link/verify_esc_range_link.lua
--     lua5.4 bin/esc_range_link/verify_esc_range_link.lua --self-test
--
-- What it drives: the real lib/esc_params.lua, with a stand-in codec and a simulated ESC behind the
-- send function. The ESC keeps a block; writes change it, reads return a copy, and the stand-in can
-- make the ESC fail a read or a write, or refuse a write without saying so.
--
-- It pins:
--   1. the range the ESC accepts: a 0 % pulse of 900..1900 us and a span of 600..1500 us, and a
--      range that does not start above 1000 us or ends below its start is refused;
--   2. a write is read back and compared: the ESC holds the values only when the read matches;
--   3. a failed read, a failed write, a write refused without a reply, and a write without a read
--      each end with its reason, and leave no block behind;
--   4. a family is known only for the YGE telemetry protocol.
--
-- --self-test drops the read-back from the write and requires the silent refusal to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local LIB = ROOT .. "/src/rfsuite/lib/"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

-- A simulated ESC with the codec's message shape.
local function simulatedEsc()
  local esc = {
    block = {esc_signature = 165, governor = 0, stick_zero_us = 1100, stick_range_us = 800},
    failRead = false, failWrite = false, refuseWrites = false,
  }
  local codec = {}
  function codec.buildReadMessage(onData, onError)
    return {kind = "read", onData = onData, onError = onError}
  end
  function codec.buildWriteMessage(data, onWritten, onError)
    return {kind = "write", data = data, onWritten = onWritten, onError = onError}
  end
  local function send(msg)
    if msg.kind == "read" then
      if esc.failRead then msg.onError(); return end
      local copy = {}
      for k, v in pairs(esc.block) do copy[k] = v end
      msg.onData(copy)
    elseif msg.kind == "write" then
      if esc.failWrite then msg.onError(); return end
      if not esc.refuseWrites then
        for k, v in pairs(msg.data) do esc.block[k] = v end
      end
      msg.onWritten()
    end
  end
  return esc, codec, send
end

local function loadLib(source)
  local chunk = assert(load(source, "@esc_params.lua", "t"))
  return chunk()
end

-- Runs the transaction checks against a given esc_params source.
local function run(paramsSource)
  local before = failures
  local params = loadLib(paramsSource)

  -- 1. The range the ESC accepts.
  local family = params.familyFor(9)
  check("YGE is the family for protocol 9", family ~= nil and family.name == "YGE")
  check("no family for an unknown protocol", params.familyFor(77) == nil)
  local ok = params.rangeChanges(family, 1020, 1980)
  check("a 1020..1980 us range becomes stick_zero 1020, stick_range 960",
    ok ~= nil and ok.stick_zero_us == 1020 and ok.stick_range_us == 960)
  local _, why = params.rangeChanges(family, 1000, 1980)
  check("a range starting at 1000 us is refused", why == "invalid", "reason=" .. tostring(why))
  _, why = params.rangeChanges(family, 1500, 1400)
  check("a range ending below its start is refused", why == "invalid", "reason=" .. tostring(why))
  _, why = params.rangeChanges(family, 1950, 2100)
  check("a zero point above the ESC's range is refused", why == "out_of_range", "reason=" .. tostring(why))
  _, why = params.rangeChanges(family, 1020, 1200)
  check("a span below the ESC's range is refused", why == "out_of_range", "reason=" .. tostring(why))
  _, why = params.rangeChanges(nil, 1020, 1980)
  check("no family means no range", why == "no_range")

  -- 2. A write is read back and compared.
  local esc, codec, send = simulatedEsc()
  local tx = params.new(codec, send)
  local readBlock
  tx:read(function(block) readBlock = block end)
  check("a read returns the ESC block", readBlock ~= nil and readBlock.stick_zero_us == 1100)
  local changes = {stick_zero_us = 1020, stick_range_us = 960}
  local wrote, reason
  tx:write(changes, function(block, err) wrote, reason = block, err end)
  check("a write the ESC keeps is confirmed by the read-back", wrote ~= nil and reason == nil,
    "reason=" .. tostring(reason))
  check("the ESC holds the written values", esc.block.stick_zero_us == 1020 and esc.block.stick_range_us == 960)

  -- 2b. The block is read again before the write: a change the ESC got since the first read is kept,
  -- and an ESC that does not answer the re-read gets nothing written.
  local esc5, codec5, send5 = simulatedEsc()
  local tx5 = params.new(codec5, send5)
  tx5:read(function() end)
  esc5.block.governor = 3
  local kept
  tx5:write(changes, function(block) kept = block end)
  check("a change made since the first read is kept", kept ~= nil and esc5.block.governor == 3
    and esc5.block.stick_zero_us == 1020, "governor=" .. tostring(esc5.block.governor))

  local esc6, codec6, send6 = simulatedEsc()
  local tx6 = params.new(codec6, send6)
  tx6:read(function() end)
  esc6.failRead = true
  local reason6
  tx6:write(changes, function(_, err) reason6 = err end)
  check("an ESC that does not answer the re-read gets nothing written",
    reason6 == "read" and esc6.block.stick_zero_us == 1100, "reason=" .. tostring(reason6))

  -- 3. Failures end with a reason and leave no block behind.
  local esc2, codec2, send2 = simulatedEsc()
  local tx2 = params.new(codec2, send2)
  local got, err2 = "unset", nil
  tx2:write(changes, function(block, e) got, err2 = block, e end)
  check("a write before a read is refused", got == nil and err2 == "esc_not_read", "reason=" .. tostring(err2))

  esc2.failRead = true
  local r2, e2 = "unset", nil
  tx2:read(function(block, e) r2, e2 = block, e end)
  check("a failed read ends with its reason", r2 == nil and e2 == "read", "reason=" .. tostring(e2))
  esc2.failRead = false

  local esc3, codec3, send3 = simulatedEsc()
  local tx3 = params.new(codec3, send3)
  tx3:read(function() end)
  esc3.failWrite = true
  local g3, e3 = "unset", nil
  tx3:write(changes, function(block, e) g3, e3 = block, e end)
  check("a failed write ends with its reason", g3 == nil and e3 == "write", "reason=" .. tostring(e3))

  local esc4, codec4, send4 = simulatedEsc()
  local tx4 = params.new(codec4, send4)
  tx4:read(function() end)
  esc4.refuseWrites = true
  local g4, e4 = "unset", nil
  tx4:write(changes, function(block, e) g4, e4 = block, e end)
  check("a write the ESC silently keeps old values for is reported as a mismatch",
    g4 ~= nil and e4 == "mismatch", "block=" .. tostring(g4) .. " reason=" .. tostring(e4))

  return failures - before
end

local paramsSource = readFile(LIB .. "esc_params.lua")

if not SELF_TEST then
  local n = run(paramsSource)
  if n == 0 then
    print("OK  ESC range over the link: accepted range, read-back, and failure reasons (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- Two broken copies: no re-read before the write (the cached block is sent, which can overwrite a change
-- made since), and no read-back after the write (a write counts as done as soon as it is acknowledged).
local mutants = {
  {name = "no re-read before the write", patterns = {
    {"    self:read%(function%(fresh, err%)\n", "    local fresh, err = self.block, nil\n    do\n"},
    {"    end%)\n    return true\n", "    end\n    return true\n"},
  }},
  {name = "no read-back after the write", patterns = {
    {"        self:verify%(changes, after%)\n      end, function%(%)",
     "        after(data)\n      end, function()"},
  }},
}
local red = 0
for _, m in ipairs(mutants) do
  local text, ok = paramsSource, true
  for _, p in ipairs(m.patterns) do
    local t, c = text:gsub(p[1], (p[2]:gsub("%%", "%%%%")))
    if c ~= 1 then ok = false end
    text = t
  end
  if not ok then
    print("FAIL  self-test: the lines for '" .. m.name .. "' were not found once; update this harness")
    os.exit(1)
  end
  failures, checks = 0, 0
  local caught = run(text)
  if caught > 0 then
    red = red + 1
    print("ok    mutant red: " .. m.name .. " (" .. caught .. " failed checks)")
  else
    print("FAIL  mutant passed the checks: " .. m.name)
  end
end
if red == #mutants then
  print("OK  self-test: both broken copies go red")
  os.exit(0)
end
os.exit(1)
