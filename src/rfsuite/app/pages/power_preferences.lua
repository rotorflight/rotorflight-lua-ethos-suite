-- Setup -> Power -> Preferences.
--
-- The model's own power settings that no manufacturer page supplies. For now that is the speed
-- controller's current limit, which the dashboard's ESC load box needs (#2355). AM32, Scorpion
-- and YGE fill it in from their own parameter block whenever their page is opened; for the other
-- seven families it is typed in here. 0 means "not set".
--
-- The limit is stored by the session (tasks/session.lua, model.esc_current_limit.update), the same
-- way the flight-time alarm is stored by the Alerts page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")

local PAGE_TITLE = "@i18n(app.modules.power.preferences_name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.modules.power.save_preferences_prompt)@"

local CURRENT_LIMIT_MAX = 1000

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle = nil
  local sessionHandler = nil
  local mcuId = nil
  local loaded = false
  local original = 0
  local limit = 0
  local field = nil

  local function isDirty()
    return limit ~= original
  end

  local function updateEnabled()
    local enabled = loaded and mcuId ~= nil
    if field and field.enable then field:enable(enabled) end
    if headerHandle then
      headerHandle.setSaveEnabled(enabled and isDirty())
    end
  end

  local function save(focusFn)
    if disposed or not loaded or not mcuId then return end
    bus.publish("model.esc_current_limit.update", {
      mcuId = mcuId,
      amps = limit > 0 and limit or nil,
    })
    original = limit
    updateEnabled()
    if focusFn then focusFn() end
  end

  local function confirmSave(focusFn)
    if not isDirty() then
      if focusFn then focusFn() end
      return
    end
    form.openDialog({
      title = MSG_SAVE_TITLE,
      message = MSG_SAVE_BODY,
      buttons = {
        {label = BTN_OK, action = function() save(focusFn); return true end},
        {label = BTN_CANCEL, action = function() if focusFn then focusFn() end; return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    field = nil
    if opts.onBack then opts.onBack() end
  end

  -- The session snapshot carries the stored limit. A pending edit is not overwritten by a
  -- snapshot that arrives while the page is dirty.
  local function onSessionUpdate(snapshot)
    if disposed then return end
    local nextMcuId = snapshot and snapshot.mcuId or nil
    if nextMcuId ~= mcuId then
      mcuId = nextMcuId
      loaded = mcuId ~= nil
      original = tonumber(snapshot and snapshot.escCurrentLimit) or 0
      limit = original
      updateEnabled()
      if form.invalidate then form.invalidate() end
      return
    end
    if loaded and not isDirty() then
      local stored = tonumber(snapshot and snapshot.escCurrentLimit) or 0
      if stored ~= original then
        original = stored
        limit = stored
        updateEnabled()
        if form.invalidate then form.invalidate() end
      end
    end
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
  })

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end
  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      disposed = true
      if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
      field = nil
    end)
  end

  local line = form.addLine("@i18n(app.modules.power.esc_current_limit)@")
  field = form.addNumberField(line, nil, 0, CURRENT_LIMIT_MAX, function()
    return limit
  end, function(value)
    limit = value or 0
    updateEnabled()
  end)
  if field and field.suffix then field:suffix("A") end

  sessionHandler = bus.subscribe("session.update", onSessionUpdate)
  updateEnabled()
end

return {open = open}
