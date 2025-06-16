--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] -- Protocol constants
local MSP_VERSION = (1 << 5)
local MSP_STARTFLAG = (1 << 4)

-- Sequence number for next MSP packet
local mspSeq = 0
local mspRemoteSeq = 0
local mspRxBuf = {}
local mspRxError = false
local mspRxSize = 0
local mspRxCRC = 0
local mspRxReq = 0
local mspStarted = false
local mspLastReq = 0
local mspTxBuf = {}
local mspTxIdx = 1
local mspTxCRC = 0

--[[
    Processes the MSP (Multiwii Serial Protocol) transmission queue.

    This function handles the transmission of MSP commands by sending the data in chunks
    according to the maximum transmission buffer size defined in the protocol. It manages
    the sequence number, start flag, and CRC (Cyclic Redundancy Check) for the data being sent.

    Returns:
        boolean: `true` if there are more data to be sent, `false` otherwise.

    Global Variables:
        mspTxBuf (table): The buffer containing the MSP data to be transmitted.
        mspTxIdx (number): The current index in the transmission buffer.
        mspLastReq (any): The last MSP request command.
        mspSeq (number): The current sequence number for MSP packets.
        mspTxCRC (number): The current CRC value for the MSP data.

    Dependencies:
        rfsuite.utils.log (function): Logs messages for debugging purposes.
        rfsuite.tasks.msp.protocol.maxTxBufferSize (number): The maximum size of the transmission buffer.
        rfsuite.tasks.msp.protocol.mspSend (function): Sends the MSP payload.
        MSP_VERSION (number): The version of the MSP protocol.
        MSP_STARTFLAG (number): The start flag for the MSP protocol.
]]
local function mspProcessTxQ()
    if #mspTxBuf == 0 then return false end

    rfsuite.utils.log("Sending mspTxBuf size " .. tostring(#mspTxBuf) .. " at Idx " .. tostring(mspTxIdx) .. " for cmd: " .. tostring(mspLastReq),"debug")

    local payload = {}
    payload[1] = mspSeq + MSP_VERSION
    mspSeq = (mspSeq + 1) & 0x0F
    if mspTxIdx == 1 then payload[1] = payload[1] + MSP_STARTFLAG end

    local i = 2
    while (i <= rfsuite.tasks.msp.protocol.maxTxBufferSize) and mspTxIdx <= #mspTxBuf do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        mspTxCRC = mspTxCRC ~ payload[i]
        i = i + 1
    end

    if i <= rfsuite.tasks.msp.protocol.maxTxBufferSize then
        payload[i] = mspTxCRC
        for j = i + 1, rfsuite.tasks.msp.protocol.maxTxBufferSize do payload[j] = 0 end
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
        rfsuite.tasks.msp.protocol.mspSend(payload)
        return false
    end
    rfsuite.tasks.msp.protocol.mspSend(payload)
    return true
end

--[[
    Sends an MSP (Multiwii Serial Protocol) request with the given command and payload.

    @param cmd (number) The command identifier to send.
    @param payload (table) The payload data to send with the command. Must be a table of numbers.

    @return nil
    Logs an error and returns nil if the command is invalid, the payload is not a table, or if there is an existing transmission buffer still sending.
]]
local function mspSendRequest(cmd, payload)
    if not cmd or type(payload) ~= "table" then
        rfsuite.utils.log("Invalid command or payload","debug")
        return nil
    end
    if #mspTxBuf ~= 0 then
        rfsuite.utils.log("Existing mspTxBuf still sending, failed to send cmd: " .. tostring(cmd),"debug")
        return nil
    end
    mspTxBuf[1] = #payload
    mspTxBuf[2] = cmd & 0xFF
    for i = 1, #payload do mspTxBuf[i + 2] = payload[i] & 0xFF end
    mspLastReq = cmd
end

--[[
    Function: mspReceivedReply
    Description: Processes the received MSP (Multiwii Serial Protocol) reply payload.
    Parameters:
        payload (table): The received payload data.
    Returns:
        boolean: 
            - true if the payload is successfully processed and the checksum is correct.
            - false if the payload size exceeds the maximum buffer size.
            - nil if the message failed due to incorrect sequence or checksum.
    Notes:
        - The function handles the MSP protocol versioning and sequence management.
        - It verifies the payload checksum for version 0 of the protocol.
        - It logs a debug message if the payload checksum is incorrect.
--]]
local function mspReceivedReply(payload)
    local idx = 1
    local status = payload[idx]
    local version = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F
    idx = idx + 1

    if start then
        mspRxBuf = {}
        mspRxError = (status & 0x80) ~= 0
        mspRxSize = payload[idx]
        mspRxReq = mspLastReq
        idx = idx + 1
        if version == 1 then
            mspRxReq = payload[idx]
            idx = idx + 1
        end
        mspRxCRC = mspRxSize ~ mspRxReq
        if mspRxReq == mspLastReq then mspStarted = true end
    elseif not mspStarted or ((mspRemoteSeq + 1) & 0x0F) ~= seq then
        mspStarted = false
        return nil
    end

    while (idx <= rfsuite.tasks.msp.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        local value = tonumber(payload[idx]) 
        if value then
            mspRxCRC = mspRxCRC ~ value
        else
            rfsuite.utils.log("Non-numeric value at payload index " .. idx,"debug")
        end
        idx = idx + 1
    end

    if idx > rfsuite.tasks.msp.protocol.maxRxBufferSize then
        mspRemoteSeq = seq
        return false
    end

    mspStarted = false
    if mspRxCRC ~= payload[idx] and version == 0 then
        rfsuite.utils.log("Payload checksum incorrect, message failed!","debug")
        return nil
    end
    return true
end

--[[
    Function: mspPollReply
    Description: Polls for an MSP (Multiwii Serial Protocol) reply within a 0.1 second time frame.
    It continuously checks for MSP data and verifies if a valid reply is received.
    If a valid reply is received, it resets the request counter and returns the request, buffer, and error status.
    If no valid reply is received within the time frame, it returns nil values.
    
    Returns:
        mspRxReq (varies) - The MSP request if a valid reply is received.
        mspRxBuf (varies) - The MSP buffer if a valid reply is received.
        mspRxError (varies) - The MSP error status if a valid reply is received.
        nil, nil, nil - If no valid reply is received within the time frame.
]]
local function mspPollReply()
    local startTime = rfsuite.clock
    -- while loops dont play nice with global clock, so we use os.clock() for timing
    while os.clock() - startTime < 0.05 do
        local mspData = rfsuite.tasks.msp.protocol.mspPoll()
        if mspData and mspReceivedReply(mspData) then
            mspLastReq = 0
            return mspRxReq, mspRxBuf, mspRxError
        end
    end
    return nil, nil, nil
end

--[[
    Function: mspClearTxBuf
    Description: Clears the MSP (Multiwii Serial Protocol) transmission buffer by setting it to an empty table.
]]
local function mspClearTxBuf()
    mspTxBuf = {}
end


return {
    mspProcessTxQ = mspProcessTxQ,
    mspSendRequest = mspSendRequest,
    mspPollReply = mspPollReply,
    mspClearTxBuf = mspClearTxBuf
}
