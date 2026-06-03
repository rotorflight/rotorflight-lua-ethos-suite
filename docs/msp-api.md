# MSP API Layer in Rotorflight Suite

This document describes the MSP API layer used by Rotorflight Suite. It complements:

- `docs/msp-framing-and-transport.md`
- `docs/msp-queue.md`

The intended audience is developers who need to understand or reimplement the Lua API layer, especially if MSP transport and queue work is moved into Ethos firmware.

Main files:

- `src/rfsuite/tasks/scheduler/msp/api.lua`: API module loader, caches, help injection, apidata storage helpers.
- `src/rfsuite/tasks/scheduler/msp/api/core.lua`: factory functions used by individual API modules.
- `src/rfsuite/tasks/scheduler/msp/api/*.lua`: individual API definitions.
- `src/rfsuite/tasks/scheduler/msp/apihelp/*.lua`: optional field help metadata.
- `src/rfsuite/app/lib/ui.lua`: main page read/save orchestration and `apidata` persistence.

## Purpose

The MSP API layer converts named API definitions such as `BATTERY_CONFIG` or `ESC_PARAMETERS_HW5` into runtime API instances. A runtime API instance knows how to:

- Build a queue message for read or write.
- Parse an MSP reply buffer into named fields.
- Build a write payload from named field values.
- Store per-instance callback/state such as UUID, timeout, staged values, and write completion.
- Expose field metadata to pages and form builders.
- Provide optional simulator responses.
- Provide optional custom methods and exported constants.

The API layer does not send bytes directly. It always hands logical messages to:

```lua
rfsuite.tasks.msp.mspQueue:add(message)
```

The queue and transport layers then handle retries, framing, chunking, and telemetry I/O.

## High-Level Flow

Read flow:

```text
API = tasks.msp.api.load("BATTERY_CONFIG")
API.setCompleteHandler(fn)
API.setErrorHandler(fn)
API.read()
  -> build queue message
  -> mspQueue:add(message)
  -> queue/transport completes
  -> message.processReply(buf)
  -> parse buf into state.mspData
  -> completeHandler(self, buf)
```

Write flow:

```text
API = tasks.msp.api.load("BATTERY_CONFIG")
API.setValue("field", value)
API.setCompleteHandler(fn)
API.setErrorHandler(fn)
API.write()
  -> build payload from staged values
  -> build queue message
  -> mspQueue:add(message)
  -> queue/transport completes
  -> message.processReply(buf)
  -> mark write complete
  -> completeHandler(self, buf)
```

## Loader Responsibilities

`api.lua` is a small module loader with bounded caches.

Important loader state:

| Field | Meaning |
| --- | --- |
| `_fileExistsCache` | Caches `utils.file_exists(path)` results. Max 24 entries. |
| `_chunkCache` | Caches compiled API module chunks. Max 2 entries. |
| `_helpChunkCache` | Caches compiled API help chunks. Max 2 entries. |
| `_helpDataCache` | Caches parsed help field tables. |
| `_deltaCacheDefault` | Default delta-cache setting. Initially true. |
| `_deltaCacheByApi` | Per-API delta-cache overrides. |
| `_ported` | Optional API-name to module-path registry. |
| `apidata` | Shared runtime page/API data cache. |
| `_core` | Cached `api/core.lua` module. |

Bounded caches are intentional for radio memory behavior. Avoid changing them to unbounded caches without checking memory impact.

## API Module Resolution

Default API path:

```text
SCRIPTS:/<baseDir>/tasks/scheduler/msp/api/<API_NAME>.lua
```

Default help path:

```text
SCRIPTS:/<baseDir>/tasks/scheduler/msp/apihelp/<API_NAME>.lua
```

`api.register(apiName, modulePath)` can override the source path for an API. If the module path is not absolute `SCRIPTS:/...`, it is resolved relative to the default API directory.

Resolution order:

1. Registered/ported module path, if present.
2. Default API path.

Only one candidate is normally active. A registered path replaces the default path.

## `api.load(apiName, loadOpts)`

The main entry point is:

```lua
local API = rfsuite.tasks.msp.api.load("BATTERY_CONFIG")
```

Optional help loading:

```lua
api.load("BATTERY_CONFIG", true)
api.load("BATTERY_CONFIG", {loadHelp = true})
```

`loadHelp = true` injects help strings from `apihelp/<API_NAME>.lua` into:

```lua
API.__rfReadStructure
API.__rfWriteStructure
```

The loader also:

- Ensures `api/core.lua` is loaded.
- Executes the API module chunk.
- Validates that the result is a table with `read` or `write`.
- Adds `__apiName`.
- Adds `__apiSource`.
- Wraps `read()` and `write()` to log API I/O.
- Injects `API.enableDeltaCache(enable)`.
- Injects `API.isDeltaCacheEnabled()`.

## Loader Return and Failure Modes

`api.load()` returns the API table on success.

It returns nil when:

- `apiName` is invalid.
- File cannot be found.
- `api/core.lua` cannot be compiled/loaded.
- API file cannot be compiled.
- The module result is not a valid API table.

Errors inside the API module chunk are not caught by `pcall` in the loader. A runtime error while executing the module can propagate.

## Shared `apidata`

`api.apidata` is a shared cache populated mainly by page read flows in `app/lib/ui.lua`.

Common shape:

```lua
tasks.msp.api.apidata = {
    values = {},
    structure = {},
    receivedBytes = {},
    receivedBytesCount = {},
    positionmap = {},
    other = {},
    _lastReadMode = {},
    _lastWriteMode = {}
}
```

On successful page reads, UI code copies:

```lua
local data = API.data()
apidata.values[apiKey] = data.parsed
apidata.structure[apiKey] = data.structure
apidata.receivedBytes[apiKey] = data.buffer
apidata.receivedBytesCount[apiKey] = data.receivedBytesCount
apidata.positionmap[apiKey] = data.positionmap
apidata.other[apiKey] = data.other or {}
```

This cache is used by:

- Form/value population.
- Delta write payload construction.
- Debug/log suffixes such as `mode=delta`.
- Some modules/tools that read API values directly.

Important lifecycle rule: for normal config APIs, `API.data()` must be copied inside the completion callback. `createConfigAPI()` clears `state.mspData` immediately after `emitComplete()` returns to reduce duplicate memory.

## Clearing API Data

`api.clearEntry(apiName)` clears one API from `apidata`.

It clears:

- `values[apiName]`
- `structure[apiName]`
- `receivedBytes[apiName]`
- `receivedBytesCount[apiName]`
- `positionmap[apiName]`
- `other[apiName]`
- `_lastReadMode[apiName]`
- `_lastWriteMode[apiName]`

`api.resetApidata()` clears known sub-tables in place, then replaces:

```lua
api.apidata = {}
```

Use `clearEntry()` for scoped cleanup. `resetApidata()` is broader and normally used during app/page reset flows.

## API Factories

`core.lua` provides four main factories:

- `core.createReadOnlyAPI(spec)`
- `core.createConfigAPI(spec)`
- `core.createCustomAPI(spec)`
- `core.createWriteOnlyAPI(spec)`

All factories return an API instance table with a common method surface, plus optional `methods` and `exports`.

## Common Runtime API Methods

Most runtime API instances expose:

```lua
API.read(...)
API.write([suppliedPayload], ...)
API.data()
API.readValue(fieldName)
API.readComplete()
API.writeComplete()
API.setValue(fieldName, value)
API.resetWriteStatus()
API.setCompleteHandler(fn)
API.setErrorHandler(fn)
API.setUUID(uuid)
API.setTimeout(timeout)
API.setRebuildOnWrite(boolean)
API.enableDeltaCache(boolean)
API.isDeltaCacheEnabled()
```

Not every method is meaningful for every factory:

- Read-only APIs return `false, "write_not_supported"` from `write()`.
- Write-only APIs return `false, "read_not_supported"` from `read()`.
- Read-only `setValue()`, `resetWriteStatus()`, and `setRebuildOnWrite()` are no-ops.
- Write-only `data()` and `readValue()` return nil.

## Runtime API State

Factories keep per-instance state in a closure. Common state fields:

| State field | Meaning |
| --- | --- |
| `mspData` | Last parsed read result, if retained. |
| `mspWriteComplete` | True after a write reply completes. |
| `payloadData` | Values staged with `setValue(fieldName, value)`. |
| `uuid` | UUID/key applied to queued messages. |
| `timeout` | Per-message timeout applied to queued messages. |
| `rebuildOnWrite` | Controls full/rebuild write behavior. |

Because state is per loaded instance, a newly loaded API starts with fresh callbacks and staged values. The loader caches compiled chunks, not runtime API instances.

## Field Tuple Format

Config-style APIs define fields as tuples:

```lua
{
    "batteryCapacity", "U16", 0, 20000, 0, "mAh", nil, nil, 50
}
```

Tuple positions:

| Index | Name | Meaning |
| ---: | --- | --- |
| 1 | field | Field name. |
| 2 | type | MSP helper type such as `U8`, `U16`, `S32`. |
| 3 | min | UI/validation metadata. |
| 4 | max | UI/validation metadata. |
| 5 | default | Default value used when building payloads if no staged value exists. |
| 6 | unit | UI display unit. |
| 7 | decimals | UI decimal metadata. |
| 8 | scale | Transport/display scaling metadata. |
| 9 | step | UI step metadata. |
| 10 | mult | UI multiplier metadata. |
| 11 | table | Value table/enum labels. |
| 12 | tableIdxInc | Table index adjustment. |
| 13 | mandatory | If false, excluded from `minBytes`. |
| 14 | byteorder | Optional byte order passed to helper read/write functions. |
| 15 | tableEthos | Ethos-specific table metadata. |
| 16 | offset | Optional metadata. |
| 17 | xvals | Optional metadata. |

`buildRuntimeStructure()` converts tuple specs into structure entries:

```lua
{
    field = "batteryCapacity",
    type = "U16",
    min = 0,
    max = 20000,
    default = 0,
    unit = "mAh",
    ...
}
```

It also builds:

- ordered field names
- reader functions
- byteorder list
- `minBytes`
- `positionmap`

`positionmap[fieldName]` is usually:

```lua
{start = byteOffset, size = byteCount}
```

This is used for delta writes.

## Supported MSP Types

`TYPE_SIZES` in `core.lua` currently includes:

```text
U8/S8, U16/S16, U24/S24, U32/S32,
U40/S40, U48/S48, U56/S56, U64/S64,
U72/S72, U80/S80, U88/S88, U96/S96,
U104/S104, U112/S112, U120/S120,
U128/S128, U256/S256
```

For each type, `mspHelper` must provide:

```text
read<Type>
write<Type>
```

where relevant.

## Read-Only API Factory

`core.createReadOnlyAPI(spec)` is used for APIs that only read from the FC.

Required:

```lua
{
    name = "API_VERSION",
    readCmd = 1,
    fields = {"version_command", "U8", "version_major", "U8", "version_minor", "U8"}
}
```

or:

```lua
parseRead = function(buf, mspHelper, state) ... end
```

Read-only message fields sent to the queue:

```lua
{
    command = spec.readCmd,
    apiname = spec.name,
    minBytes = minBytes,
    processReply = processReply,
    errorHandler = onError,
    simulatorResponse = spec.simulatorResponseRead,
    timeout = state.timeout,
    uuid = state.uuid,
    retryOnErrorReply = spec.readRetryOnErrorReply == true,
    retryBackoff = spec.readRetryBackoff,
    completeOnErrorReplyAttempt = spec.readCompleteOnErrorReplyAttempt,
    payload = optional read payload
}
```

Read-only APIs support `buildReadPayload`, `readPayload`, and `resolveReadUUID`. They do not support `resolveReadTimeout` in the current implementation.

## Config API Factory

`core.createConfigAPI(spec)` is the standard read/write factory for FC-backed configuration.

Required:

```lua
{
    name = "BATTERY_CONFIG",
    readCmd = 32,
    writeCmd = 33,
    fields = FIELD_SPEC
}
```

Optional:

- `writeFields`
- `parseRead`
- `buildReadPayload`
- `readPayload`
- `buildWritePayload`
- `simulatorResponseRead`
- `simulatorResponseWrite`
- `resolveReadUUID`
- `resolveWriteUUID`
- `resolveReadTimeout`
- `resolveWriteTimeout`
- `readRetryOnErrorReply`
- `readRetryBackoff`
- `completeOnErrorReplyAttempt`
- `writeUuidFallback`
- `initialRebuildOnWrite`
- API version gates
- `methods`
- `exports`

Read messages include:

```lua
command = spec.readCmd
apiname = spec.name
minBytes = minBytes
processReply = handleReadReply
errorHandler = dispatchError
simulatorResponse = spec.simulatorResponseRead
timeout = state.timeout
uuid = state.uuid
retryOnErrorReply = spec.readRetryOnErrorReply == true
retryBackoff = spec.readRetryBackoff
completeOnErrorReplyAttempt = spec.readCompleteOnErrorReplyAttempt
payload = optional read payload
```

Write messages include:

```lua
command = spec.writeCmd
apiname = spec.name
payload = built or supplied payload
processReply = handleWriteReply
errorHandler = dispatchError
simulatorResponse = spec.simulatorResponseWrite or {}
timeout = state.timeout
uuid = resolved write UUID
```

## Custom API Factory

`core.createCustomAPI(spec)` is used when simple field tuples are not enough.

It supports:

- `customRead`
- `customWrite`
- `parseRead`
- `readCompleteCondition`
- `readCompleteFn`
- `validateWrite`
- dynamic simulator responses via function
- custom read/write structures

Custom read flow:

1. If `spec.customRead` exists, call it directly:

```lua
spec.customRead(state, emitComplete, dispatchError, ...)
```

2. Otherwise build a normal queue message.

Custom write flow:

1. If `spec.customWrite` exists, call it directly:

```lua
spec.customWrite(suppliedPayload, state, emitComplete, dispatchError, ...)
```

2. Otherwise validate, build payload, and queue a normal write message.

Example: `RXFAIL_CONFIG` uses `customWrite` to break a logical write into multiple queued MSP writes, one per changed channel.

Example: `BATTERY_INI` uses `customRead`/`customWrite` to read and write a local INI file without sending FC MSP traffic.

## Write-Only API Factory

`core.createWriteOnlyAPI(spec)` is used for APIs such as `EEPROM_WRITE`.

Required:

```lua
{
    name = "EEPROM_WRITE",
    writeCmd = 250
}
```

Optional:

- `buildWritePayload`
- `writePayload`
- `validateWrite`
- `simulatorResponseWrite`
- `resolveWriteUUID`
- `resolveWriteTimeout`
- `writeUuidFallback`
- `initialRebuildOnWrite`
- `methods`
- `exports`

Write-only `write()` sets `state.mspWriteComplete = false` before enqueueing the message.

## Version Gating

`operationSupported(spec, op)` applies API-version constraints.

For operation `read`:

```lua
minVersion = spec.readMinApiVersion or spec.minApiVersion
maxVersion = spec.readMaxApiVersion or spec.maxApiVersion
```

For operation `write`:

```lua
minVersion = spec.writeMinApiVersion or spec.minApiVersion
maxVersion = spec.writeMaxApiVersion or spec.maxApiVersion
```

If the current API version is outside the allowed range:

```lua
read()  -> false, "read_not_supported"
write() -> false, "write_not_supported"
```

## UUID Handling

`API.setUUID(uuid)` stores `state.uuid`.

Read UUID behavior:

- Most factories use `state.uuid`.
- Some APIs provide `resolveReadUUID(state, ...)`.

Write UUID behavior:

1. If `state.uuid` exists, use it.
2. Else if `spec.writeUuidFallback == true` or `"unique"`, generate a UUID with `utils.uuid()` or `tostring(os.clock())`.
3. Else use nil.
4. If `spec.resolveWriteUUID` exists, it overrides the message UUID.

UUIDs are passed to the queue for duplicate suppression. They are not MSP wire bytes.

## Timeout Handling

`API.setTimeout(timeout)` stores `state.timeout`.

Read/write messages pass this to the queue as:

```lua
message.timeout = state.timeout
```

Some config/custom/write-only APIs support:

```lua
resolveReadTimeout(state, ...)
resolveWriteTimeout(state, suppliedPayload, ...)
```

These can override the message timeout at queue-message build time.

Read-only APIs currently have `setTimeout()` but do not call `resolveReadTimeout`.

## Callback Handling

`setCompleteHandler(fn)` and `setErrorHandler(fn)` require functions. Passing non-functions raises an error.

Handlers are per loaded API instance.

Completion path:

- Read success parses `buf` and then calls the complete handler.
- Write success sets `state.mspWriteComplete = true` and calls the complete handler.

Error path:

- Parse errors call the error handler with `"parse_failed"` or custom parse error.
- Queue timeout/max-retries call the API error handler through the queue's `errorHandler`.
- Custom validation/build errors may call the error handler directly or return false/reason.

## Read Result Shape

Parsed read data normally has this shape:

```lua
{
    parsed = {
        fieldName = value
    },
    structure = readStructure,
    buffer = buf,
    positionmap = positionmap,
    other = nil,
    receivedBytesCount = #buf or parsed count
}
```

`API.readValue(fieldName)` returns:

```lua
state.mspData.parsed[fieldName]
```

if present.

`API.readComplete()` varies by factory:

- Read-only/config: `state.mspData ~= nil and receivedBytesCount >= minBytes`.
- Custom: uses `spec.readCompleteFn(state)` if present, else buffer length.
- Write-only: always false.

For normal config APIs, `state.mspData` is cleared after the complete handler returns. Use `API.data()` inside the complete handler.

## Write Payload Building

Writes can use:

1. A caller-supplied payload:

```lua
API.write(payload)
```

2. A spec-supplied builder:

```lua
buildWritePayload(payloadData, mspData, mspHelper, state, ...)
```

3. The generic structure builder:

```lua
core.buildWritePayload(apiName, payloadData, writeStructure, rebuildOnWrite)
```

`API.setValue(fieldName, value)` stages values into `state.payloadData`.

The generic full builder uses:

```lua
value = payloadData[name] or fieldDef.default or 0
value = floor(value * scale + 0.5)
mspHelper.write<Type>(tmp, value, optionalByteorder)
```

Important quirk: because it uses Lua `or`, a staged value of `false` is treated as absent. Numeric `0` is truthy in Lua and is preserved.

## Full Versus Delta Writes

`core.buildWritePayload()` chooses delta or full payload mode.

Delta mode is used when all of these exist:

```lua
apidata.positionmap[apiName]
apidata.receivedBytes[apiName]
apidata.receivedBytesCount[apiName]
```

unless:

```lua
noDelta == true
```

In config APIs, `noDelta` is:

```lua
state.rebuildOnWrite == true
```

So:

```lua
API.setRebuildOnWrite(true)
```

forces full/rebuild mode.

Delta mode starts with the previously received byte buffer and overwrites only editable fields found in the current form page. This preserves untouched fields and reduces reliance on defaults.

Full mode rebuilds the payload from `writeStructure` and staged/default values.

The API layer records write mode for logging:

```lua
apidata._lastWriteMode[apiName] = "delta"
apidata._lastWriteMode[apiName] = "full"
apidata._lastWriteMode[apiName] = "rebuild"
```

## Delta Cache Controls

Global default:

```lua
tasks.msp.api.enableDeltaCache(true|false)
```

Per API:

```lua
API.enableDeltaCache(true|false)
tasks.msp.api.setApiDeltaCache(apiName, true|false|nil)
```

Read-side storage uses the setting to decide whether to keep:

- `receivedBytes`
- `receivedBytesCount`
- `positionmap`

If delta cache is disabled for an API, reads still store parsed values and structure, but not the byte buffers needed for delta writes.

`isDeltaCacheEnabled(apiName)` returns false when the GUI is not running.

## Simulator Responses

`core.simResponse(bytes)` returns:

```lua
bytes
```

only in simulator mode. Outside simulator mode it returns nil.

This lets API modules define:

```lua
local SIM_RESPONSE = core.simResponse({...})
```

In real radio mode, simulator responses are omitted from queued messages. In simulator mode, `mspQueue.lua` uses `message.simulatorResponse` directly as the completed reply.

`createCustomAPI()` can also accept simulator response functions:

```lua
simulatorResponseRead = function(state, op, ...) return {...} end
```

## Methods and Exports

Factories support:

```lua
methods = {
    readVersion = function(state, ...) ... end
}
```

Each method is wrapped so callers do not receive the internal state directly:

```lua
api[name] = function(...)
    return fn(state, ...)
end
```

Factories also support:

```lua
exports = {
    simulatorResponse = SIM_RESPONSE,
    mspSignature = MSP_SIGNATURE
}
```

Exports are copied directly onto the API instance.

Current method examples:

- `API_VERSION.readVersion()`
- `FC_VERSION.readVersion()`
- `FC_VERSION.readRfVersion()`
- custom `resetWriteStatus()` implementations for INI-backed APIs

Most exports are static metadata such as `simulatorResponse`, ESC signatures, or header byte counts.

## API Help Injection

When `api.load(apiName, {loadHelp = true})` is used, help text from `apihelp/<apiName>.lua` is injected into structures.

For regular fields:

```lua
entry.help = helpFields[fieldName]
```

For bitmap fields:

```lua
bit.help = helpFields[parentField .. "->" .. bitName] or helpFields[bitName]
```

Help injection mutates the runtime structure table returned by the API instance.

## Page Read Orchestration

`app/lib/ui.lua` uses the API layer to read all APIs for a page.

Simplified flow:

```text
initialize tasks.msp.api.apidata tables
for each API in page.apidata.api:
    API = tasks.msp.api.load(apiKey, {loadHelp = true})
    API.enableDeltaCache(optional setting)
    API.setCompleteHandler(function()
        data = API.data()
        copy data into tasks.msp.api.apidata
        schedule next API
    end)
    API.setErrorHandler(function()
        retry up to 3 attempts
    end)
    API.read()
```

The page-level read flow has its own retry scheduling in addition to queue-level retry behavior.

## Page Save Orchestration

`app/lib/ui.lua` also saves page APIs.

Simplified flow:

```text
for each API in page.apidata.api:
    payloadData = apidata.values[apiName]
    API = tasks.msp.api.load(apiName)
    API.enableDeltaCache(optional setting)
    API.setRebuildOnWrite(optional setting)
    API.setErrorHandler(...)
    API.setCompleteHandler(...)
    copy form values into payloadData
    for each k, v in payloadData:
        API.setValue(k, v)
    if page.preSavePayload:
        payload = core.buildWritePayload(...)
        payload = page.preSavePayload(payload)
        API.write(payload)
    else:
        API.write()
```

Save completion is counted across all queued API writes. Enqueue rejection is treated as save failure.

## Custom API Patterns

Common patterns in the repository:

### Simple Config API

Example: `BATTERY_CONFIG`.

- Defines `FIELD_SPEC`.
- Uses `core.createConfigAPI`.
- Uses default parser and default write payload builder.
- Uses `writeUuidFallback = true`.

### Write-Only Command

Example: `EEPROM_WRITE`.

- Uses `core.createWriteOnlyAPI`.
- Supplies `validateWrite` to block writes while armed.
- Supplies empty write payload.
- Uses `writeUuidFallback = true`.

### Indexed Read/Write

Example: `GET_MIXER_INPUT_COLLECTIVE`.

- Read payload includes a fixed index.
- Write payload includes the fixed index plus fields.
- Custom UUID resolvers include the index.
- Uses `writeFields` because write payload differs from read payload.

### Multi-Message Custom Write

Example: `RXFAIL_CONFIG`.

- Reads a large structure.
- Normalizes changed items.
- Queues multiple write messages from one logical API write.
- Chains `processReply` callbacks to send the next item.

### Local INI API

Example: `BATTERY_INI`.

- Uses `customRead` and `customWrite`.
- Does not queue FC MSP traffic.
- Updates local model/session preferences.
- Implements custom reset behavior.

## API Module Spec Keys

Common spec keys:

| Key | Used by | Meaning |
| --- | --- | --- |
| `name` | all | API name and queue `apiname`. |
| `readCmd` | read/config/custom | MSP command for reads. |
| `writeCmd` | config/custom/write-only | MSP command for writes. |
| `fields` | read/config | Read field spec. |
| `writeFields` | config | Optional write field spec. |
| `readStructure` | custom | Prebuilt read structure. |
| `writeStructure` | custom | Prebuilt write structure. |
| `minBytes` | read/custom | Minimum bytes for read completion/queue cost. |
| `parseRead` | read/config/custom | Custom parser. |
| `buildReadPayload` | read/config/custom | Dynamic read payload builder. |
| `readPayload` | read/config/custom | Static read payload. |
| `buildWritePayload` | config/custom/write-only | Dynamic write payload builder. |
| `writePayload` | write-only | Static write payload. |
| `validateWrite` | custom/write-only | Validation hook. |
| `customRead` | custom | Fully custom read implementation. |
| `customWrite` | custom | Fully custom write implementation. |
| `simulatorResponseRead` | all readable | Sim reply bytes or function for custom. |
| `simulatorResponseWrite` | writable | Sim write response bytes or function for custom. |
| `resolveReadUUID` | read/config/custom | Dynamic read UUID. |
| `resolveWriteUUID` | config/custom/write-only | Dynamic write UUID. |
| `resolveReadTimeout` | config/custom | Dynamic read timeout. |
| `resolveWriteTimeout` | config/custom/write-only | Dynamic write timeout. |
| `writeUuidFallback` | writable | Generate UUID when caller did not set one. |
| `initialRebuildOnWrite` | writable | Initial `state.rebuildOnWrite`. |
| `readRetryOnErrorReply` | read/config/custom | Queue retry behavior for MSP error replies. |
| `readRetryBackoff` | read/config/custom | Queue retry backoff override. |
| `completeOnErrorReplyAttempt` | read/config/custom | Complete on error reply after N attempts. |
| `minApiVersion` | all | Shared min API version gate. |
| `maxApiVersion` | all | Shared max API version gate. |
| `readMinApiVersion` | readable | Read min version gate. |
| `readMaxApiVersion` | readable | Read max version gate. |
| `writeMinApiVersion` | writable | Write min version gate. |
| `writeMaxApiVersion` | writable | Write max version gate. |
| `methods` | all | Custom methods bound to internal state. |
| `exports` | all | Static values copied to API instance. |

## Message Handoff to Queue

The API layer builds queue messages with this shape:

```lua
{
    command = readCmd or writeCmd,
    apiname = spec.name,
    payload = optionalPayload,
    minBytes = minBytes,
    processReply = replyHandler,
    errorHandler = errorHandler,
    simulatorResponse = simBytes,
    timeout = resolvedTimeout,
    uuid = resolvedUuid,
    retryOnErrorReply = optional,
    retryBackoff = optional,
    completeOnErrorReplyAttempt = optional,
    structure = optionalCustomStructure
}
```

The queue then adds `_qid` and `_pageScript`.

## Pseudocode: Config API Read

```text
function API.read(...):
    if read not supported by API version:
        return false, "read_not_supported"

    payload = nil
    if spec.buildReadPayload:
        payload = spec.buildReadPayload(state.payloadData, state.mspData, mspHelper, state, ...)
    else if spec.readPayload exists:
        payload = spec.readPayload

    message = {
        command = spec.readCmd,
        apiname = spec.name,
        minBytes = computedMinBytes,
        processReply = handleReadReply,
        errorHandler = dispatchError,
        simulatorResponse = spec.simulatorResponseRead,
        timeout = state.timeout,
        uuid = state.uuid,
        retryOnErrorReply = spec.readRetryOnErrorReply == true,
        retryBackoff = spec.readRetryBackoff,
        completeOnErrorReplyAttempt = spec.completeOnErrorReplyAttempt
    }

    if spec.resolveReadUUID:
        message.uuid = spec.resolveReadUUID(state, ...)

    if payload is not nil:
        message.payload = payload

    if spec.resolveReadTimeout:
        message.timeout = spec.resolveReadTimeout(state, ...)

    return mspQueue:add(message)
```

## Pseudocode: Config API Write

```text
function API.write(suppliedPayload, ...):
    if write not supported by API version:
        return false, "write_not_supported"
    if spec.writeCmd is nil:
        return false, "write_not_supported"

    payload = suppliedPayload

    if payload is nil:
        if spec.buildWritePayload:
            payload = spec.buildWritePayload(state.payloadData, state.mspData, mspHelper, state, ...)
        else:
            payload = core.buildWritePayload(
                spec.name,
                state.payloadData,
                writeStructure,
                state.rebuildOnWrite == true
            )

    message = {
        command = spec.writeCmd,
        apiname = spec.name,
        payload = payload,
        processReply = handleWriteReply,
        errorHandler = dispatchError,
        simulatorResponse = spec.simulatorResponseWrite or {},
        timeout = state.timeout,
        uuid = resolveWriteUUID(spec, state)
    }

    if spec.resolveWriteUUID:
        message.uuid = spec.resolveWriteUUID(state, suppliedPayload, ...)

    if spec.resolveWriteTimeout:
        message.timeout = spec.resolveWriteTimeout(state, suppliedPayload, ...)

    return mspQueue:add(message)
```

## Firmware Migration Notes

If MSP framing/queue moves into firmware, the API layer can stay mostly in Lua. It would still need a queue-like transaction API to submit:

```text
command, payload, timeout, uuid, retry options, simulator response
```

If the API layer also moves into firmware, firmware would need to replace:

- API module discovery/loading or a generated registry.
- Field tuple metadata.
- MSP buffer parsing into named fields.
- Write payload building from named field values.
- Delta payload construction from previously read bytes.
- API version gating.
- Simulator response behavior or a simulator-mode substitute.
- Custom API hooks for INI/local APIs, multi-message writes, and indexed payloads.

A practical cutover would likely keep the API definitions in Lua first and move only queue/framing/transport into firmware. That preserves page metadata, form generation, custom Lua API modules, and existing save/read orchestration while removing the most frequent byte-level work from Lua.

## Compatibility Points

- API instances are stateful closures; reloading an API creates fresh staged values and callbacks.
- The loader caches compiled chunks, not instances.
- `API.data()` for config APIs must be consumed inside the completion callback.
- `writeUuidFallback = true` is widely used to avoid duplicate suppression collisions for writes.
- `API.setTimeout()` affects the next queued read/write message for that instance.
- Read-only APIs do not currently support `resolveReadTimeout`.
- The default config read handler clears `state.mspData` after completion to reduce memory.
- Delta writes depend on `apidata.receivedBytes`, `receivedBytesCount`, and `positionmap`.
- Delta cache is disabled when GUI is not running.
- Full payload building uses defaults for fields not staged by `setValue()`.
- Custom APIs may bypass the queue entirely, queue multiple messages, or interact with local files.

## Test Scenarios

An implementation or refactor should verify:

1. `api.load()` returns nil for missing APIs and valid API tables for existing APIs.
2. Help injection adds `help` fields when `loadHelp = true`.
3. Read-only API read enqueues a message and write returns `write_not_supported`.
4. Write-only API write enqueues a message and read returns `read_not_supported`.
5. Config API read parses named fields correctly.
6. Config API write builds expected payload bytes from `setValue()`.
7. Supplied payload to `API.write(payload)` bypasses generic payload building.
8. `setUUID()` reaches the queue message UUID.
9. `writeUuidFallback = true` generates unique write UUIDs.
10. `setTimeout()` reaches the queue message timeout.
11. `resolveReadUUID` and `resolveWriteUUID` override state UUID.
12. `resolveReadTimeout` and `resolveWriteTimeout` override state timeout where supported.
13. API version gates return `read_not_supported` or `write_not_supported`.
14. Custom parse failure calls the error handler.
15. Config API `API.data()` is available inside complete handler and cleared afterwards.
16. Delta writes use cached `receivedBytes` and `positionmap`.
17. `setRebuildOnWrite(true)` forces rebuild/full mode.
18. Disabling delta cache prevents received byte caches from being stored on page read.
19. Custom API `customWrite` can queue multiple messages and complete once all are done.
20. INI-backed custom APIs work without FC MSP traffic.

## Known Quirks

- `api.load()` executes API module chunks without `pcall`; module runtime errors can propagate.
- `api._chunkCacheMax` is only 2, so frequent API switching recompiles/reloads chunks after eviction.
- `buildFullPayload()` and `buildDeltaPayload()` allocate temporary tables while building write bytes; avoid invoking them in hot wakeup paths.
- `buildFullPayload()` uses `payloadData[name] or default or 0`; boolean false cannot be staged as a value.
- Read-only APIs expose write-related methods, but they are no-ops or unsupported.
- `createConfigAPI()` clears `state.mspData` after completion; this is intentional but easy to miss.
- `api.resetApidata()` clears known subtables in place, then replaces `api.apidata` with a new table.
- `isDeltaCacheEnabled()` returns false when `app.guiIsRunning` is false, even if the default is enabled.
- Most `exports.simulatorResponse` values are nil on real radios because `core.simResponse()` returns nil outside simulator mode.
