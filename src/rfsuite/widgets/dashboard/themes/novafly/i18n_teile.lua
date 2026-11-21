-- Texte des Themes in der Sprache des Senders. Deutsch, der Lader und t.wort sind Auszuege aus novasetup/lib/i18n.lua,
-- i18n_<sprache>.lua sind Auszuege aus novasetup/lib/i18n_<sprache>.lua; geladen wird nur die Sprache des Senders.
-- Von einem Skript erzeugt - nie von Hand aendern.
local H = ...
local nova = H.nova
local t = {
    k_warten = "Speichert - bitte warten",
    laeuft = "laeuft ...",
    laeuft_still = "laeuft ...",
    f_kein_heli = "NO LINK",
    b_arm_unbekannt = "ARM ?",
    f_setup_scharf = "Heli ist scharf. Setup nur am Boden.",
    dezimal = ",",
    woerter = {},
    muster = {},
}

t.grund = {
    msp_nicht_bereit = "MSP-Schicht noch nicht bereit. Moment ...",
}

function t.grundtext(g)                          -- Vergleich und Anzeige: ohne Log
    if g == nil then return "" end
    g = tostring(g)
    return t.grund[g] or g
end
t.klartext = t.grundtext

t.sprache = "de"   -- SPRACHE VOM SENDER: Ethos nennt sie mit system.getLocale()
local okS, sprache = pcall(function() return system.getLocale() end)
if okS and type(sprache) == "string" then sprache = sprache:match("^(%a%a)") or sprache end   -- "en-US" / "pt_BR": die Datei heisst nach den zwei Buchstaben
if okS and type(sprache) == "string" and sprache ~= "" and sprache ~= "de" then
    local datei = H.laden(loadfile, "i18n_" .. sprache .. ".lua") or H.laden(loadfile, "i18n_en.lua")   -- fehlt sie, englisch: die Suite kennt mehr Sprachen als das Theme
    if datei then
        local okU, ueber = pcall(datei, nova)
        if okU and type(ueber) == "table" then
            for k, v in pairs(ueber) do
                if t[k] ~= nil then t[k] = v end   -- Wort fuer Wort ueber das Deutsche; ein Schluessel, den es nicht gibt, zaehlt nicht (kein Schluessel, kein Satz)
            end
            t.sprache = sprache
        end
    end
end

local wortMerk = {}                                -- Texte ohne Zahl: einmal gesucht, dann gemerkt (Treffer wie Fehlschlag)
local zahlMerk, zahlMerkN = {}, 0                  -- Texte mit Zahl ebenso, begrenzt: jedes Bild neu uebersetzen riss am X18 die Befehlsgrenze
local ZAHL_MERK_MAX = 120
local function uebersetzt(text, tiefe)             -- Wort, Muster, dann die Teile: Spalten (zwei Leerzeichen), Vorsatz "S1 " / "5  ", "Wort:", erstes oder letztes Stueck
    local w = t.woerter
    local u = w[text]
    if u ~= nil then return u end
    if tiefe > 3 then return text end
    local m = t.muster
    for i = 1, #m do
        local neu, n = text:gsub(m[i][1], m[i][2])
        if n > 0 then return neu end
    end
    local links, luft, rechts = text:match("^(.-)(%s%s+)(.*)$")
    if links and links ~= "" and rechts ~= "" then
        return uebersetzt(links, tiefe + 1) .. luft .. uebersetzt(rechts, tiefe + 1)
    end
    local vorsatz, rest = text:match("^(S[12] )(.+)$")
    if not vorsatz then vorsatz, rest = text:match("^(%d+%s+)(.+)$") end
    if vorsatz then return vorsatz .. uebersetzt(rest, tiefe + 1) end
    local wortAux, aux = text:match("^(.-) (AUX %d+)$")          -- "FLUGSCHREIBER AUX 7": das Wort davor, AUX bleibt in jeder Sprache
    if wortAux and wortAux ~= "" then return uebersetzt(wortAux, tiefe + 1) .. " " .. aux end
    local kopf, schwanz = text:match("^(.-:)%s(.*)$")
    if kopf and w[kopf] then return w[kopf] .. " " .. uebersetzt(schwanz, tiefe + 1) end
    local erstes, danach = text:match("^(%S+)%s(.*)$")          -- "SUMME 110%": Wort vor einem Wert ohne Buchstaben
    if erstes and w[erstes] and not danach:find("%a") then return w[erstes] .. " " .. danach end
    local davor, letztes = text:match("^(.-)%s(%S+)$")          -- "WEG KOLL. 12": Woerter vor dem letzten Stueck ohne Buchstaben
    if davor and w[davor] and not letztes:find("%a") then return w[davor] .. " " .. letztes end
    return text
end
function t.wort(text)                              -- WORT FUER WORT AM GLAS: ein Text aus einem Schirm in der Sprache des Senders; auf Deutsch unveraendert
    if t.sprache == "de" or type(text) ~= "string" or text == "" then return text end
    local u = wortMerk[text] or zahlMerk[text]
    if u ~= nil then return u end
    u = uebersetzt(text, 0)
    if text:find("%d") then
        if t.dezimal == "." then u = (u:gsub("(%d),(%d)", "%1.%2")) end   -- Sprachen mit Dezimalpunkt (Englisch): 3,0 -> 3.0
        if zahlMerkN >= ZAHL_MERK_MAX then zahlMerk, zahlMerkN = {}, 0 end
        zahlMerk[text] = u
        zahlMerkN = zahlMerkN + 1
    else
        wortMerk[text] = u
    end
    return u
end

return t
