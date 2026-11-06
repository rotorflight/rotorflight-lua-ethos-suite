-- Setup -> ESC & Motors -> Forward Programming -> Goosky.
--
-- Goosky ESCs run AM32 firmware: same esc_signature (0xC2), EEPROM layout, pages and
-- handshake. This is the AM32 page under the Goosky brand, selectable with the Goosky
-- telemetry protocol (16, a firmware alias of BLHeli32 from API 12.10) or BLHeli32 itself.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local am32Page = requireModule("app/pages/esc_forward_am32.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.goosky.name)@"

local function open(opts)
  am32Page.open(opts, {pageTitle = PAGE_TITLE, logTag = "esc_goosky", summaryBrand = PAGE_TITLE})
end

return {open = open}
