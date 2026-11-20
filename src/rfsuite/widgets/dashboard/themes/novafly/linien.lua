-- Von einem Skript erzeugt aus den alten Cockpit-Bildern gfx/tacho_*.png - nicht von Hand aendern.
-- Je Bild (Reihenfolge wie BILDER in cockpit.lua): der Mittelton einer Linie (Mittel der Flanken der Linie oben, Zeilen 4 und 6),
-- ihr heller Kern (Zeile 5) und der Grund des Bilds (Zeile 150). rahmen.lua malt damit alle Linien, Bogen und Balken.
return {
    {mitte = {29, 126, 208}, kern = {153, 255, 255}, grund = {9, 10, 14}},   -- tacho_base.png
    {mitte = {203, 30, 159}, kern = {255, 155, 255}, grund = {9, 10, 14}},   -- tacho_magenta.png
    {mitte = {48, 204, 60}, kern = {180, 255, 197}, grund = {9, 10, 14}},   -- tacho_gruen.png
    {mitte = {203, 106, 23}, kern = {255, 255, 143}, grund = {9, 10, 14}},   -- tacho_orange.png
    {mitte = {203, 184, 15}, kern = {255, 255, 133}, grund = {9, 10, 14}},   -- tacho_gelb.png
    {mitte = {6, 38, 84}, kern = {91, 136, 191}, grund = {1, 4, 7}},   -- tacho_carbon.png
    {mitte = {4, 32, 24}, kern = {42, 121, 106}, grund = {3, 6, 7}},   -- tacho_carbon_gruen.png
    {mitte = {43, 14, 59}, kern = {126, 62, 141}, grund = {3, 3, 7}},   -- tacho_carbon_violett.png
    {mitte = {54, 12, 12}, kern = {108, 26, 27}, grund = {1, 1, 1}},   -- tacho_carbon_rot.png
}
