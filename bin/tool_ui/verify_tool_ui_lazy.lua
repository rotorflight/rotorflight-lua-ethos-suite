-- Prueft, dass die Tool-UI erst beim Oeffnen des Tools laedt.
--
-- Das Harness faehrt das ECHTE src/rfsuite/app/tool.lua unter einer
-- Ethos-Stub-Umgebung: loadfile, Bus, Settings-Store, system.registerSystemTool
-- und ein lcd.loadMask, der nichts kostet. Der Punkt ist nicht, das Tool zu
-- testen -- es ist festzustellen, WELCHE Module wann in package.loaded
-- auftauchen.
--
-- Vier Faelle, jeder gegen eine falsche Erwartung:
--   1. Nach dem Laden von tool.lua (init ist noch nicht gelaufen) liegt KEIN
--      app/-Modul des Tool-UI-Unterbaums in package.loaded.
--   2. Nach create() liegen sie ALLE drin.
--   3. close() laedt nichts nach, was nicht vorher schon da war.
--   4. Ein zweites create() laedt nichts erneut (requireModule cacht).
--
-- Gegen die alte Fassung muss Fall 1 ROT werden -- dort stehen die
-- requireModule-Aufrufe in Spalte 1 und die Module sind sofort da.
--
-- usage:  lua bin/tool_ui/verify_tool_ui_lazy.lua
--         (pfad optional: alternativ das Wurzelverzeichnis des Repos)

-- Heimfall: die Suite rechnet ihre Modulpfade gegen src/rfsuite auf, nicht
-- gegen src -- main.lua:52 laedt "lib/require.lua" und liegt selbst in
-- src/rfsuite/. Dasselbe Muster wie bin/storage/verify_atomic_writes.lua.
local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local bestanden, fehlgeschlagen = 0, 0

local echtesPrint = print

local function pruefe(name, bedingung, zusatz)
  if bedingung then
    bestanden = bestanden + 1
    echtesPrint(string.format("  OK    %s", name))
  else
    fehlgeschlagen = fehlgeschlagen + 1
    echtesPrint(string.format("  FEHLT %s%s", name, zusatz and ("  -- " .. zusatz) or ""))
  end
end

-- ── Ethos-Stubs ─────────────────────────────────────────────────────────────
local geladen = {}          -- Reihenfolge des ersten Auftauchens
local ladeReihenfolge = {}

package.path = SUITE .. "/?.lua;" .. package.path

-- Die Suite laedt ihre Module ueber EINFACHE, relativ zum Arbeitsverzeichnis
-- aufgeloeste Pfade: tool.lua:36 ruft loadfile("lib/require.lua"), und
-- requireModule() daraus ruft loadfile("lib/bus.lua") -- beides ohne
-- Verzeichnisanteil. Auf dem Sender ist das Arbeitsverzeichnis der Pfad des
-- Wurzelskripts (src/rfsuite). Damit der Harness denselben Aufloesungsweg
-- hat, wird hier der Prefixer gesetzt, den die Suite selbst nicht braucht.
-- Er wird beim Traces fuehrt, aber nicht in den Modulnamen, die zaehlen.
lokalPraefix = SUITE .. "/"
_G.PRAEFIX = lokalPraefix

local echtesLoadfile = loadfile
local geladen = {}          -- Reihenfolge des ersten Auftauchens
local ladeReihenfolge = {}

-- loadfile wird von lib/require.lua aufgerufen; dort greift die Umleitung.
-- Der Prefixer macht aus dem suite-eigenen "lib/require.lua" einen absoluten
-- Pfad -- fuer den Ladevorgang identisch, fuer die Auswertung aber
-- wieder aufgeraeumt, damit zaehleUnter() die echten Modulpfade sieht.
_G.loadfile = function(pfad, ...)
  if type(pfad) == "string" and pfad:match("%.lua$") then
    local absolut = pfad:sub(1, 1) == "/" and pfad or (lokalPraefix .. pfad)
    geladen[absolut] = (geladen[absolut] or 0) + 1
    ladeReihenfolge[#ladeReihenfolge + 1] = absolut
    return echtesLoadfile(absolut, ...)
  end
  return echtesLoadfile(pfad, ...)
end

_G.package = package
_G.package.loaded = package.loaded

-- sys-Table: Ethos liefert sie; das Tool braucht sie fuer init().
local registriertesTool = nil
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  registerSystemTool = function(tool) registriertesTool = tool return tool end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
}

-- lcd: loadMask ist im echten Code das teuerste (Bitmap-Arena), hier zaehlt
-- es nur die Aufrufe, damit ein Fehlschlag nicht an ihm haengt.
local maskAufrufe = 0
_G.lcd = {
  loadMask = function(p) maskAufrufe = maskAufrufe + 1; return { pfad = p } end,
  loadImage = function(p) return { pfad = p } end,
  getWindowSize = function() return 480, 320 end,
  drawRectangle = function() end,
  drawText = function() end,
  drawBitmap = function() end,
  setColor = function() end,
  setFgColor = function() end,
  setBgColor = function() end,
  font = function() return 1 end,
  color = function() end,
  text = function() end,
  box = function() end,
  line = function() end,
  circle = function() end,
  CONSOLE = { WHITE = 0, BLACK = 1, YELLOW = 2, GREEN = 3, BLUE = 4 },
}
_G.model = { get = function() return 0 end, name = function() return "stub" end }

-- ECHTES print, ueber eine eigene Referenz: die Suite ruft ueberall print(), und
-- ein stiller Stub schluckt dann auch die Ausgabe dieses Harness. Genau das ist
-- passiert -- der erste gruene Lauf gab Exitcode 0 ohne eine einzige Zeile.
_G.print = function() end

-- form: der Menuepfad baut echte Widgets. Hier zaehlt nur, dass er durchlaeuft
-- -- die tatsaechliche Formular-Arbeit gehoert nicht zu dieser Pruefung, sie
-- wird an anderer Stelle (bin/storage, bin/flight_record) geprueft.
local feldIndex = 0
-- form.getFieldSlots(line, hints) liefert eine Liste von Rechtecken; header.lua:131
-- liest slots[1].y, slots[2].x und slots[1].h daraus. Ein Zahlen-Rueckgabewert
-- laesst das Harness an dieser Stelle abbrechen -- das Schema ist hier
-- getestet, nicht geraten.
local function slotsStub(breite)
  breite = breite or 480
  local n = 6
  local w = breite / n
  local out = {}
  for i = 1, n do
    out[i] = { x = (i - 1) * w, y = 0, w = w, h = 30 }
  end
  return out
end

-- Ethos-Widgets: form.addButton/addStaticText liefern Objekte mit Methoden.
-- Im Menuepfad wird :focus() aufgerufen (header.lua:162/198-201,
-- menu_container.lua:289/295); alles andere wird nur gelesen. Die Felder sind
-- bewusst minimal -- jede zusaetzliche Methode waere eine Annahme ueber
-- Verhalten, die diese Pruefung nicht macht.
local function feldStub(slot)
  return {
    slot = slot,
    focus = function() end,
    setText = function() end,
    setEnabled = function() end,
    setValue = function() end,
    getValue = function() return nil end,
    show = function() end,
    hide = function() end,
    isShown = function() return true end,
    isEnabled = function() return true end,
  }
end

_G.form = {
  addButton = function(_, slot) return feldStub(slot) end,
  addLine = function() return 1 end,
  addStaticText = function(_, rect) return feldStub(rect) end,
  addTextButton = function(_, slot) return feldStub(slot) end,
  clear = function() end,
  getFieldSlots = function(_, hints)
    -- Die Slotzahl richtet sich nach den Hints, die header.lua uebergibt.
    local n = type(hints) == "table" and #hints or 6
    local out = {}
    local w = 480 / math.max(n, 1)
    for i = 1, n do
      out[i] = { x = (i - 1) * w, y = 0, w = w, h = 30 }
    end
    return out
  end,
  height = function() return 320 end,
  openProgressDialog = function() return { close = function() end } end,
}
_G.lcd.getTextSize = function(t)
  feldIndex = feldIndex + 1
  return #t, 12
end
_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.print = function() end

-- Ethos-Globals, die die Menue-Kette als WERTE benutzt. Sie sind nicht im
-- Repo definiert (vergleiche activelook.lua:24, wo FONT_PX eine eigene
-- Tabelle ist) -- sie kommen von der Plattform, genau wie TIME_LEFT.
--
-- Zahlen, keine Strings: header.lua:122 rechnet `options = FONT_S + CENTERED`,
-- also addieren sich Font und Ausrichtung. Das ist am Quelltext geprueft und
-- nicht geraten.
_G.TIME_LEFT = 1
_G.TEXT_LEFT = 2
_G.LEFT = 3
_G.CENTERED = 4
_G.RIGHT = 5
_G.TOP_LEFT = 6
_G.FONT_XS = 10
_G.FONT_S = 20
_G.FONT_M = 30
_G.FONT_L = 40
_G.FONT_XL = 50

-- key events, close_key.lua filtert darauf
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07

-- i18n-Tags: die Quelltexte enthalten @i18n(... )@-Platzhalter, die zur
-- Laufzeit uebersetzt werden. Fuer diese Pruefung irrelevant, aber leere
-- Strings sind harmlos.
local TEST = {
  "app/menu_container.lua",
  "app/navigation.lua",
  "app/header.lua",
  "app/tile_grid.lua",
  "app/close_key.lua",
  "app/esc_protocol_guard.lua",
  "app/servo_bus_guard.lua",
  "lib/memstats.lua",
  "lib/msp_esc_sensor_config.lua",
  "lib/msp_serial_config.lua",
}

local function zaehleUnter(name)
  local ziel = SUITE .. "/" .. name
  local n = 0
  for _, pfad in ipairs(ladeReihenfolge) do
    if pfad == ziel then n = n + 1 end
  end
  return n
end

local function moduleGeladen(name)
  -- lib/require.lua cached unter "rfsuite." .. pfad ohne .lua
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  return package.loaded[key] ~= nil
end

echtesPrint("Lade app/tool.lua ...")
local tool = dofile(SUITE .. "/app/tool.lua")
local handle = tool.init()
pruefe("init() liefert ein Handle", handle ~= nil)

echtesPrint("")
echtesPrint("Fall 1: NACH DEM LADEN, VOR create() -- nichts darf geladen sein")
for _, name in ipairs(TEST) do
  pruefe(string.format("%-34s nicht geladen", name),
    not moduleGeladen(name) and zaehleUnter(name) == 0,
    string.format("geladen=%s, loadfile-Aufrufe=%d",
      tostring(moduleGeladen(name)), zaehleUnter(name)))
end

echtesPrint("")
echtesPrint("Fall 2: NACH create() -- der Tool-UI-Unterbaum muss vollstaendig sein")
registriertesTool.create()
for _, name in ipairs(TEST) do
  pruefe(string.format("%-34s geladen", name), moduleGeladen(name),
    "nach create() weiterhin nicht geladen")
end

echtesPrint("")
echtesPrint("Fall 3: close() laedt nichts nach")
local vorher = {}
for _, name in ipairs(TEST) do vorher[name] = zaehleUnter(name) end
registriertesTool.close()
for _, name in ipairs(TEST) do
  pruefe(string.format("%-34s unveraendert", name), zaehleUnter(name) == vorher[name],
    string.format("neu geladen: %d", zaehleUnter(name) - vorher[name]))
end

echtesPrint("")
echtesPrint("Fall 4: zweites create() laedt nichts erneut")
for _, name in ipairs(TEST) do vorher[name] = zaehleUnter(name) end
registriertesTool.create()
for _, name in ipairs(TEST) do
  pruefe(string.format("%-34s kein zweiter Ladevorgang", name), zaehleUnter(name) == vorher[name],
    string.format("erneut geladen: %d", zaehleUnter(name) - vorher[name]))
end

echtesPrint("")
echtesPrint(string.rep("-", 60))
echtesPrint(string.format("bestanden: %d   fehlgeschlagen: %d", bestanden, fehlgeschlagen))
echtesPrint("lcd.loadMask-Aufrufe: " .. maskAufrufe)
if fehlgeschlagen > 0 then
  echtesPrint("")
  echtesPrint("FEHLGESCHLAGEN")
  os.exit(1)
end
echtesPrint("ALLE BESTANDEN")
