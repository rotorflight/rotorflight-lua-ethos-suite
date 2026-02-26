--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
FrSky telemetry slot to S.Port appId lookup.
Maps telemetry-config slot IDs to one or more SPORT appIds.

Update process:
1. Keep slot IDs aligned with FC telemetry config ordering.
2. Keep appIds aligned with sensor definitions in `frsky.lua`.
3. Use numeric hex constants (`0xNNNN`) to avoid runtime conversion.
]]

return {
    [1] = {0x5100},
    [3] = {0x0210},
    [4] = {0x0200},
    [5] = {0x5250},
    [6] = {0x0600},
    [7] = {0x5260},
    [8] = {0x0910},
    [11] = {0x51A0},
    [12] = {0x51A1},
    [13] = {0x51A2},
    [14] = {0x51A3},
    [15] = {0x51A4},
    [17] = {0x0218},
    [18] = {0x0208},
    [19] = {0x5258},
    [20] = {0x0508},
    [21] = {0x5268},
    [22] = {0x5269},
    [23] = {0x0418},
    [24] = {0x0419},
    [25] = {0x0219},
    [26] = {0x0229},
    [27] = {0x5128},
    [28] = {0x5129},
    [30] = {0x021A},
    [31] = {0x020A},
    [32] = {0x525A},
    [33] = {0x050A},
    [36] = {0x041A},
    [41] = {0x512B},
    [42] = {0x0211},
    [43] = {0x0901},
    [44] = {0x0902},
    [45] = {0x0900},
    [46] = {0x0201},
    [47] = {0x0222},
    [50] = {0x0401},
    [51] = {0x0402},
    [52] = {0x0400},
    [57] = {0x5210},
    [58] = {0x0100},
    [59] = {0x0110},
    [60] = {0x0500},
    [61] = {0x0501},
    [65] = {0x0730},
    [66] = {0x0730},
    [69] = {0x0700},
    [70] = {0x0710},
    [71] = {0x0720},
    [77] = {0x0800},
    [78] = {0x0820},
    [79] = {0x0840},
    [80] = {0x0830},
    [85] = {0x51D0},
    [86] = {0x51D1},
    [87] = {0x51D2},
    [88] = {0x5120},
    [89] = {0x5121},
    [90] = {0x5122},
    [91] = {0x5123},
    [92] = {0x5124},
    [93] = {0x5125},
    [95] = {0x5130},
    [96] = {0x5131},
    [99] = {0x5110, 0x5111}
}
