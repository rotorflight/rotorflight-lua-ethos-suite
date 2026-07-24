-- S.Port / F.Port MSP transport.
--
-- Adapted from rotorflight-lua-ethos-suite's tasks/scheduler/msp/sp.lua,
-- which uses Ethos's newer sensor-object telemetry API (sport.getSensor()
-- -> :pushFrame()/:popFrame()) rather than the older raw
-- sportTelemetryPush/Pop globals -- that object API is itself a proper
-- frame queue, so (unlike older raw-global approaches) no manual
-- duplicate-frame filtering is needed here.
--
-- Private to the background task subsystem -- nothing outside tasks/msp/
-- should load this file directly.
--
-- moduleNumber (0 = internal, 1 = external) is passed in by
-- tasks/msp/transport_select.lua's load() as this chunk's vararg -- an
-- external module can itself speak S.Port (e.g. a TBS/TW-XLite-style
-- external module), and its telemetry only arrives tagged with module 1.
-- Binding sport.getSensor() to a hardcoded module 0 would silently drop
-- that traffic (our custom sensors and MSP would just never see replies).
local moduleNumber = ...

local transport = {}

local LOCAL_SENSOR_ID = 0x0D
local SPORT_REMOTE_SENSOR_ID = 0x1B
local FPORT_REMOTE_SENSOR_ID = 0x00
local REQUEST_FRAME_ID = 0x30
local REPLY_FRAME_ID = 0x32

local sensor

local function getSensor()
  if not sensor then
    sensor = sport.getSensor({module = moduleNumber or 0, primId = REPLY_FRAME_ID})
  end
  return sensor
end

function transport.mspSend(payload)
  local dataId = (payload[1] or 0) | ((payload[2] or 0) << 8)
  local v3, v4, v5, v6 = payload[3] or 0, payload[4] or 0, payload[5] or 0, payload[6] or 0
  local value = v3 | (v4 << 8) | (v5 << 16) | (v6 << 24)

  local s = getSensor()
  if not s then return nil end
  return s:pushFrame({physId = LOCAL_SENSOR_ID, primId = REQUEST_FRAME_ID, appId = dataId, value = value})
end

function transport.mspPoll()
  local s = getSensor()
  if not s then return nil end

  while true do
    local frame = s:popFrame()
    if not frame then return nil end

    local sensorId, frameId, dataId, value = frame:physId(), frame:primId(), frame:appId(), frame:value()
    if (sensorId == SPORT_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID) and frameId == REPLY_FRAME_ID then
      return {
        dataId & 0xFF,
        (dataId >> 8) & 0xFF,
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
      }
    end
    -- not an MSP reply frame; keep draining the queue for one that is
  end
end

transport.maxTxBufferSize = 6
transport.maxRxBufferSize = 6

return transport
