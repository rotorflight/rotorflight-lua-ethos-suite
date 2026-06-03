# MSP Queue Behavior in Rotorflight Suite

This document describes the MSP queue used by Rotorflight Suite. It is intended for developers who need to understand or reimplement the queue behavior, especially if MSP transport/framing work is moved from Lua into Ethos firmware.

The main file is:

- `src/rfsuite/tasks/scheduler/msp/mspQueue.lua`

Related files:

- `src/rfsuite/tasks/scheduler/msp/msp.lua`: creates and configures the singleton queue, calls it from `msp.wakeup()`, and clears it on disconnect/reset.
- `src/rfsuite/tasks/scheduler/msp/common.lua`: stages and emits the byte-level MSP chunks used by the queue.
- `src/rfsuite/tasks/scheduler/msp/protocols.lua`: provides protocol-specific queue defaults such as retry count, timeout, and queue depth.
- `src/rfsuite/tasks/scheduler/msp/api/core.lua`: builds the message tables submitted to the queue.

## Purpose

The MSP queue serializes logical MSP requests so the Suite only works on one command at a time. It is responsible for:

- Accepting logical MSP messages from API modules and tools.
- Rejecting duplicate or excessive messages.
- Maintaining a FIFO queue with low memory churn.
- Starting one active message at a time.
- Calling the active transport's `mspWrite(command, payload)` function.
- Pumping `common.mspProcessTxQ()` so staged bytes continue to leave the radio.
- Polling `common.mspPollReply()` for completed replies.
- Handling retry/backoff/timeout policy.
- Calling success/error handlers supplied with each message.
- Updating session/UI status such as `rfsuite.session.mspBusy` and `mspStatusMessage`.

The queue does not build MSP wire frames. It operates at command level. Framing and chunking are handled below it by `common.lua` and the active transport.

## Lifecycle

`msp.lua` creates a singleton queue:

```lua
mspQueue = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/mspQueue.lua"))()
msp.mspQueue = mspQueue
```

Then `msp.lua` applies protocol-specific settings:

```lua
mspQueue.maxRetries = msp.protocol.maxRetries
mspQueue.loopInterval = 0
mspQueue.copyOnAdd = true
mspQueue.interMessageDelay = 0.05
mspQueue.timeout = msp.protocol.mspQueueTimeout or 2.0
mspQueue.drainAfterReplyMss = 0.05
mspQueue.drainMaxPolls = 5
mspQueue.busyWarningThreshold = msp.protocol.mspQueueBusyWarning or 8
mspQueue.maxQueueDepth = msp.protocol.mspQueueMaxDepth or 20
mspQueue.busyStatusCooldown = msp.protocol.mspQueueBusyStatusCooldown or 0.35
```

Current protocol defaults:

| Protocol | `maxRetries` | `timeout` / `mspQueueTimeout` | `maxQueueDepth` |
| --- | ---: | ---: | ---: |
| S.Port/F.Port | 10 | 4.0 seconds | 20 |
| CRSF | 5 | 2.0 seconds | 20 |

Important typo/quirk: `msp.lua` sets `drainAfterReplyMss`, but `mspQueue.lua` reads `drainAfterReplyMs`. Because of the extra `s`, the assignment in `msp.lua` does not alter the actual drain window. The queue keeps its constructor default `drainAfterReplyMs = 0.03` unless another caller sets the correctly spelled field.

`msp.wakeup()` drives the queue:

```text
if telemetryState == true:
    mspQueue:processQueue()
else:
    mspQueue:clear()
```

The queue is also cleared during MSP reset, telemetry disconnect, app close/reset paths, and some page/module cleanup flows.

## Queue Data Structure

The queue is not a plain Lua array. It is a small FIFO object:

```lua
{
    first = 1,
    last = 0,
    data = {}
}
```

Operations:

- `qpush(q, value)`: increments `last` and stores at `data[last]`.
- `qpop(q)`: removes `data[first]`, advances `first`, and resets indexes when drained.
- `qreset(q)`: clears entries in place and resets `first/last`.
- `qcompact(q)`: occasionally moves active entries back to index 1.

This design avoids replacing the queue table in hot paths. It is intentionally memory-conscious for Ethos.

Compaction occurs when:

```text
q.first > 64 and q.first > activeCount
```

where `activeCount = q.last - q.first + 1`.

## Queue Controller State

The singleton returned by `mspQueue.lua` has these important fields:

| Field | Meaning |
| --- | --- |
| `queue` | FIFO of pending messages not yet in flight. |
| `currentMessage` | Active in-flight message, or `nil`. |
| `currentMessageStartTime` | Time of the first successful send for the active message. Used for overall message timeout. |
| `lastTimeCommandSent` | Time of the last successful call to `mspProtocol.mspWrite()`. Used for send interval and retry backoff. |
| `retryCount` | Number of successful send attempts for the active message. Starts at zero when popped from queue. |
| `maxRetries` | Maximum retry count setting. Actual send attempts are `maxRetries + 1`. |
| `timeout` | Default per-message timeout in seconds. Overridden by `message.timeout`. |
| `retryBackoff` | Default delay between resend attempts in seconds. Overridden by `message.retryBackoff`. |
| `drainAfterReplyMs` | Time window used to poll for duplicate/late replies after success. |
| `drainMaxPolls` | Maximum duplicate/late replies to drain after success. |
| `uuid` | Last queued duplicate-suppression key. |
| `apiname` | Present as a state field but not currently assigned independently; duplicate key includes `apiname` through `uuid`. |
| `interMessageDelay` | Gap after a message completes/fails before starting the next message. |
| `_nextMessageAt` | Earliest time the next message may start. |
| `loopInterval` | Legacy throttle for starting new messages. Usually zero. |
| `_nextProcessAt` | Earliest time allowed by `loopInterval`. |
| `copyOnAdd` | If true, clone messages when enqueuing. Set true by `msp.lua`. |
| `busyWarningThreshold` | Soft queue pressure threshold. Still enqueues. |
| `maxQueueDepth` | Hard pending-message cap. Zero disables hard cap. |
| `busyStatusCooldown` | Minimum seconds between busy status updates. |
| `_lastBusyStatusAt` | Timestamp of last busy status update. |
| `mspBusyStart` | Watchdog start time while queue is active. |
| `_qidSeq` | Monotonic queue id sequence assigned to messages. |

## Public Queue Methods

### `queue:queueCount()`

Returns the number of queued messages that are not currently in flight.

It does not include `currentMessage`.

### `queue:isProcessed()`

Returns true when:

```text
currentMessage == nil and queueCount() == 0
```

Many pages use this to decide whether it is safe to update UI state, close loaders, start another live update, or refresh data.

### `queue:add(message)`

Adds a message to the queue.

Return shape:

```lua
ok, reason, qid, pending = queue:add(message)
```

Reasons:

| Reason | `ok` | Meaning |
| --- | --- | --- |
| `queued` | true | Message accepted. |
| `queued_busy` | true | Message accepted, but pending count is above the soft warning threshold. |
| `duplicate` | false | Message key matches the last queued/in-flight key. |
| `busy` | false | Queue is at hard max depth. |
| `telemetry_off` | false | `rfsuite.session.telemetryState` is false. |
| `nil_message` | false | Caller passed nil. |

`pending` includes the in-flight message:

```text
pending = queueCount() + (currentMessage and 1 or 0)
```

### `queue:processQueue()`

Main state machine. Called from `msp.wakeup()` while telemetry is connected.

It:

1. Updates optional queue debug logging.
2. Marks idle state when processed.
3. Applies the busy watchdog.
4. Starts the next message when allowed.
5. Calls transport send/stage logic when retry gates allow it.
6. Pumps TX chunks through `common.mspProcessTxQ()`.
7. Polls replies through `common.mspPollReply()`.
8. Handles timeout, error-retry, success, or max-retry paths.

### `queue:clear()`

Clears pending and active queue state.

It:

- Sets `rfsuite.session.mspBusy = false`.
- Clears `mspBusyStart`.
- Wipes the FIFO queue in place.
- Clears `currentMessage`, `currentMessageStartTime`, and `lastTimeCommandSent`.
- Clears `_nextMessageAt`.
- Clears duplicate key state.
- Calls `rfsuite.tasks.msp.common.mspClearTxBuf()` if available.

It does not reset `_qidSeq`, `retryCount`, `maxRetries`, timeout settings, or pressure settings.

### `queue:pendingByteCost()`

Estimates queued byte cost:

```text
sum(max(message.minBytes or 0, #message.payload or 0))
```

It includes `currentMessage` and all queued messages. This is an estimate for sizing/pressure, not protocol frame count.

### `queue:removeQueuedBy(predicate)`

Removes queued messages that match a predicate.

Important behavior:

- Only pending FIFO entries are considered.
- `currentMessage` is never removed.
- Predicate is called under `pcall`.
- A message is removed only if the predicate returns `true`.
- The queue is compacted in place after removal.

This is used by pages/modules to drop stale page-specific requests when navigating or closing.

## Message Table Contract

A queued message is a logical MSP request plus queue metadata:

```lua
{
    command = 123,
    payload = { ... },
    apiname = "BATTERY_CONFIG",
    uuid = "some-key",
    timeout = 2.0,
    retryBackoff = 0.35,
    retryOnErrorReply = true,
    completeOnErrorReplyAttempt = 2,
    processReply = function(self, buf) end,
    errorHandler = function(self, reason) end,
    simulatorResponse = { ... },
    minBytes = 10,
    structure = { ... },
    isWrite = true
}
```

Queue-consumed fields:

| Field | Used by queue for |
| --- | --- |
| `command` | Transport send, reply matching, status/log messages. |
| `payload` | Transport send and read/write log inference. Empty/nil means logical read for logging, but queue still calls `mspWrite()`. |
| `apiname` | Duplicate key suffix and logs. |
| `uuid` | Duplicate suppression key. |
| `timeout` | Per-message timeout override. |
| `retryBackoff` | Per-message retry delay override. |
| `retryOnErrorReply` | Retry when `mspPollReply()` returns matching command with error flag. |
| `completeOnErrorReplyAttempt` | Treat an error reply as completion after enough attempts. |
| `processReply` | Completion callback. Called as `message:processReply(buf)`. |
| `errorHandler` | Error callback. Called as `errorHandler(message, reason)`. |
| `simulatorResponse` | Complete response buffer used in simulator mode. |
| `minBytes` | Used by `pendingByteCost()`. |
| `isWrite` | Optional logging/status override. |

Fields added by queue:

| Field | Meaning |
| --- | --- |
| `_qid` | Monotonic queue id assigned during `add()`. Used by protocol logging through `common.lua`. |
| `_pageScript` | Set to `rfsuite.app.lastScript` if available. Useful for cleanup/removal decisions. |

`structure` may appear on custom API messages, but `mspQueue.lua` does not consume it.

## Message Cloning

When `copyOnAdd` is true, `queue:add()` clones the message.

Clone behavior:

- `payload` is array-cloned.
- `simulatorResponse` is not cloned; the same table reference is retained.
- Other table-valued fields are shallow-cloned.
- Scalar fields and functions are copied by reference.
- The original metatable is preserved.

This protects queued payload bytes from later caller mutation without fully deep-copying every table.

## Duplicate Suppression

Duplicate suppression is done in `add()`.

The duplicate key is:

```lua
key = message.uuid
if message.apiname then
    key = (key or "") .. ":" .. message.apiname
end
```

If `key` exists and matches `self.uuid`, the message is rejected:

```text
ok=false, reason="duplicate"
```

On successful enqueue:

```lua
if key then self.uuid = key end
```

Important implications:

- Duplicate suppression compares only with the last accepted duplicate key, not with every queued message.
- If `apiname` exists and `uuid` is nil, the key becomes `":" .. apiname`.
- A message without `uuid` and without `apiname` has no duplicate key and is never rejected as duplicate.
- Enqueueing a different key replaces the remembered key, so an older key can be accepted again while the older message is still pending.
- `self.uuid` is cleared when the active message completes, times out, max-retries via `clear()`, or the queue is manually cleared.
- `self.uuid` may refer to a queued message that has not yet started.

## Queue Pressure

The queue has a soft and hard pressure mechanism.

Hard cap:

```lua
pending = queueCount() + (currentMessage and 1 or 0)
if maxQueueDepth > 0 and pending >= maxQueueDepth:
    reject with reason "busy"
```

The hard cap is checked before enqueueing. If `maxQueueDepth = 20`, the 20th pending/in-flight slot is rejected when `pending` is already 20 or more.

Soft threshold:

```lua
pendingAfterEnqueue = queueCount() + (currentMessage and 1 or 0)
if pendingAfterEnqueue >= busyWarningThreshold:
    accept with reason "queued_busy"
```

Soft pressure updates `mspStatusMessage` but does not reject the message.

Busy status messages are throttled by `busyStatusCooldown` only for the hard-cap rejection path. The soft `queued_busy` status is emitted directly when the message is accepted.

## Status Messages

The queue updates these session fields:

```lua
rfsuite.session.mspStatusMessage
rfsuite.session.mspStatusUpdatedAt
rfsuite.session.mspStatusLast
rfsuite.session.mspStatusClearAt
```

`setMspStatus(message)` only updates if the new message differs from the current one.

When a non-nil status is set:

- `mspStatusLast` is set to the same message.
- `mspStatusClearAt` is cleared.
- UI progress dialogs are updated if available.

When the queue becomes idle:

```lua
session.mspStatusClearAt = now + 0.75
```

UI code then allows the last status to remain visible briefly.

Common status shapes:

```text
MSP Read 123 queued
MSP Write 124 send
MSP Write 124 retry 2/6
MSP Read 123 timeout
MSP Write 124 ok
MSP Write 124 error flag
MSP Write 124 max retries
MSP queue busy (20 pending)
MSP duplicate request skipped (back off)
MSP poll error
```

Read/write status is inferred by:

```lua
if message.isWrite ~= nil:
    isWrite = message.isWrite
else:
    isWrite = message.payload and #message.payload > 0
```

Because the queue always calls `mspWrite(command, payload or {})`, this label is only a log/status convention. It does not control which queue method is used.

## Main Processing State Machine

At a high level:

```text
IDLE
  if queue empty:
    session.mspBusy = false
    return

  if delay gates allow:
    pop next message
    retryCount = 0
    -> ACTIVE

ACTIVE
  mark session.mspBusy = true
  if send gates allow:
    call mspProtocol.mspWrite(command, payload)
    if accepted:
      update lastTimeCommandSent
      set currentMessageStartTime on first accepted send
      retryCount += 1

  call common.mspProcessTxQ()
  poll common.mspPollReply()

  if timeout:
    call errorHandler("timeout")
    clear current message only
    -> IDLE

  if matching error reply and retryOnErrorReply:
    wait for retry backoff
    -> ACTIVE

  if matching success reply:
    call processReply(buf)
    drain duplicate replies
    clear current message
    -> IDLE

  if max retries exceeded:
    clear whole queue
    call errorHandler("max_retries")
    -> IDLE
```

## Starting a Message

If there is no `currentMessage`, `processQueue()` may pop the next message.

Before popping, it checks:

1. `interMessageDelay`
2. `loopInterval`

`interMessageDelay` is a post-message gap. `msp.lua` sets it to `0.05` seconds.

`loopInterval` is a legacy throttle that only gates the start of the next message. `msp.lua` sets it to zero.

When a message is popped:

```lua
self.currentMessageStartTime = nil
self.lastTimeCommandSent = nil
self.currentMessage = qpop(self.queue)
self.retryCount = 0
```

Then the queue marks itself active:

```lua
session.mspBusy = true
self.mspBusyStart = self.mspBusyStart or now
utils.muteSensorLostWarnings()
```

## Send Gate and Retry Gate

The queue does not continuously call `mspWrite()` every wakeup. It gates sends by interval and retry backoff.

Protocol send interval:

```lua
lastTimeInterval = mspProtocol.mspIntervalOveride or 0.25
```

Current protocols set `mspIntervalOveride = 0.15`.

Interval gate:

```lua
canSendByInterval =
    not lastTimeCommandSent
    or (lastTimeCommandSent + lastTimeInterval) < now
```

Retry/backoff gate:

```lua
backoff =
    currentMessage.retryBackoff
    or queue.retryBackoff
    or DEFAULT_RETRY_BACKOFF_SECONDS

canSendByBackoff =
    retryCount == 0
    or (lastTimeCommandSent and (now - lastTimeCommandSent) >= backoff)
```

Send condition:

```lua
if canSendByInterval and canSendByBackoff and retryCount <= maxRetries:
    sent = mspProtocol.mspWrite(command, payload or {})
```

If `mspWrite()` returns true:

```lua
lastTimeCommandSent = now
if currentMessageStartTime is nil:
    currentMessageStartTime = now
retryCount += 1
```

The first accepted send starts the overall timeout clock.

## Attempt Count Semantics

`retryCount` is incremented after every successful call to `mspProtocol.mspWrite()`.

The send condition is:

```lua
retryCount <= maxRetries
```

The max-retries failure path is:

```lua
retryCount > maxRetries
```

Therefore total possible send attempts are:

```text
maxRetries + 1
```

Examples:

| `maxRetries` | Maximum successful send attempts |
| ---: | ---: |
| 3 | 4 |
| 5 | 6 |
| 10 | 11 |

Retry status displays:

```text
retry <retryCount>/<maxRetries + 1>
```

For CRSF default `maxRetries = 5`, the status can show up to `retry 6/6`.

The per-message timeout can stop a message before all possible attempts are used. The actual number of sends observed depends on:

- `message.timeout` or `queue.timeout`
- `message.retryBackoff` or `queue.retryBackoff`
- `mspProtocol.mspIntervalOveride`
- whether `mspWrite()` returns true or false while the common-layer TX buffer is busy

So `maxRetries + 1` is the upper bound, not a guarantee that every timed-out message will be sent that many times.

## Transport Interaction

The queue calls three lower-level functions during active processing:

```lua
mspProtocol.mspWrite(command, payload or {})
mspCommon.mspProcessTxQ()
mspCommon.mspPollReply()
```

Current behavior:

- `mspWrite()` stages a logical MSP request into `common.lua`.
- If `common.lua` already has a TX buffer, `mspWrite()` returns false and the queue does not increment `retryCount`.
- `mspProcessTxQ()` emits one Suite MSP chunk if bytes are pending.
- `mspPollReply()` returns `cmd, buf, err` only when a full reply has been reassembled.

Important current behavior: the queue always calls `mspWrite()`, even when `payload` is nil or empty. It never calls `mspRead()` in the normal queued path.

## Poll Error Handling

`mspPollReply()` is called through `pcall`.

If it raises an error:

```lua
setMspStatus("MSP poll error")
self._nextMessageAt = now + 0.05
return
```

The current message is not cleared. The queue backs off slightly and will try again on a later wakeup.

## Timeout Handling

Timeout condition:

```lua
currentMessage
and currentMessageStartTime
and (now - currentMessageStartTime) > (currentMessage.timeout or queue.timeout)
```

If timeout fires:

1. Log timeout if MSP read/write logging is enabled.
2. Call `message.errorHandler(message, "timeout")` if present.
3. Increment `session.mspTimeouts`.
4. Set status to `MSP ... timeout`.
5. Clear only the active message state:

```lua
currentMessage = nil
uuid = nil
apiname = nil
lastTimeCommandSent = nil
currentMessageStartTime = nil
```

6. Set `_nextMessageAt` if `interMessageDelay > 0`.
7. Return.

Important: despite a debug log saying "Flushing queue", this path does not clear the pending FIFO queue. It only drops the current message and lets later queued messages run after the inter-message delay.

Also important: the timeout path does not call `page.mspTimeout()`. That page hook is called only in the max-retries path.

## Error Replies and Retry

If `mspPollReply()` returns a matching command with `err == true` and the message has:

```lua
retryOnErrorReply = true
```

then the queue does not complete the message. It does:

```lua
lastTimeCommandSent = now
setMspStatus("MSP ... error reply")
return
```

This forces the normal retry/backoff gate to wait before resending.

`retryCount` is not incremented by the error reply itself. It increments only when a later `mspWrite()` call succeeds.

## Success and Completion

The success path is entered when any of these conditions is true:

```lua
cmd == currentMessage.command and not err
```

or:

```lua
cmd == currentMessage.command
and err
and currentMessage.completeOnErrorReplyAttempt
and retryCount >= currentMessage.completeOnErrorReplyAttempt
```

or the special case:

```lua
currentMessage.command == 68 and retryCount == 2
```

Command `68` is treated as successful on the second attempt even without the normal successful reply condition.

On completion:

1. If `processReply` exists, call it as:

```lua
currentMessage:processReply(buf)
```

Because of Lua colon syntax, the message table is passed as `self`.

2. Log MSP payload if developer logging is enabled.
3. Set status to either:

```text
MSP ... ok
```

or:

```text
MSP ... error flag
```

4. In real radio mode, call `drainAfterSuccess()` for the completed command.
5. Clear active message state.
6. Set `_nextMessageAt` if `interMessageDelay > 0`.
7. Call `page.mspSuccess()` if the active page provides it.

The queue then returns. The next message starts in a later `processQueue()` call after the inter-message delay.

## Duplicate/Late Reply Drain

After a successful completion, real-radio mode calls:

```lua
drainAfterSuccess(self, completedCommand)
```

This briefly polls `mspCommon.mspPollReply()` to consume duplicate/late replies for the same command.

Stop conditions:

- No command returned.
- Unexpected command returned.
- Error flag returned.
- `drainMaxPolls` exhausted.
- `drainAfterReplyMs` time window exceeded.

This helps avoid a late duplicate reply from a previous retry being consumed by the next queued message.

Simulator mode skips this drain.

## Max Retries Handling

If the message has not completed and:

```lua
retryCount > maxRetries
```

then the max-retries path runs.

It:

1. Logs max retries if enabled.
2. Calls `queue:clear()`.
3. Sets status to `MSP ... max retries`.
4. Increments `session.mspTimeouts`.
5. Calls `message.errorHandler(message, "max_retries")` if present.
6. Calls `page.mspTimeout()` if present.

Important: unlike the per-message timeout path, max retries clears the whole queue, including pending messages.

## Busy Watchdog

`MSP_BUSY_TIMEOUT` is hardcoded to `2.5` seconds.

If:

```lua
mspBusyStart and (now - mspBusyStart) > MSP_BUSY_TIMEOUT
```

the queue does:

```lua
session.mspBusy = false
mspBusyStart = nil
return
```

It does not clear `currentMessage`, pending messages, `lastTimeCommandSent`, or the common-layer TX buffer.

This watchdog is mainly a UI/task unblock mechanism. It does not abort the active MSP transaction.

On the next active processing pass, `mspBusyStart` will be set again if work remains.

## Simulator Mode

In simulator mode:

```lua
system.getVersion().simulation == true
```

the queue bypasses transport send/poll:

- It does not call `mspProtocol.mspWrite()`.
- It does not call `mspCommon.mspProcessTxQ()`.
- It does not call `mspCommon.mspPollReply()`.

Instead:

```lua
cmd = currentMessage.command
buf = currentMessage.simulatorResponse
err = nil
```

If `simulatorResponse` is missing:

- It logs a debug message if logging is enabled.
- Clears the active message state.
- Returns.

No `errorHandler` is called for missing simulator responses.

## Logging

Developer flags:

- `rfsuite.preferences.developer.logmspQueue`: logs queue depth changes.
- `rfsuite.preferences.developer.logmsp`: logs MSP payloads via `utils.logMsp()`.
- `rfsuite.preferences.developer.logmsprw`: logs read/write command lifecycle messages.

`getRwModeSuffix()` can append:

```text
mode=delta
mode=full
mode=rebuild
```

for API read/write mode diagnostics. It reads from:

```lua
rfsuite.tasks.msp.api.apidata._lastReadMode[apiname]
rfsuite.tasks.msp.api.apidata._lastWriteMode[apiname]
```

Payload logs are truncated to `MAX_MSP_LOG_BYTES = 96`.

## Interaction With App/UI Code

Common app usage patterns:

- Pages check `mspQueue:isProcessed()` before refreshing, saving, or starting live-update writes.
- UI progress/save dialogs display `session.mspStatusMessage`.
- Navigation cleanup can remove stale queued messages using `removeQueuedBy()`.
- `session.mspBusy` prevents other background tasks from competing with MSP.
- Page hooks can implement `mspRetry`, `mspSuccess`, and `mspTimeout`.

Page hooks:

| Hook | Called when |
| --- | --- |
| `page.mspRetry(queue)` | A send attempt is accepted by `mspWrite()`. Called even for first send. |
| `page.mspSuccess()` | A message completes through the success path. |
| `page.mspTimeout()` | Max-retries path fires. Not called for per-message timeout. |

## Clear Paths

The queue is cleared when:

- Telemetry state is false in `msp.wakeup()`.
- MSP reset is requested.
- App/page cleanup explicitly calls `mspQueue:clear()`.
- Max retries fires.
- Some modules/tools explicitly clear on close or reset.

Clear behavior also calls `common.mspClearTxBuf()`, which drops the lower-level byte buffer currently being emitted.

## Detailed Process Pseudocode

This is close to the current Lua:

```text
function processQueue():
    now = clock()

    if isProcessed():
        session.mspBusy = false
        mspBusyStart = nil
        if session.mspStatusMessage:
            session.mspStatusClearAt = now + 0.75
        return

    if mspBusyStart and now - mspBusyStart > 2.5:
        session.mspBusy = false
        mspBusyStart = nil
        return

    if currentMessage is nil:
        if interMessageDelay active and now < nextMessageAt:
            session.mspBusy = false
            mspBusyStart = nil
            return

        if loopInterval active and now < nextProcessAt:
            session.mspBusy = false
            mspBusyStart = nil
            return

        if loopInterval active:
            nextProcessAt = now + loopInterval

        currentMessageStartTime = nil
        lastTimeCommandSent = nil
        currentMessage = pop queue
        retryCount = 0

    session.mspBusy = true
    if mspBusyStart is nil:
        mspBusyStart = now

    interval = protocol.mspIntervalOveride or 0.25
    backoff = currentMessage.retryBackoff or queue.retryBackoff or 1.0

    canSendByInterval =
        lastTimeCommandSent is nil
        or lastTimeCommandSent + interval < now

    canSendByBackoff =
        retryCount == 0
        or (lastTimeCommandSent and now - lastTimeCommandSent >= backoff)

    if real radio:
        if canSendByInterval and canSendByBackoff and retryCount <= maxRetries:
            sent = protocol.mspWrite(currentMessage.command, currentMessage.payload or {})
            if sent:
                lastTimeCommandSent = now
                if currentMessageStartTime is nil:
                    currentMessageStartTime = now
                retryCount += 1
                call page.mspRetry(queue)

        common.mspProcessTxQ()

        ok, cmd, buf, err = pcall(common.mspPollReply)
        if not ok:
            set status "MSP poll error"
            nextMessageAt = now + 0.05
            return

    else:
        if currentMessage.simulatorResponse is nil:
            clear active message fields
            return
        cmd = currentMessage.command
        buf = currentMessage.simulatorResponse
        err = nil

    if currentMessageStartTime and now - currentMessageStartTime > messageTimeout:
        call errorHandler("timeout")
        session.mspTimeouts += 1
        set status timeout
        clear active message fields only
        nextMessageAt = now + interMessageDelay
        return

    if cmd:
        lastTimeCommandSent = nil

    if cmd == currentMessage.command and err and currentMessage.retryOnErrorReply:
        lastTimeCommandSent = now
        set status error reply
        return

    if success condition:
        call processReply(buf)
        set status ok/error flag
        drain duplicate replies
        clear active message fields
        nextMessageAt = now + interMessageDelay
        call page.mspSuccess()
        return

    if retryCount > maxRetries:
        clear whole queue
        call errorHandler("max_retries")
        call page.mspTimeout()
        return
```

## Firmware Migration Notes

If MSP queue behavior moves into Ethos firmware, decide whether firmware owns only transport/chunking or the whole command queue.

If Lua keeps the queue and firmware owns only MSP framing:

- Preserve the `mspWrite(command, payload)` staging behavior.
- Preserve a non-blocking `mspProcessTxQ()`/`mspPollReply()` equivalent or provide one combined poll that Lua can call each wakeup.
- Keep "one logical MSP transfer in common layer at a time" semantics.

If firmware owns the queue too:

- Lua should submit logical messages with the same metadata: command, payload, timeout, retry/backoff, duplicate key, callbacks or completion tokens.
- Firmware should report command-level completion, not per-frame completion.
- Firmware should expose pending/idle state equivalent to `isProcessed()`.
- Firmware should expose queue pressure/rejection reasons or map them cleanly back to Lua.
- Firmware should preserve `maxRetries + 1` attempt semantics unless Lua/UI expectations are updated.
- Firmware should decide whether timeout drops only the current message and max-retries drops the whole queue, matching current Lua.
- Firmware should provide status strings or structured status so progress dialogs can keep equivalent behavior.
- Firmware should provide a way to remove stale queued messages by page/API key, or Lua should keep a small queue wrapper for that purpose.

Compatibility points to preserve or deliberately change:

- Queue always calls `mspWrite()` for logical reads and writes.
- `maxRetries` means extra retries plus the initial send, so attempts are `maxRetries + 1`.
- `retryOnErrorReply` retries matching MSP error replies.
- `completeOnErrorReplyAttempt` can turn error replies into completion.
- Command `68` has a hardcoded special completion case at `retryCount == 2`.
- Per-message timeout clears only current message.
- Max-retries clears the whole queue.
- `mspBusyStart` watchdog only clears `session.mspBusy`; it does not abort transport state.
- `removeQueuedBy()` cannot remove the active message.

## Test Scenarios

A firmware or refactored queue implementation should be tested against these behaviors:

1. Enqueue when telemetry is off returns `telemetry_off`.
2. Enqueue nil returns `nil_message`.
3. Enqueue a duplicate `uuid/apiname` returns `duplicate`.
4. Enqueue above hard `maxQueueDepth` returns `busy`.
5. Enqueue above soft threshold returns `queued_busy` but still queues.
6. FIFO order is preserved.
7. `copyOnAdd = true` protects queued payload from caller mutation.
8. `isProcessed()` is false while a message is active even if FIFO is empty.
9. First accepted send sets `currentMessageStartTime`.
10. `mspWrite()` returning false does not increment `retryCount`.
11. `retryCount` allows `maxRetries + 1` sends.
12. Matching success reply calls `processReply(buf)` and `page.mspSuccess()`.
13. Matching error reply with `retryOnErrorReply` retries rather than completing.
14. Matching error reply with `completeOnErrorReplyAttempt` completes after the configured attempt.
15. Per-message timeout calls `errorHandler("timeout")` and preserves pending queue entries.
16. Max retries calls `errorHandler("max_retries")`, calls `page.mspTimeout()`, and clears pending queue entries.
17. `removeQueuedBy()` removes only pending messages.
18. Simulator messages use `simulatorResponse` directly and do not call transport functions.
19. Missing simulator response clears the active message without calling `errorHandler`.
20. `clear()` drops active, pending, and lower-level common TX state.

## Known Quirks

- `msp.lua` sets `drainAfterReplyMss`, but the queue reads `drainAfterReplyMs`. The intended override does not currently take effect.
- Timeout logging says "Flushing queue", but the timeout path only clears the active message.
- `page.mspRetry()` is called for every accepted send attempt, including the first send.
- `page.mspTimeout()` is not called for the per-message timeout path.
- `self.apiname` exists on the controller but duplicate suppression stores the combined key in `self.uuid`; `self.apiname` is cleared but not otherwise meaningfully assigned by `add()`.
- The queue's hard busy watchdog does not abort MSP transport state; it only clears `session.mspBusy`.
- The queued path does not use `mspRead()`, so any transport distinction between read and write wrappers is bypassed by normal queue traffic.
