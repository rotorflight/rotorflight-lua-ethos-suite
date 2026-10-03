-- Instruction counts for the system tool's Ethos callbacks (app/tool.lua),
-- per menu screen and per page. See instruction_harness.lua for what is
-- counted and why.
--
-- Usage (run from anywhere; needs Lua 5.3+):
--     lua5.4 bin/perf/measure_app_instructions.lua [filter] [ticks] [w h] [profile]
--   filter : only open pages whose script path contains this text; menus on
--            the way to them are still walked (default: every page)
--   ticks  : 50ms ticks to run on each page after opening it (default 60)
--   w, h   : window size (default 800 480)
--   profile: "open" | "tick" -- profile the matching page's open press, or
--            its worst tick, by function
--
-- What runs: the real main.lua (background task + tool + dashboard
-- registration) booted with system.getVersion().simulation = true, so
-- tasks/msp/queue.lua answers every request with the codec's own
-- simulatorResponse through the real reply path. A page's read reply is
-- therefore decoded inside the background task's wakeup, as on the radio, and
-- its fields are filled on the tool's next wakeup.
--
-- The walk presses the real tile closures menu_container.lua hands to
-- form.addButton -- on the radio that closure is the Ethos callback a tile
-- press runs -- and leaves each screen through tool.event(EVT_CLOSE), the
-- physical RTN key. Per page it reports:
--   open : the tile press (page load + form build + first MSP publish)
--   wake : worst tool wakeup() while the page is open
--   paint: worst tool paint()
--   bg   : worst background-task wakeup() while the page is open
--   back : the RTN press that leaves the page (dispose + menu rebuild)
--
-- Not modelled: Ethos invoking a field's own getValue/setValue closures (each
-- is a separate, small callback), dialog button presses, and saves.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local H = dofile(scriptDir() .. "/instruction_harness.lua")

local FILTER = arg and arg[1] or ""
if FILTER == "all" then FILTER = "" end
local TICKS = tonumber(arg and arg[2]) or 60
H.window.w = tonumber(arg and arg[3]) or 800
H.window.h = tonumber(arg and arg[4]) or 480
local PROFILE = arg and arg[5]

H.settings = {developer = {developer_mode = true}}

-- Simulator mode: the MSP queue serves simulatorResponse instead of a link.
local realGetVersion = system.getVersion
system.getVersion = function()
  local v = realGetVersion()
  v.simulation = true
  return v
end

-- ---------------------------------------------------------------------------
-- form: enough of Ethos's form API for every page to build. Buttons are
-- recorded per screen (form.clear() starts a new one) so the walk can press
-- tiles; every other widget is a permissive handle.
-- ---------------------------------------------------------------------------
local screenButtons = {}
local clears = 0

local function newWidget()
  return H.permissive({
    value = function() return 0 end,
    enable = function() end,
    focus = function() end,
  })
end

local function slots(n)
  local list = {}
  local w = H.window.w / math.max(n, 1)
  for i = 1, n do list[i] = {x = (i - 1) * w, y = 0, w = w, h = 38} end
  return list
end

local formHeight = 0
local function addLine()
  formHeight = formHeight + 40
  return newWidget()
end

-- Any add*/open* call not spelled out below returns a widget handle, as
-- Ethos's own form.addNumberField(), addChoiceField(), ... do.
form = setmetatable({
  clear = function()
    clears = clears + 1
    formHeight = 0
    screenButtons = {}
  end,
  height = function() return formHeight end,
  addLine = addLine,
  addExpansionPanel = function() return H.permissive({addLine = addLine}) end,
  getFieldSlots = function(_, hints) return slots(type(hints) == "table" and #hints or 1) end,
  addButton = function(_, _, opts)
    screenButtons[#screenButtons + 1] = opts or {}
    return newWidget()
  end,
  addTextButton = function(_, _, _, press)
    screenButtons[#screenButtons + 1] = {press = press}
    return newWidget()
  end,
  openDialog = function() return newWidget() end,
  openProgressDialog = function() return newWidget() end,
  openWaitDialog = function() return newWidget() end,
}, {__index = function(self, k)
  local fn = H.noop
  if type(k) == "string" and (k:match("^add") or k:match("^open")) then fn = newWidget end
  rawset(self, k, fn)
  return fn
end})

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------
assert(loadfile("main.lua"))().init()
local task = assert(H.registered.tasks[1], "background task did not register")
local tool = assert(H.registered.tools[1], "system tool did not register")

-- ROOT_ENTRIES and MENUS are tool.lua locals; create() holds both as upvalues.
local function upvalue(fn, name)
  for i = 1, math.huge do
    local n, v = debug.getupvalue(fn, i)
    if not n then return nil end
    if n == name then return v end
  end
end
local ROOT_ENTRIES = assert(upvalue(tool.create, "ROOT_ENTRIES"), "ROOT_ENTRIES not found")
local MENUS = assert(upvalue(tool.create, "MENUS"), "MENUS not found")

local bus = package.loaded["rfsuite.lib.bus"]
local connected = false
bus.subscribe("session.update", function(s) connected = s and s.connected == true end)

local results, order = {}, {}
local function slot(name)
  local r = results[name]
  if not r then
    r = {open = 0, wake = 0, paint = 0, bg = 0, back = 0, opened = false}
    results[name] = r
    order[#order + 1] = name
  end
  return r
end

-- One 50ms tick: background task, then the tool's own wakeup and paint (the
-- tool owns the screen, so the dashboard is not painted).
local function tick(r)
  H.advance(0.05)
  local b = H.measure(task.wakeup)
  local w = H.measure(tool.wakeup, {})
  local p = H.measure(tool.paint, {})
  if r then
    if b > r.bg then r.bg = b end
    if w > r.wake then r.wake = w end
    if p > r.paint then r.paint = p end
  end
  return math.max(b, w, p)
end

H.linkUp = true
task.init()
H.start()
for _ = 1, 200 do
  H.advance(0.05)
  H.measure(task.wakeup)
  if connected and _ > 60 then break end
end
if not connected then H.print("ERROR: session never connected") end

local root = slot("tool.create")
root.open = H.measure(tool.create)
root.opened = true
for _ = 1, 10 do tick(root) end

local function visibleEntries(entries)
  local list = {}
  for _, e in ipairs(entries) do
    if not e.visibleWhen or e.visibleWhen() == true then list[#list + 1] = e end
  end
  return list
end

-- menu_container adds the header's buttons first and then one per visible
-- entry, so the tiles are the last #visible buttons on the screen.
local function tilePress(visible, index)
  local first = #screenButtons - #visible
  local opts = screenButtons[first + index]
  return opts and opts.press
end

-- The suite's prints are silenced; a profile has to go to the real one.
local function printProfile(label)
  local silenced = print
  print = H.print
  H.printProfile(label, 30)
  print = silenced
end

local function back(r)
  local d = H.measure(tool.event, {}, EVT_CLOSE, 0, 0, 0)
  if r and d > r.back then r.back = d end
end

local function wanted(entry)
  return FILTER == "" or (entry.script and entry.script:find(FILTER, 1, true))
end

local function leadsTo(entry)
  if entry.script then return wanted(entry) end
  local menu = MENUS[entry.menuId]
  if not menu then return false end
  for _, e in ipairs(visibleEntries(menu.entries)) do
    if leadsTo(e) then return true end
  end
  return false
end

local function visit(entries, path)
  local visible = visibleEntries(entries)
  for i, entry in ipairs(visible) do
    if leadsTo(entry) then
      local name = entry.script or ("menu " .. entry.menuId)
      local r = slot(name)
      local press = tilePress(visible, i)
      if not press then
        H.print("ERROR: no tile button for " .. name .. " under " .. path)
      else
        local before = clears
        local profileOpen = PROFILE == "open" and entry.script ~= nil
        H.setProfiling(profileOpen)
        r.open = math.max(r.open, H.measure(press))
        H.setProfiling(false)
        if profileOpen then printProfile("open " .. name) end
        -- A press that built nothing was refused by the entry's guard.
        r.opened = r.opened or clears > before
        if clears > before then
          if entry.menuId then
            tick(r)
            visit(MENUS[entry.menuId].entries, path .. "/" .. entry.menuId)
          else
            local worst, worstAt = 0, 0
            for t = 1, TICKS do
              local d = tick(r)
              if d > worst then worst, worstAt = d, t end
            end
            if PROFILE == "tick" and worstAt > 0 then
              -- Re-open and profile the worst tick by number.
              back(nil)
              tilePress(visible, i)()
              for t = 1, worstAt do
                H.setProfiling(t == worstAt)
                tick(nil)
              end
              H.setProfiling(false)
              printProfile("worst tick " .. worstAt .. " on " .. name)
            end
          end
          back(r)
          tick(nil)
        end
      end
    end
  end
end

visit(ROOT_ENTRIES, "root")
H.stop()

print = H.print
print(string.format("RESULT app size=%dx%d ticks=%d filter=%s", H.window.w, H.window.h, TICKS,
  FILTER == "" and "all" or FILTER))
for _, name in ipairs(order) do
  local r = results[name]
  print(string.format("  %-46s open=%6d wake=%6d paint=%6d bg=%6d back=%6d%s", name, r.open, r.wake,
    r.paint, r.bg, r.back, r.opened and "" or " NOT-OPENED"))
end
H.printModuleLoads(8)
