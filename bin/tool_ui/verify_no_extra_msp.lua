-- Zaehlt die MSP-Anfragen, die das Werkzeug ueber seinen ganzen Lebenszyklus
-- stellt, und prueft, dass sie sich nicht pro Zyklus vermehren.
--
-- Hintergrund: Das Werkzeug laedt seinen UI-Unterbaum erst beim Oeffnen statt
-- beim Boot (#2421). Die Sorge dabei war eine doppelte: dass dadurch (a) ein
-- Speicherleck entsteht und (b) zusaetzliche MSP-Aufrufe dazukommen, die den
-- Heap hochziehen. (a) beantwortet der Heap-Boden aus der Boot-Sonde, (b)
-- beantwortet DIESES Harness -- und zwar strenger als eine Beobachtung auf der
-- Leitung: es zaehlt an der Quelle, dem bus.publish, fuer einen fest
-- vorgegebenen Ablauf, und der Ablauf laesst sich byteweise zwischen zwei
-- Staenden vergleichen.
--
-- Gefahren wird das ECHTE src/rfsuite/app/tool.lua inklusive der echten
-- Guards; gestubbt sind nur die Ethos-Widgets, der Hintergrund-Task und die
-- Verbindung -- Letztere muessen "laeuft" und "verbunden" melden, sonst feuern
-- die Guards gar nicht und der Test vergaenge an 0 == 0.
--
-- Der Weg fuehrt bewusst in BEIDE bewachten Menues:
--   Wurzel -> Hardware -> Servos        (servo_bus_guard,  MSP 54)
--   Wurzel -> Hardware -> ESC-Motoren -> ESC-Tools
--                                         (esc_protocol_guard, MSP 123)
-- Ein Ablauf, der sie auslaesst, wuerde nichts messen.
--
-- usage:  lua bin/tool_ui/verify_no_extra_msp.lua
--         (pfad optional: alternativ das Wurzelverzeichnis des Repos)

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local arg1 = ...
local ROOT = (arg1 or (scriptDir() .. "/../..")):gsub("\\", "/")
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
package.path = SUITE .. "/?.lua;" .. package.path

local echtesLoadfile = loadfile
local SUITE_PRAEFIX = SUITE .. "/"
_G.loadfile = function(pfad, ...)
  if type(pfad) == "string" and pfad:match("%.lua$") then
    local absolut = pfad:sub(1, 1) == "/" and pfad or (SUITE_PRAEFIX .. pfad)
    return echtesLoadfile(absolut, ...)
  end
  return echtesLoadfile(pfad, ...)
end

local registriertesTool = nil
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  registerSystemTool = function(tool) registriertesTool = tool return tool end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
}

_G.lcd = {
  loadMask = function(p) return { pfad = p } end,
  loadImage = function(p) return { pfad = p } end,
  getWindowSize = function() return 480, 320 end,
  getTextSize = function(t) return #t, 12 end,
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

-- Die Suite ruft ueberall print(); ein stiller Stub schluckt dann auch die
-- Ausgabe dieses Harness.
_G.print = function() end

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

-- Jede Kachel wird hier festgehalten. Die Navigation laeuft ueber den
-- press-Callback, den menu_container.lua:242-265 baut -- das ist derselbe
-- Weg wie eine Betätigung im Menue, nur ohne Taste. Identifiziert wird die
-- Kachel ueber ihren Icon-Pfad, weil der aus den Menue-Daten stammt und
-- deshalb nicht geraten werden muss.
local kacheln = {}
_G.form = {
  addButton = function(_, slot, taste)
    local eintrag = { slot = slot, icon = taste and taste.icon and taste.icon.pfad, press = taste and taste.press }
    kacheln[#kacheln + 1] = eintrag
    return feldStub(slot)
  end,
  addLine = function() return 1 end,
  addStaticText = function(_, rect) return feldStub(rect) end,
  addTextButton = function(_, slot) return feldStub(slot) end,
  clear = function() end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local w = 480 / math.max(n, 1)
    local out = {}
    for i = 1, n do out[i] = { x = (i - 1) * w, y = 0, w = w, h = 30 } end
    return out
  end,
  height = function() return 320 end,
  openProgressDialog = function() return { close = function() end } end,
}

_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.TIME_LEFT, _G.TEXT_LEFT, _G.LEFT = 1, 2, 3
_G.CENTERED, _G.RIGHT, _G.TOP_LEFT = 4, 5, 6
_G.FONT_XS, _G.FONT_S, _G.FONT_M, _G.FONT_L, _G.FONT_XL = 10, 20, 30, 40, 50
_G.EVT_CLOSE, _G.EVT_KEY, _G.EVT_EXIT_BREAK = 0x01, 0x02, 0x03
_G.EVT_KEY_DOWN_BREAK, _G.KEY_ENTER_LONG = 0x04, 0x05
_G.KEY_RTN_BREAK, _G.KEY_EXIT_BREAK = 0x06, 0x07

-- ── MSP-Zaehlung an der Quelle ───────────────────────────────────────────────
-- Der echte Bus wird VOR dem Werkzeug geladen und sein publish erst danach
-- umhüllt. Alle, die die Tabelle gehalten haben, sehen die Umhüllung -- es
-- bleibt also der echte Bus, nur mit einem Zähler davor.
local bus = assert(echtesLoadfile(SUITE_PRAEFIX .. "lib/bus.lua")())

-- Die Anfragen werden SOFORT beantwortet, so wie ein erreichbarer FC es
-- tut. Das ist keine Kosmetik, sondern der Unterschied zwischen einer
-- Pruefung und keiner: ohne Antwort bleibt `pending` dauerhaft true, und
-- `pending` bremst jede Wiederholung -- unabhaengig davon, ob `attempted`
-- richtig gesetzt wird. Genau daran ist eine erste Fassung dieses Harness
-- gescheitert: sie blieb auch mit kaputtem Latch gruen, weil nie jemand
-- geantwortet hat. Erst mit Antwort greift der Latch ueberhaupt.
--
-- Byte-Layouts aus den echten Decodern, nicht geraten:
--   123  msp_esc_sensor_config.decode  -- 14 Felder (U8,U8,U16,U16,U16,U8,U8,S8,S8,U16)
--   54   msp_serial_config.decode      -- 9-Byte-Record (U8,U32,U8,U8,U8,U8)
local ANTWORT = {
  [123] = function() return { 1, 0, 200, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } end,
  [54] = function() return { 1, 0, 0, 0, 0, 0, 0, 0, 0 } end,
}

local spur = {}
local echtesPublish = bus.publish
bus.publish = function(topic, nachricht)
  if topic == "msp.request" and type(nachricht) == "table" then
    spur[#spur + 1] = nachricht.command or "?"
    local antwort = ANTWORT[nachricht.command]
    if antwort and nachricht.processReply then
      local buf = antwort()
      buf.offset = 1
      nachricht.processReply(nil, buf)
    end
  end
  return echtesPublish(topic, nachricht)
end

-- ── Ablauf ──────────────────────────────────────────────────────────────────
local ESC_ICON = "app/gfx/esc_tools.png"
local SERVO_ICON = "app/gfx/servos.png"
local HW_ICON = "app/gfx/hardware.png"
local ESC_MOTORS_ICON = "app/gfx/esc_motors.png"

-- Die juengste Kachel mit diesem Icon: nach jedem Menuewechsel gehoeren die
-- Kacheln des neuen Bildschirms ans Ende der Liste.
local function druecke(iconpfad)
  for i = #kacheln, 1, -1 do
    if kacheln[i].icon == iconpfad and kacheln[i].press then
      kacheln[i].press()
      return true
    end
  end
  return false
end

local function spurAnzahl() return #spur end

local function spurSeit(von)
  local r = {}
  for i = von + 1, #spur do r[#r + 1] = tostring(spur[i]) end
  return table.concat(r, ",")
end

echtesPrint("Lade app/tool.lua ...")
local tool = dofile(SUITE .. "/app/tool.lua")
local handle = tool.init()
pruefe("init() liefert ein Handle", handle ~= nil)

-- Die Guards fragen nur, wenn der Hintergrund-Task laeuft UND die Verbindung
-- steht (tool.lua:469/475). Beides wird ueber den echten Bus gemeldet -- nicht
-- ueberstubbed, damit der Zustandsautomat der Suite derselbe laeuft wie im
-- Betrieb.
bus.publish("task.status", { running = true, updatedAt = os.clock() })
bus.publish("session.update", { connected = true, apiVersionSupported = true })

local ZYKLEN = 3
local spurProZyklus = {}

for zyklus = 1, ZYKLEN do
  registriertesTool.create()

  -- Die Spur-Abschnitte werden SOFORT als Text festgehalten, nicht erst am
  -- Ende des Zyklus. Sonst zeigt der Servos-Abschnitt die Antwort, die der
  -- ESC-Schritt danach angehaengt hat -- und der Bericht erzaehlt zwei
  -- Anfragen, wo eine war.
  local markeServos = spurAnzahl()
  pruefe(string.format("Zyklus %d  Hardware-Menue ist erreichbar", zyklus), druecke(HW_ICON))
  pruefe(string.format("Zyklus %d  Servos-Menue ist erreichbar", zyklus), druecke(SERVO_ICON))
  local nachServos = spurAnzahl() - markeServos
  local textServos = spurSeit(markeServos)

  local markeEsc = spurAnzahl()
  pruefe(string.format("Zyklus %d  ESC-Motoren-Menue ist erreichbar", zyklus), druecke(ESC_MOTORS_ICON))
  pruefe(string.format("Zyklus %d  ESC-Tools-Menue ist erreichbar", zyklus), druecke(ESC_ICON))
  local nachEsc = spurAnzahl() - markeEsc
  local textEsc = spurSeit(markeEsc)

  -- Der Tick. Das ist der Weg, ueber den ein Retry-Sturm ueberhaupt entstehen
  -- koennte: Ethos ruft wakeup() fortlaufend, menu_container.lua:305-306
  -- gibt das an den Wache-Handler weiter, und der ruft request() auf. Ohne
  -- diesen Block pruefte das Harness nur das Betreten des Menues -- also genau
  -- den Fall, in dem sich nichts sammeln kann.
  local markeTick = spurAnzahl()
  local TICKS = 100
  for _ = 1, TICKS do
    registriertesTool.wakeup({})
  end
  local imTick = spurAnzahl() - markeTick

  registriertesTool.close()

  spurProZyklus[#spurProZyklus + 1] = string.format("Servos=%d(%s) ESC=%d(%s) Tick=%d",
    nachServos, textServos, nachEsc, textEsc, imTick)
end

-- ── Auswertung ──────────────────────────────────────────────────────────────
local ESC_LESEN = 123      -- msp_esc_sensor_config.READ_COMMAND
local SERIAL_LESEN = 54    -- msp_serial_config.READ_COMMAND

echtesPrint("")
echtesPrint("Spur je Zyklus:")
for i, z in ipairs(spurProZyklus) do
  echtesPrint(string.format("  %d  %s", i, z))
end
echtesPrint("")

-- Jedes bewachte Menue stellt beim Betreten genau EINE Anfrage: die Wache
-- liest einmal und haelt das Ergebnis (attempted). Mehr waere der Retry-Sturm,
-- vor dem dieses Harness hier steht.
for i = 1, #spurProZyklus do
  local z = spurProZyklus[i]
  pruefe(string.format("Zyklus %d  genau eine Servos-Abfrage (MSP %d)", i, SERIAL_LESEN),
    z:find("Servos=1%(" .. SERIAL_LESEN .. "%)") ~= nil, z)
  pruefe(string.format("Zyklus %d  genau eine ESC-Abfrage (MSP %d)", i, ESC_LESEN),
    z:find("ESC=1%(" .. ESC_LESEN .. "%)") ~= nil, z)
end

-- Und die entscheidende Eigenschaft: die Spur muss in JEDEM Zyklus gleich
-- sein. Waechst sie, sammelt sich etwas an -- genau Robs Sorge.
for i = 2, #spurProZyklus do
  pruefe(string.format("Zyklus %d ist identisch zu Zyklus 1", i),
    spurProZyklus[i] == spurProZyklus[1],
    string.format("%s  vs.  %s", spurProZyklus[i], spurProZyklus[1]))
end

-- 100 Ticks im bewachten Menue duerfen KEINE einzige Anfrage erzeugen. Der
-- Wache-Handler liest einmal und haelt das Ergebnis; sendet er bei jedem Tick,
-- ist das der Sturm, um den es hier geht.
pruefe("100 Ticks im ESC-Menue erzeugen keine Anfrage", spurProZyklus[1]:find("Tick=0$") ~= nil,
  spurProZyklus[1])

pruefe("insgesamt gleich viele Anfragen in allen Zyklen",
  #spur == 2 * #spurProZyklus, "Spur hat " .. #spur .. " Eintraege fuer " .. #spurProZyklus .. " Zyklen")

echtesPrint("")
echtesPrint(string.rep("-", 60))
echtesPrint(string.format("bestanden: %d   fehlgeschlagen: %d", bestanden, fehlgeschlagen))
echtesPrint("MSP-Anfragen gesamt: " .. #spur .. "   Spur: " .. spurSeit(0))
if fehlgeschlagen > 0 then
  echtesPrint("")
  echtesPrint("FEHLGESCHLAGEN")
  os.exit(1)
end
echtesPrint("ALLE BESTANDEN")
