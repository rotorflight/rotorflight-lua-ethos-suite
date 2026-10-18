-- The question a page asks when Back is pressed with unsaved changes (issue #2504).
--
-- Shared by the page runtime (app/page_runtime.lua) and by the pages that keep their own state, so
-- the dialog reads the same everywhere. It only builds the dialog's arguments; the caller opens it.
--
-- Buttons: Save (only where the page can save now), Discard (leaves the page at once), and Stay
-- (the default, which closes the dialog and keeps the page open). While the model is armed a save
-- of a flight-controller page is refused, so the question offers Discard and Stay only, with the
-- text that says why.

local leaveConfirm = {}

local MSG_TITLE = "@i18n(app.msg_unsaved_title)@"
local MSG_BODY = "@i18n(app.msg_unsaved_body)@"
local MSG_ARMED_BODY = "@i18n(app.msg_unsaved_armed_body)@"
local BTN_SAVE = "@i18n(app.btn_save)@"
local BTN_DISCARD = "@i18n(app.btn_discard)@"
local BTN_STAY = "@i18n(app.btn_stay)@"

--- The dialog arguments for form.openDialog(), or for PageRuntime:openMessageDialog().
---
--- @param opts.canSave  boolean  true where Save is possible now
--- @param opts.save     function called for Save; the page stays open afterwards
--- @param opts.discard  function called for Discard; the page leaves
--- @param opts.focus    function optional; returns focus to the Save button after Stay
function leaveConfirm.args(opts)
  local buttons = {}
  if opts.canSave then
    buttons[#buttons + 1] = {label = BTN_SAVE, action = function()
      if opts.save then opts.save() end
      return true
    end}
  end
  buttons[#buttons + 1] = {label = BTN_DISCARD, action = function()
    if opts.discard then opts.discard() end
    return true
  end}
  buttons[#buttons + 1] = {label = BTN_STAY, action = function()
    if opts.focus then opts.focus() end
    return true
  end}
  return {
    title = MSG_TITLE,
    message = opts.canSave and MSG_BODY or MSG_ARMED_BODY,
    buttons = buttons,
    wakeup = function() end,
    paint = function() end,
  }
end

return leaveConfirm
