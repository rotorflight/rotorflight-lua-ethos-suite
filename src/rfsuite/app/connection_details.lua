-- The connection details dialog: what the radio knows about the flight-controller link (issue #2318).
--
-- Opened from the header's info button on every page. It reads the session only: the link state,
-- how far the handshake has got, and the craft name, firmware and API version the session holds.
-- Latency and drop rates are not kept by the session, so they are not shown.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()

local connectionDetails = {}

local TITLE = "@i18n(app.connection_title)@"
local BODY_FMT = "@i18n(app.connection_body_fmt)@"
local LINK_UP = "@i18n(app.connection_link_up)@"
local LINK_DOWN = "@i18n(app.connection_link_down)@"
local HANDSHAKE_FMT = "@i18n(app.connection_handshake_fmt)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local NOT_KNOWN = "-"

-- The handshake's steps, as the session records them (tasks/session.lua copyHandshake).
local HANDSHAKE_STEPS = {
  "apiVersion", "fcVariant", "mcuId", "craftName", "clockSynced",
  "batteryConfig", "smartfuelConfig", "rxMap",
}

local function text(value)
  if value == nil or value == "" then return NOT_KNOWN end
  return tostring(value)
end

-- How many of the handshake's steps the link has completed.
function connectionDetails.handshakeProgress(session)
  local handshake = session and session.handshake
  local done = 0
  if type(handshake) == "table" then
    for _, step in ipairs(HANDSHAKE_STEPS) do
      if handshake[step] == true then done = done + 1 end
    end
  end
  return done, #HANDSHAKE_STEPS
end

--- The body of the dialog for a session. Pure: the dialog is opened by open().
function connectionDetails.body(session)
  session = session or {}
  local link = session.connected == true and LINK_UP or LINK_DOWN
  local done, total = connectionDetails.handshakeProgress(session)
  return string.format(BODY_FMT, link, string.format(HANDSHAKE_FMT, done, total),
    text(session.craftName), text(session.rfVersion), text(session.apiVersion))
end

--- Opens the dialog for the current session.
function connectionDetails.open()
  local session = rfsuite and rfsuite.session or {}
  form.openDialog({
    title = TITLE,
    message = connectionDetails.body(session),
    buttons = {{label = BTN_OK, action = function() return true end}},
    wakeup = function() end,
    paint = function() end,
  })
end

return connectionDetails
