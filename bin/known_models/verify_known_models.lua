-- Behaviour check for Issue #2323: the radio remembers what each flight controller is called,
-- and can list the controllers it knows with no link up.
--
-- Run it:
--     lua5.4 bin/known_models/verify_known_models.lua
--     lua5.4 bin/known_models/verify_known_models.lua --self-test
--
-- The claim: while a flight controller is connected, tasks/session.lua writes its name next
-- to its preferences (lib/model_preferences.lua, `[craft] name`), and lib/known_models.lua
-- lists every store on the card -- id, name, path, last write -- without a connection.
--
-- What is driven, and why it is not a fixture:
--   * The real lib/ini.lua, lib/atomic_write.lua, lib/model_preferences.lua,
--     lib/known_models.lua and tasks/session.lua. Only the world around them is faked: an
--     in-memory card that behaves the way Ethos does where it matters here (a write needs
--     its directory to exist; io.read(file, "L") takes the handle first; system.listFiles
--     answers nil for a missing directory and carries ".." and sub-directories).
--   * system.listFiles and os.stat were measured on the Ethos 26.1.3 simulator (X20PRO_EU)
--     rather than assumed: listFiles returns an array of names with "..", files and
--     directories, nil for a directory that is not there; os.stat().mtime is a table of
--     year..second. The fake answers in the same shapes. The fake lists in DESCENDING order
--     on purpose, so that a module that relies on the listing's own order shows it.
--   * The session is driven through its own handshake: the API-version verdict is answered,
--     then the UID and NAME replies are delivered in BOTH orders, because the two reads
--     are independent and either may come first.
--
-- Which checks are gates, and how --self-test proves it:
--   Each gate goes red when one named piece of the change is taken out, and --self-test
--   takes each out in turn and requires exactly that gate to fail:
--     quoting          the name is written bare               -> "names survive a save and a load"
--     uid-hook         session.lua does not record on UID     -> "NAME then UID"
--     name-hook        session.lua does not record on NAME    -> "UID then NAME"
--     craft-save-hook  session.lua ignores craft.name.saved   -> "craft.name.saved updates the store"
--     sort             the id sort is removed                 -> "listed in id order"
--     filter           the ".ini" end anchor is removed       -> "only stores are listed"
--   The other checks are controls: they pin behaviour that has to survive a change here.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"

local realOpen = io.open
local realRead = io.read
local realClose = io.close
local realOsRename, realOsRemove = os.rename, os.remove
local realClock = os.clock

local function readReal(path)
  local f = assert(realOpen(path, "rb"))
  local data = f:read("a")
  f:close()
  -- A checkout with core.autocrlf=true carries CRLF; the self-test's search strings do not.
  return (data:gsub("\r\n", "\n"))
end

-- ---------------------------------------------------------------------------
-- The card. Strings are whole paths with the Ethos prefix kept ("SCRIPTS:/...").
-- ---------------------------------------------------------------------------
local FS

local function resetFs()
  FS = { files = {}, dirs = { ["SCRIPTS:"] = true }, mtime = {}, tick = 0, commits = {} }
end

local function touch(path)
  FS.tick = FS.tick + 1
  FS.mtime[path] = {
    year = 2026, month = 10, day = 9, hour = 12,
    minute = (FS.tick // 60) % 60, second = FS.tick % 60,
  }
end

local function parentOf(path) return path:match("^(.*)/[^/]*$") end

local function newHandle(path, mode, content)
  local h = { __fs = true, path = path, mode = mode, pos = 1, content = content or "", buf = {} }
  function h:write(...)
    for _, v in ipairs({ ... }) do self.buf[#self.buf + 1] = tostring(v) end
    return self
  end
  function h:flush() end
  function h:seek() self.pos = 1 end
  function h:read(fmt)
    if fmt == "a" or fmt == "*a" then
      local rest = self.content:sub(self.pos)
      self.pos = #self.content + 1
      return rest
    end
    return nil
  end
  function h:readLine()
    if self.pos > #self.content then return nil end
    local stop = self.content:find("\n", self.pos, true)
    local line
    if stop then
      line = self.content:sub(self.pos, stop)
      self.pos = stop + 1
    else
      line = self.content:sub(self.pos)
      self.pos = #self.content + 1
    end
    return line
  end
  function h:close()
    if self.closed then return true end
    self.closed = true
    if self.mode:find("w", 1, true) then
      FS.files[self.path] = table.concat(self.buf)
      touch(self.path)
    end
    return true
  end
  return h
end

io.open = function(path, mode)
  mode = mode or "r"
  if mode:find("w", 1, true) then
    if not FS.dirs[parentOf(path)] then return nil end
    FS.files[path] = ""
    touch(path)
    return newHandle(path, mode)
  end
  local content = FS.files[path]
  if content == nil then return nil end
  return newHandle(path, mode, content)
end

-- Ethos spells these io.read(file, "L") and io.close(file); stock Lua has no such form.
io.read = function(h, fmt)
  if type(h) == "table" and h.__fs then return h:readLine(fmt) end
  return realRead(h, fmt)
end
io.close = function(h)
  if type(h) == "table" and h.__fs then return h:close() end
  return realClose(h)
end

os.mkdir = function(path)
  if FS.dirs[parentOf(path)] then FS.dirs[path] = true; return true end
  return nil
end
os.rename = function(from, to)
  if FS.files[from] == nil then return nil end
  FS.files[to] = FS.files[from]
  FS.mtime[to] = FS.mtime[from]
  FS.files[from], FS.mtime[from] = nil, nil
  FS.commits[to] = (FS.commits[to] or 0) + 1
  return true
end
os.remove = function(path)
  if FS.files[path] == nil then return nil end
  FS.files[path], FS.mtime[path] = nil, nil
  return true
end
os.stat = function(path)
  if FS.files[path] ~= nil then return { mode = 0, size = #FS.files[path], mtime = FS.mtime[path] } end
  if FS.dirs[path] then return { mode = 16, size = 0, mtime = FS.mtime[path] or {} } end
  return nil
end

local function fakeListFiles(dir)
  dir = dir:gsub("/+$", "")
  if not FS.dirs[dir] then return nil end
  local names = { [".."] = true }
  for path in pairs(FS.files) do
    if parentOf(path) == dir then names[path:match("([^/]*)$")] = true end
  end
  for path in pairs(FS.dirs) do
    if parentOf(path) == dir then names[path:match("([^/]*)$")] = true end
  end
  local out = {}
  for name in pairs(names) do out[#out + 1] = name end
  table.sort(out, function(a, b) return a > b end) -- descending, see the header
  return out
end

local function snapshotCard()
  local keys = {}
  for path, content in pairs(FS.files) do
    local m = FS.mtime[path]
    keys[#keys + 1] = path .. "\0" .. content .. "\0" .. (m and (m.minute .. ":" .. m.second) or "")
  end
  table.sort(keys)
  return table.concat(keys, "\1")
end

-- ---------------------------------------------------------------------------
-- Checks
-- ---------------------------------------------------------------------------
local results = {}
local failures, checks = 0, 0
local quiet = false

local function check(label, ok, detail)
  checks = checks + 1
  results[label] = ok and true or false
  if not ok then failures = failures + 1 end
  if quiet then return end
  if ok then
    print(string.format("  ok    %s", label))
  else
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

-- ---------------------------------------------------------------------------
-- A world with the real library modules, optionally with one piece taken out.
-- ---------------------------------------------------------------------------
local function replaceOnce(text, find, with, what)
  local from, to = text:find(find, 1, true)
  assert(from, "self-test mutation did not apply: " .. what)
  return text:sub(1, from - 1) .. with .. text:sub(to + 1)
end

local MUTATIONS = {
  quoting = {
    gate = "names survive a save and a load, whatever they look like",
    ["lib/model_preferences.lua"] = function(t)
      return replaceOnce(t, [['"' .. disk.craft.name .. '"']], "disk.craft.name", "quoting")
    end,
  },
  ["uid-hook"] = {
    gate = "a name recorded when the NAME reply comes first, then the UID",
    ["tasks/session.lua"] = function(t)
      return replaceOnce(t, "loadModelPreferences()\n      recordCraftName()\n",
        "loadModelPreferences()\n", "uid-hook")
    end,
  },
  ["name-hook"] = {
    gate = "a name recorded when the UID reply comes first, then the NAME",
    ["tasks/session.lua"] = function(t)
      return replaceOnce(t, "session.craftName = name\n      recordCraftName()\n",
        "session.craftName = name\n", "name-hook")
    end,
  },
  ["craft-save-hook"] = {
    gate = "a rename via craft.name.saved updates the store immediately while connected",
    ["tasks/session.lua"] = function(t)
      return replaceOnce(t, "bus.subscribe(\"craft.name.saved\", onCraftNameSaved)\n",
        "-- bus.subscribe(\"craft.name.saved\", onCraftNameSaved)\n", "craft-save-hook")
    end,
  },
  sort = {
    gate = "stores are listed in id order, not in the card's order",
    ["lib/known_models.lua"] = function(t)
      return replaceOnce(t, "  table.sort(ids)\n", "", "sort")
    end,
  },
  filter = {
    gate = "only stores are listed, not the temp file, the folder or the note",
    ["lib/known_models.lua"] = function(t)
      return replaceOnce(t, [[files[i]:match("^(.+)%.ini$")]], [[files[i]:match("^(.+)%.ini")]], "filter")
    end,
  },
}

local LIB = {
  ["lib/ini.lua"] = true, ["lib/atomic_write.lua"] = true, ["lib/table_clone.lua"] = true,
  ["lib/model_preferences.lua"] = true, ["lib/known_models.lua"] = true,
}

local function loadWorld(mut)
  for key in pairs(package.loaded) do
    if type(key) == "string" and key:match("^rfsuite%.") then package.loaded[key] = nil end
  end
  local cache = {}
  local function shim(name)
    if cache[name] ~= nil then return cache[name] end
    assert(LIB[name], "unexpected dependency in the library world: " .. tostring(name))
    local text = readReal(SRC .. "/" .. name)
    if mut and mut[name] then text = mut[name](text) end
    local chunk = assert(load(text, "@" .. SRC .. "/" .. name))
    local mod = chunk()
    cache[name] = mod
    return mod
  end
  package.loaded["rfsuite.lib.require"] = shim
  return {
    modelPreferences = shim("lib/model_preferences.lua"),
    knownModels = shim("lib/known_models.lua"),
    ini = shim("lib/ini.lua"),
  }
end

-- ---------------------------------------------------------------------------
-- Parts 1 and 2: the stored name, and the listing
-- ---------------------------------------------------------------------------
local MODELS = "SCRIPTS:/rfsuite.user/models"

-- The name held in memory, nil where none has been recorded. The suite reads it from the
-- prefs table directly, so the harness does too.
local function nameOf(prefs)
  local name = prefs.craft and prefs.craft.name
  if name ~= nil and name ~= "" then return name end
  return nil
end

local function partLibrary(mut)
  resetFs()
  local w = loadWorld(mut)
  local mp, km = w.modelPreferences, w.knownModels
  system = { listFiles = fakeListFiles }

  -- 1. A name goes through lib/ini.lua, which reads "007", "0x10", "1e3" back as numbers and
  --    "true" as a boolean. It has to come back as what was written.
  local cases = {
    { "SAB Goblin RAW 700", "SAB Goblin RAW 700" },
    { "007", "007" },
    { "0x10", "0x10" },
    { "1e3", "1e3" },
    { "6.50", "6.50" },
    { "true", "true" },
    { "false", "false" },
    { 'say "hi"', 'say "hi"' },
    { '"quoted"', '"quoted"' },
    { "a=b", "a=b" },
    { "[craft]", "[craft]" },
    { "x;y", "x;y" },
    { "  padded  ", "padded" },
    { "tab\there", "tabhere" },
    { string.rep("n", 40), string.rep("n", 32) },
  }
  local bad = {}
  for i, c in ipairs(cases) do
    local id = "ROUND" .. i
    local prefs, path = mp.load(id)
    prefs = mp.setCraftName(prefs, c[1])
    mp.save(path, prefs)
    local again = mp.load(id)
    local got = nameOf(again)
    if got ~= c[2] then bad[#bad + 1] = string.format("%q -> %q (wanted %q)", c[1], tostring(got), c[2]) end
  end
  check("names survive a save and a load, whatever they look like", #bad == 0, table.concat(bad, "; "))

  -- 2. setCraftName reports a change only when there is one.
  do
    local prefs = mp.withDefaults({})
    local named, changed = mp.setCraftName(prefs, "Goblin")
    check("a new name is a change", changed == true and nameOf(named) == "Goblin")
    local _, again = mp.setCraftName(named, "Goblin")
    check("the same name is not a change", again == false)
    local kept, e1 = mp.setCraftName(named, "")
    local kept2, e2 = mp.setCraftName(named, nil)
    check("an empty name never replaces a stored one",
      e1 == false and e2 == false and nameOf(kept) == "Goblin" and nameOf(kept2) == "Goblin")
    local renamed, e3 = mp.setCraftName(named, "Goblin 2")
    check("a different name replaces it", e3 == true and nameOf(renamed) == "Goblin 2")
  end

  -- 3. A store written before the name existed.
  resetFs()
  os.mkdir("SCRIPTS:/rfsuite.user")
  os.mkdir(MODELS)
  do
    local f = io.open(MODELS .. "/OLD.ini", "w")
    f:write("[general]\nflightcount=7\n\n")
    f:close()
    local prefs = mp.load("OLD")
    check("a store from before the name loads, with no name and its stats intact",
      nameOf(prefs) == nil and mp.stats(prefs).flightcount == 7)
  end

  -- 4. The listing.
  resetFs()
  os.mkdir("SCRIPTS:/rfsuite.user")
  os.mkdir(MODELS)
  local function put(path, content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
  end
  for _, c in ipairs({ { "heli_b", "Bravo 700" }, { "heli_a", "007" }, { "heli_c", "Charlie" } }) do
    local prefs, path = mp.load(c[1])
    prefs = mp.setCraftName(prefs, c[2])
    mp.save(path, prefs)
  end
  put(MODELS .. "/legacy.ini", "[general]\nflightcount=3\n\n")
  put(MODELS .. "/broken.ini", "\0\0 not an ini [[[ \n===\n")
  put(MODELS .. "/heli_a.ini.tmp", "[craft]\nname=\"half written\"\n")
  put(MODELS .. "/notes.txt", "hello")
  os.mkdir(MODELS .. "/sub")

  local before = snapshotCard()
  local list = km.list()
  local after = snapshotCard()

  local ids = {}
  for i, r in ipairs(list) do ids[i] = r.id end
  check("stores are listed in id order, not in the card's order",
    table.concat(ids, ",") == "broken,heli_a,heli_b,heli_c,legacy", table.concat(ids, ","))
  check("only stores are listed, not the temp file, the folder or the note",
    #list == 5, "listed: " .. table.concat(ids, ","))

  local byId = {}
  for _, r in ipairs(list) do byId[r.id] = r end
  check("a stored name comes back as written, including one that looks like a number",
    byId.heli_a and byId.heli_a.name == "007" and byId.heli_b and byId.heli_b.name == "Bravo 700"
      and byId.heli_c and byId.heli_c.name == "Charlie")
  check("a store with no name, and one that will not parse, are listed with a nil name",
    byId.legacy and byId.legacy.name == nil and byId.broken and byId.broken.name == nil)
  check("each record carries the path of its file",
    byId.heli_b and byId.heli_b.path == MODELS .. "/heli_b.ini")
  local m = byId.heli_b and byId.heli_b.modified
  check("each record carries when its file last changed, as a table",
    type(m) == "table" and m.year == 2026 and m.month == 10 and m.day == 9
      and type(m.minute) == "number" and type(m.second) == "number")
  check("listing writes nothing to the card", before == after)

  -- 5. No directory, no API.
  resetFs()
  check("a card with no models directory lists nothing", #km.list() == 0)
  system = {}
  check("a runtime with no system.listFiles lists nothing", #km.list() == 0)
end

-- ---------------------------------------------------------------------------
-- Part 3: the session, through its own handshake
-- ---------------------------------------------------------------------------
local clock = { now = 100.0 }
os.clock = function()
  clock.now = clock.now + 0.001
  return clock.now
end

local SESSION_PATH = SRC .. "/tasks/session.lua"
local SESSION_REAL = {
  ["lib/mspcodec.lua"] = true, ["lib/msp_api_version.lua"] = true, ["lib/msp_handshake.lua"] = true,
  ["lib/msp_battery.lua"] = true, ["lib/msp_governor_config.lua"] = true, ["lib/msp_rx_map.lua"] = true,
  ["lib/msp_telemetry_config.lua"] = true, ["lib/msp_dataflash_summary.lua"] = true,
  ["lib/msp_flight_stats.lua"] = true, ["lib/msp_eeprom.lua"] = true, ["tasks/flight_timer.lua"] = true,
  ["lib/model_preferences.lua"] = true, ["lib/ini.lua"] = true, ["lib/atomic_write.lua"] = true,
  ["lib/table_clone.lua"] = true,
}

local function newRig(sessionSource)
  for key in pairs(package.loaded) do
    if type(key) == "string" and key:match("^rfsuite%.") then package.loaded[key] = nil end
  end
  local queue = {
    added = {},
    add = function(self, message) self.added[#self.added + 1] = message; return true end,
    clear = function() end,
  }
  local busSubs = {}
  local fakeBus = {}
  fakeBus.publish = function(topic, payload)
    if topic == "session.update" then fakeBus.lastSnapshot = payload end
    for _, handler in ipairs(busSubs[topic] or {}) do handler(payload) end
  end
  fakeBus.subscribe = function(topic, handler)
    busSubs[topic] = busSubs[topic] or {}
    busSubs[topic][#busSubs[topic] + 1] = handler
    return handler
  end
  local modules = {}
  package.loaded["rfsuite.lib.require"] = function(name)
    if SESSION_REAL[name] then
      if modules[name] == nil then modules[name] = assert(loadfile(SRC .. "/" .. name))() end
      return modules[name]
    elseif name == "lib/bus.lua" then
      return fakeBus
    elseif name == "lib/debug_log.lua" then
      return { print = function() end, msp = function() end, format = function() end,
        mspEnabled = function() return false end }
    elseif name == "lib/settings_store.lua" then
      return { load = function() return {} end, simulatedApiVersionMode = function() return false end,
        syncNameEnabled = function() return false end }
    elseif name == "lib/battery_profile_index.lua" then
      return { fromTelemetrySensor = function() return nil end, index0 = function() return nil end }
    elseif name == "lib/smartfuel_reserve.lua" then
      return { applyPercent = function() end }
    elseif name == "lib/smartfuel_calc.lua" or name == "lib/diy_sensor.lua" then
      return { new = function() return { reset = function() end } end }
    end
    return setmetatable({}, { __index = function()
      return function()
        return { command = 0, payload = {}, processReply = function() end, errorHandler = function() end }
      end
    end })
  end

  CATEGORY_SYSTEM_EVENT, TELEMETRY_ACTIVE = 2, 0
  SMARTFUEL_APP_ID, UNIT_PERCENT = 0x1A00, "%"
  local active = true
  system = {
    getVersion = function() return { simulation = false } end,
    getSource = function() return { state = function() return active end } end,
    playFile = function() end,
    playHaptic = function() end,
  }
  model = { name = function() return "Test" end, set = function() end }

  local session = assert(load(sessionSource or readReal(SESSION_PATH), "@" .. SESSION_PATH))()
  session.setTelemetrySensors({ getValue = function() return nil end, reset = function() end })

  local rig = { session = session, queue = queue, bus = fakeBus, handshake = modules["lib/msp_handshake.lua"]
    or assert(loadfile(SRC .. "/lib/msp_handshake.lua"))() }
  function rig.tick() session.wakeup(queue, "sport", nil, { telemetryState = function() return active end }) end
  function rig.find(command)
    for _, message in ipairs(queue.added) do
      if message.command == command then return message end
    end
  end
  return rig
end

-- A new table each time: lib/mspcodec.lua advances a read offset inside the buffer it is
-- given, so a second decode of the same table reads past its end and returns zeros.
local function uidBytes() return { 43, 0, 34, 0, 9, 81, 51, 52, 52, 56, 53, 49 } end

local function toBytes(text)
  local out = {}
  for i = 1, #text do out[i] = text:byte(i) end
  return out
end

-- Connect: answer the API verdict so the identity reads are queued. Returns the rig and the
-- id the UID bytes decode to, taken from the same builder the session uses.
local function connect(sessionSource)
  local rig = newRig(sessionSource)
  local expectedId
  rig.handshake.buildUidReadMessage(function(id) expectedId = id end).processReply(nil, uidBytes())
  rig.tick()
  local api = rig.find(1)
  api.processReply(api, { 0, 12, 9 })
  rig.tick()
  return rig, expectedId
end

local function deliver(rig, command, bytes)
  local message = rig.find(command)
  message.processReply(message, bytes)
end

local function storeOf(id) return FS.files[MODELS .. "/" .. id .. ".ini"] end

local function partSession(sessionSource)
  local UID, NAME = 0x2B + 0, 10 -- NAME_READ_COMMAND is 10; UID is read from the module below
  resetFs()
  do
    local rig, id = connect(sessionSource)
    UID = rig.handshake.UID_READ_COMMAND
    NAME = rig.handshake.NAME_READ_COMMAND
    deliver(rig, UID, uidBytes())
    deliver(rig, NAME, toBytes("Goblin 700"))
    local text = storeOf(id)
    check("a name recorded when the UID reply comes first, then the NAME",
      text ~= nil and text:find('name="Goblin 700"', 1, true) ~= nil,
      "store: " .. tostring(text))
  end

  resetFs()
  do
    local rig, id = connect(sessionSource)
    deliver(rig, NAME, toBytes("Goblin 700"))
    check("the NAME reply alone, with no UID yet, writes no store", storeOf(id) == nil)
    deliver(rig, UID, uidBytes())
    local text = storeOf(id)
    check("a name recorded when the NAME reply comes first, then the UID",
      text ~= nil and text:find('name="Goblin 700"', 1, true) ~= nil,
      "store: " .. tostring(text))
  end

  -- A second connection to the same controller: same name, nothing to write.
  resetFs()
  do
    local rig, id = connect(sessionSource)
    deliver(rig, UID, uidBytes())
    deliver(rig, NAME, toBytes("Goblin 700"))
    local path = MODELS .. "/" .. id .. ".ini"
    local writes = FS.commits[path] or 0
    local again = connect(sessionSource)
    deliver(again, UID, uidBytes())
    deliver(again, NAME, toBytes("Goblin 700"))
    check("reconnecting with the same name rewrites nothing", (FS.commits[path] or 0) == writes,
      "commits " .. writes .. " -> " .. tostring(FS.commits[path]))

    local renamed = connect(sessionSource)
    deliver(renamed, UID, uidBytes())
    deliver(renamed, NAME, toBytes("Goblin 800"))
    local text = storeOf(id)
    check("a controller that was renamed is recorded under the new name, in one write",
      text:find('name="Goblin 800"', 1, true) ~= nil and (FS.commits[path] or 0) == writes + 1,
      "commits " .. tostring(FS.commits[path]))

    local blank = connect(sessionSource)
    deliver(blank, UID, uidBytes())
    deliver(blank, NAME, {})
    check("a controller that answers with no name leaves the recorded one alone",
      storeOf(id):find('name="Goblin 800"', 1, true) ~= nil)

    -- A rename published via craft.name.saved while connected updates session and store
    blank.bus.publish("craft.name.saved", "Goblin 900")
    blank.tick()
    check("a rename via craft.name.saved updates the store immediately while connected",
      blank.bus.lastSnapshot and blank.bus.lastSnapshot.craftName == "Goblin 900"
        and storeOf(id):find('name="Goblin 900"', 1, true) ~= nil,
      "store: " .. tostring(storeOf(id)))

    -- An empty craft.name.saved is ignored
    blank.bus.publish("craft.name.saved", "")
    blank.tick()
    check("an empty craft.name.saved leaves the recorded name alone",
      blank.bus.lastSnapshot and blank.bus.lastSnapshot.craftName == "Goblin 900"
        and storeOf(id):find('name="Goblin 900"', 1, true) ~= nil)
  end

  resetFs()
  do
    local offlineRig = newRig(sessionSource)
    offlineRig.bus.publish("craft.name.saved", "Ignored")
    check("craft.name.saved while disconnected writes no store", storeOf("unknown") == nil)
  end
end

-- ---------------------------------------------------------------------------
local function runAll(mutationName)
  local mut = mutationName and MUTATIONS[mutationName] or nil
  local sessionSource
  if mut and mut["tasks/session.lua"] then sessionSource = mut["tasks/session.lua"](readReal(SESSION_PATH)) end
  partLibrary(mut)
  partSession(sessionSource)
end

if arg and arg[1] == "--self-test" then
  quiet = true
  runAll(nil)
  local baseline = failures
  local bad = baseline == 0
  print(string.format("baseline: %d checks, %d failing", checks, baseline))
  if not bad then print("SELF-TEST FAILED: the unmutated run must be green first"); os.exit(1) end
  local order = { "quoting", "uid-hook", "name-hook", "craft-save-hook", "sort", "filter" }
  local all = true
  for _, name in ipairs(order) do
    results, failures, checks = {}, 0, 0
    runAll(name)
    local gate = MUTATIONS[name].gate
    local red = results[gate] == false
    local others = {}
    for label, ok in pairs(results) do
      if ok == false and label ~= gate then others[#others + 1] = label end
    end
    table.sort(others)
    print(string.format("  %-9s gate %s%s", name, red and "red   " or "NOT RED", red and "" or "  <-- cannot detect it"))
    if #others > 0 then print("            also red: " .. table.concat(others, "; ")) end
    if not red then all = false end
  end
  if not all then print("SELF-TEST FAILED"); os.exit(1) end
  print("self-test ok: every gate goes red when its piece is taken out")
  os.exit(0)
end

runAll(nil)
os.clock = realClock
print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
