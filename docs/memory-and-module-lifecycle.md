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

**Scope of the rule, clarified by §10:** the evidence gathered when this rule
was written measured *registration* — whether a subsystem's callbacks are
wired up eagerly or behind a proxy. It did not measure the load *timing of a
page's UI subtree underneath* a subsystem that still registers eagerly. That
narrower case has now been measured on-device and is worth doing: see §10.

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

**A gated flag with no caller is an unmanaged cache, not a no-op.**
`clearCaches()` is a pure option-dispatch table, so an option nobody
requests fails silently: nothing errors, nothing is logged, and the whole
cache class simply stays resident. That is exactly what happened to the
`images` flag until #2380 — the branch existed, and
`widgets/dashboard.lua`'s `clearThemeCache()` only ever passed
`{theme = true}`, so every decoded dashboard bitmap survived every theme
switch, model change and widget close for the rest of the app session. When
adding a flag here, the call site is part of the change; a flag nothing
requests is indistinguishable from a flag that does not work.

Three caches hold decoded bitmaps rather than strings, and all have a
release path that `clearCaches({images = true})` drives:

| Cache | Held by | Released by |
| --- | --- | --- |
| `imageBitmapCache` (context.lua) | the context module | `clearCaches({images = true})`, plus an LRU ceiling of `IMAGE_BITMAP_CACHE_MAX` entries |
| `_imgCache` (`objects/image/model.lua`) | the object module, keyed by craft name | a clearer registered via `utils.registerImageCacheClearer()`, run by the same `images` branch |
| `session.dialImageCache` (`objects/dial/image.lua`) | the session table, keyed by dial panel | `clearCaches({images = true})` |

In addition, `imagePathCache` (context.lua) caches resolved string paths and negative probe results (`path or false`) so missing images are not repeatedly probed against the filesystem; it is cleared by the same `images` branch.

The LRU ceiling exists because the bitmap cache's key space is open-ended —
every distinct model photo, dial panel and per-box `image` parameter mints a
new key — so clearing on lifecycle events alone still lets path churn within
one session accumulate. An evicted bitmap is not freed on the spot; the
handle simply becomes garbage once nothing references it, and the next
`loadImage()` re-decodes it.

`objects/image/model.lua` needs a registry rather than a lookup because the
engine `loadfile()`s object modules on demand and holds them in its own
`objectsByType` map, so a clearer has to be a closure the module registers
over its own local cache. The engine never evicts that map, so a given
object module registers exactly one clearer per app session.

**Not yet measured on hardware.** What is established here is the retention
path: the bitmaps were reachable from a live reference, and they no longer
are. How many kilobytes that is worth on a real radio is not established —
quantifying it needs a `live` vs `churn` split around
`collectgarbage("count")` (a `live` figure after a full collect measures
true retention, `churn` measures the sawtooth), per #2364. Without that
split, growth across theme switches cannot be told apart from the ~44 KB
per page-visit baseline in §9.

## 8. Closures survive `form.clear()` — pool them

Live testing showed Ethos retains some `form` callback/widget allocations
after `form.clear()`. Reusing the same callback objects across a rebuild
cannot fix retained widget objects, but does avoid *adding* fresh
retained closures on every repeat visit. `app/field_layout.lua` pools
field getter/setter closures by page+field shape for exactly this reason
— see its own header comment for the full reasoning.

### 8a. But do not shrink the pool on the way out

The natural next step after "the pool is a permanent table" is to drop each
entry when its page is released, on the reasoning that a slot whose
`dataRef` and `controlRef` are both nil is dead weight. **That is a
regression, not a saving**, and it is worth writing down because the
argument for it is very plausible.

The retained widget is what holds the closure alive. Evicting the pool
entry does not free the closure — it only guarantees the *next* visit to
that page builds a fresh set, while the old widget keeps the old one. So
eviction converts a bounded, one-time pool into closure sets that grow
linearly with the number of page visits, which is the exact thing §8's
pooling exists to prevent.

Measured by replaying every page's real field inventory (356 field shapes
across 33 pages, taken from the pages' own spec tables) through
`app/field_layout.lua` on Lua 5.4, opening each page, building every
field and releasing the runtime:

| Full tours of the page set | Pooled (current) | Evict-on-release |
|---|---|---|
| 1 | 195 entries built | 195 built |
| 2 | 195 | 390 |
| 5 | 195 | 975 |
| 20 | 195 | 3900 |

The pool also turns out to be *bounded by construction*, not merely slow
to grow: it is keyed by field shape, and every field shape in the app is
a literal in some page's source, so it saturates on the first tour at 195
entries (~110 KB) and never grows again. A tour through a single ESC
vendor page is 195 entries; only visiting *all ten* ESC vendor pages —
which are mutually exclusive in practice — reaches 356.

The real lever on this pool is therefore its **per-entry cost**, not its
size. Every entry is a slot table plus its key string plus two closures;
`poolStats()` on the module reports the total and live counts `(count, live)` so the cost
and detached tail can be checked on a radio instead of estimated. See #2381.

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

### 9.1 Tuning the collector is a different lever from forcing it

§9 rules out `collectgarbage("collect")` as a *fix*, because a complete cycle
can only reclaim what is genuinely unreachable. **That ruling is untouched by
this subsection.** Configuring the incremental collector changes *when* a cycle
starts, not *what* is collectable: a cycle triggered at 120% of live instead of
200% reclaims exactly the same objects, sooner. Nothing here makes retained
memory collectable.

The pause exists because the two ends of the range are both bad. A cycle starts
once the heap has reached `live * pause / 100`, and the default is 200 — so with
400 KB live, the heap is allowed to reach roughly 1.2 MB before the collector
begins reclaiming at all. Ethos kills a script whose Lua heap passes its limit
(#2295, *"Lua has used too much RAM, it has been Killed"*). A pause tuned for a
general-purpose host therefore begins its work after the point at which the radio
has already given up.

`main.lua` sets it to **120** in `init()`, before `background_task.init()`, and
prints what it applied:

    [boot] gc: pause=120% of live heap before a cycle starts (Lua default 200)

### 9.2 `collectgarbage("setpause")` is not a getter

This is the whole reason the applied value is printed rather than read back:

    collectgarbage("setpause", n)   -- sets the pause, RETURNS THE PREVIOUS one
    collectgarbage("setpause")     -- sets the pause to 0, returns the previous

Measured on the Lua 5.3.6 in this checkout, and asserted by
`bin/gc_pause/verify_gc_pause.lua` rather than left to a comment, because
`main.lua` cites the behaviour. Pause 0 means "collect as constantly as
possible" — the exact opposite of the intent. So: the applied value is kept in a
local and printed, no file under `src/` may call either setter without an
explicit argument, and the call is `pcall`'d because a Lua without the mode
string would otherwise abort the boot. A guard that fails says so.

### 9.3 What the value is *not*

- **Not measured.** Nothing in this repository states Ethos's Lua heap limit, so
  there is no number to derive a pause from, and no on-device run measures what a
  lower pause costs the background task's instruction budget
  (`tasks/engine.lua`). It is one line to change and one line to revert, which
  is what makes it worth trying.
- **Not a fix for the allocation rate.** It moves the collector's onset earlier;
  it does not allocate less. The churn itself still has to be reduced (#2364).
- **Not covering the boot burst.** The eager `loadfile()` chain at
  `main.lua:53/57/61` parses before `init()` runs, at the default pause. What it
  leaves behind is live code, which no pause setting makes smaller — so this is a
  creep measure, not a boot-peak measure.
- **`setstepmul` is deliberately untouched.** It is the second knob, it trades
  collector throughput against step size, and there is no measurement here of
  jitter it would fix.

### 9.4 How to decide it, without writing a line of code

The metric that matters is the **peak `lua=` in the `[bgtask mem]` log over a
30-minute flight** — and it is already logged, by `tasks/background.lua`. So the
measurement is a procedure, not a feature: run the same session twice, once with
the pause at the default and once at 120, and compare the peaks. The `[boot]` line
above records which of the two a given log came from.

A separate `live` figure, against which `churn` could be split, would need a
forced full collect — and the one place that could show it,
`app/pages/diagnostics_rfstatus.lua`, computes its memory text from a `wakeup`
handler. A forced collect there would be precisely the hot-path forced collect
this subsection is about. That is why there is no live/churn split in the
diagnostics page: the number it would add is not worth a full cycle on every
tick of that page.

## 10. New evidence: deferring a page's UI subtree is not §1

§1 says don't defer a *top-level subsystem's registration* without new
on-device evidence. There is now on-device evidence, and it is a different
thing: **the tool's own UI subtree can be deferred, and it was worth 60.4 kB
on an X18RS.**

`app/tool.lua` used to `requireModule()` its UI subtree at module scope, so
ten modules — `menu_container`, `header`, `tile_grid`, `close_key`,
`navigation`, `esc_protocol_guard`, `servo_bus_guard`, `msp_esc_sensor_config`,
`msp_serial_config`, `memstats`, 52885 bytes of source — were parsed and
retained on every boot to serve a page most pilots never open. They are now
loaded through `ensureX()` helpers called at the point of use.

**What distinguishes this from the reverted experiment in §1:** §1 is about
whether to defer *registering a subsystem that must run at boot*. The tool's
UI subtree has no such duty — `menuContainer.openRoot` has exactly one call
site (`app/tool.lua:531`, the `create()`), and the guards have one each. The
subsystem registration itself stayed eager; only the UI under it moved.

**Two things the measurement settles, and one it does not:**

- Settled: on-device, connected, empty screen, floor read before any
  navigation — master 926.4 kB, deferred 866.0 kB, **−60.4 kB**. The
  predicted figure from a desktop closure measurement scaled by the factor
  in §9-adjacent analysis was −54.0 kB, so within 12 %.
- Settled: the §1 concern did **not** materialise for the *load timing* of a
  UI subtree. The branch boots, connects, and runs the full tool lifecycle
  without error. §1's measurement was about the callback/registration layer,
  not about when a subtree is parsed.
- **Not settled:** the saving is in the **resting** state, not the peak. With
  the tool open the two builds are 4.8 kB apart — noise. Once the tool is
  open the ten modules are loaded; they are merely loaded later. A pilot who
  keeps the tool open does not get the memory back.

**A measurement trap worth recording, because it cost a full A/B cycle:**
comparing a lazy build against a master build captured under a *different
radio state* will produce a spectacularly wrong number. A run here read
−523.5 kB. With a third master run added, that decomposed exactly into
−463.1 kB for Lua that had been deleted off the card between the two runs,
−60.4 kB for this change, and a residue of 0.0 kB. **If the numbers do not
decompose, the missing ingredient is usually a third measurement, not a
better explanation.** Compare `bmpRamAvail` between the runs — if it differs,
the screen state differs and the comparison is void.

The `collectgarbage()` dead end in §9 is unaffected: nothing here is a cache
problem. Fewer modules are loaded.

## 11. The C stack is a second budget, and it has exactly one unbounded term

The heap is the budget everyone watches. It is not the only one. Ethos runs
FreeRTOS, and a Lua script runs inside one of those tasks. In the reference Lua
VM every Lua-to-Lua call consumes one C stack level, so a call chain that
grows without bound does not raise a catchable Lua error - it walks the stack
pointer down past the end of the task's stack array and into whatever the
linker placed below it. On the radio that is `ioMutex`, and the result is a
hardfault caught by the watchdog, not an exception.

That is why the two failure modes have to be kept apart. A heap exhaustion
says *"Lua has used too much RAM, it has been Killed"*. A stack overflow says
nothing at all until the radio resets. Any change that trades one for the other
- or claims to fix an EM by reducing heap - has to say which one it measured.

### 11.0 Where the two budgets physically live

From the Ethos linker script and the firmware author, on the X18RS:

| Region | Origin | Size | Holds |
|---|---|---|---|
| ITCMRAM | `0x00000000` | 64 K | **unused** |
| **DTCMRAM** | `0x20000000` | 128 K | **all variables and all stacks** |
| RAM_D1 | `0x24000000` | 512 K | the model allocator (used by the mixer) |
| RAM_D2 | `0x30000000` | 288 K | **the model backup, loaded in case of an EM** |
| RAM_D3 | `0x38000000` | 64 K | peripherals that need BDMA |
| **SDRAM** | `0xD0000000` | 8 MB | **everything else: the Lua heap and the bitmap arena** |

Two consequences that are easy to get wrong:

- **The stack and the Lua heap are in different memories.** The Main task's
  stack is a static array in DTCMRAM; the Lua heap is in SDRAM. Exhausting one
  cannot corrupt the other, and a heap reduction cannot buy stack headroom.
  `system.getMemoryUsage()`'s `mainStackAvailable` is derived as
  `4 * STACK_AVAILABLE_WORDS(mainStack, MAIN_STACK_SIZE)` - a macro over that
  DTCMRAM array, not a heap figure and not a FreeRTOS call.
- **The Lua heap and the bitmap arena share one 8 MB region.** `luaRamAvailable`
  and `luaBitmapsRamAvailable` are two compile-time maxima carved out of the
  same SDRAM, not two separately reserved pools. They compete: a script that
  grows the Lua heap eats bitmap headroom, and the failure surfaces as a
  *bitmap* error. Treat them as one budget with two views.

An EM is a **designed, survivable recovery**, not a dead radio: the model lives
in RAM_D1 and its backup in RAM_D2, and the backup is loaded on EM. That is also
why a Main-stack overflow is survivable at all - the corruption hits a mutex in
DTCMRAM, while the model and its backup sit in entirely different regions.

The layout inside DTCMRAM is what makes the failure sharp, though:

```
0x20000000  …  unknown .bss  …  0x20005c14
0x20005c14  audioStack   4 096 B
0x20006c14  audioTaskId       4 B
0x20006c18  ioMutex           4 B   <- first casualty of a downward overflow
0x20006c1c  mainStack    20 480 B   <- grows down, into the three above
0x2000BC1C  …  82 916 B of DTCMRAM above the stack  …
```

A FreeRTOS stack pointer starts at the top of its array and grows downward, so
an exhausted Main task reaches `ioMutex` first. **There is no guard region
between them - that adjacency is link order, not design** - and 27 676 B of
DTCMRAM lies below `mainStack`, all of it shared with the program's variables.
A full 20 KB overflow does not corrupt one mutex; it walks into everything the
firmware keeps in that 128 K.

### 11.1 The bound

`lib/bus.lua` is the only channel the system tool, the dashboard widget and the
background task use to talk to each other, and `publish()` invokes its
handlers **synchronously**, inside its own loop. A handler is allowed to
publish again - two or three levels of that is ordinary. A handler that
publishes to a topic whose handler publishes back to the first one is not
ordinary, and nothing in the bus stopped it.

`MAX_PUBLISH_DEPTH` in `lib/bus.lua` stops it. The limit is deliberately far
above legitimate nesting and far below anything that could threaten a stack:
its job is to make the worst case **finite**, not to be the last level before an
overflow. The real budget is not known - what
`system.getMemoryUsage().mainStackAvailable` counts is an open question, raised
with the Ethos firmware author in
[rotorflight/rotorflight-lua-ethos-suite#2420](https://github.com/rotorflight/rotorflight-lua-ethos-suite/issues/2420).

The guard **raises**, on purpose. The error unwinds exactly one level, into the
`pcall()` of the publish that invoked the offending handler, so the cycle is
cut, the existing handler-error branch above it reports it, and every
`publish()` still decrements on the way out. A silently dropped publish would
be indistinguishable from a bus that works.

`bus.maxPublishDepth()` publishes the deepest chain actually observed, so the
constant can be set from a measurement later instead of from a judgement.

### 11.2 The minimum, and why not an instantaneous reading

`lib/stack_probe.lua` keeps the **smallest** value of
`system.getMemoryUsage().mainStackAvailable` seen since the task started. The
question the radio is being asked is how close it has *ever* come to the edge,
and an instantaneous reading cannot answer that - it is one moment, and the
interesting moment is the worst one.

It lives in its own small module rather than in `lib/memstats.lua` because
that module is loaded lazily, inside the tool's own lifecycle (see section 10),
and the only caller here is the background task, which runs from boot. Routing
it through `memstats` would mean loading `memstats` at boot: 2.9 kB of
permanently retained code for a module that does nothing in 99 % of sessions,
which is exactly the cost section 10 removed.

`note()` deliberately ignores a missing or non-numeric field instead of
coercing it. The print lines use `or 0`, and feeding that fallback into a
minimum would pin the reported figure at 0.0 kB for the rest of the session -
a confident-looking number that means only "this firmware did not report the
field". `formatStackFields()` renders that case as `-` instead.

### 11.3 What this does not tell you

Measuring the deepest *publish* nesting is not measuring C stack depth. It
bounds the one recursive term in this suite; it says nothing about the depth of
the dashboard's paint path, which is a plain nested call chain with no cycle
in it. Until the meaning of `mainStackAvailable` is answered, no number from
the Lua side can be converted into bytes of headroom.

---

## 12. Nothing on a wakeup path builds a table per call

The dashboard wakeup path runs several times a second and `session.update` is
published at up to 20 Hz, so a table rebuilt per call there is the sawtooth in
the `'[bgtask mem] lua='` log rather than a detail. Three allocations on those
paths were measured at 184 B, 128 B and 1392 B per call, and all three were a
lookup table, a result table or a closure rebuilt for values the file already
had at module level:

- a name-to-suffix table rebuilt inside `getSensorStats()`, while the
  `STAT_SUFFIXES` constant 80 lines above already held it — and the two had
  drifted, so the rebuild read a different suffix for `rssi` than
  `recordSensorStat()` wrote
- a `compileTransform()` closure built, called on the next expression and thrown
  away, for the boxes that do not cache their config
- a copy of the subscriber list, made on every `publish()`

Two rules follow, and both are about what the file already demonstrates:

1. **A constant lookup table lives at module level, and in one place only.** Two
   copies of the same mapping will disagree, and the disagreement stays invisible
   until it returns the wrong number to a pilot.
2. **Reuse a result object per key, not one for everything.**
   `getSensorStats()` keeps one table per sensor name and overwrites its fields.
   A single shared table would be cheaper still, but a caller that reads two
   sensors before drawing would see the second one twice. Keyed by name that
   costs 88 B per sensor queried and removes the trap; the temperature path in
   the same function already cached its result this way.

For the publish copy, one pooled snapshot per nesting level replaces the
per-publish table, indexed by the `publishDepth` that section 11 already keeps —
so the pool cannot grow past `MAX_PUBLISH_DEPTH` entries and the guard and the
pool share one counter. Two details are load-bearing, and
`bin/allocation_churn/verify_allocation_churn.lua` pins both:

- **each slot is cleared (`snapshot[i] = nil`) upon retrieval.** Leaving
  handler references in the pooled snapshot would retain closures (and via
  their upvalues, entire closed `PageRuntime` instances or widget hierarchies)
  across publishes. In PUC-Rio Lua, setting array entries to `nil` does *not*
  shrink the table's allocated array capacity (`sizearray` remains unchanged
  without a rehash), so writing `1..count` on subsequent publishes continues to
  allocate 0.0 bytes while immediately preventing closure retention.
- **the semantics of the copy are preserved exactly.** A handler unsubscribed by
  another handler *during* a publish still gets its turn in that publish and
  none in the next. Tombstoning the slot instead of shifting looks like the
  obvious fix and is not this: it changes that behaviour, and its slots are never
  reclaimed, so the subscriber list only grows — and page open/close is what
  unsubscribes here.

### Measuring this without fooling yourself

`collectgarbage("count")` is the live heap **plus** whatever has not been
collected yet, so a difference between two readings is an allocation figure only
when no collection ran in between. Measured with the pause left alone, the numbers
come out non-monotonic: the check reported 6 subscribers cheaper than 3, which is
impossible, because the collector had run mid-loop and the reading was cut. So the
harness pins the pause high, keeps a retained ballast array so the "double the
live heap" trigger is out of reach, and asserts both directions on every run —
the current code under the bound and the removed code over it. A bound that both
sides meet proves nothing, which is why the removed implementations are carried
in the harness rather than only described.

The same trap applies to parse cost. `loadfile()` without running the chunk
measures the parser's transient allocations, not the prototype the radio keeps,
and parsing two revisions of a file in one process shares every interned string
between them: that produced a parse delta that *fell* while the source grew. The
figure quoted for that path is derived from a factor measured elsewhere, and is
labelled as derived.

---

## Quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| Considering deferring/proxying a top-level subsystem's registration to save startup RAM | Already tried and reverted -- measured worse retained-RAM growth | Don't, without new on-device evidence (§1) |
| A page that is rarely opened pulls a big UI subtree in at boot, with no boot-time duty of its own | Modules required at module scope, retained forever by the `requireModule` cache | Load it at the point of use via `ensureX()` (§10) — worth 60.4 kB on an X18RS, resting state |
| An A/B against a live build gives a wildly implausible delta | The two runs had different radio state | Add a third measurement; check `bmpRamAvail` for a screen-state difference first (§10) |
| RAM climbs on every visit to the same page | Module reloaded fresh via `loadfile()`, rebuilding module-level tables | Self-cache (§3) |
| RAM climbs *and* stale/duplicate event behavior appears over time | Module subscribes to the bus at load time, never cached | Self-cache (§3/§4) — non-negotiable |
| A page's own live-data callback keeps firing after leaving the page | Page subscribed in open(), never unsubscribed in close() | Pair subscribe/unsubscribe (§5) |
| A long-lived cache table keeps growing across the whole session | Cache never cleared, or cleared by reassignment while something else still holds the old table | Clear in place (§7) |
| A cache class grows across the whole session although a `clearCaches`-style option exists for it | The option is gated and no call site ever requests it — a silent failure by construction | Request the option at the lifecycle call site, and bound the cache if its key space is open-ended (§7, #2380) |
| RAM grows on menu/page rebuild despite everything above being clean | Likely Ethos's own `form` widget retention (§9) | Don't force `collectgarbage()` — it won't help; this needs a different kind of fix (or may be a platform limit) |
| The heap peaks past Ethos's limit before the collector starts reclaiming | The pause is 200, so a cycle only begins at twice the live heap (§9.1) | `main.lua` sets it to 120 and prints what it applied — judge it by the peak `lua=` (§9.4) |
| The collector is running flat out on a radio | `collectgarbage("setpause")` was called without a value, which sets the pause to **0** (§9.2) | Print the applied value; never read it back — the setter returns the previous one |
| Lowering the pause did not reduce memory use | It moves the collector's onset earlier; it does not allocate less (§9.3) | Reduce the churn itself (#2364) — the two are complementary, not alternatives |
| `lua=` in the background log sawtooths while the dashboard is up | A table, result object or closure rebuilt per call on a wakeup or publish path | Module-level constant, per-key result object, pooled iteration copy (§12) |
| Heap grows *and* a stat box shows another sensor's numbers | Two copies of the same name-to-suffix mapping, disagreeing | One mapping, at module level (§12) |
| An allocation measurement comes out smaller than the code change should allow | The collector ran inside the measurement window | Pin the pause, add ballast, assert the removed code over the bound too (§12) |
