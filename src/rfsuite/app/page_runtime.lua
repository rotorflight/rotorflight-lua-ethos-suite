-- Shared "profile-scoped MSP editor page" machinery.
--
-- Extracted after app/pages/pids.lua and app/pages/pid_controller.lua
-- were built as near-verbatim hand copies of the identical pattern --
-- deliberately, so the actually-shared shape would come from two real
-- examples instead of being guessed at from one (see AGENTS.md's "Shared
-- page machinery" note for that reasoning). What follows is the distilled
-- result: several of these behaviors only exist because a live device
-- exposed a real bug in an earlier, simpler version -- see each method's
-- comment for the specific story rather than re-deriving it from scratch.
--
-- Owns: the loading/saving dialog (a nil-safe form.openProgressDialog
-- wrapper -- form.openProgressDialog() can return nil, which used to
-- crash), busy-state on the header's Save/Reload buttons, the full
-- load/save/reload/confirm cycle, the profile-switch-triggered
-- auto-reload (deferred to the page's own wakeup tick, since
-- form.openProgressDialog() only works reliably called from there, not
-- from a bus-subscriber callback nested inside the background task's own
-- wakeup), and long-press-ENTER-to-save (also deferred to that same
-- wakeup tick, and ordered so system.killEvents(KEY_ENTER_BREAK) has a
-- full cycle to take effect before any confirmation dialog exists to
-- receive a stray keypress).
--
-- Does NOT own: the field list, the row/grid layout, or which MSP codec
-- module is used -- those stay page-specific. A page using this:
--   1. local runtime = pageRuntime.new({...})
--   2. runtime:buildChrome()                    -- header, events, wakeup, bus
--   3. build its own fields against runtime.data[key], calling
--      runtime:registerField(key, widget) for each
--   4. runtime:loadInitial()
--
-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- every one of the nine pages reloads this ~500-line file fresh via
-- loadfile() on every single open, but PageRuntime itself is just a
-- class table (methods only); all real state lives in the fresh instance
-- PageRuntime.new() returns each call, so re-parsing/re-executing this
-- whole chunk on every navigation was pure waste with no correctness
-- benefit. Added after a live memory investigation confirmed the *bulk*
-- of this rebuild's observed RAM growth is an Ethos platform trait (the
-- `form` widget system itself retaining something per created button/
-- field, outside Lua's own GC reachability -- confirmed by checking that
-- rotorflight-lua-ethos-suite shows the same symptom under the same
-- rebuild-every-navigation pattern) that no script-side change can
-- eliminate -- but redundant reloading of a whole 500-line stateless
-- module on every page open is a separate, real, avoidable cost this
-- rebuild's own code controls. See AGENTS.md's "Memory stats printing"
-- section for the full trace.
if package.loaded["rfsuite.app.page_runtime"] then
  return package.loaded["rfsuite.app.page_runtime"]
end

local bus = assert(loadfile("lib/bus.lua"))()
local eeprom = assert(loadfile("lib/msp_eeprom.lua"))()
local reboot = assert(loadfile("lib/msp_reboot.lua"))()
local closeKey = assert(loadfile("app/close_key.lua"))()
local header = assert(loadfile("app/header.lua"))()
local memstats = assert(loadfile("lib/memstats.lua"))()
local debugLog = assert(loadfile("lib/debug_log.lua"))()
local progressDialog = assert(loadfile("app/progress_dialog.lua"))()

-- Generic dialog/progress text, matching rotorflight-lua-ethos-suite's own
-- actual strings (app/tasks.lua's triggerSaveDialogs()/triggerReloadDialogs(),
-- app/lib/ui.lua's progressDisplay() defaults) rather than a bespoke
-- per-page message -- self-caught rationalization: earlier versions of
-- this rebuild had each page supply its own save/reload confirmation text
-- ("Save PIDs to the flight controller?", "Save PID Controller settings to
-- the flight controller?", ...), which is exactly the kind of pointless
-- duplication the original doesn't have -- it shows the same confirmation
-- for every page's Save, and the same for every page's Reload. i18n tags
-- are resolved by a build-time text substitution (see
-- .vscode/scripts/resolve_i18n_tags.py), not at Lua runtime.
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.msg_reload_settings)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local MSG_SAVING_TITLE = "@i18n(app.msg_saving)@"
local MSG_SAVING_BODY = "@i18n(app.msg_saving_settings)@"
local MSG_SAVE_FAILED_TITLE = "@i18n(app.msg_save_failed_title)@"
local MSG_SAVE_FAILED_BODY = "@i18n(app.msg_save_failed_body)@"
-- EEPROM_WRITE is rejected by the FC while armed -- not a real failure, the
-- change already sits in RAM and commits on disarm. Matches the original
-- suite's own trap (app/tasks.lua's armedSaveWarning(), fed by
-- lib/utils.lua's "armed_blocked" reason from queueEepromWrite()): shown
-- instead of MSG_SAVE_FAILED_* when the EEPROM write fails while
-- self.isArmed is true (see performSave()'s errorHandler below).
local MSG_SAVE_ARMED_TITLE = "@i18n(app.msg_save_not_commited)@"
local MSG_SAVE_ARMED_BODY = "@i18n(app.msg_please_disarm_to_save_warning)@"

local PageRuntime = {}
PageRuntime.__index = PageRuntime

local function clearTable(t)
  if not t then return end
  for k in pairs(t) do
    t[k] = nil
  end
end

-- config: {
--   pageTitle,                  -- e.g. "PIDs" -- shown in the header only (dialogs are all generic, see below)
--   logTag,                     -- e.g. "pids" -- debug print prefix; defaults to pageTitle
--   mspModule,                  -- single-source pages: buildReadMessage(onData,onError) / buildWriteMessage(data,onWritten,onError)
--   sources,                    -- multi-source pages instead of mspModule: {{key=, mspModule=}, ...} -- see below.
--                               -- A source's mspModule may omit buildWriteMessage entirely if it's
--                               -- genuinely read-only (e.g. lib/msp_status.lua) -- performSave() skips
--                               -- writing that source rather than erroring.
--   opts,                       -- page.open(opts)'s own argument (onBack/setEventHandler/setWakeupHandler/setCleanupHandler)
--   profileField,               -- which "session.update" field drives the auto-reload; defaults "pidProfile"
--   unloadPackageKeys,          -- optional package.loaded keys for page-owned modules to drop on dispose
--   initialData,                 -- optional single-source data already read before field construction.
--                               -- Used by ESC forward pages so unsupported model-specific fields are
--                               -- never built in the first place.
--   onLoaded,                   -- optional; called every time loadData() succeeds (first load, manual
--                               -- Reload, and the automatic profile-switch reload alike) -- for a page's
--                               -- own UI that needs to react to freshly-loaded data beyond what a
--                               -- registered field's getter already covers (e.g. app/pages/rates.lua's
--                               -- rate-table-name status line, a plain static text with no getter of its
--                               -- own for Ethos to call). Deliberately NOT the same thing as relying on
--                               -- some other field's getter running as a side effect -- self-caught bug,
--                               -- found live: that only actually ran once a field was interacted with,
--                               -- not the instant data arrived, since Ethos doesn't necessarily re-invoke
--                               -- every field's getter just because loadData() re-enabled them.
--   beforeSave,                 -- optional; called at the start of performSave(), after the pilot
--                               -- confirms but before any MSP_SET_* write is built.
--   extraSaveMessage,           -- optional text appended to the generic save confirmation body.
--   eepromWrite,                 -- optional; defaults true. Set false for direct targets whose original
--                               -- page writes its own non-FC storage and does not request MSP_EEPROM_WRITE.
--   onTool,                     -- optional; enables the header Tool button and runs page-specific
--                               -- actions from the app tool's own callback context.
--   onWakeup,                   -- optional; called from the page_runtime wakeup handler after its own
--                               -- deferred dialog/reload work.
--   onPaint,                    -- optional; called from app/tool.lua's paint callback while page is open.
--   onDispose,                  -- optional; called from dispose() before fields/data are cleared.
--   rebootAfterSave,            -- optional; if true, performSave() publishes lib/msp_reboot.lua's
--                               MSP_REBOOT write right after the EEPROM write acks, matching
--                               rotorflight-lua-ethos-suite's own rebootFc() (called from the same
--                               spot). Skipped if self.isArmed == true (see onSessionUpdate() below,
--                               and lib/msp_reboot.lua's own comment for why this is the only safety
--                               gate on that command) -- the save itself (and its EEPROM commit)
--                               still completes either way; only the automatic reboot is withheld,
--                               same as the original's own validateWrite() blocking just the REBOOT
--                               API call, not the rest of the save. May also be a function returning
--                               true/false for pages whose reboot need is data-dependent.
-- }
-- No per-page save/reload confirmation text -- confirmSave()/confirmReload()
-- always show the same generic dialog for every page, matching the
-- original suite (see the MSG_* constants above).
--
-- Single- vs multi-source data shape: a page passing plain `mspModule`
-- (one MSP command) gets a *flat* `runtime.data[fieldKey]`, same as
-- before multi-source support existed -- app/pages/pids.lua and
-- app/pages/pid_controller.lua both rely on this and needed no changes
-- when this was added. A page passing `sources` (multiple MSP commands
-- combined into one page, e.g. app/pages/tail_rotor.lua reading both
-- PID_PROFILE and GOVERNOR_PROFILE, matching the original's own
-- profile_tailrotor module) gets a *nested* `runtime.data[sourceKey][fieldKey]`
-- instead, one sub-table per source -- there is no plausible field-name
-- collision to hide by flattening, and staying nested keeps it obvious
-- which MSP command a field's write actually lands on.
function PageRuntime.new(config)
  local self = setmetatable({}, PageRuntime)
  self.pageTitle = assert(config.pageTitle)
  self.logTag = config.logTag or config.pageTitle
  self.sources = config.sources or {{key = "default", mspModule = assert(config.mspModule)}}
  self.singleSource = (#self.sources == 1) and not config.sources
  self.opts = assert(config.opts)
  self.profileField = config.profileField or "pidProfile"
  self.unloadPackageKeys = config.unloadPackageKeys
  self.onLoaded = config.onLoaded
  self.beforeSave = config.beforeSave
  self.extraSaveMessage = config.extraSaveMessage
  self.eepromWrite = config.eepromWrite ~= false
  self.onTool = config.onTool
  self.onWakeup = config.onWakeup
  self.onPaint = config.onPaint
  self.onDispose = config.onDispose
  self.rebootAfterSave = config.rebootAfterSave
  self.initialData = config.initialData
  -- Kept in sync from every "session.update" (see onSessionUpdate()
  -- below) purely for rebootAfterSave's own safety gate -- nil until the
  -- first update arrives (or if the "armflags" telemetry sensor has never
  -- resolved), treated the same as "not armed" by that gate, matching
  -- the original's own resolveArmedState() fallback.
  self.isArmed = nil

  -- Self-caught bug, found live: for multi-source pages, self.data[key]
  -- sub-tables didn't exist until that source's first read completed --
  -- but Ethos calls a just-built field's getValue() on its very first
  -- paint, before loadInitial() has gotten anywhere, so
  -- field_layout.lua's dataTable(runtime, spec) indexed a still-nil
  -- self.data["pid"]/self.data["governor"] and crashed ("attempt to
  -- index a nil value") on every field, repeatedly, until that source's
  -- read actually landed. Pre-creating an empty sub-table per source
  -- here means dataTable() always has a real table to index into --
  -- fields just read/display nil (blank/zero) until real data arrives,
  -- same as a single-source page's fields do before its own first read.
  self.data = {}
  if not self.singleSource then
    for _, source in ipairs(self.sources) do
      self.data[source.key] = {}
    end
  end
  if self.singleSource and self.initialData then
    self.data = self.initialData
  end
  self.dataRef = {data = self.data}
  self.controlRef = {runtime = self}
  self.loaded = false
  -- True once any registered field's setter has run since the last
  -- successful load/save -- gates the header Save button so it only
  -- lights up once the pilot has actually changed something, matching
  -- rotorflight-lua-ethos-suite's own save_dirty_only behavior. See
  -- markDirty()/setDirty()/updateSaveEnabled() below and
  -- app/field_layout.lua's buildField(), which is what actually calls
  -- markDirty() for every field this runtime owns.
  self.dirty = false
  self.busy = false
  self.fields = {}
  self.activeDialog = nil
  self.headerHandle = nil
  self.lastProfile = nil
  -- The profile that was active when data was last (re)loaded -- nil
  -- until the first loadData() completes, so the initial session.update
  -- replay (see lib/bus.lua's subscribe()) only anchors lastProfile
  -- without triggering a spurious reload before the page has loaded once.
  self.loadedProfile = nil
  -- Set by onSessionUpdate/the event handler, consumed by the wakeup
  -- handler wired in buildChrome() -- see that method's comment for why
  -- neither flag's actual dialog can open synchronously from where it's set.
  self.pendingReload = false
  self.pendingSaveConfirm = false
  -- Set by performSave()'s own write/EEPROM error handlers, consumed by
  -- the wakeup handler alongside pendingReload/pendingSaveConfirm --
  -- opening the failure dialog straight from those handlers would be the
  -- same class of bug documented on showDialog()/confirmSave() above:
  -- they fire from the MSP queue's own callback chain (nested inside the
  -- background task's wakeup), not this page's. Holds the failure reason
  -- string (or true if none was given) until the wakeup tick opens the
  -- dialog.
  self.pendingSaveError = nil
  -- Same idea, set instead of pendingSaveError when the EEPROM write fails
  -- while self.isArmed is true -- see MSG_SAVE_ARMED_*'s own comment above.
  self.pendingSaveArmed = false
  -- Same idea, for onLoaded (see its own config comment above) -- set by
  -- loadData()'s success branch, consumed by the wakeup handler alongside
  -- pendingReload/pendingSaveConfirm. See that handler's own comment for
  -- why onLoaded doesn't just get called directly from loadData().
  self.pendingOnLoaded = false
  self.pendingUiActions = {}
  self.disposed = false

  -- Diagnostic checkpoint, paired with goBack()'s own "<logTag> exit"
  -- print: a live log showed the *exit* figure creeping up release over
  -- release even across repeat visits to the very same page, surviving a
  -- real collectgarbage("collect") at app.close() -- something is being
  -- retained, not just GC noise. This print, taken the instant a brand
  -- new PageRuntime exists (before buildChrome()/any fields), isolates
  -- "did the previous visit to this exact page leave anything behind" --
  -- compare this number against that same page's own last "exit" print
  -- from its prior visit.
  memstats.print(self.logTag .. " open")

  return self
end

function PageRuntime:log(msg)
  debugLog.print("[" .. (self.logTag or "page") .. "] " .. msg)
end

function PageRuntime:queueUiAction(action)
  if self.disposed or not action then return end
  self.pendingUiActions[#self.pendingUiActions + 1] = action
end

function PageRuntime:runPendingUiActions()
  local actions = self.pendingUiActions
  if not actions or #actions == 0 then return end
  self.pendingUiActions = {}
  for i = 1, #actions do
    if self.disposed then return end
    actions[i]()
  end
end

-- Small animated dialog shown while an MSP round-trip (read or save) is
-- in flight. Purely cosmetic -- but see the nil-guard below, which is not.
--
-- Self-caught bug, found live: form.openProgressDialog() can return nil
-- -- observed right as a profile-switch-triggered reload started, exact
-- trigger conditions unconfirmed. Without this guard, the unconditional
-- dialog:value() calls crashed with "attempt to index a nil value (local
-- 'dialog')" -- and since that happened inside showDialog(), called
-- *before* the actual msp.request publish in loadData(), the read never
-- even got sent, leaving the just-disabled fields dimmed forever with no
-- request in flight to ever re-enable them.
function PageRuntime:openLoadingDialog(title, message)
  local logTag = self.logTag
  local dialog = progressDialog.open({
    title = title,
    message = message,
    speed = progressDialog.SPEED.DEFAULT,
  })
  if not dialog then
    debugLog.print("[" .. logTag .. "] openLoadingDialog: form.openProgressDialog returned nil -- continuing without the loading animation")
    return nil
  end
  return dialog
end

function PageRuntime:showDialog(title, message)
  self.activeDialog = self:openLoadingDialog(title, message)
end

-- Closes whichever dialog (read or save) is currently open, if any, and
-- re-focuses a button -- Ethos has a bug where the form loses focus
-- entirely once a form.openProgressDialog closes, so something must
-- always be re-focused afterwards (see app/header.lua's focus* fns).
-- `focusFn` should be whichever button the pilot actually pressed to
-- trigger this dialog; when nothing specific triggered it (the page's
-- initial load), it defaults to focusMenu.
function PageRuntime:closeDialog(focusFn)
  local dialog = self.activeDialog
  if not dialog then return end
  dialog:value(100)
  dialog:close()
  self.activeDialog = nil
  if focusFn then
    focusFn()
  elseif self.headerHandle then
    self.headerHandle.focusMenu()
  end
end

-- Save and Reload both touch the same `data`/field state, so only one may
-- run at a time -- disable both while either is in flight.
function PageRuntime:setBusy(busy)
  if self.disposed or not self.headerHandle then return end
  self.busy = busy and true or false
  self:updateSaveEnabled()
  self.headerHandle.setReloadEnabled(not busy)
end

-- Save is only ever enabled once the page has a completed load, isn't
-- mid save/reload, and has unsaved changes -- see self.dirty's own
-- comment in PageRuntime.new().
function PageRuntime:updateSaveEnabled()
  if self.disposed or not self.headerHandle then return end
  self.headerHandle.setSaveEnabled(self.loaded and self.dirty and not self.busy)
end

-- Called by every field this runtime owns (see app/field_layout.lua's
-- buildField()) the moment its setter actually runs -- i.e. only on a
-- real pilot edit, never during initial field construction/population,
-- since Ethos only invokes a field's setter on user interaction, not
-- when the field is built or its getter is polled for display.
function PageRuntime:markDirty()
  if self.disposed or self.dirty then return end
  self.dirty = true
  self:updateSaveEnabled()
end

-- Explicit reset, used once a load/save actually lands the page's data
-- in sync with the flight controller again (see loadData()'s success
-- branch and performSave()'s writeSource() success branches below).
function PageRuntime:setDirty(dirty)
  if self.disposed then return end
  self.dirty = dirty and true or false
  self:updateSaveEnabled()
end

-- Call once per field the page builds, right after creating it. Starts
-- disabled -- loadInitial()'s first read enables it once real data exists.
function PageRuntime:registerField(key, field)
  if self.disposed then return end
  field:enable(false)
  self.fields[key] = field
end

-- Reads every source in self.sources, one at a time (the MSP queue is a
-- single-flight FIFO anyway -- see tasks/msp/queue.lua -- so sequential
-- chaining costs nothing real and avoids ever having to reconcile two
-- concurrent in-flight reads' success/failure ordering). Single-source
-- pages (plain `mspModule`) still see a flat `self.data`, unchanged from
-- before multi-source support existed; multi-source pages get
-- `self.data[source.key]` per source -- see PageRuntime.new()'s comment.
-- The loading dialog is always the same generic MSG_LOADING_*, whether
-- this is the page's very first read, a manual Reload, or the automatic
-- profile-switch reload -- previously each of those three passed its own
-- custom message ("Reading from flight controller...", "Re-reading...",
-- "Profile changed -- reloading..."), which is the same needless
-- per-call duplication confirmSave()/confirmReload() used to have.
function PageRuntime:loadData(focusFn)
  if self.disposed then return end

  -- Remembered so a failed read can restore the fields to whatever state
  -- they were actually in beforehand (see the error branch below) rather
  -- than leaving them disabled forever -- self-caught bug: that branch
  -- used to only close the dialog, never re-enable the fields, so a read
  -- that timed out (plausible right when a profile-switch event and its
  -- telemetry blip coincide) left the page permanently dimmed with no way
  -- to recover short of leaving and reopening it.
  local wasLoaded = self.loaded
  self:setBusy(true)
  self.loaded = false
  for _, field in pairs(self.fields) do
    field:enable(false)
  end
  self:showDialog(MSG_LOADING_TITLE, MSG_LOADING_BODY)

  local self_ = self
  local function readSource(index)
    if self_.disposed then return end
    if index > #self_.sources then
      self_:queueUiAction(function()
        self_:log("loadData: read succeeded")
        self_.loaded = true
        -- Anchor to whatever profile is active *now* -- see loadedProfile's
        -- declaration above for why this is what unblocks reload-on-change.
        self_.loadedProfile = self_.lastProfile
        for _, field in pairs(self_.fields) do
          field:enable(true)
        end
        -- Freshly-read data matches the flight controller again -- clears
        -- any dirty state left over from edits abandoned by a manual
        -- Reload, or from the automatic profile-switch reload discarding
        -- whatever was on-screen for the old profile.
        self_:setDirty(false)
        self_:setBusy(false)
        self_:closeDialog(focusFn)
        if self_.onLoaded then
          self_.pendingOnLoaded = true
        end
      end)
      return
    end

    local source = self_.sources[index]
    self_:log("loadData: publishing msp.request (read " .. source.key .. ")")
    bus.publish("msp.request", source.mspModule.buildReadMessage(function(values)
      if self_.disposed then return end
      if self_.singleSource then
        self_.data = values
        self_.dataRef.data = values
      else
        self_.data[source.key] = values
      end
      readSource(index + 1)
    end, function(reason)
      if self_.disposed then return end
      self_:queueUiAction(function()
        self_:log("loadData: read FAILED (" .. source.key .. "): " .. tostring(reason))
        self_.loaded = wasLoaded
        if wasLoaded then
          for _, field in pairs(self_.fields) do
            field:enable(true)
          end
        end
        self_:setBusy(false)
        self_:closeDialog(focusFn)
      end)
    end))
  end

  readSource(1)
end

-- The actual MSP write(s) (+ a single EEPROM commit at the end, not one
-- per source -- an EEPROM write commits everything at once regardless of
-- how many MSP commands changed), split out from confirmSave() so the
-- confirmation prompt sits in front of it rather than being folded into
-- the same closure. `self.data` (or `self.data[source.key]`) is whatever
-- loadData() last read -- fields the page never displays round-trip
-- unchanged rather than being clobbered to 0, as long as each source's
-- MSP module always encodes/decodes its full wire struct (see e.g.
-- lib/msp_pid_profile.lua).
function PageRuntime:performSave(focusFn)
  if self.disposed then return end

  if self.beforeSave then
    self.beforeSave(self)
  end

  self:setBusy(true)
  self:showDialog(MSG_SAVING_TITLE, MSG_SAVING_BODY)

  local self_ = self

  local function finishSave()
    if self_.disposed then return end
    self_:queueUiAction(function()
      self_:setBusy(false)
      self_:closeDialog(focusFn)
    end)
  end

  -- Only called from the EEPROM write's own success path (never on
  -- failure -- matches the original's own saveDone(), which is what
  -- calls rebootFc(), never saveFailed()). Skips (but still lets the
  -- rest of the save stand -- the EEPROM commit above already
  -- happened) if `self.isArmed == true`; see rebootAfterSave's own
  -- config comment and lib/msp_reboot.lua's for why this is the one
  -- safety gate on that command.
  local function maybeReboot()
    local shouldReboot = self_.rebootAfterSave
    if type(shouldReboot) == "function" then
      shouldReboot = shouldReboot(self_)
    end
    if not shouldReboot then return end
    if self_.isArmed == true then
      self_:log("performSave: rebootAfterSave skipped (isArmed == true)")
      return
    end
    self_:log("performSave: publishing MSP_REBOOT")
    bus.publish("msp.request", reboot.buildWriteMessage(function()
      self_:log("performSave: MSP_REBOOT acked")
    end, function(reason)
      self_:log("performSave: MSP_REBOOT failed: " .. tostring(reason))
    end))
  end

  local function writeSource(index)
    if self_.disposed then return end
    if index > #self_.sources then
      if not self_.eepromWrite then
        self_:setDirty(false)
        finishSave()
        maybeReboot()
        return
      end
      bus.publish("msp.request", eeprom.buildWriteMessage(function()
        self_:setDirty(false)
        finishSave()
        maybeReboot()
      end, function(reason)
        self_:log("performSave: EEPROM_WRITE failed: " .. tostring(reason))
        if self_.isArmed == true then
          self_.pendingSaveArmed = true
        else
          self_.pendingSaveError = reason or true
        end
        finishSave()
      end))
      return
    end

    local source = self_.sources[index]
    -- A source whose mspModule has no buildWriteMessage at all (e.g.
    -- lib/msp_status.lua -- MSP_STATUS is genuinely read-only, firmware
    -- has no MSP_SET_STATUS) is skipped rather than written -- lets a
    -- multi-source page mix writable and read-only sources (e.g.
    -- app/pages/configuration.lua reading MSP_STATUS just for the live
    -- gyro rate its own PID-loop-speed choice field's labels need)
    -- without page_runtime.lua needing a separate "read-only source"
    -- config flag; a codec simply not defining the write half already
    -- says everything needed.
    if not source.mspModule.buildWriteMessage then
      writeSource(index + 1)
      return
    end

    local values = self_.singleSource and self_.data or self_.data[source.key]
    bus.publish("msp.request", source.mspModule.buildWriteMessage(values, function()
      if self_.disposed then return end
      writeSource(index + 1)
    end, function(reason)
      self_:log("performSave: write FAILED (" .. tostring(source.key) .. "): " .. tostring(reason))
      self_.pendingSaveError = reason or true
      finishSave()
    end))
  end

  writeSource(1)
end

-- Mirrors the original suite's app/tasks.lua:288-314 (`save_confirm`
-- preference): before actually writing to the flight controller, confirm
-- with the pilot. This rebuild has no preferences/settings subsystem to
-- gate that on, so it's unconditional here rather than invented just for
-- this one toggle -- the original's own default expectation for
-- something that writes flight-critical FC memory. Title/message/button
-- labels are the same generic MSG_SAVE_*/BTN_* for every page -- see the
-- constants' own comment above for why per-page text was dropped.
function PageRuntime:confirmSave(focusFn)
  if self.disposed then return end

  local controlRef = self.controlRef
  local message = MSG_SAVE_BODY
  if self.extraSaveMessage then
    message = message .. "\n\n" .. self.extraSaveMessage
  end
  form.openDialog({
    title = MSG_SAVE_TITLE,
    message = message,
    buttons = {
      {label = BTN_OK, action = function()
        local runtime = controlRef and controlRef.runtime
        if not runtime or runtime.disposed then return true end
        runtime:performSave(focusFn)
        return true
      end},
      {label = BTN_CANCEL, action = function() return true end},
    },
    wakeup = function() end,
    paint = function() end,
  })
end

-- Shown from the wakeup tick (see pendingSaveError's own comment above)
-- when any write in performSave()'s chain -- a source's MSP_SET_* or the
-- final EEPROM_WRITE -- comes back with an error instead of an ack.
-- Previously that failure just closed the saving dialog with nothing
-- shown to the pilot: the FC could reject EEPROM_WRITE outright and the
-- save would silently no-op. Armed-FC rejections are routed to
-- showSaveArmed() below instead, since that's not actually a failure.
function PageRuntime:showSaveError(focusFn)
  if self.disposed then return end

  form.openDialog({
    title = MSG_SAVE_FAILED_TITLE,
    message = MSG_SAVE_FAILED_BODY,
    buttons = {
      {label = BTN_OK, action = function()
        if focusFn then focusFn() end
        return true
      end},
    },
    wakeup = function() end,
    paint = function() end,
  })
end

-- Shown from the wakeup tick instead of showSaveError() when the EEPROM
-- write failed while self.isArmed was true. Not a real failure -- the
-- FC firmware rejects EEPROM_WRITE outright while armed (flight-critical
-- memory), but the values just written via MSP_SET_* already sit in RAM
-- and commit for real on disarm. Matches the original suite's own
-- armedSaveWarning() trap (app/tasks.lua).
function PageRuntime:showSaveArmed(focusFn)
  if self.disposed then return end

  form.openDialog({
    title = MSG_SAVE_ARMED_TITLE,
    message = MSG_SAVE_ARMED_BODY,
    buttons = {
      {label = BTN_OK, action = function()
        if focusFn then focusFn() end
        return true
      end},
    },
    wakeup = function() end,
    paint = function() end,
  })
end

-- Mirrors the original's `reload_confirm` preference (app/tasks.lua:414-
-- 441) the same way confirmSave() mirrors `save_confirm`. Only ever
-- called for the *manual* on-screen Reload button (see buildChrome()) --
-- the original distinguishes a prompted `triggerReload` from a silent
-- `triggerReloadNoPrompt` used by automatic paths, and this runtime's own
-- automatic profile-switch reload (pendingReload, see the wakeup handler
-- in buildChrome()) is exactly that silent case -- it must not stop and
-- wait on a dialog the pilot never asked for.
function PageRuntime:confirmReload(focusFn)
  if self.disposed then return end

  local controlRef = self.controlRef
  form.openDialog({
    title = MSG_RELOAD_TITLE,
    message = MSG_RELOAD_BODY,
    buttons = {
      {label = BTN_OK, action = function()
        local runtime = controlRef and controlRef.runtime
        if not runtime or runtime.disposed then return true end
        runtime:loadData(focusFn)
        return true
      end},
      {label = BTN_CANCEL, action = function() return true end},
    },
    wakeup = function() end,
    paint = function() end,
  })
end

-- Mirrors the original's wakeup() (title suffix): "<pageTitle> #<profile>"
-- once the active profile is known.
function PageRuntime:updateTitle()
  if self.disposed or not self.headerHandle then return end
  if self.lastProfile ~= nil then
    self.headerHandle.setTitle(self.pageTitle .. " #" .. self.lastProfile)
  else
    self.headerHandle.setTitle(self.pageTitle)
  end
end

-- Mirrors the original's refreshOnProfileChange: reload once the active
-- profile actually changes out from under an already-loaded page. Skipped
-- while a save/reload is already in flight (activeDialog ~= nil) -- it'll
-- be caught on the next session.update once that clears, same as
-- app/tasks.lua's own profileRateChangeDetection() skipping while
-- app.dialogs.saveDisplay/progressDisplay is set.
--
-- Self-caught bug, found live: this used to call loadData() directly from
-- here. This handler runs synchronously inside tasks/session.lua's
-- bus.publish("session.update", ...), i.e. nested inside the *background
-- task's* own wakeup call stack -- not this page's. Plain field/title
-- updates (`:value()`, `:enable()`) worked fine from there (confirmed
-- live), but form.openProgressDialog() specifically returned nil every
-- time when called from that context. So this only sets a flag now; the
-- actual loadData() call happens from the wakeup handler wired in
-- buildChrome(), which the app tool only calls as part of *its own*
-- registered wakeup -- the proper context for spawning new UI.
function PageRuntime:onSessionUpdate(update)
  if self.disposed then return end

  self.isArmed = update.isArmed

  local previous = self.lastProfile
  self.lastProfile = update[self.profileField]
  self:updateTitle()

  if self.lastProfile ~= previous then
    self:log("session.update " .. self.profileField .. " " .. tostring(previous)
      .. " -> " .. tostring(self.lastProfile) .. " (loadedProfile="
      .. tostring(self.loadedProfile) .. ", loaded=" .. tostring(self.loaded)
      .. ", activeDialog=" .. tostring(self.activeDialog ~= nil) .. ")")
  end

  if self.lastProfile ~= nil and self.loadedProfile ~= nil
      and self.lastProfile ~= self.loadedProfile
      and self.loaded and not self.activeDialog then
    self:log("reload pending: profile " .. tostring(self.loadedProfile)
      .. " -> " .. tostring(self.lastProfile))
    self.pendingReload = true
  end
end

-- Every page (all nine, including app/pages/pids.lua) funnels through
-- here to leave -- Back key/EXIT key/on-screen Menu button all end up
-- calling this same method (see buildChrome() and header.lua's onBack
-- below) -- so it's the one place to see a "this module is exiting" RAM
-- snapshot for any of them, without touching each page individually.
function PageRuntime:goBack()
  local logTag = self.logTag or "page"
  memstats.print(logTag .. " exit")
  local onBack = self.opts and self.opts.onBack
  self:dispose()
  if onBack then
    onBack()
  end
  collectgarbage("collect")
  memstats.print(logTag .. " after back")
end

function PageRuntime:dispose()
  if self.disposed then return end
  self.disposed = true

  if self.sessionHandler then
    bus.unsubscribe("session.update", self.sessionHandler)
  end
  if self.opts and self.opts.setWakeupHandler then
    self.opts.setWakeupHandler(nil)
  end
  if self.opts and self.opts.setEventHandler then
    self.opts.setEventHandler(nil)
  end
  if self.opts and self.opts.setPaintHandler then
    self.opts.setPaintHandler(nil)
  end
  if self.opts and self.opts.setCleanupHandler then
    self.opts.setCleanupHandler(nil)
  end
  self:closeDialog()

  if self.onDispose then
    self.onDispose(self)
  end

  local fieldLayout = package.loaded["rfsuite.app.field_layout"]
  if fieldLayout and fieldLayout.releaseRuntime then
    fieldLayout.releaseRuntime(self)
  end

  if self.fields then
    for _, field in pairs(self.fields) do
      if field and field.enable then
        pcall(function() field:enable(false) end)
      end
    end
    clearTable(self.fields)
  end

  local oldData = self.data
  self.data = {}
  if self.dataRef then
    self.dataRef.data = self.data
  end
  if oldData then
    if self.singleSource then
      clearTable(oldData)
    elseif self.sources then
      for _, source in ipairs(self.sources) do
        self.data[source.key] = {}
        clearTable(oldData[source.key])
      end
      clearTable(oldData)
    end
  end

  self.sources = nil
  self.opts = nil
  self.headerHandle = nil
  self.sessionHandler = nil
  self.activeDialog = nil
  self.onLoaded = nil
  self.beforeSave = nil
  self.onTool = nil
  self.onWakeup = nil
  self.onPaint = nil
  self.onDispose = nil
  self.loaded = false
  self.dirty = false
  self.busy = false
  self.lastProfile = nil
  self.loadedProfile = nil
  self.initialData = nil
  self.pendingReload = false
  self.pendingSaveConfirm = false
  self.pendingSaveError = nil
  self.pendingSaveArmed = false
  self.pendingOnLoaded = false
  if self.pendingUiActions then
    clearTable(self.pendingUiActions)
    self.pendingUiActions = nil
  end
  if self.controlRef then
    self.controlRef.runtime = nil
    self.controlRef = nil
  end
  self.dataRef = nil

  if self.unloadPackageKeys then
    for _, key in ipairs(self.unloadPackageKeys) do
      package.loaded[key] = nil
    end
    self.unloadPackageKeys = nil
  end

  memstats.print((self.logTag or "page") .. " disposed")
end

-- Builds the header (Menu/Save/Reload/Tool row), wires the physical Back
-- key + long-press-ENTER-to-save event handling, wires the per-tick
-- wakeup handler that consumes pendingReload/pendingSaveConfirm, and
-- subscribes to "session.update" for the profile-switch auto-reload.
--
-- Call once, right after the page's own form.clear() and before building
-- any of its own fields -- loadInitial() (called after those fields are
-- registered) is what actually kicks off the first read.
function PageRuntime:buildChrome()
  local opts = self.opts
  local controlRef = self.controlRef

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      local runtime = controlRef.runtime
      if not runtime then return false end
      -- Mirrors the original's app/app.lua:390-417: a long-press of the
      -- physical ENTER/rotary key saves, exactly like pressing the
      -- on-screen Save button, from anywhere on the page. Consumes the
      -- event either way so Ethos's own default long-press behavior on
      -- whatever field happens to have focus never fires instead.
      --
      -- Self-caught bug, found live: this used to call confirmSave()
      -- (opens form.openDialog) directly, right here, before
      -- system.killEvents(KEY_ENTER_BREAK) -- so the dialog (and its
      -- focused OK button) existed *before* the kill had any chance to
      -- take effect, and the still-in-flight release of the physical key
      -- (it's still physically down when KEY_ENTER_LONG fires) landed on
      -- OK and auto-confirmed the save the instant the dialog appeared.
      -- The original never makes this mistake because it never opens its
      -- confirmation dialog synchronously from inside event() at all --
      -- only kills the event and sets a flag there; the dialog opens
      -- later, from a separate task tick. Mirrored here: this only kills
      -- the event and sets pendingSaveConfirm; confirmSave() itself runs
      -- from the wakeup handler below, same as pendingReload.
      if value == KEY_ENTER_LONG then
        system.killEvents(KEY_ENTER_BREAK)
        if runtime.loaded and not runtime.activeDialog then
          runtime.pendingSaveConfirm = true
        end
        return true
      end
      if not closeKey.shouldHandleClose(category, value) then return false end
      runtime:goBack()
      return true
    end)
  end

  self.headerHandle = header.build(self.pageTitle, {
    onBack = function()
      local runtime = controlRef.runtime
      if runtime then runtime:goBack() end
    end,
    onSave = function()
      local runtime = controlRef.runtime
      if not runtime or not runtime.loaded then return end
      runtime:confirmSave(runtime.headerHandle.focusSave)
    end,
    onReload = function()
      local runtime = controlRef.runtime
      if runtime then runtime:confirmReload(runtime.headerHandle.focusReload) end
    end,
    onTool = self.onTool and function()
      local runtime = controlRef.runtime
      if runtime and runtime.onTool then
        runtime:onTool(runtime.headerHandle.focusTool)
      end
    end or nil,
  })
  self:setBusy(true)

  -- Placed after headerHandle exists: bus.subscribe() replays the last
  -- "session.update" synchronously (see lib/bus.lua), and updateTitle()
  -- needs headerHandle to already be valid when that replay fires.
  self.sessionHandler = function(update)
    local runtime = controlRef.runtime
    if runtime then
      runtime:onSessionUpdate(update)
    end
  end
  bus.subscribe("session.update", self.sessionHandler)

  -- Consumes pendingReload/pendingSaveConfirm/pendingOnLoaded from the app
  -- tool's own wakeup -- the context form.openProgressDialog()/
  -- form.openDialog() actually need, unlike the bus-callback chain or the
  -- event handler itself, either of which opening a dialog synchronously
  -- caused real, live-caught bugs (see the comments above and in
  -- onSessionUpdate()). pendingOnLoaded joined the two flags here as a
  -- precaution after a live report that app/pages/rates.lua's profile-
  -- switch reload wasn't firing (title suffix updates confirmed working,
  -- so onSessionUpdate()/pendingReload/the wakeup dispatch itself are
  -- fine) -- the same page's onLoaded was, until this change, the one
  -- caller in this file doing something other than plain :value()/
  -- :enable() from a nested bus-callback context (its
  -- :minimum()/:maximum() bounds re-application, see lib/rate_curve_scale.lua),
  -- and this file already has two confirmed-live precedents for "some
  -- Ethos calls need the tool's own tick, not this nested one" (the
  -- dialog functions above). Deferring onLoaded the same way costs
  -- nothing (one wakeup tick, imperceptible) whether or not that's the
  -- exact mechanism -- **not yet independently confirmed as the actual
  -- root cause**, since nothing here proves the two symptoms (reload not
  -- firing, onLoaded being the one non-value()/enable() nested call) are
  -- actually connected rather than coincidental.
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      local runtime = controlRef.runtime
      if not runtime or runtime.disposed then return end
      runtime:runPendingUiActions()
      if runtime.pendingReload and runtime.loaded and not runtime.activeDialog then
        runtime.pendingReload = false
        runtime:log("wakeup: running deferred profile-change reload")
        runtime:loadData()
      end
      if runtime.pendingSaveConfirm and runtime.loaded and not runtime.activeDialog then
        runtime.pendingSaveConfirm = false
        runtime:confirmSave(runtime.headerHandle.focusSave)
      end
      if runtime.pendingSaveError and not runtime.activeDialog then
        runtime.pendingSaveError = nil
        runtime:showSaveError(runtime.headerHandle and runtime.headerHandle.focusSave)
      end
      if runtime.pendingSaveArmed and not runtime.activeDialog then
        runtime.pendingSaveArmed = false
        runtime:showSaveArmed(runtime.headerHandle and runtime.headerHandle.focusSave)
      end
      if runtime.pendingOnLoaded then
        runtime.pendingOnLoaded = false
        if runtime.onLoaded then
          runtime.onLoaded()
        end
      end
      if runtime.onWakeup then
        runtime.onWakeup(runtime)
      end
    end)
  end

  if opts.setPaintHandler and self.onPaint then
    opts.setPaintHandler(function()
      local runtime = controlRef.runtime
      if runtime and not runtime.disposed and runtime.onPaint then
        runtime.onPaint(runtime)
      end
    end)
  end

  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      local runtime = controlRef.runtime
      if runtime then runtime:dispose() end
    end)
  end
end

-- Call once, after all of the page's own fields have been built and
-- registered via registerField() -- kicks off the very first read.
--
-- Diagnostic checkpoint, paired with PageRuntime.new()'s "<logTag> open"
-- print: a live log showed plain menu/tile screens (header + buttons
-- only) leaking a small, steady ~11-14KB per cycle, while every page with
-- actual form.addNumberField()/form.addChoiceField() fields leaked
-- ~40-75KB -- pointing at field construction specifically, not general
-- page/header overhead (every screen, menus included, builds the same
-- header). This print, taken right after buildChrome() + every field is
-- registered but before the first MSP round-trip starts, isolates that:
-- compare it against this same visit's own "<logTag> open" to see the
-- pure chrome+field-construction cost, and against "<logTag> exit" to see
-- the cost of the MSP round-trip/dialog/idle-on-page time separately.
function PageRuntime:loadInitial()
  memstats.print(self.logTag .. " fields built")
  if self.initialData then
    self.loaded = true
    self.loadedProfile = self.lastProfile
    for _, field in pairs(self.fields) do
      field:enable(true)
    end
    self:setDirty(false)
    self:setBusy(false)
    self.pendingOnLoaded = self.onLoaded ~= nil
    self.initialData = nil
    return
  end
  self:loadData()
end

package.loaded["rfsuite.app.page_runtime"] = PageRuntime
return PageRuntime
