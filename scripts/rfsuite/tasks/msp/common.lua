--[[
  Rotorflight MSP common helpers (Ethos, Lua 5.3)
  - Supports MSP v1 and v2 at runtime
  - Default version is set by MSPV_DEFAULT (changeable) and can
    also be changed dynamically via setMSPVersion(1|2)

  Notes:
  * Uses native Lua 5.3 bitwise operators (&, |, ~, <<, >>); no bit32.
  * Keeps existing public function names/hooks: mspProcessTxQ, mspSendRequest,
    mspReceivedReply, mspPollReply, mspClearTxBuf.
  * TX:
      v2 → flags(1), cmd(16le), len(16le), payload; no XOR
      v1 → len(8), cmd(8), payload..., XOR(8)
  * RX: auto-detects by status.version bits; v2 has no XOR; v1 checks XOR.
]]--

local rfsuite = require("rfsuite")

---------------------------------------------------------------------
-- Version selection
---------------------------------------------------------------------
-- Change this to 1 if you want v1 by default, 2 for v2
local MSPV_DEFAULT = 2

-- Runtime-active version; can be changed via setMSPVersion(1|2)
local MSPV = MSPV_DEFAULT

-- Compute status byte version bit
local function version_bit()
  -- v1 uses bit5; v2 uses bit6
  if MSPV == 2 then
    return (1 << 6)
  else
    return (1 << 5)
  end
end

-- START flag (bit 4)
local MSP_STARTFLAG = (1 << 4)

---------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------
local mspSeq        = 0          -- local sequence we send
local mspRemoteSeq  = 0          -- last sequence seen from target
local mspLastReq    = 0          -- last command we transmitted
local mspStarted    = false      -- receiving a multi-chunk frame

local mspTxBuf      = {}         -- pending TX payload bytes (MSP payload only)
local mspTxIdx      = 1          -- current index in mspTxBuf while chunking
local mspTxCRC      = 0          -- v1 XOR while building

local mspRxBuf      = {}         -- assembled RX payload (MSP payload only)
local mspRxReq      = 0          -- command id of frame being received
local mspRxSize     = 0          -- expected payload length
local mspRxError    = false      -- error flag parsed from status
local mspRxCRC      = 0          -- v1 XOR while parsing

---------------------------------------------------------------------
-- Small util wrappers
---------------------------------------------------------------------
local function log(msg, lvl)
  if rfsuite and rfsuite.utils and rfsuite.utils.log then
    rfsuite.utils.log(msg, lvl or "debug")
  end
end

local function maxTx() return rfsuite.tasks.msp.protocol.maxTxBufferSize end
local function maxRx() return rfsuite.tasks.msp.protocol.maxRxBufferSize end

---------------------------------------------------------------------
-- Build TX payload buffer from cmd & payload per MSP version
-- Keeps function name/signature
---------------------------------------------------------------------
local function mspSendRequest(cmd, payload)
  if (type(cmd) ~= "number") or (type(payload) ~= "table") then
    log("mspSendRequest: bad args", "debug"); return nil
  end
  if #mspTxBuf ~= 0 then
    log("mspSendRequest: busy (pending frame for cmd " .. tostring(mspLastReq) .. ")", "debug")
    return nil
  end

  local len = #payload
  mspTxBuf = {}
  mspTxIdx = 1
  mspTxCRC = 0

  if MSPV == 2 then
    -- MSPv2 header: flags(1) cmdLo(1) cmdHi(1) lenLo(1) lenHi(1)
    local flags = 0
    mspTxBuf[1] = flags
    mspTxBuf[2] = (cmd & 0xFF)
    mspTxBuf[3] = ((cmd >> 8) & 0xFF)
    mspTxBuf[4] = (len & 0xFF)
    mspTxBuf[5] = ((len >> 8) & 0xFF)
    for i = 1, len do
      mspTxBuf[5 + i] = (payload[i] or 0) & 0xFF
    end
    -- No XOR for v2
  else
    -- MSPv1 header: len(1) cmd(1) payload... XOR(1)
    mspTxBuf[1] = (len & 0xFF)
    mspTxBuf[2] = (cmd & 0xFF)
    mspTxCRC = (mspTxBuf[1] ~ mspTxBuf[2])
    for i = 1, len do
      local b = (payload[i] or 0) & 0xFF
      mspTxBuf[2 + i] = b
      mspTxCRC = (mspTxCRC ~ b)
    end
    mspTxBuf[#mspTxBuf + 1] = (mspTxCRC & 0xFF)
  end

  mspLastReq = cmd
  return true
end

---------------------------------------------------------------------
-- Copy bytes from mspTxBuf into a transport payload buffer and send.
-- Returns: true if more chunks remain, false if this chunk finished the frame.
---------------------------------------------------------------------
local function mspProcessTxQ()
  if #mspTxBuf == 0 then return false end

  log("Sending mspTxBuf size " .. tostring(#mspTxBuf) .. " at Idx " .. tostring(mspTxIdx) .. " for cmd: " .. tostring(mspLastReq), "debug")

  local payload = {}
  payload[1] = (mspSeq + version_bit())
  mspSeq = (mspSeq + 1) & 0x0F
  if mspTxIdx == 1 then payload[1] = payload[1] + MSP_STARTFLAG end

  local i = 2
  local max = maxTx()
  while (i <= max) and (mspTxIdx <= #mspTxBuf) do
    payload[i] = mspTxBuf[mspTxIdx]
    mspTxIdx = mspTxIdx + 1
    i = i + 1
  end

  -- pad remainder with zeros (preserves existing behavior)
  if i <= max then
    for j = i, max do payload[j] = 0 end
  end

  local more = (mspTxIdx <= #mspTxBuf)
  if not more then
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0
  end

  rfsuite.tasks.msp.protocol.mspSend(payload)
  return more
end

---------------------------------------------------------------------
-- Parse an incoming CRSF-MSP payload (table of bytes).
-- Returns true when a full MSP frame has been assembled into mspRxBuf;
-- false if more chunks are expected; nil on error/sequence loss.
---------------------------------------------------------------------
local function mspReceivedReply(payload)
  if (type(payload) ~= "table") or (#payload == 0) then return nil end

  local idx = 1
  local status = payload[idx]; idx = idx + 1
  local err    = ((status & 0x80) ~= 0)
  local start  = ((status & MSP_STARTFLAG) ~= 0)
  local seq    = (status & 0x0F)
  local ver    = ((status & 0x60) >> 5) -- 0/1/2

  if start then
    -- reset assembly
    mspRxBuf = {}
    mspRxError = err

    if ver == 2 then
      -- v2 start-chunk header
      local flags = payload[idx]; idx = idx + 1 -- currently unused
      local cmdLo = payload[idx]; idx = idx + 1
      local cmdHi = payload[idx]; idx = idx + 1
      local lenLo = payload[idx]; idx = idx + 1
      local lenHi = payload[idx]; idx = idx + 1
      mspRxReq  = ((cmdHi << 8) | cmdLo)
      mspRxSize = ((lenHi << 8) | lenLo)
      -- no XOR for v2
      mspRxCRC  = 0
    elseif ver == 1 then
      -- v1 start-chunk header
      mspRxSize = payload[idx]; idx = idx + 1
      mspRxReq  = payload[idx]; idx = idx + 1
      mspRxCRC  = (mspRxSize ~ mspRxReq)
    else
      log("Unsupported MSP version in RX: " .. tostring(ver), "debug")
      return nil
    end

    if mspRxReq == mspLastReq then mspStarted = true end
  else
    if (not mspStarted) or (((mspRemoteSeq + 1) & 0x0F) ~= seq) then
      mspStarted = false
      log("RX out of sequence", "debug")
      return nil
    end
  end

  -- copy chunk payload
  while (idx <= #payload) and (#mspRxBuf < mspRxSize) do
    local b = payload[idx]
    mspRxBuf[#mspRxBuf + 1] = b
    if ver == 1 then mspRxCRC = (mspRxCRC ~ (b or 0)) end
    idx = idx + 1
  end

  -- if not complete, expect another chunk
  if #mspRxBuf < mspRxSize then
    mspRemoteSeq = seq
    return false
  end

  -- frame complete
  mspStarted = false

  if ver == 1 then
    -- optional trailing XOR byte (if present)
    if idx <= #payload then
      local tail = payload[idx]
      if mspRxCRC ~= tail then
        log("MSP v1 XOR mismatch", "debug")
        return nil
      end
    end
  end

  return true
end

---------------------------------------------------------------------
-- Poll for reply (<= ~100ms)
---------------------------------------------------------------------
local function mspPollReply()
  local startTime = os.clock()
  while (os.clock() - startTime) < 0.1 do
    local mspData = rfsuite.tasks.msp.protocol.mspPoll()
    if mspData and mspReceivedReply(mspData) then
      mspLastReq = 0
      return mspRxReq, mspRxBuf, mspRxError
    end
  end
  return nil, nil, nil
end

---------------------------------------------------------------------
-- Helpers / API
---------------------------------------------------------------------
local function mspClearTxBuf()
  mspTxBuf = {}
  mspTxIdx = 1
  mspTxCRC = 0
end

-- External control of MSP version (1 or 2)
local function setMSPVersion(v)
  if v == 1 or v == 2 then
    MSPV = v
    log("MSP version set to v" .. tostring(v), "debug")
  else
    log("setMSPVersion: ignored invalid value " .. tostring(v), "debug")
  end
end

local function getMSPVersion()
  return MSPV
end

---------------------------------------------------------------------
-- Export (keeps existing names; adds setters)
---------------------------------------------------------------------
return {
  mspProcessTxQ    = mspProcessTxQ,
  mspSendRequest   = mspSendRequest,
  mspReceivedReply = mspReceivedReply,
  mspPollReply     = mspPollReply,
  mspClearTxBuf    = mspClearTxBuf,
  setMSPVersion    = setMSPVersion,
  getMSPVersion    = getMSPVersion,
}
