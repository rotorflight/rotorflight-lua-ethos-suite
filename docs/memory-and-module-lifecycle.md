# Memory & Module Lifecycle

Ethos radios are memory- and CPU-constrained embedded devices. This suite loads
Lua modules with `loadfile("path.lua")()` everywhere instead of `require()` —
which means every one of these rules exists because of a real, previously
measured problem, not a hypothetical one. This doc is the reference for why
each rule exists and how to apply it to new code.

## 1. Eager subsystem registration beats lazy proxies

Before assuming "load it lazily" is automatically the RAM-friendly choice,
know that this codebase already tried the opposite and measured it losing.
`main.lua`'s own header comment:

> All three subsystems register direct callbacks eagerly. This costs more
> startup RAM than lazy proxies, but avoids retained-RAM growth observed on
> device with the lazy callback layer.

The three top-level subsystems (`app/tool.lua`'s system tool,
`widgets/dashboard.lua`, `tasks/background.lua`'s background task) are all
`loadfile()`'d and `init()`'d unconditionally at boot, not behind a
deferred/proxy registration layer, specifically because on-device testing
showed the lazy version *grew* retained RAM over a session more than just
paying the eager cost once at startup does. Don't reintroduce a lazy
proxy/deferred-registration layer for these three subsystems without new
on-device evidence — this isn't a style choice, it's a reverted experiment.

This is a different (and larger-grained) concern than §2 below:
this section is about *whether to defer registering a whole subsystem at
all*; §2 is about the mechanics of what happens when the same file is
`loadfile()`'d more than once regardless.

## 2. `loadfile()` has no `require()`-style caching

`require()` caches by module name: the second call to `require("foo")`
returns the same table the first call built. `loadfile("foo.lua")()` does
not — it re-parses and re-executes the file from scratch on every call,
producing a brand-new, independent set of tables and closures each time.

A page opened via `app/page_runtime.lua`-style navigation calls
`loadfile()` on every one of its dependencies **every time the page is
opened**, not once per app session. For a stateless codec module this is
pure waste; for a module with module-level tables or a bus subscription,
it is actively harmful (see §3 and §4).

## 3. When to self-cache a module

Self-cache via `package.loaded[...]` (mirroring `require()`'s own
behavior) when a module is:

- **Loaded repeatedly from a hot path** — a page/menu that gets opened and
  closed repeatedly during normal use — *and*
- Either **stateless but non-trivial to rebuild** (a codec with field
  tables, metadata, or a simulator fixture), **or** **has any load-time
  side effect** (see §4).

Do **not** bother self-caching a module that's only ever `loadfile()`'d
once by a long-lived subsystem (e.g. something `tasks/session.lua` or
`tasks/background.lua` loads once at task init) — there's nothing
repeated to cache against.

The idiom, verbatim, matching `lib/bus.lua`'s own (the pattern's origin
point in this codebase):

```lua
if package.loaded["rfsuite.lib.my_module"] then
  return package.loaded["rfsuite.lib.my_module"]
end

-- ... module body ...

package.loaded["rfsuite.lib.my_module"] = my_module
return my_module
```

Living examples: `lib/msp_pid_tuning.lua`, `lib/msp_reboot.lua`,
`lib/mspcodec.lua`, `lib/settings_store.lua`, `app/page_runtime.lua`,
`app/field_layout.lua`.

**Known gaps** (loaded repeatedly from many separate page-open call
sites, no self-cache guard — candidates for the same treatment):
`lib/msp_eeprom.lua` and `lib/model_preferences.lua` (the latter has a
real module-level `DEFAULTS` table, making the rebuild cost non-trivial).

## 4. The subscription-leak trap

This is the sharpest reason to self-cache, and the easiest to miss: a
module that calls `bus.subscribe(...)` at load time (not inside a
function) registers a new handler *every single time it's loaded*. Without
caching, every page visit adds one more orphaned subscriber that is never
cleaned up, since nothing ever unsubscribes a handler it doesn't know
exists. Ten visits to the same page silently leaves ten copies of that
handler firing on every future bus event, forever.

Example: `lib/elrslink_task.lua` self-caches specifically because it
subscribes to `"session.update"` at load time. `lib/debug_log.lua`'s own
comment: "Self-cached so callers share one bus subscription and one small
settings snapshot."

If a module subscribes to the bus at load time, it **must** self-cache.
There is no other correct option short of never subscribing at load time
in the first place.

## 5. Subscribe/unsubscribe pairing on page close

Separately from §4 (which is about a module leaking a subscription every
time it's *loaded*), any page or widget that subscribes to the bus from
inside its own `open()`/`create()` must unsubscribe on its own
`close()`/`dispose()` — regardless of whether the module itself is
cached. The idiom used throughout:

```lua
local sessionHandler

-- on open/create:
sessionHandler = function(session) ... end
bus.subscribe("session.update", sessionHandler)

-- on close/dispose:
if sessionHandler then
  bus.unsubscribe("session.update", sessionHandler)
  sessionHandler = nil
end
```

Examples: `widgets/dashboard.lua`'s `close()`, `app/page_runtime.lua`'s
dispose path, and most `app/pages/*.lua` files that read live session
data (`diagnostics_elrs_link.lua`, `ports.lua`, `power_alerts.lua`,
`settings_dashboard_theme.lua`, `stats.lua`).

## 6. Explicit `package.loaded[key] = nil` teardown

Self-caching (§3) trades a rebuild cost for a table that now lives for
the rest of the app session. That's fine for small, cheap-to-hold
modules, but for anything sized enough to matter, pair it with explicit
un-caching on app/page close so it doesn't outlive the thing that needed
it:

```lua
for _, key in ipairs(unloadPackageKeys) do
  package.loaded[key] = nil
end
collectgarbage("collect")
```

Examples: `app/tool.lua`'s `close(state)` (app-wide teardown, whole
session package keys), `app/page_runtime.lua`'s per-page
`self.unloadPackageKeys` (see `app/pages/telemetry.lua` for a page that
sets this).

## 7. Clear caches in place, don't replace the table

When clearing a reusable cache/queue table, prefer wiping keys in place
over reassigning `t = {}`:

```lua
local function clearTable(t)
  for key in pairs(t) do t[key] = nil end
end
```

Reassigning creates a new table and allocates again on the next hot-path
tick; it also silently breaks anything holding a reference to the *old*
table (a real bug class, not just a style preference). `widgets/dashboard/context.lua`'s
`clearCaches(options)` uses exactly this `clearTable()` helper for its
image/theme/render caches, gated behind flags (`{renders=, theme=,
images=, liveSources=}`) so a theme switch only clears what actually
needs to change.

## 8. Closures survive `form.clear()` — pool them

Live testing showed Ethos retains some `form` callback/widget allocations
after `form.clear()`. Reusing the same callback objects across a rebuild
cannot fix retained widget objects, but does avoid *adding* fresh
retained closures on every repeat visit. `app/field_layout.lua` pools
field getter/setter closures by page+field shape for exactly this reason
— see its own header comment for the full reasoning.

## 9. A dead end: don't reach for `collectgarbage()` without new evidence

A prior version of the menu-rebuild path forced `collectgarbage("collect")`
on every menu-screen (re)build to fight observed RAM growth. A live A/B
log across the same 6-page navigation stretch showed **statistically
indistinguishable** growth with vs. without the forced collect
(+44.0/+39.2/... KB vs +55.6/+41.5/... KB). A full, forced
`collectgarbage("collect")` is a *complete* GC cycle — if it cannot
reclaim memory, that memory is genuinely still reachable from a live
reference, not garbage merely waiting to be swept.

Three files were checked and ruled out as the source: `lib/bus.lua`,
`tasks/msp/queue.lua`, `tasks/msp/common.lua`. The leading remaining
hypothesis — plausible given growth scales with field/button count — is
that Ethos's own `form` widget system itself pins something outside
Lua's GC reachability graph entirely, i.e. a platform trait, not
something fixable from script code. See `app/menu_container.lua`'s own
"DISPROVEN, DO NOT RE-ADD without new evidence" comment for the full
write-up.

**Before proposing `collectgarbage()` as a fix for RAM growth tied to
page/menu navigation, check whether it's this same already-ruled-out
case.** A targeted fix (self-caching, subscription cleanup, in-place
clearing) that actually reduces *live references* is the only kind of
fix that can work here.

## Quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| Considering deferring/proxying a top-level subsystem's registration to save startup RAM | Already tried and reverted -- measured worse retained-RAM growth | Don't, without new on-device evidence (§1) |
| RAM climbs on every visit to the same page | Module reloaded fresh via `loadfile()`, rebuilding module-level tables | Self-cache (§3) |
| RAM climbs *and* stale/duplicate event behavior appears over time | Module subscribes to the bus at load time, never cached | Self-cache (§3/§4) — non-negotiable |
| A page's own live-data callback keeps firing after leaving the page | Page subscribed in open(), never unsubscribed in close() | Pair subscribe/unsubscribe (§5) |
| A long-lived cache table keeps growing across the whole session | Cache never cleared, or cleared by reassignment while something else still holds the old table | Clear in place (§7) |
| RAM grows on menu/page rebuild despite everything above being clean | Likely Ethos's own `form` widget retention (§9) | Don't force `collectgarbage()` — it won't help; this needs a different kind of fix (or may be a platform limit) |
