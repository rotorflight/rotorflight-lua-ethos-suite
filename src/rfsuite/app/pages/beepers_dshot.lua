-- Controls -> Beepers -> ESC Beacon page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local beepersPage = requireModule("app/pages/beepers_page.lua")

local page = beepersPage.new({
  title = "@i18n(app.modules.beepers.name)@ / @i18n(app.modules.beepers.menu_dshot)@",
  tone = true,
  fields = {
    {bit = 1, maskField = "dshotBeaconOffFlags", label = "@i18n(app.modules.beepers.field_rx_lost)@"},
    {bit = 9, maskField = "dshotBeaconOffFlags", label = "@i18n(app.modules.beepers.field_rx_set)@"},
  },
})

return page
