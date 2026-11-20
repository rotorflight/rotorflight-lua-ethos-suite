-- NovaFly-Cockpit als rfsuite-Theme: Name, eine Zustandsdatei fuer vor, im und nach dem Flug, das Menue mit der Farbe.
-- Gebaut fuer 480 x 320 (X18, X18S) und 800 x 480 (X20, X18R, X18RS): die Lage der Teile folgt dem Fenster, die Linien, Ecken
-- und der Absatz haben je Schirmgroesse ihr Mass (rahmen.lua). rfsuite 2.3.0 vergleicht minResolution mit dem Fenster seiner
-- Einstellungsseite (lcd.getWindowSize, auf der X18 472 x 287), nicht mit dem Schirm; ein groesseres Mindestmass nimmt das Theme aus der Liste.
return {name = "NovaFly", preflight = "zustand.lua", inflight = "zustand.lua", postflight = "zustand.lua", configure = "configure.lua", standalone = false,
        minResolution = {x = 472, y = 287}, maxResolution = {x = 800, y = 480}}
