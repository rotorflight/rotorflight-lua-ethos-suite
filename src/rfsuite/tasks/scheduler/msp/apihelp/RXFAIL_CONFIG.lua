--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MAX_SUPPORTED_RC_CHANNEL_COUNT = 18

local help = {}

for i = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
    help["channel_" .. i .. "_mode"] = "Select how each channel behaves when signal is lost: Auto, Hold, or Set."
    help["channel_" .. i .. "_value"] = "Channel value used only when mode is Set."
end

return help
