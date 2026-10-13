# Storage on the Radio

RFSuite keeps its persistent state in plain INI files on the SD card. This
document lists what is written where, and how a write is made safe against the
radio being switched off mid-save.

## Files

| File | Contents | Written by |
| --- | --- | --- |
| `SCRIPTS:/rfsuite.user/settings.ini` | All system-tool settings, including the audio event and timer configuration, the dashboard themes, and the ActiveLook configuration. | `lib/settings_store.lua` |
| `SCRIPTS:/rfsuite.user/models/<mcuId>.ini` | Per-flight-controller preferences: battery/smart-fuel configuration, the flight statistics (flight count, total flight time, last flight time), and the name the flight controller reported (`[craft] name`). | `lib/model_preferences.lua` |
| `LOGS:/rfsuite/telemetry/<mcuId>/logs.ini` | The model name shown in the *Logs* page for that flight-controller's folder. | `tasks/logging.lua` |
| `LOGS:/rfsuite/telemetry/<mcuId>/<timestamp>.csv` | One telemetry CSV per flight, appended to while the flight is in progress. | `tasks/logging.lua` |

`settings.ini` and the per-model files are INI: a `[section]` header per block,
`key=value` per setting, `;` for a comment line. The reader
(`ini.load_ini_file()`) skips any line it does not recognise, so a damaged file
does not raise an error — it loads as whatever survived. That is why a save must
never leave a partially written file behind in the first place.

### The craft name, and the known-models list

`tasks/session.lua` writes the name the flight controller reports (`MSP_NAME`)
into `[craft] name` of that controller's file, so the radio can name a model
with no link up. The UID and the name arrive in separate replies and either may
come first; whichever comes second writes. A name that has not changed writes
nothing, and an empty answer never replaces a stored name. Saving a new craft
name on the Configuration page updates the store and session immediately via
`craft.name.saved`.

The name is stored inside double quotes (`name="007"`). The INI reader turns a
bare `007`, `0x10` or `1e3` into a number and `true` into a boolean, so a name
written without quotes would not survive a save and a load. A store written
before the name existed has no `[craft]` section and lists with no name.

`lib/known_models.lua` lists the stores on the card with no link:
`requireModule("lib/known_models.lua").list()` returns one record per file in
`models/`, sorted by id: `id`, `name` (nil if none is recorded), `path`, and
`modified`, the table `os.stat()` reports for the file. It writes nothing. It
reads every store, so call it from a tool page, not from a widget or a wakeup,
and load it where it is called -- nothing loads it at boot.

The `rfsuite.user` folder is the suite's own folder on the SD card. Deleting it
resets RFSuite to defaults; nothing outside it is touched.

## Atomic writes

Every file the suite owns is written the same way, through
`lib/atomic_write.lua`:

1. The content is staged into a sibling temp file, `<file>.tmp` — the live file
   is never opened for writing.
2. The temp file is flushed and closed.
3. The temp file is renamed onto the live path, which is the single step that
   replaces the old contents with the new ones.

Because step 1 touches only the temp file, a radio that is powered off, put to
sleep, or loses its battery anywhere in the write leaves the previous file
complete and readable. The pilot gets either the old settings or the new ones,
never a half-written mixture — and because the INI reader cannot report damage,
this is the only place that guarantee can come from.

A `<file>.tmp` left on the card by an interrupted write is inert: nothing reads
it, and the next save stages over the same path and removes it. Its name is
fixed rather than generated, so at most one such file can exist per target and
they cannot accumulate.

The rename is treated as successful only when the temp file is actually gone
from disk, not when `os.rename()` reports no error: a radio build that returns
nothing on success must not be read as a failure. If the rename does not take
effect, it is retried once after removing the target, and only if that also
fails is the staged content written directly over the target — the pre-fix
behavior, reached only once the safe route has failed twice.

The in-flight CSV is the one file that is *not* written this way end to end:
its header is staged and renamed as above, and the samples that follow are
appended to the finished file, because a telemetry log is meant to grow during
a flight.

### What this does not cover

- **A short write that reports nothing.** A card that fills up mid-write can
  leave the staged file incomplete, and the evidence available here is the
  write's own result and `close()` — an incomplete write that raises is caught
  and the original file is kept, but one that reports success while having
  written less than asked for is not detected here. The EdgeTX suite's
  `config_store.lua` and `flight_log.lua` close that gap by reading the staged
  file back and measuring it before the original is touched; porting that needs
  a byte-exact read, which the Ethos `io.read(file, "L")` spelling used
  throughout this suite does not make obvious.
- **A save interrupted between target removal and the final rename** leaves
  `<file>.tmp` on disk while `<file>` is missing; the next boot will load defaults
  unless manually recovered from `.tmp`.
- **The SD card being removed or failing** is outside this mechanism.
- **The log page's own deletions** are not part of the write path.

## Adding a new stored file

Write it through `lib/atomic_write.lua`, not through `io.open(path, "w")`:

```lua
local atomicWrite = requireModule("lib/atomic_write.lua")

-- whole content already in hand
atomicWrite.write(path, contents)

-- or written in pieces, without building the whole string first
local f = atomicWrite.stage(path)
if not f then return false end
f:write("[section]\n")
-- ...
return atomicWrite.commit(f, path)
```

`ini.save_ini_file()` is the normal way to store a table, and it already goes
through this. Reaching for `io.open(path, "w")` reintroduces exactly the
truncation window described above.
