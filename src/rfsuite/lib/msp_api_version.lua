-- Message-builder + compatibility check for MSP_API_VERSION (cmd 1,
-- read-only). Distinct from FC_VERSION (cmd 3, see lib/msp_handshake.lua):
-- that one reports the firmware's own semver (and this rebuild's derived
-- rfVersion); this one reports the MSP *protocol* version the FC actually
-- speaks -- {mspProtocolVersion, apiVersionMajor, apiVersionMinor}, wire
-- format confirmed against rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/API_VERSION.lua.
--
-- The major number identifies the firmware *family* this MSP dialect
-- belongs to (Rotorflight, Wingflight, Betaflight, iNav, ... each stakes
-- out its own), not a generic "how new" number -- talking to the wrong
-- family entirely (e.g. this suite's 12.x against a Wingflight FC's 22.x)
-- is a hard mismatch, not a "just needs an update" case. The minor number
-- is the real floor *within* that family. See tasks/session.lua's
-- runHandshake() for where this gets read and tasks/msp/queue.lua's
-- isSim branch for why the simulator override below only ever matters
-- there -- real hardware ignores simulatorResponse entirely.

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 1

-- This rebuild's own floor: Rotorflight's MSP API family is 12.x (see
-- AGENTS.md), and 12.09 is the minimum minor version this rebuild's own
-- MSP codecs assume throughout (see e.g. tasks/msp/common.lua's own
-- "MSPv2-only" header comment).
local EXPECTED_API_MAJOR = 12
local MIN_API_MINOR = 9

-- Concrete versions offered by the developer "simulated API version"
-- picker (see app/pages/developer_settings.lua) -- add new entries here as
-- Rotorflight ships new MSP API versions; nothing else needs to change,
-- the simulator byte-triplet is derived from the string itself below.
-- Kept ahead of what's actually shipped where useful (12.10 doesn't exist
-- yet) so the "does a future minor bump still pass the floor check" path
-- is exercisable before real firmware needs it.
local SIMULATABLE_VERSIONS = {"12.09", "12.10"}

-- "Invalid" simulates talking to a *different firmware family* entirely
-- (major 22 -- Wingflight's own, per that project's own
-- lib/msp_api_version.lua) rather than merely "too old within family",
-- since that's the sharper, more common real-world mismatch this exists
-- to catch.
local INVALID_SIM_RESPONSE = {0, 22, 0}

-- Known MSP API major-version "epochs" claimed by other firmware
-- families/projects, for classifyUnsupported() below to name *what* was
-- actually detected instead of just a bare major number. Deliberately
-- excludes EXPECTED_API_MAJOR (this rebuild's own family) -- an
-- unrecognized major just falls back to no name, caller's own choice what
-- to show. iNav's own epoch isn't confirmed yet, so it's not listed --
-- add it here once known, nothing else needs to change.
local KNOWN_FAMILY_NAMES = {
  [22] = "Wingflight",
  [1] = "Betaflight",
}

local msp_api_version = {
  READ_COMMAND = READ_COMMAND,
  EXPECTED_API_MAJOR = EXPECTED_API_MAJOR,
  MIN_API_MINOR = MIN_API_MINOR,
  SIMULATABLE_VERSIONS = SIMULATABLE_VERSIONS,
  INVALID_SIM_RESPONSE = INVALID_SIM_RESPONSE,
}

-- true/false once both major/minor are known; nil if either is still
-- unread (caller's responsibility not to treat nil as "unsupported").
function msp_api_version.isSupported(major, minor)
  if major == nil or minor == nil then return nil end
  if major ~= EXPECTED_API_MAJOR then return false end
  return minor >= MIN_API_MINOR
end

-- Classifies *why* isSupported() returned false, for UI messaging (see
-- widgets/dashboard.lua's boot-time error overlay): "invalid" when major
-- doesn't match this rebuild's own family at all -- a genuinely different
-- product, not just an old version of this one -- with familyName filled
-- in when that other major is a recognized family (nil otherwise);
-- "unsupported" when major matches but minor is below this rebuild's own
-- floor -- same family, just needs a firmware update, so no familyName
-- (nothing to name, it's already this one). Returns nil when
-- isSupported() would also return nil (still unread) or true (supported --
-- nothing to classify).
function msp_api_version.classifyUnsupported(major, minor)
  if msp_api_version.isSupported(major, minor) ~= false then return nil end
  if major ~= EXPECTED_API_MAJOR then
    return "invalid", KNOWN_FAMILY_NAMES[major]
  end
  return "unsupported", nil
end

-- Builds the {mspProtocolVersion, major, minor} simulator fixture for a
-- developer-selected version string (e.g. "12.09", from
-- SIMULATABLE_VERSIONS) or "invalid"/nil for the cross-family fixture.
function msp_api_version.simResponseForVersion(versionString)
  if not versionString or versionString == "invalid" then
    return INVALID_SIM_RESPONSE
  end
  local major, minor = versionString:match("^(%d+)%.(%d+)$")
  if not major then return INVALID_SIM_RESPONSE end
  return {0, tonumber(major), tonumber(minor)}
end

function msp_api_version.buildReadMessage(onData, onError, simulatorResponse)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      buf.offset = 1
      mspcodec.readU8(buf) -- MSP protocol version byte -- not this rebuild's concern, MSPv2-only throughout
      local major = mspcodec.readU8(buf)
      local minor = mspcodec.readU8(buf)
      onData({major = major, minor = minor})
    end,
    errorHandler = onError,
    simulatorResponse = simulatorResponse or msp_api_version.simResponseForVersion(SIMULATABLE_VERSIONS[#SIMULATABLE_VERSIONS]),
  }
end

return msp_api_version
