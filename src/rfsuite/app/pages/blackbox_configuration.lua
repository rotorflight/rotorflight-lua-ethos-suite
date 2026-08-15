-- Controls -> Blackbox -> Configuration page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local blackboxPage = requireModule("app/pages/blackbox_edit_page.lua")

return blackboxPage.new({
  kind = "config",
  title = "@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_configuration)@",
})
