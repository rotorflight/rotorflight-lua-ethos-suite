-- The two settings a Tune Advisor flight carries beside its statistics (issues
-- #2639, #2640, #2642): the Cyclic polarity and ring of the rate profile
-- (MSP_RC_TUNING, index 1) and the I-term relax type of the PID profile
-- (MSP_PID_PROFILE, index 2). tasks/tune_history.lua reads them at each capture.
-- Loaded on that first read, not at boot: the boot-resident task does not hold
-- the two codecs before a flight is captured.
if package.loaded["rfsuite.lib.tune_history_settings"] then
  return package.loaded["rfsuite.lib.tune_history_settings"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")

local settings = {}
local entries = nil

-- minBytes: the reply must hold every field, or the codec reads the missing
-- bytes as 0 and the flight would carry a tune of zeros
local function list()
  if not entries then
    local rcTuning = requireModule("lib/msp_rc_tuning.lua")
    local pidProfile = requireModule("lib/msp_pid_profile.lua")
    entries = {
      {codec = rcTuning, minBytes = #rcTuning.encode({})},
      {codec = pidProfile, minBytes = #pidProfile.encode({})},
    }
  end
  return entries
end

-- Asks the FC for setting `index`. onData(data) gets the decoded reply;
-- onError(reason, refused) is the caller's error handler. A reply too short for
-- every field is refused: the layout is one this suite does not know.
function settings.request(index, onData, onError)
  local entry = list()[index]
  local msg = entry.codec.buildReadMessage(onData, onError)
  local decode = msg.processReply
  msg.processReply = function(self, buf)
    if type(buf) ~= "table" or #buf < entry.minBytes then
      onError("settings reply too short", true)
      return
    end
    decode(self, buf)
  end
  bus.publish("msp.request", msg)
end

package.loaded["rfsuite.lib.tune_history_settings"] = settings
return settings
