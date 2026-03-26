--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local MAX_SUPPORTED_RC_CHANNEL_COUNT = 18

local help = {}

for i = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
    help["channel_" .. i .. "_mode"] = "@i18n(api.RXFAIL_CONFIG.channel_mode)@"
    help["channel_" .. i .. "_value"] = "@i18n(api.RXFAIL_CONFIG.channel_value)@"
end

return help
