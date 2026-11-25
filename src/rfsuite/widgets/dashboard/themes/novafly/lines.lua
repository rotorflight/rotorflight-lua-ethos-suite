-- Line colours of the nine cockpit colours, in the order of COLORS in cockpit.lua: the mid tone of a line, its bright
-- core and the background of the colour. frame.lua draws every line, arc and bar with them.
return {
    {mid = {29, 126, 208}, core = {153, 255, 255}, bg = {9, 10, 14}},   -- blue
    {mid = {203, 30, 159}, core = {255, 155, 255}, bg = {9, 10, 14}},   -- magenta
    {mid = {48, 204, 60}, core = {180, 255, 197}, bg = {9, 10, 14}},   -- green
    {mid = {203, 106, 23}, core = {255, 255, 143}, bg = {9, 10, 14}},   -- orange
    {mid = {203, 184, 15}, core = {255, 255, 133}, bg = {9, 10, 14}},   -- yellow
    {mid = {6, 38, 84}, core = {91, 136, 191}, bg = {1, 4, 7}},   -- carbon
    {mid = {4, 32, 24}, core = {42, 121, 106}, bg = {3, 6, 7}},   -- carbon green
    {mid = {43, 14, 59}, core = {126, 62, 141}, bg = {3, 3, 7}},   -- carbon violet
    {mid = {54, 12, 12}, core = {108, 26, 27}, bg = {1, 1, 1}},   -- carbon red
}
