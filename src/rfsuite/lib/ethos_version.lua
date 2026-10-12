-- Ethos firmware-version comparison. Stateless -- same category of
-- neutral utility as lib/elrs_decode_primitives.lua -- so any subsystem
-- may load this without it becoming shared state.
--
-- Ethos's version numbering jumped from an old 1.x line to a new 26.x
-- line, so {26, 1, 0} is a *newer* release than {1, 6, 5}, not an older
-- one -- callers gating on "has the new API" (e.g. lib/diy_sensor.lua's
-- rawValue/value push, widgets/dashboard.lua's theme-color support)
-- should compare against the 26.x line, not assume a small major number
-- means old.

local ethos_version = {}

function ethos_version.atLeast(target)
  -- system.getVersion() is available in Ethos 1.1.0 and later; this function is only
  -- called from Ethos contexts where it is guaranteed to exist.
  local version = system.getVersion() or {}
  local current = {
    tonumber(version.major or version.majorVersion) or 0,
    tonumber(version.minor or version.minorVersion) or 0,
    tonumber(version.revision or version.patch or version.revisionNumber) or 0,
  }
  for i = 1, 3 do
    local want = tonumber(target and target[i]) or 0
    if current[i] > want then return true end
    if current[i] < want then return false end
  end
  return true
end

return ethos_version
