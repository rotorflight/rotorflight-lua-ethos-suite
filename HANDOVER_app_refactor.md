# Handover: App → Tasks Decoupling Refactor

## Goal

Break `rfsuite.app` out of the shared `rfsuite` memory space so it can be fully
unloaded when not running. The task layer (`rfsuite.tasks`) must always run;
the app is optional. The dependency direction must be reversed: tasks must never
reach into `rfsuite.app` — instead the app registers state into `rfsuite.tasks`
when active and clears it on close.

The end state: `app` becomes a standalone Ethos tool that communicates only via
`rfsuite.tasks`, `rfsuite.session`, and `rfsuite.bus`.

---

## Branch

`refactor/app-state-to-tasks` — branched from master after commit `1b76e7c9`
(the bus move, which landed in master as PR #2227).

### Commits on this branch

| Hash | What |
|---|---|
| `d5c243cc` | Fix missed app.ui calls in mspQueue setMspStatus |
| `75a5759a` | Replace app.ui direct calls from tasks with rfsuite.tasks.uiCallbacks |
| `3882a72e` | Reverse app→tasks state coupling for guiIsRunning, lastScript, escPowerCycleLoader, rebootInProgress |
| *(pending)* | Group A: uiCallbacks for resetAppTasks, closeSave, closeProgress, showArmedWarning, rebootFc, invalidatePages, mspRetry, mspSuccess, mspTimeout; tasks.lua and generic_actions.lua and mspQueue.lua updated |
| *(pending)* | Group B: rfsuite.tasks.activePage for core.lua and ESC_PARAMETERS_HW5.lua; activePage lifecycle managed in ui.openPage, cleanupCurrentPage, utils.invalidatePages |

---

## What Has Been Done

### 1. Message bus → `rfsuite.bus` (already in master, PR #2227)

- Moved `src/rfsuite/tasks/scheduler/msp/message_bus.lua` → `src/rfsuite/lib/message_bus.lua`
- Loaded in `main.lua` as `rfsuite.bus` before tasks or app
- `msp.lua` aliases `msp.bus = rfsuite.bus` (backward compat for internal msp use)
- `getBus()` in `mspQueue.lua` now returns `rfsuite.bus` directly
- All consumer files updated to reference `rfsuite.bus`
- `msp.reset()` no longer calls `bus.reset()` (shared bus must not be wiped by MSP reset)

### 2. State flags → `rfsuite.tasks.*` / `rfsuite.session.*`

**`guiIsRunning` → `rfsuite.tasks.appRunning`**
- App sets this in `wakeup_protected()` (true) and `close()` / reset (false)
- All task/widget/dashboard reads now use `rfsuite.tasks.appRunning`
- Proxy in `main.lua` returns `rfsuite.tasks.appRunning or false` for legacy `rfsuite.app.guiIsRunning` reads

**`escPowerCycleLoader` → `rfsuite.tasks.escPowerCycleLoader`**
- Direct writes in `app.lua` updated; proxy `__newindex` mirrors writes from module files
- Tasks/app/tasks.lua now read `rfsuite.tasks.escPowerCycleLoader`

**`lastScript` → `rfsuite.tasks.lastScript` (mirrored)**
- Proxy `__newindex` mirrors every `rfsuite.app.lastScript = x` write to `rfsuite.tasks.lastScript`
- Direct writes in `app.lua` also set `rfsuite.tasks.lastScript`
- Cross-boundary reads in `mspQueue.lua`, `api.lua`, `lib/utils.lua` use `rfsuite.tasks.lastScript`
- Internal app reads still use `app.lastScript` (unchanged — will clean up when app is fully separated)

**`rebootInProgress` → `rfsuite.session.rebootInProgress`**
- Moved from `app.triggers.rebootInProgress` to neutral session space
- All reads/writes in `ui.lua`, `app.lua`, `onconnect/tasks.lua` updated

### 3. UI callbacks → `rfsuite.tasks.uiCallbacks`

- App registers a table of function references into `rfsuite.tasks.uiCallbacks` at `create()`
- App clears it to `nil` at `close()`
- Tasks call through the table with nil guards — silent no-ops when app is not running
- Functions registered: `updateProgressDialogMessage`, `applyMspStatusToActiveDialogs`, `progressDisplaySave`
- Fixed in: `common.lua`, `mspQueue.lua` (setMspStatus), `BATTERY_INI.lua`, `FLIGHT_STATS_INI.lua`

---

## What Remains

Run this to see all remaining `rfsuite.app` references in tasks:

```
grep -rn "rfsuite\.app" src/rfsuite/tasks --include="*.lua"
```

**As of the last session, this returns no results — the tasks directory is clean.**

### Group A — Misc (smaller, do this first) ✅ DONE

**`src/rfsuite/tasks/tasks.lua:350-351` and `:825`**

```lua
-- line 350 (telemetry reset handler):
if rfsuite.app and rfsuite.app.tasks and rfsuite.app.tasks.reset then
    rfsuite.app.tasks.reset()
end

-- line 825 (cleanupClosedAppRuntime):
local app = rfsuite.app
if app and app.tasks and app.tasks.reset then
    app.tasks.reset()
end
```

Fix: add `resetAppTasks` to `rfsuite.tasks.uiCallbacks` in `app.lua`:
```lua
resetAppTasks = function() if app.tasks and app.tasks.reset then app.tasks.reset() end end,
```
Then in `tasks.lua` replace both call sites with:
```lua
local cb = rfsuite.tasks.uiCallbacks
if cb and cb.resetAppTasks then cb.resetAppTasks() end
```

---

**`src/rfsuite/tasks/scheduler/msp/generic_actions.lua:17,30`**

```lua
local function appTriggers()
    local app = rfsuite.app
    return app and app.triggers or nil
end

local function settingsSavedReply(context)
    local app = rfsuite.app
    local triggers = app and app.triggers
    ...
    triggers.closeSave = true
    ...
    app.ui.rebootFc(page)
    app.utils.invalidatePages({preserveCurrentPage = true})
end
```

Fix: extend `rfsuite.tasks.uiCallbacks` with:
```lua
closeSave       = function() app.triggers.closeSave = true end,
closeProgress   = function() app.triggers.closeProgressLoader = true end,
showArmedWarning= function() app.triggers.showSaveArmedWarning = true end,
rebootFc        = function(page) if app.ui and app.ui.rebootFc then app.ui.rebootFc(page) end end,
invalidatePages = function(opts) if app.utils and app.utils.invalidatePages then app.utils.invalidatePages(opts) end end,
```
Then rewrite `generic_actions.lua` to call through `rfsuite.tasks.uiCallbacks` instead of directly into `rfsuite.app`.

---

**`src/rfsuite/tasks/scheduler/msp/mspQueue.lua:425,613,636`**

```lua
local page = rfsuite.app and rfsuite.app.Page
if page and page.mspRetry then page.mspRetry(self) end
```

These three calls invoke a `mspRetry` callback on the current page object. Fix:
- Add to `rfsuite.tasks.uiCallbacks`: `mspRetry = function(queue) if app.Page and app.Page.mspRetry then app.Page.mspRetry(queue) end end`
- Replace call sites:
```lua
local cb = rfsuite.tasks.uiCallbacks
if cb and cb.mspRetry then cb.mspRetry(self) end
```

---

**`src/rfsuite/tasks/scheduler/msp/api/ESC_PARAMETERS_HW5.lua:234`**

```lua
local app = rfsuite.app
```

Read what `app` is used for in context and move to `rfsuite.tasks.uiCallbacks` or `rfsuite.tasks.activePage` as appropriate.

---

### Group B — `app.Page` / `app.formFields` (the hard one, do last) ✅ DONE

**`src/rfsuite/tasks/scheduler/msp/api/core.lua:293-430`**

Functions `buildFullPayload` and `buildDeltaPayload` reach directly into:
- `rfsuite.app.Page.apidata.formdata.fields` — field metadata (scale, mult, step, min, max, decimals)
- `rfsuite.app.formFields` — which form fields are currently active/edited
- `rfsuite.app.Page.apidata.api` — API name list

Fix pattern — **`rfsuite.tasks.activePage`**:

When the app loads a page, it writes:
```lua
rfsuite.tasks.activePage = {
    fields   = app.Page.apidata.formdata.fields,   -- field metadata array
    api      = app.Page.apidata.api,               -- api name list
    formFields = app.formFields,                   -- active form fields
}
```

When the app closes a page (`ui.cleanupCurrentPage`), it clears:
```lua
rfsuite.tasks.activePage = nil
```

Then `core.lua` reads `rfsuite.tasks.activePage` instead of `rfsuite.app.Page.apidata.*`.

**Important**: `activePage` should be a shallow reference (not a copy) so tasks always
see the live values that the app updates as the user edits fields.

Also at `core.lua:430`:
```lua
if not rfsuite.app.Page then
```
→ `if not rfsuite.tasks.activePage then`

---

## Key Architectural Decisions

- **`rfsuite.bus`** — shared infrastructure, lives before tasks and app. MSP registers its
  actions on it; app subscribes while running.

- **`rfsuite.tasks.uiCallbacks`** — app populates with function refs on `create()`, nils on `close()`.
  Tasks call through with nil guards. No bus needed for these — they are persistent per-session
  callbacks, not per-request contexts.

- **`rfsuite.tasks.activePage`** — shallow reference to live page data. App owns the data;
  tasks read it. Cleared by app when page closes, so tasks naturally get nil when no page is open.

- **`rfsuite.session`** — neutral shared state for things both app and tasks need to read/write
  (e.g. `rebootInProgress`, `mspStatusMessage`).

- **Do NOT reset `rfsuite.bus` from `msp.reset()`** — the bus is shared. MSP cleanup is handled
  by `releaseQueuedHandlers` on queue clear.

- **Proxy in `main.lua`** — `__index` returns `rfsuite.tasks.*` values for legacy `rfsuite.app.guiIsRunning`
  and `escPowerCycleLoader` reads (avoids triggering lazy app load). `__newindex` mirrors
  `lastScript` and `escPowerCycleLoader` writes to `rfsuite.tasks`.
