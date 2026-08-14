-- PID Bandwidth profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced ->
-- PID Bandwidth -- see app/tool.lua.
--
-- Edits nine more MSP_PID_PROFILE fields (cmd 94/95, see
-- lib/msp_pid_profile.lua) that no other page touches yet: the gyro/
-- dterm/bterm cutoff frequencies, roll/pitch/yaw each. Matches the
-- original suite's own app/modules/profile_pidbandwidth/pidbandwidth.lua.
--
-- Layout simplified vs. the original in one respect: its own first row
-- label is literally its own page name ("PID Bandwidth") reused for the
-- gyro-cutoff group, presumably so the row reads naturally under a
-- generic-looking column header without a second, more specific label.
-- Reusing the page's own title as a row label directly beneath a header
-- that already shows that same title would just look redundant here, so
-- this uses a descriptive "Gyro Cutoff" label instead -- the same
-- information, without the doubled text.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building comes from app/field_layout.lua.

local requireModule = assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.pid_bandwidth.name)@"

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "pidbandwidth",
    mspModule = pidProfile,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_pid_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.pid_bandwidth.gyro_cutoff)@", {
    {title = "@i18n(app.modules.pid_bandwidth.roll)@", spec = {key = "gyro_cutoff_0"}},
    {title = "@i18n(app.modules.pid_bandwidth.pitch)@", spec = {key = "gyro_cutoff_1"}},
    {title = "@i18n(app.modules.pid_bandwidth.yaw)@", spec = {key = "gyro_cutoff_2"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.pid_bandwidth.dterm_cutoff)@", {
    {title = "@i18n(app.modules.pid_bandwidth.roll)@", spec = {key = "dterm_cutoff_0"}},
    {title = "@i18n(app.modules.pid_bandwidth.pitch)@", spec = {key = "dterm_cutoff_1"}},
    {title = "@i18n(app.modules.pid_bandwidth.yaw)@", spec = {key = "dterm_cutoff_2"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.pid_bandwidth.bterm_cutoff)@", {
    {title = "@i18n(app.modules.pid_bandwidth.roll)@", spec = {key = "bterm_cutoff_0"}},
    {title = "@i18n(app.modules.pid_bandwidth.pitch)@", spec = {key = "bterm_cutoff_1"}},
    {title = "@i18n(app.modules.pid_bandwidth.yaw)@", spec = {key = "bterm_cutoff_2"}},
  })

  runtime:loadInitial()
end

return {open = open}
