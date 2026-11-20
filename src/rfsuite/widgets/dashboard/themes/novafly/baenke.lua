-- BAENKE: die Seite rechts vom Cockpit auf dessen Grund (seite_teile.lua S.grund), die Linien des Cockpits laufen von links
-- herein und klingen aus. Oben der Antrieb der Bank (Governor, Solldrehzahl, Hochlauf, Gain), darunter vier Chips mit der
-- Drehrate je Achse und drei Chips mit den Gains je Achse, die Chips aus den Linien des Cockpits mit Ecken r 4, der erste
-- jeder Reihe offen zum linken Rand. Rechts ein stehender Drehzahlbalken: die gemessene Drehzahl gegen die Solldrehzahl der
-- Bank, gruen bis zum Soll, gelb knapp darueber, rot zu hoch, mit der Marke der hoechsten Drehzahl dieser Bank (Schleppmonitor).
local H = ...
local floor = math.floor

local LINKS, RECHTS = 10, 376            -- die Flucht der Chips: beide Reihen beginnen und enden gleich
local RATE_CHIP = {y = 66, h = 58, n = 4, luecke = 6}
local GAIN_CHIP = {y = 136, h = 104, n = 3, luecke = 6}
local BALKEN = {x = 440, w = 24, oben = 62, unten = 300, rand = 4}   -- der Rahmen des Balkens; die Saeule bleibt rand innerhalb
local ZONEN_X, ZONEN_W = 467, 3          -- der Streifen der Zonen rechts am Balken
local SKALA, GELB_AB = 1.25, 1.08        -- der Balken reicht bis 125 % der Solldrehzahl; gelb ab dem Soll, rot ab 108 %
local IST_X, IST_W = 386, 94             -- die gemessene Drehzahl oben ueber dem Balken
local BANK_RX, BANK_Y, BANK_SCHRITT = 434, 150, 30   -- BANK 1 2 3 rechtsbuendig neben dem Balken
local FUSS_Y = 277
local KEINE_ZONE = {x = 0, y = 0, w = 0, h = 0}   -- ZURUECK gibt es auf einer Seite nicht: zurueck geht das Wischen
local RATE_TYP = {[0] = "NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK", "ROTORFLIGHT"}
local GOV_MODUS = {[0] = "OFF", "LIMIT", "DIRECT", "ELECTRIC", "NITRO"}   -- gov_mode der Firmware; bei 3 und 4 regelt der FC die Drehzahl
local GRAD_S = "\194\176/s"
local U_MIN = "U/min"

local t = H.i18n
local stil, S = nil, nil
local nova = {dirty = false, armLage = "unbekannt", flugbuch = {}, hohesDetail = true, kursiv = nil, i18n = t}
local werte = {pid = nil, rc = nil, gov = nil, govProfil = nil, fehler = nil}
local gelesenFuer = nil                  -- {bank, rate}, fuer die die Werte gelesen wurden; ein Wechsel liest neu
local laeuft = false

local CODEC = {PID_TUNING = "lib/msp_pid_tuning.lua", RC_TUNING = "lib/msp_rc_tuning.lua",
               GOVERNOR_CONFIG = "lib/msp_governor_config.lua", GOVERNOR_PROFILE = "lib/msp_governor_profile.lua"}
local ACHSE = {roll = 0, pitch = 1, yaw = 2}

local function pidNamen(d)   -- die PID-Felder des Codecs (roll_p) in den Namen von rfsuite 2.3.x (pid_0_P), die malen() liest
    local w = {}
    for k, v in pairs(d) do
        local achse, g = nil, nil
        if type(k) == "string" then achse, g = string.match(k, "^(%a+)_(%a)$") end
        if achse ~= nil and ACHSE[achse] ~= nil then w["pid_" .. ACHSE[achse] .. "_" .. string.upper(g)] = v else w[k] = v end
    end
    return w
end

local function lesen(name, fertig)
    local rf = H.rf()
    local q = rf and rf.tasks and rf.tasks.msp
    if q == nil or q.api == nil then   -- ohne die MSP-Schlange von rfsuite 2.3.x: der Bus der Suite mit ihrem Codec
        return S.busLesen(CODEC[name], function(d)
            if d ~= nil and name == "PID_TUNING" then d = pidNamen(d) end
            fertig(d)
        end)
    end
    local ok, api = pcall(q.api.load, name)
    if not ok or type(api) ~= "table" then return false end
    local felder = api.__rfReadStructure
    if type(felder) ~= "table" or #felder == 0 then felder = api.__rfWriteStructure end
    local einmal = false
    api.setCompleteHandler(function()
        if einmal then return end
        einmal = true
        local w = {}
        if type(felder) == "table" then
            for i = 1, #felder do
                local e = felder[i]
                if type(e) == "table" and e.field then
                    local ok2, v = pcall(api.readValue, e.field)
                    if ok2 and v ~= nil then w[e.field] = v end
                end
            end
        end
        fertig(w)
    end)
    api.setErrorHandler(function()
        if einmal then return end
        einmal = true
        fertig(nil)
    end)
    local ok3, r = pcall(api.read)
    if not ok3 or r == false then einmal = true return false end
    return true
end

local KETTE = {{"PID_TUNING", "pid", "PID"}, {"RC_TUNING", "rc", "RATEN"}, {"GOVERNOR_CONFIG", "gov", "GOVERNOR"}, {"GOVERNOR_PROFILE", "govProfil", "GOVERNOR"}}
local function kette(i)   -- liest die vier Saetze nacheinander; ein Fehler steht im Fuss, die Kette laeuft weiter
    local glied = KETTE[i]
    if glied == nil then laeuft = false return end
    if not lesen(glied[1], function(w)
        werte[glied[2]] = w
        if w == nil then werte.fehler = glied[3] end
        kette(i + 1)
    end) then
        werte.fehler = "MSP"
        laeuft = false
    end
end

local function anstossen(s)
    if laeuft then return end
    laeuft = true
    werte.pid, werte.rc, werte.gov, werte.govProfil, werte.fehler = nil, nil, nil, nil, nil
    gelesenFuer = {bank = s.bank and floor(s.bank) or nil, rate = s.rate and floor(s.rate) or nil}
    kette(1)
end

local function takt()   -- jeder Wakeup: ein Wechsel von Bank oder Rate am FC liest die Werte neu
    if stil == nil or gelesenFuer == nil or laeuft then return end
    local s = H.stand() or {}
    local bank, rate = s.bank and floor(s.bank) or nil, s.rate and floor(s.rate) or nil
    if bank ~= gelesenFuer.bank or rate ~= gelesenFuer.rate then anstossen(s) end
end

local function zahl(v, f)
    if v == nil then return "--", stil.FELD_LEISE end
    if f then v = f(v) end
    return tostring(floor(v + 0.5)), H.farben.gruen
end

local function zahlZeile(cx, cy, z, font, farbe, einheit)   -- die Zahl mit der Einheit klein in derselben Zeile, zusammen mittig
    local segs = {{z, farbe, font}}
    if einheit ~= nil then segs[2] = {einheit, stil.WEISS, FONT_XS} end
    S.zeile(cx, cy, segs)
end

local function chipLage(c, i)   -- x und Breite des i-ten Chips einer Reihe: alle in derselben Flucht LINKS..RECHTS
    local w = floor((RECHTS - LINKS - (c.n - 1) * c.luecke) / c.n)
    return LINKS + (i - 1) * (w + c.luecke), w
end

local function paar(x, y, buchstabe, v)
    local z, farbe = zahl(v)
    stil.beschriftung(x, y - 7, buchstabe, stil.WEISS, FONT_S)
    stil.beschriftung(x + 16, y - 8, z, farbe, FONT_STD)
end

local function antrieb()   -- das Kopfband: Governor, Solldrehzahl, Hochlauf, Gain in der Flucht der vier Chips
    local g, p = werte.gov or {}, werte.govProfil or {}
    local modus = g.gov_mode ~= nil and GOV_MODUS[floor(g.gov_mode)] or nil
    local spalten = {{"GOVERNOR", modus},
                     {"DREHZAHL", p.governor_headspeed, U_MIN},
                     {"HOCHLAUF", g.gov_spoolup_time, "s", function(q) return q / 10 end},
                     {"GAIN", p.governor_gain}}
    for i = 1, 4 do
        local x, w = chipLage(RATE_CHIP, i)
        if i == 1 then x, w = 0, x + w end
        local sp = spalten[i]
        stil.beschriftungMittig(x + w / 2, 18, S.wort(sp[1]), stil.WEISS, FONT_XS)
        local z, farbe
        if i == 1 then z, farbe = sp[2] or "--", sp[2] and H.farben.gruen or stil.FELD_LEISE
        else z, farbe = zahl(sp[2], sp[4]) end
        zahlZeile(x + w / 2, 35, z, FONT_STD, farbe, sp[2] ~= nil and sp[3] or nil)
    end
end

local function balken(R, s, aktiv)   -- die gemessene Drehzahl als Saeule gegen das Soll der Bank; ohne Soll (LIMIT, DIRECT, ungelesen) gegen das Ende des Cockpit-Bogens
    local b = BALKEN
    S.chip(b.x, b.oben, b.w, b.unten - b.oben)
    local g, p = werte.gov or {}, werte.govProfil or {}
    local regelt = g.gov_mode ~= nil and floor(g.gov_mode) >= 3
    local soll = regelt and p.governor_headspeed or nil
    if soll ~= nil and soll <= 0 then soll = nil end
    local voll = soll and (soll * SKALA) or H.rpmVoll()
    local hoehe = b.unten - b.oben
    local function yVon(wert)
        local anteil = wert / voll
        if anteil < 0 then anteil = 0 elseif anteil > 1 then anteil = 1 end
        return b.unten - hoehe * anteil
    end
    if soll and R then   -- die Zonen rechts am Balken und die Soll-Marke quer darueber
        local ySoll, yGelb = yVon(soll), yVon(soll * GELB_AB)
        S.flaeche(ZONEN_X, ySoll, ZONEN_W, b.unten - ySoll, R.GRUEN)
        S.flaeche(ZONEN_X, yGelb, ZONEN_W, ySoll - yGelb, R.GELB)
        S.flaeche(ZONEN_X, b.oben, ZONEN_W, yGelb - b.oben, R.ROT)
        S.flaeche(b.x - 4, floor(ySoll), b.w + 8, 1, stil.WEISS)
        stil.beschriftungRechts(BANK_RX, ySoll - 6, tostring(floor(soll + 0.5)), stil.WEISS, FONT_XS)
    end
    local rpm = s.rpm
    if rpm ~= nil and rpm > 0 and R then
        local farbe = R.GRUEN
        if soll and rpm > soll * GELB_AB then farbe = R.ROT elseif soll and rpm > soll then farbe = R.GELB end
        local yOben, yUnten = yVon(rpm), b.unten - b.rand
        if yOben < b.oben + b.rand then yOben = b.oben + b.rand end
        if yUnten > yOben then S.flaeche(b.x + b.rand, yOben, b.w - 2 * b.rand, yUnten - yOben, farbe) end
    end
    local sl = aktiv and H.schlepp[aktiv]
    if sl and sl.max and sl.max > 0 then   -- die Marke der hoechsten Drehzahl dieser Bank, wie der Schleppmonitor
        local y = yVon(sl.max)
        if y < b.oben + b.rand then y = b.oben + b.rand end
        S.flaeche(b.x + 2, floor(y) - 1, b.w - 4, 2, stil.WEISS)
    end
    stil.beschriftungMittig(IST_X + IST_W / 2, 18, S.wort("IST"), stil.WEISS, FONT_XS)
    local z, farbe = zahl(rpm)
    zahlZeile(IST_X + IST_W / 2, 35, z, FONT_STD, farbe, rpm ~= nil and U_MIN or nil)
    for i = 1, 3 do
        stil.beschriftungRechts(BANK_RX, BANK_Y + (i - 1) * BANK_SCHRITT, S.wort("BANK") .. " " .. i, aktiv == i and stil.WEISS or stil.FELD_LEISE, FONT_S)
    end
end

local function malen()
    if stil == nil then return end
    stil.fensterFrisch()
    stil.bandGemalt, stil.fussGemalt = false, false
    S.grund()
    S.linien(false)
    local R = H.rahmen()
    local s = H.stand() or {}
    local aktiv = s.bank and floor(s.bank) or nil
    local rate = s.rate and floor(s.rate) or nil
    antrieb()

    local r = werte.rc or {}
    local typ = r.rates_type and RATE_TYP[floor(r.rates_type)] or nil
    local ist_rf = (typ == "ROTORFLIGHT")
    local achsen = {{"ROLL", 1}, {"NICK", 2}, {"HECK", 3}, {"KOLL.", 4}}
    for i = 1, 4 do   -- Drehrate je Achse, die grosse Zahl in Grad je Sekunde
        local x, w = chipLage(RATE_CHIP, i)
        local y, h = RATE_CHIP.y, RATE_CHIP.h
        S.chip(x, y, w, h, i == 1 and "links" or nil)
        if i == 1 then x, w = 0, x + w end
        stil.beschriftungMittig(x + w / 2, y + 15, S.wort(achsen[i][1]), stil.WEISS, FONT_S)
        local v, farbe = zahl(r["rcRates_" .. achsen[i][2]], ist_rf and function(q) return q * 5 end or nil)
        zahlZeile(x + w / 2, y + 40, v, FONT_L, farbe, r["rcRates_" .. achsen[i][2]] ~= nil and GRAD_S or nil)
    end

    local p = werte.pid or {}
    local gachsen = {{"ROLL", 0}, {"NICK", 1}, {"HECK", 2}}
    for i = 1, 3 do   -- Gains je Achse: P I D F B O
        local x, w = chipLage(GAIN_CHIP, i)
        local y, h = GAIN_CHIP.y, GAIN_CHIP.h
        S.chip(x, y, w, h, i == 1 and "links" or nil)
        if i == 1 then x, w = 0, x + w end
        local a = gachsen[i]
        stil.beschriftungMittig(x + w / 2, y + 13, S.wort(a[1]), stil.WEISS, FONT_S)
        paar(x + 10, y + 36, "P", p["pid_" .. a[2] .. "_P"])
        paar(x + 62, y + 36, "I", p["pid_" .. a[2] .. "_I"])
        paar(x + 10, y + 58, "D", p["pid_" .. a[2] .. "_D"])
        paar(x + 62, y + 58, "F", p["pid_" .. a[2] .. "_F"])
        paar(x + 10, y + 80, "B", p["pid_" .. a[2] .. "_B"])
        if a[2] ~= 2 then paar(x + 62, y + 80, "O", p["pid_" .. a[2] .. "_O"]) end
    end

    balken(R, s, aktiv)
    stil.beschriftung(140, FUSS_Y, S.wort("RATE") .. " " .. (rate and tostring(rate) or "?") .. "   " .. (typ or ""), stil.WEISS, FONT_S)
    if werte.fehler ~= nil then stil.beschriftung(290, FUSS_Y, "MSP " .. S.wort(werte.fehler), stil.ROT, FONT_S) end
end

local function ereignis()   -- auf der Bankseite gibt es nichts zu tippen; jede Beruehrung gehoert trotzdem dem Theme
    return true
end

local function oeffnen()
    if t == nil then return false, "i18n_teile.lua fehlt" end
    if stil == nil then
        local chunk, g = H.laden(loadfile, "stil_teile.lua")
        if not chunk then return false, "stil_teile.lua laedt nicht: " .. tostring(g) end
        local ok, s = pcall(chunk, {nova = nova, laden = H.laden})
        if not ok or type(s) ~= "table" then return false, "stil_teile.lua bricht ab: " .. tostring(s) end
        stil = s
        chunk, g = H.laden(loadfile, "seite_teile.lua")
        if not chunk then stil = nil return false, "seite_teile.lua laedt nicht: " .. tostring(g) end
        ok, s = pcall(chunk, {H = H, stil = stil})
        if not ok or type(s) ~= "table" then stil = nil return false, "seite_teile.lua bricht ab: " .. tostring(s) end
        S = s
    end
    anstossen(H.stand() or {})
    return true
end

local function verlassen()
    stil, S = nil, nil
end

return {malen = malen, ereignis = ereignis, oeffnen = oeffnen, verlassen = verlassen, takt = takt, zurueck = KEINE_ZONE, seite = true}
