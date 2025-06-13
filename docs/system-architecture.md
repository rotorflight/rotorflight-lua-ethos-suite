## 1. System Architecture Overview

This section provides a high-level view of the Rotorflight Lua Ethos Suite (`rfsuite`) and its major components.

### Directory Structure

* **`main.lua`**: Entry point that initializes the suite, loads configuration, user preferences, session state, tasks, and the application.
* **`app/`**: Contains the UI application logic (`app.lua`), module definitions (`modules/`), and UI libraries (`lib/ui.lua`, `lib/utils.lua`).
* **`tasks/`**: Background tasks for handling MSP communication, events, callbacks, and toolbox operations. Core services run in a separate background task.
* **`widgets/`**: Reusable UI widgets for dashboard elements (e.g., dials, text, preflight displays) and toolbox tools.
* **`lib/`**: Utility libraries, including INI parsing (`ini.lua`), compilation helpers (`compile.lua`), internationalization (`i18n.lua`), and general utilities (`utils.lua`).

### Interaction Flow

1. **Initialization**: `main.lua` sets up `rfsuite.config`, loads or creates user preferences (`rfsuite.preferences`), initializes session variables (`rfsuite.session`), and starts the background task (`rfsuite.tasks`) alongside the UI application (`rfsuite.app`).
2. **Tasks vs. App**:

   * **Tasks**: Handle low-level MSP protocol interactions, scheduling, parsing, and callbacks. Exposed via the `rfsuite.tasks.msp.api` and `rfsuite.tasks.callback` systems.
   * **App**: Manages pages and user interaction. Defines `Page` objects that load modules from `app/modules`, render forms, and invoke MSP operations through the API loader.
3. **Widgets**: Modules and pages incorporate widgets for consistent UI elements. Widgets are loaded from `widgets/dashboard/objects` and can be configured via module parameters.
4. **Session & Preferences**:

   * **Preferences**: Stored in an INI file under `rfsuite.userpreferences`, merged with defaults on startup.
   * **Session**: Runtime state (e.g., `activeProfile`, `apiVersion`, `flightMode`) tracked in `rfsuite.session` to coordinate between tasks and UI.

## 2. Module Creation Guide (`rfsuite/app/modules`)

This section details how to add a new application module that leverages the API data system for form generation.

### Module Structure

Each module lives in its own folder under `app/modules/`:

```
app/modules/<module_name>/
  ├─ init.lua       -- Registers the module with the app framework
  ├─ <module>.lua   -- Core module logic (UI rendering, callbacks)
  ├─ help.lua       -- Help text and documentation for the module
  └─ <icon>.png     -- Icon displayed in navigation
```

* **`init.lua`** must call `app.registerModule({ name = "<module_name>", ... })` to make the module available in the UI.
* **Core Logic** (`<module>.lua`) implements a `Page` subclass with methods:

  * `Page:onEnter()` to initialize form data
  * `Page:onDraw()` to render fields and widgets
  * `Page:onExit()` to clean up or persist changes

### Using the apidata System

Modules leverage the `app.Page.apidata` object to generate forms and interact with MSP APIs:

1. **Initialization**:

   ```lua
   local API = rfsuite.app.Page.apidata.load(apiName)
   app.Page.apidata = {
     api      = API,
     formdata = API.data(),
     structure= API.data().structure,
   }
   ```
2. **Form Fields**:

   * `formdata.fields` is a table of field definitions, each with attributes like `label`, `type`, `byteorder`, and `field` name.
   * The module iterates over `formdata.fields` to render input widgets, e.g.:

     ```lua
     for _, field in ipairs(app.Page.apidata.formdata.fields) do
       ui.renderField(field)
     end
     ```
3. **Reading/Writing Values**:

   * Use `app.Page.apidata.api.readValue(key)` to fetch the current value from the parsed data.
   * Use `app.Page.apidata.api.setValue(key, newValue)` to queue a write operation.
4. **Submission & Callbacks**:

   * On form submission, modules call `app.Page.apidata.api.write()` to push updates.
   * Use `rfsuite.tasks.callback.now()` via `api.scheduleWakeup()` for asynchronous operations.

### Integration with MSP Tasks

* Modules do **not** parse raw MSP data directly. Instead, they rely on the `tasks/msp/api` loader to fetch parsed data structures and buffer states.
* For custom behavior, modules can invoke `rfsuite.tasks.msp.api.scheduleWakeup()` to schedule periodic reads or writes.

## 3. MSP API Documentation (`rfsuite/tasks/msp/api`)

This section describes the MSP API loader and its capabilities for parsing and interacting with MultiWii Serial Protocol data.

### API Loader (`api.lua`)

* **Base Directory**: API definitions reside in `tasks/msp/api/` and are versioned based on the Ethos firmware version.
* **File Caching**: `_fileExistsCache` optimizes repeated file-existence checks.

#### Key Functions

* `apiLoader.load(apiName)`:

  * Loads `<apiName>.lua` via `dofile`, ensures it returns a table with `read` or `write` functions, and wraps them for logging.
  * Returns `nil` if the file is missing or invalid.

* `apiLoader.clearFileExistsCache()`:

  * Clears the cached file-existence results (useful after adding/removing API files).

* `apiLoader.scheduleWakeup(func)`:

  * Schedules a callback using the global `tasks.callback` system for immediate execution.

* `get_type_size(data_type)`:

  * Returns the byte size for MSP data types (e.g., `U8=1`, `S16=2`, ..., `U128=16`).

* **Parsing Functions**:

  * `parseMSPChunk(buf, structure, state)`:

    * Processes up to a fixed number of fields per call (default 5), allowing chunked parsing across ticks.
  * `parseMSPData(buf, structure, processed, other, options)`:

    * Blocking mode: Parses entire buffer according to `structure` and returns a table with `parsedData`, `positionmap`, and other metadata.
    * Chunked mode: Accepts `options.chunked=true` and uses `scheduleWakeup` to process asynchronously, invoking `options.completionCallback` upon completion.

### MSP Helper (`mspHelper.lua`)

* Implements generic reading of unsigned and signed integers of various byte widths:

  * `readUInt(buf, numBytes, byteorder)`
  * `readSInt(buf, numBytes, byteorder)`
  * Maintains an internal buffer offset (`buf.offset`).

---


