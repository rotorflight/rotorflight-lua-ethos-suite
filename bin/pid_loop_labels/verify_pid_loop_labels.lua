-- Behaviour check for the PID loop speed labels on Setup > Configuration (#2648): the four
-- choices are labelled from the board's gyro sample rate, MSP_BOARD_INFO's sampleRateHz,
-- not from a rounded gyro task interval.
--
-- Run it:
--     lua5.4 bin/pid_loop_labels/verify_pid_loop_labels.lua
--     lua5.4 bin/pid_loop_labels/verify_pid_loop_labels.lua --self-test
--
-- Two parts:
--   * lib/msp_board_info.lua reads sampleRateHz from a reply of either layout: the USE_BOARD_INFO
--     layout (with a manufacturer id) and the layout of a build without it (no manufacturer id,
--     one byte shorter). A truncated reply gives no rate.
--   * app/pages/configuration.lua labels the choices from that rate, unrounded, and from the
--     gyro task interval only when the board reports no rate.
--
-- The page runs against a stand-in page runtime that loads the test's data and then runs the
-- page's own onLoaded(). The form records the choice labels.
--
-- Against the unpatched page a 3.2 kHz gyro is labelled 3 kHz, so the page checks fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/configuration.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- ---------------------------------------------------------------------------
-- Part 1: the board info reply.
-- ---------------------------------------------------------------------------
local mspcodec = assert(loadfile(SRC .. "/lib/mspcodec.lua"))()
package.loaded["rfsuite.lib.mspcodec"] = mspcodec
local boardInfo

local cache = {}
local stubRequire
local function requireWith(stubs)
  return function(name)
    if stubs[name] then return stubs[name] end
    if cache[name] == nil then
      cache[name] = assert(loadfile(SRC .. "/" .. name))()
    end
    return cache[name]
  end
end
package.loaded["rfsuite.lib.require"] = requireWith({["lib/mspcodec.lua"] = mspcodec})
boardInfo = assert(loadfile(SRC .. "/lib/msp_board_info.lua"))()

local function bytesOf(text)
  local out = {}
  for i = 1, #text do out[i] = text:byte(i) end
  return out
end

local function append(into, more)
  for _, b in ipairs(more) do into[#into + 1] = b end
  return into
end

local function u16(value)
  return {value & 0xFF, (value >> 8) & 0xFF}
end

-- The 8-byte header, then the target name, the board name and design, and the optional
-- manufacturer id, then the signature, the MCU type, the configuration state, the sample rate,
-- the configuration problems (u32) and the SPI and I2C counts.
local function reply(opts)
  local buf = {82, 70, 76, 84, 0, 0, 0, 0} -- identifier "RFLT", version 0, type 0, caps 0
  append(buf, {3})
  append(buf, bytesOf("ABC"))                  -- target name
  if opts.usesBoardInfo then
    append(buf, {4})
    append(buf, bytesOf("MATE"))              -- board name
    append(buf, {2})
    append(buf, bytesOf("XY"))                -- board design
    append(buf, {4})
    append(buf, bytesOf("MATE"))              -- manufacturer id
  else
    append(buf, {0, 0})                       -- board name and design, both empty
  end
  for _ = 1, 32 do buf[#buf + 1] = 0 end      -- signature
  buf[#buf + 1] = 12                          -- MCU type
  buf[#buf + 1] = 0                           -- configuration state
  append(buf, u16(opts.sampleRateHz or 0))    -- gyro sample rate
  append(buf, {0, 0, 0, 0})                   -- configuration problems
  buf[#buf + 1] = 0                           -- SPI devices
  buf[#buf + 1] = 0                           -- I2C devices
  return buf
end

print("the board info reply")
do
  local full = boardInfo.parse(reply({usesBoardInfo = true, sampleRateHz = 3200}))
  check("the USE_BOARD_INFO layout gives the sample rate (3200 Hz)",
    full ~= nil and full.sampleRateHz == 3200, "rate=" .. tostring(full and full.sampleRateHz))
  check("and the names are still read", full ~= nil and full.targetName == "ABC" and full.boardDesign == "XY",
    "names=" .. tostring(full and full.targetName) .. "/" .. tostring(full and full.boardDesign))

  local fast = boardInfo.parse(reply({usesBoardInfo = true, sampleRateHz = 6660}))
  check("a 6660 Hz gyro reads as 6660 Hz", fast ~= nil and fast.sampleRateHz == 6660,
    "rate=" .. tostring(fast and fast.sampleRateHz))

  local other = boardInfo.parse(reply({usesBoardInfo = false, sampleRateHz = 3200}))
  check("a build without USE_BOARD_INFO gives no rate (its reply is one byte shorter)",
    other ~= nil and other.sampleRateHz == nil and other.targetName == "ABC",
    "rate=" .. tostring(other and other.sampleRateHz))

  local cut = reply({usesBoardInfo = true, sampleRateHz = 3200})
  for _ = 1, 8 do cut[#cut] = nil end
  local truncated = boardInfo.parse(cut)
  check("a reply cut inside the rate gives no rate, and no error",
    truncated ~= nil and truncated.sampleRateHz == nil, "rate=" .. tostring(truncated and truncated.sampleRateHz))

  local grown = reply({usesBoardInfo = true, sampleRateHz = 3200})
  append(grown, {9, 9, 9})
  local later = boardInfo.parse(grown)
  check("a longer reply from a later firmware still gives the rate", later ~= nil and later.sampleRateHz == 3200,
    "rate=" .. tostring(later and later.sampleRateHz))
end

-- ---------------------------------------------------------------------------
-- Part 2: the page's choice labels.
-- ---------------------------------------------------------------------------
local PID_LOOP_LABEL = "@i18n(app.modules.configuration.pid_loop_speed)@"

local runtimeConfig, preparedData, recordedChoices
local pageRuntime = {
  new = function(config)
    runtimeConfig = config
    return setmetatable({controlRef = {}, fields = {}, dataRef = {data = {}}}, {
      __index = {
        buildChrome = function() end,
        registerField = function() end,
        loadInitial = function(self)
          self.dataRef.data = preparedData
          runtimeConfig.onLoaded()
        end,
      },
    })
  end,
}

local lines
form = {
  clear = function() end,
  invalidate = function() end,
  addLine = function(label)
    local line = {label = label}
    lines[#lines + 1] = line
    return line
  end,
  addChoiceField = function(line, _, options, getter, setter)
    if line.label == PID_LOOP_LABEL then recordedChoices = options end
    return {line = line, options = options, enable = function() end}
  end,
  addTextField = function(line) return {line = line, enable = function() end} end,
}

local stubs = {
  ["app/page_runtime.lua"] = pageRuntime,
  ["app/field_layout.lua"] = {buildSingle = function() end},
  ["lib/bus.lua"] = {publish = function() end, subscribe = function() end, unsubscribe = function() end},
  ["lib/msp_board_info.lua"] = boardInfo,
}
package.loaded["rfsuite.lib.require"] = requireWith(stubs)

local function labelsFor(gyroTaskUs, sampleRateHz)
  lines, recordedChoices = {}, nil
  preparedData = {
    status = {task_delta_time_gyro = gyroTaskUs},
    advancedConfig = {pid_process_denom = 1},
    craftName = {name = "Test"},
    featureConfig = {enabledFeatures = 0},
    boardInfo = sampleRateHz and {sampleRateHz = sampleRateHz} or nil,
  }
  local page = dofile(PAGE_PATH)
  page.open({})
  local labels = {}
  for _, option in ipairs(recordedChoices or {}) do labels[#labels + 1] = option[1] end
  return labels
end

local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

print("the PID loop speed labels")
do
  local labels = labelsFor(312, 3200)
  local expected = {"3.2 kHz", "1.6 kHz", "1.07 kHz", "0.8 kHz"}
  check("a 3.2 kHz board is labelled from its rate: 3.2 / 1.6 / 1.07 / 0.8 kHz",
    same(labels, expected), table.concat(labels, " / "))

  local fast = labelsFor(150, 6660)
  check("a 6.66 kHz board is not rounded to 7 kHz (first label 6.66 kHz)",
    fast[1] == "6.66 kHz", "first label " .. tostring(fast[1]))

  local fallback = labelsFor(250, nil)
  check("a board with no rate falls back to the gyro task interval, as before",
    same(fallback, {"4.0 kHz", "2.0 kHz", "1.33 kHz", "1 kHz"}), table.concat(fallback, " / "))
end

-- ---------------------------------------------------------------------------
-- self-test: with the rate rounded to the kHz, a 3.2 kHz board is labelled 3 kHz.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the label check must go red with the rate rounded to the kHz")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub("gyroHz = sampleRateHz\r?\n", "gyroHz = math.floor(sampleRateHz / 1000 + 0.5) * 1000\n", 1)
  check("self-test: the rate line was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local realChunk = assert(load(mutated, "@" .. PAGE_PATH))
    local page = realChunk()
    lines, recordedChoices = {}, nil
    preparedData = {
      status = {task_delta_time_gyro = 312}, advancedConfig = {pid_process_denom = 1},
      craftName = {name = "Test"}, featureConfig = {enabledFeatures = 0},
      boardInfo = {sampleRateHz = 3200},
    }
    page.open({})
    local first = recordedChoices and recordedChoices[1] and recordedChoices[1][1]
    check("self-test: with the rate rounded, 3.2 kHz is labelled as 3.0 kHz (the checks above go red)",
      first == "3.0 kHz", "first label " .. tostring(first))
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
