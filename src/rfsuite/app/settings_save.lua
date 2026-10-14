-- Reports a local settings save that the store refused (issue #2500).
--
-- settingsStore.save() and modelPreferences.save() return false when the INI
-- file cannot be written. Every local settings page calls this when that happens,
-- so no page can drop the failure again: the page keeps its dirty state (the
-- Save button stays lit), publishes nothing, and the pilot sees a dialog.

local settingsSave = {}

local MSG_TITLE = "@i18n(app.msg_save_failed_title)@"
local MSG_BODY = "@i18n(app.msg_save_failed_local_body)@"
local BTN_OK = "@i18n(app.btn_ok)@"

-- focusFn returns focus to the Save button once the dialog is closed.
function settingsSave.reportFailure(focusFn)
  if not (form and type(form.openDialog) == "function") then return end
  form.openDialog({
    title = MSG_TITLE,
    message = MSG_BODY,
    buttons = {
      {
        label = BTN_OK,
        action = function()
          if focusFn then focusFn() end
          return true
        end,
      },
    },
    wakeup = function() end,
    paint = function() end,
  })
end

return settingsSave
