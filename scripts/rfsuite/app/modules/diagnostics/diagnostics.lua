local i18n = rfsuite.i18n.get
local enableWakeup = false

-- Local config table for in-memory edits
local config = {}


local function openPage(pageIdx, title, script)
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.diagnostics.name")
    )
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

end

return {
    openPage   = openPage,
    navButtons = {
        menu   = true,
        save   = false,
        reload = false,
        tool   = false,
        help   = false,
    },
    API = {},
}
