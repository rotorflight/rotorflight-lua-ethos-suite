# MSP Framing and Transport Handling in Rotorflight Suite

This document describes how Rotorflight Suite currently turns an MSP API request into one or more telemetry transport frames, and how replies are reassembled. It is written for developers considering moving the MSP framing/splitting/reassembly code out of Lua and into Ethos firmware.

The relevant Lua files are:

- `src/rfsuite/tasks/scheduler/msp/msp.lua`: selects the active telemetry transport and wires the MSP queue to it.
- `src/rfsuite/tasks/scheduler/msp/mspQueue.lua`: schedules logical MSP requests and handles retry/timeout policy.
- `src/rfsuite/tasks/scheduler/msp/common.lua`: builds logical MSP request buffers, splits them into transport-sized chunks, and reassembles replies.
- `src/rfsuite/tasks/scheduler/msp/crsf.lua`: wraps/unpacks Suite MSP chunks in CRSF MSP frames.
- `src/rfsuite/tasks/scheduler/msp/sp.lua`: wraps/unpacks Suite MSP chunks in S.Port/F.Port telemetry frames.
- `src/rfsuite/tasks/scheduler/msp/protocols.lua`: defines transport-specific limits and timing defaults.

## High-Level Flow

The Suite has three layers:

1. The API layer builds a logical MSP command and payload.
2. The queue layer schedules that command, controls retries/timeouts, and calls the active transport.
3. The common/transport layer frames, splits, sends, receives, and reassembles bytes.

The send path is:

```text
API module
  -> message = { command = <MSP cmd>, payload = { ... } }
  -> mspQueue:add(message)
  -> mspQueue:processQueue()
  -> activeProtocol.mspWrite(command, payload)
  -> common.mspSendRequest(command, payload)
  -> common.mspProcessTxQ()
  -> activeProtocol.mspSend(chunk)
  -> CRSF or S.Port telemetry API
```

The receive path is:

```text
telemetry API
  -> activeProtocol.mspPoll()
  -> common.mspPollReply()
  -> common._receivedReply(chunk)
  -> complete reply: cmd, payload, error
  -> mspQueue calls message:processReply(payload)
```

## Terminology

This document uses these terms:

- Logical MSP request: the command plus MSP payload requested by Lua, before telemetry chunking.
- Logical MSP buffer: the byte buffer built by `common.mspSendRequest()`. For v1 this starts with `LEN CMD`; for v2 this starts with `FLAGS CMD16 LEN16`.
- Suite MSP chunk: the fixed-size chunk emitted by `common.mspProcessTxQ()` and consumed by `common._receivedReply()`. It always starts with the Suite status byte.
- Transport frame: the underlying Ethos telemetry frame used to carry one Suite MSP chunk. This is either a CRSF MSP frame or a S.Port/F.Port frame.
- FC MSP payload: the final payload bytes passed to an API parser after reassembly. This excludes Suite status, MSP length, MSP command, and MSP CRC/header bytes.

The firmware migration should preserve this separation. Most Lua callers care only about logical MSP requests and completed FC MSP payloads.

## Queue Message Versus Wire Frame

`mspQueue.lua` does not know about MSP wire framing. It only sees a logical message table.

Common fields passed into `mspQueue:add(message)` are:

```lua
{
    command = 123,
    payload = { ... },
    apiname = "BATTERY_CONFIG",
    uuid = "some-dedup-key",
    timeout = 2.0,
    retryBackoff = 0.35,
    retryOnErrorReply = true,
    completeOnErrorReplyAttempt = 2,
    processReply = function(self, buf) end,
    errorHandler = function(self, reason) end,
    simulatorResponse = { ... },
    minBytes = 10,
    isWrite = true
}
```

Only `command` and `payload` become MSP bytes. The rest are queue/control metadata.

When the queue is ready to send a message, it calls:

```lua
mspProtocol.mspWrite(self.currentMessage.command, self.currentMessage.payload or {})
```

For reads, the payload is normally empty. The same queue path is still used.

## Common Layer State

The current implementation in `common.lua` is stateful. A firmware implementation needs equivalent state, even if names differ.

TX state:

| Lua variable | Purpose |
| --- | --- |
| `mspSeq` | Local 4-bit TX sequence used in Suite status bytes. It increments for every emitted Suite chunk and wraps modulo 16. It is not reset by `mspClearTxBuf()`. |
| `mspTxBuf` | Logical MSP buffer waiting to be split into chunks. |
| `mspTxIdx` | One-based index of the next logical byte to copy from `mspTxBuf`. |
| `mspTxCRC` | Running MSP v1 XOR CRC accumulated while emitting logical bytes. |
| `mspLastReq` | Command ID of the last logical request staged for TX. Used to match replies. |

RX state:

| Lua variable | Purpose |
| --- | --- |
| `mspRemoteSeq` | Last accepted remote sequence number during RX assembly. |
| `mspRxBuf` | Reassembled FC MSP payload bytes. |
| `mspRxError` | Error flag from bit 7 of the received Suite status byte. |
| `mspRxSize` | Expected FC MSP payload length from the MSP header. |
| `mspRxCRC` | Running MSP v1 XOR CRC accumulated while receiving payload bytes. |
| `mspRxReq` | Command ID parsed from the reply. |
| `mspStarted` | True while a valid reply for `mspLastReq` is being assembled. |

The Lua code assumes one logical MSP transfer at a time in `common.lua`. `common.mspSendRequest()` refuses to stage another request while `mspTxBuf` is non-empty.

## Protocol Selection

The active telemetry protocol is selected in `protocols.lua` from `rfsuite.session.telemetryType`.

Current protocol limits:

| Protocol | Transport file | `maxTxBufferSize` | `maxRxBufferSize` |
| --- | --- | ---: | ---: |
| S.Port/F.Port | `sp.lua` | 6 | 6 |
| CRSF | `crsf.lua` | 8 | 58 |

These limits are the size of the Suite MSP chunk passed between `common.lua` and the transport module. They are not the logical MSP payload size.

For example, with S.Port:

```text
Suite chunk = 6 bytes total
             1 status byte + up to 5 logical MSP bytes
```

With CRSF:

```text
Suite chunk = 8 bytes total
             1 status byte + up to 7 logical MSP bytes
```

## Logical MSP Request Buffer

`common.mspSendRequest(cmd, payload)` builds a single logical MSP request buffer in `mspTxBuf`.

### MSP v1 Request Buffer

For MSP v1, Suite builds:

```text
LEN CMD PAYLOAD...
```

Where:

- `LEN` is one byte: `#payload`.
- `CMD` is one byte: `cmd & 0xFF`.
- `PAYLOAD` is zero or more bytes.
- CRC is not stored in `mspTxBuf` initially; it is appended later when the final chunk is emitted.

The v1 CRC is XOR of:

```text
LEN ^ CMD ^ each payload byte
```

The CRC is appended to the final emitted Suite chunk, not stored in `mspTxBuf` up front.

### MSP v2 Request Buffer

For MSP v2, Suite builds:

```text
FLAGS CMD_LOW CMD_HIGH LEN_LOW LEN_HIGH PAYLOAD...
```

Where:

- `FLAGS` is currently `0`.
- `CMD_LOW`, `CMD_HIGH` are little-endian command bytes.
- `LEN_LOW`, `LEN_HIGH` are little-endian payload length bytes.
- `PAYLOAD` is zero or more bytes.

The current Lua implementation does not append or verify a v2 CRC in `common.lua`. The v2 branch only sends the header and payload bytes through the Suite chunking layer.

## Suite Chunk Status Byte

Every Suite MSP chunk starts with a status byte:

```text
bit 7:   not set by TX; RX treats it as an error flag if present
bits 6-5: MSP protocol version bits
bit 4:   start flag
bits 3-0: sequence number, modulo 16
```

The transmitter builds this byte as:

```lua
versionBits = (mspVersion == 2) and (2 << 5) or (1 << 5)
status = versionBits + sequence
if isStart then status = status + (1 << 4) end
status = status & 0x7F
```

Important consequences:

- The first chunk of a logical MSP request has the start flag set.
- Continuation chunks do not have the start flag set.
- Every chunk has a 4-bit sequence number.
- There is no separate part index.
- The command is not repeated on every chunk.
- The length is not repeated on every chunk.
- Continuation order is validated by incrementing the sequence modulo 16.

Status byte values for common cases:

| MSP version | Start? | Sequence | Status byte |
| --- | --- | ---: | ---: |
| v1 | yes | 0 | `0x30` |
| v1 | no | 1 | `0x21` |
| v1 | no | 2 | `0x22` |
| v2 | yes | 0 | `0x50` |
| v2 | no | 1 | `0x41` |
| v2 | no | 2 | `0x42` |

These examples assume `mspSeq` starts at zero. In the running Suite, `mspSeq` is global to the common layer and continues across requests.

## TX Splitting

`common.mspProcessTxQ()` takes bytes from `mspTxBuf` and emits protocol-sized chunks.

Each emitted chunk has:

```text
STATUS BYTE, MSP-BUFFER BYTE 1, MSP-BUFFER BYTE 2, ...
```

The number of MSP-buffer bytes per chunk is:

```text
maxTxBufferSize - 1
```

Because byte 1 is always the Suite status byte.

For MSP v1:

- The CRC is accumulated while copying logical MSP bytes into chunks.
- If the current chunk has room after all logical MSP bytes are copied, the CRC byte is appended.
- Remaining unused bytes in the final chunk are padded with zeroes.
- Once the final chunk is sent, `mspTxBuf`, `mspTxIdx`, and `mspTxCRC` are cleared.

For MSP v2:

- Bytes are copied until the logical v2 buffer is exhausted.
- Unused bytes in each chunk are padded with zeroes.
- No v2 CRC is appended by this Lua code.

### TX Pseudocode

This is intentionally close to the Lua behavior:

```text
function sendRequest(cmd, payload):
    if payload is not a byte table:
        return false
    if cmd is nil:
        return false
    if txBuffer is not empty:
        return false

    if mspVersion == 1:
        txBuffer = [len(payload), cmd & 0xFF, payload...]
    else:
        txBuffer = [
            0,
            cmd & 0xFF,
            (cmd >> 8) & 0xFF,
            len(payload) & 0xFF,
            (len(payload) >> 8) & 0xFF,
            payload...
        ]

    lastRequest = cmd
    txIndex = 0
    txCrc = 0
    return true
```

```text
function processTxQueue():
    if txBuffer is empty:
        return false

    chunk = []
    chunk[0] = makeStatusByte(isStart = (txIndex == 0))
    txSequence = (txSequence + 1) & 0x0F

    maxChunkBytes = protocol.maxTxBufferSize
    outIndex = 1

    while outIndex < maxChunkBytes and txIndex < len(txBuffer):
        chunk[outIndex] = txBuffer[txIndex]
        if mspVersion == 1:
            txCrc = txCrc XOR chunk[outIndex]
        txIndex += 1
        outIndex += 1

    if mspVersion == 1:
        if outIndex < maxChunkBytes:
            chunk[outIndex] = txCrc
            outIndex += 1
            pad chunk with zeroes to maxChunkBytes
            clear txBuffer, txIndex, txCrc
            protocol.mspSend(chunk)
            return false

        protocol.mspSend(chunk)
        return true

    else:
        pad chunk with zeroes to maxChunkBytes
        protocol.mspSend(chunk)
        if txIndex >= len(txBuffer):
            clear txBuffer, txIndex, txCrc
            return false
        return true
```

Implementation notes:

- `processTxQueue()` returns whether more chunks remain to be sent.
- `mspQueue.lua` does not rely heavily on that return value; it calls `mspProcessTxQ()` during wakeups while the logical message remains in flight.
- The protocol send function receives exactly one Suite MSP chunk at a time.
- S.Port chunks should be 6 bytes.
- CRSF chunks should be 8 bytes.

## TX Example: MSP v1 over S.Port

Suppose:

```text
cmd     = 200 decimal = 0xC8
payload = 0A 14 1E 28 32 3C
```

The logical MSP v1 request buffer is:

```text
06 C8 0A 14 1E 28 32 3C
```

CRC is:

```text
06 ^ C8 ^ 0A ^ 14 ^ 1E ^ 28 ^ 32 ^ 3C
```

Which gives:

```text
CRC = E8
```

S.Port `maxTxBufferSize` is 6, so each Suite chunk carries:

```text
1 status byte + 5 logical bytes
```

Assuming the TX sequence starts at zero, the Suite chunks are:

```text
chunk 1:
  30, 06, C8, 0A, 14, 1E

chunk 2:
  21, 28, 32, 3C, E8, 00
```

Notice:

- `CMD` appears only in chunk 1 because it is part of the logical MSP header.
- Chunk 2 is identified by the sequence number, not by a part index.
- The CRC appears only once, at the end of the final chunk.
- The final zero is padding, not payload.

## TX Example: MSP v1 over CRSF

With the same command and payload, CRSF `maxTxBufferSize` is 8, so each Suite chunk carries:

```text
1 status byte + 7 logical bytes
```

The chunks are:

```text
chunk 1:
  30, 06, C8, 0A, 14, 1E, 28, 32

chunk 2:
  21, 3C, E8, 00, 00, 00, 00, 00
```

The same logical MSP buffer is used. Only the transport chunk size changes.

## TX Example: MSP v2 over CRSF

Suppose:

```text
cmd     = 0x012C
payload = AA BB CC
```

The logical MSP v2 request buffer is:

```text
00 2C 01 03 00 AA BB CC
```

Where:

- `00` is flags.
- `2C 01` is command `0x012C`, little-endian.
- `03 00` is length 3, little-endian.
- `AA BB CC` is payload.

CRSF `maxTxBufferSize` is 8, so the first Suite chunk carries one status byte plus seven logical bytes:

```text
chunk 1:
  50, 00, 2C, 01, 03, 00, AA, BB

chunk 2:
  41, CC, 00, 00, 00, 00, 00, 00
```

Assumptions:

- MSP version is 2.
- TX sequence starts at zero.
- No v2 CRC is appended by the current Lua code.

## S.Port/F.Port Transport Wrapping

`sp.lua` maps each 6-byte Suite chunk into a FrSky telemetry frame.

Given:

```text
chunk[1], chunk[2], chunk[3], chunk[4], chunk[5], chunk[6]
```

S.Port sends:

```text
physId = 0x0D
primId = 0x30
appId  = chunk[1] | (chunk[2] << 8)
value  = chunk[3] | (chunk[4] << 8) | (chunk[5] << 16) | (chunk[6] << 24)
```

Inbound replies are accepted from:

```text
physId = 0x1B for S.Port remote sensor
physId = 0x00 for F.Port remote sensor
primId = 0x32
```

Then `appId` and `value` are mapped back to the same 6-byte Suite chunk shape:

```text
byte 1 = appId low
byte 2 = appId high
byte 3 = value byte 0
byte 4 = value byte 1
byte 5 = value byte 2
byte 6 = value byte 3
```

`sp.lua` also performs a light sequence filter before passing chunks to `common.lua`:

- A start chunk begins a reply.
- Duplicate continuation sequence numbers are ignored.
- Out-of-order continuation sequence numbers abort the current reply.

## CRSF Transport Wrapping

`crsf.lua` wraps each Suite chunk into a CRSF MSP frame.

For outgoing frames, it prepends CRSF routing bytes:

```text
0xC8, 0xEA, SUITE_CHUNK...
```

Where:

- `0xC8` is the flight controller/BetaFlight address.
- `0xEA` is the radio transmitter address.

CRSF defines these MSP frame types:

```text
0x7A = MSP read request
0x7C = MSP write request
```

Current Suite queue behavior is subtle: `mspQueue.lua` always calls `mspProtocol.mspWrite(command, payload or {})`, even for logical reads with an empty payload. Therefore queued Suite API traffic currently uses the CRSF `mspWrite()` wrapper and frame type `0x7C`.

`crsf.lua` also provides `mspRead()`, which would select `0x7A`, but the current queue path does not call it.

Inbound replies are popped as CRSF frame type:

```text
0x7B = MSP response
```

Inbound CRSF payloads must begin with reverse routing:

```text
0xEA, 0xC8, SUITE_CHUNK...
```

`crsf.lua` strips the first two routing bytes and returns only the Suite chunk to `common.lua`.

The actual CRSF physical frame length and CRSF frame CRC are handled by the Ethos CRSF sensor API, not by this Lua code.

## Reply Reassembly

Replies are reassembled by `common._receivedReply(payload)`, where `payload` is one Suite chunk returned by the active transport.

The first byte is always the Suite status byte:

```text
status = payload[1]
versionBits = (status & 0x60) >> 5
start = (status & 0x10) ~= 0
seq = status & 0x0F
```

### Start Chunk

If `start` is set:

- RX buffer is reset.
- Error flag is read from bit 7 of the status byte.
- Header is parsed from the chunk after the status byte.

For MSP v1 replies:

```text
LEN CMD PAYLOAD... CRC
```

The code:

- Reads `LEN`.
- Usually reads `CMD` when `versionBits == 1`.
- Initializes CRC as `LEN ^ CMD`.
- Accepts the reply only if `CMD == mspLastReq`.

There is also legacy handling for `versionBits == 0`, where the reply command is assumed to be the last request command instead of read from the frame.

For MSP v2 replies:

```text
FLAGS CMD_LOW CMD_HIGH LEN_LOW LEN_HIGH PAYLOAD...
```

The code:

- Reads flags.
- Reads 16-bit command.
- Reads 16-bit payload length.
- Accepts the reply only if `CMD == mspLastReq`.

### Continuation Chunk

If `start` is not set:

- A reply must already be in progress.
- Sequence must equal `(previousSeq + 1) & 0x0F`.
- On a sequence mismatch, the current reply is discarded.

### Payload Copy

After header handling, bytes are copied into `mspRxBuf` until:

```text
#mspRxBuf == expected payload length
```

Padding bytes after the payload are ignored except for the v1 CRC byte.

### Completion

When enough payload bytes have been collected:

- RX assembly is marked complete.
- MSP v1 CRC is accumulated. The current Lua rejection check only fires when `versionBits == 0`; for normal `versionBits == 1` replies the mismatch condition is not used to reject the packet.
- `mspPollReply()` returns:

```lua
cmd, mspRxBuf, mspRxError
```

`mspQueue.lua` then compares `cmd` with the active message command and calls the message completion or retry/error path.

### RX Pseudocode

This is close to current Lua behavior, including the v1 CRC quirk:

```text
function receiveChunk(chunk):
    idx = 0
    status = chunk[idx]
    versionBits = (status & 0x60) >> 5
    start = (status & 0x10) != 0
    seq = status & 0x0F
    idx += 1

    if start:
        rxBuffer = []
        rxError = (status & 0x80) != 0

        if configuredMspVersion == 2:
            flags = chunk[idx]; idx += 1
            cmdLow = chunk[idx]; idx += 1
            cmdHigh = chunk[idx]; idx += 1
            lenLow = chunk[idx]; idx += 1
            lenHigh = chunk[idx]; idx += 1
            rxCommand = cmdLow | (cmdHigh << 8)
            rxSize = lenLow | (lenHigh << 8)
            rxCrc = 0
            rxStarted = (rxCommand == lastRequest)

        else:
            rxSize = chunk[idx]; idx += 1
            rxCommand = lastRequest
            if versionBits == 1:
                rxCommand = chunk[idx]
                idx += 1
            rxCrc = rxSize XOR rxCommand
            rxStarted = (rxCommand == lastRequest)

    else:
        if not rxStarted:
            resetRxAssembly()
            return nil
        if ((remoteSeq + 1) & 0x0F) != seq:
            resetRxAssembly()
            return nil

    while idx < protocol.maxRxBufferSize and len(rxBuffer) < rxSize:
        value = chunk[idx]
        append value to rxBuffer
        if configuredMspVersion == 1 and value is not nil:
            rxCrc = rxCrc XOR value
        idx += 1

    if len(rxBuffer) < rxSize:
        remoteSeq = seq
        return false

    rxStarted = false

    if configuredMspVersion == 1:
        receivedCrc = chunk[idx] or 0
        if rxCrc != receivedCrc and versionBits == 0:
            report CRC error
            return nil

    return true
```

### RX State Machine

The firmware-side RX assembler can be modeled like this:

```text
IDLE
  on start chunk for lastRequest:
    parse header
    copy payload bytes
    if complete -> COMPLETE
    else -> ACCUMULATING

IDLE
  on continuation chunk:
    discard

ACCUMULATING
  on expected sequence continuation:
    copy payload bytes
    if complete -> COMPLETE
    else remain ACCUMULATING

ACCUMULATING
  on duplicate/out-of-order sequence:
    discard current assembly
    -> IDLE

COMPLETE
  optional v1 CRC behavior as above
  return cmd, payload, error
  clear lastRequest in mspPollReply()
  -> IDLE
```

`sp.lua` has its own light sequence filter before `common.lua` sees chunks. Firmware should avoid double-dropping valid frames if both layers are retained during migration.

### RX Byte Example: MSP v1 Reply over S.Port

Assume the Suite sent command `0xC8` and the FC replies with three payload bytes:

```text
payload = 11 22 33
```

Logical v1 reply:

```text
03 C8 11 22 33 CB
```

CRC calculation:

```text
03 ^ C8 ^ 11 ^ 22 ^ 33 = CB
```

With S.Port chunk size 6 and remote sequence starting at zero:

```text
chunk 1:
  30, 03, C8, 11, 22, 33

chunk 2:
  21, CB, 00, 00, 00, 00
```

`common._receivedReply()` behavior:

1. Sees `0x30`: v1, start, seq 0.
2. Reads length `0x03`.
3. Reads command `0xC8` because `versionBits == 1`.
4. Copies `11 22 33` into `mspRxBuf`.
5. Reply is complete after chunk 1 because payload length is satisfied.
6. The CRC byte is expected at the next byte index in the same chunk. Because this example's CRC is in chunk 2, the current Lua shape would complete before consuming chunk 2.

This highlights an important compatibility detail: the current Lua assembler expects the v1 CRC to be available immediately after the final payload byte in the same chunk where the payload completes. For normal Suite-generated TX frames, the CRC is placed that way when there is room. Firmware-side RX should be tested with real FC replies for how the FC chunks CRC on S.Port and CRSF.

If the reply payload length leaves room for CRC in the same chunk, for example two payload bytes:

```text
logical reply: 02 C8 11 22 F9
chunk 1:       30, 02, C8, 11, 22, F9
```

The assembler reads CRC from the same chunk index after the payload bytes.

## Queue Retry and Timeout Interaction

The queue sends a logical MSP message once, then waits for a matching reply.

Important queue behavior:

- It calls `mspProtocol.mspWrite(command, payload)` to stage the logical request.
- It calls `mspCommon.mspProcessTxQ()` during wakeups to continue emitting chunks.
- It calls `mspCommon.mspPollReply()` to receive and reassemble replies.
- Per-message timeout is `message.timeout` or the protocol queue default.
- `retryBackoff` controls the delay before resending the same logical message.
- `retryOnErrorReply = true` causes MSP error replies to be retried.
- `completeOnErrorReplyAttempt = N` allows an MSP error reply to be treated as completion after enough attempts.

Because `common.mspSendRequest()` returns `false` while a TX buffer is already active, firmware-side code should preserve equivalent "one logical MSP transfer in flight" semantics unless the higher-level queue is changed too.

## Simulator Mode

In simulator mode, `mspQueue.lua` bypasses transport framing. It uses:

```lua
message.simulatorResponse
```

as the complete reply buffer. This is not representative of wire framing.

## Firmware Migration Notes

If this code moves into Ethos firmware, the firmware-side API should likely expose a logical MSP transaction interface rather than making Lua manage chunks.

The minimum logical interface needed by Suite would be close to:

```text
sendMsp(command, payload, options)
pollMspReply() -> command, payload, error
resetMspTransport()
```

The firmware implementation would need to own:

- MSP v1/v2 logical request buffer construction.
- Suite status-byte generation or a compatible replacement.
- Chunk splitting by active transport capacity.
- Sequence tracking.
- MSP v1 CRC append and current-compatible RX CRC behavior.
- CRSF routing bytes and frame type selection for MSP request/write/response.
- S.Port/F.Port appId/value packing and unpacking.
- Reply reassembly across telemetry frames.
- Timeout/retry hooks, or enough state for Lua's queue to keep controlling timeout/retry policy.

Compatibility-sensitive details:

- Existing Lua expects one logical command in flight at a time.
- Existing duplicate suppression is done above the transport in `mspQueue.lua`.
- Existing logs and progress UI rely on command-level completion, not per-chunk completion.
- The command is not repeated in continuation chunks.
- Continuation chunks are only ordered by the status sequence nibble.
- S.Port final chunks are padded to 6 bytes.
- CRSF Suite chunks are padded to 8 bytes before CRSF wrapping.
- Current Lua MSP v2 behavior does not append/check a v2 CRC in `common.lua`; changing that may affect compatibility and should be tested against the FC MSP implementation.
- Current Lua v1 RX CRC rejection behavior is not a strict "reject all bad CRCs" check for normal `versionBits == 1` replies. Treat this as a compatibility point to verify before tightening behavior in firmware.

## Proposed Firmware Boundary

There are two realistic migration shapes.

Option A: firmware owns only telemetry chunk transport.

```text
Lua still builds Suite chunks
Firmware sends/receives CRSF or S.Port frames
Lua still runs common.lua reassembly
```

This is the smallest firmware change, but it leaves most MSP CPU/memory churn in Lua.

Option B: firmware owns MSP-over-telemetry transactions.

```text
Lua sends command + payload
Firmware builds MSP buffer, chunks, sends, receives, reassembles
Lua receives command + payload + error
```

This is the useful target if the aim is to move MSP code out of Lua. It lets Lua avoid repeated chunk tables, CRC work, sequence checks, and telemetry polling loops.

Suggested firmware-facing API for Option B:

```text
bool mspStart(command, payloadBytes, options)
MspStatus mspPoll()
void mspReset()
```

Where `mspPoll()` returns one of:

```text
idle
busy
complete(command, payloadBytes, errorFlag)
timeout
transport_error
crc_error
sequence_error
```

The existing Lua queue could then be simplified to:

```text
if no transaction in flight:
    firmware.mspStart(command, payload, options)

status = firmware.mspPoll()
if status == complete:
    call processReply(payload)
if status is terminal error:
    call errorHandler(reason) or retry
```

## Implementation Test Vectors

These vectors are useful for validating a firmware implementation against current Lua behavior.

### Vector 1: MSP v1 TX, S.Port Chunking

Input:

```text
mspVersion = 1
maxTxBufferSize = 6
initial mspSeq = 0
cmd = C8
payload = 0A 14 1E 28 32 3C
```

Logical buffer:

```text
06 C8 0A 14 1E 28 32 3C
```

CRC:

```text
E8
```

Expected Suite chunks:

```text
30 06 C8 0A 14 1E
21 28 32 3C E8 00
```

Expected S.Port outbound frames:

```text
physId=0D primId=30 appId=0630 value=1E140AC8
physId=0D primId=30 appId=2821 value=00E83C32
```

Note: `appId` and `value` are shown as assembled numeric little-endian fields.

### Vector 2: MSP v1 TX, CRSF Chunking

Input:

```text
mspVersion = 1
maxTxBufferSize = 8
initial mspSeq = 0
cmd = C8
payload = 0A 14 1E 28 32 3C
```

Expected Suite chunks:

```text
30 06 C8 0A 14 1E 28 32
21 3C E8 00 00 00 00 00
```

Expected CRSF MSP payloads before Ethos CRSF frame wrapping:

```text
C8 EA 30 06 C8 0A 14 1E 28 32
C8 EA 21 3C E8 00 00 00 00 00
```

Frame type should be:

```text
7C for current queued Suite API traffic
7A only if a caller explicitly uses the CRSF mspRead() wrapper
```

The current `mspQueue.lua` path uses `mspWrite()` for both logical reads and writes.

### Vector 3: MSP v2 TX, CRSF Chunking

Input:

```text
mspVersion = 2
maxTxBufferSize = 8
initial mspSeq = 0
cmd = 012C
payload = AA BB CC
```

Logical buffer:

```text
00 2C 01 03 00 AA BB CC
```

Expected Suite chunks:

```text
50 00 2C 01 03 00 AA BB
41 CC 00 00 00 00 00 00
```

No v2 CRC byte is appended by the current Lua code.

### Vector 4: MSP v1 RX, Single Chunk

Input Suite chunk:

```text
30 02 C8 11 22 F9
```

Configured:

```text
mspVersion = 1
mspLastReq = C8
```

Expected:

```text
cmd = C8
payload = 11 22
error = false
complete = true
```

CRC:

```text
02 ^ C8 ^ 11 ^ 22 = F9
```

### Vector 5: MSP v2 RX, Single CRSF-Sized Chunk

Input Suite chunk:

```text
50 00 2C 01 03 00 AA BB CC
```

Configured:

```text
mspVersion = 2
mspLastReq = 012C
maxRxBufferSize >= 9
```

Expected:

```text
cmd = 012C
payload = AA BB CC
error = false
complete = true
```

## Open Questions Before Firmware Cutover

- Should firmware preserve the current v1 RX CRC behavior exactly, or should it strictly reject all bad v1 CRCs?
- Should firmware add MSP v2 CRC support, and if so does the FC currently expect it on this telemetry path?
- Should Lua continue to own retry policy, or should firmware expose timeout/retry as transaction options?
- Should firmware expose raw chunk logging equivalent to `proto_logger.lua` for field debugging?
- How should simulator mode be represented if firmware owns the MSP transaction layer?
- Should S.Port's light prefilter remain in Lua during migration, or should firmware make `common.lua` unnecessary in one step?

## Short Answers

Does Suite repeat the command on each frame?

No. The command is part of the logical MSP header and normally appears only in the first chunk.

Does Suite use a part index?

No full part index is used. Each chunk carries a 4-bit sequence number in the status byte.

Is there a length and CRC?

For MSP v1, yes:

```text
LEN CMD PAYLOAD... CRC
```

The length and command are at the start of the logical MSP frame. The CRC is appended at the end of the final emitted chunk.

For MSP v2, the Lua code uses:

```text
FLAGS CMD16 LEN16 PAYLOAD...
```

and does not append/check a v2 CRC in `common.lua`.
