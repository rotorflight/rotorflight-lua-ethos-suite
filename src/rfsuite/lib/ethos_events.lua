--=============================================================================
--  ethos_events.lua
--
--  Ethos Event Debug Helper
--
--  PURPOSE
--  -------
--  Converts Ethos event category/value numbers into readable names and
--  prints formatted debug output (or returns the formatted line).
--
--  Designed for:
--    • Widgets
--    • Tools
--    • Model scripts
--    • Quick event inspection while developing
--
--  INSTALLATION
--  ------------
--  Place this file in:
--      /SCRIPTS/LIB/ethos_events.lua
--
--  Then include it in your script:
--
--      local events = require("ethos_events")
--
--
--  BASIC USAGE
--  -----------
--  Inside your event handler:
--
--      function dashboard.event(widget, category, value, x, y)
--          events.debug("dashboard", category, value, x, y)
--      end
--
--
--  OUTPUT FORMAT
--  -------------
--      [tag] CATEGORY  VALUE  x=... y=...
--
--  Example:
--      [dashboard] EVT_KEY  KEY_PAGE_LONG  x=nil y=nil
--
--
--  OPTIONAL FILTERING
--  -------------------
--  events.debug(tag, category, value, x, y, options)
--
--  options table supports:
--
--      onlyKey = true
--          → Only print EVT_KEY events
--
--      onlyValues = { [KEY_*]=true }
--          → Only print selected key values
--
--      throttleSame = true
--          → Suppress identical consecutive lines
--
--      returnOnly = true
--          → Return the formatted line instead of printing it
--
--
--  EXAMPLE: Only PAGE Keys
--
--      local only = {
--          [KEY_PAGE_LONG]  = true,
--          [KEY_PAGE_FIRST] = true,
--          [KEY_PAGE_UP]    = true,
--          [KEY_PAGE_BREAK] = true,
--          [KEY_PAGE_DOWN]  = true,
--      }
--
--      events.debug("dashboard", category, value, x, y,
--          { onlyValues = only, throttleSame = true })
--
--
--  NOTES
--  -----
--  • Safe to include in production; simply remove debug() calls.
--  • If a new key/event is not listed, its numeric value will be printed.
--
--=============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Event category names
-- ---------------------------------------------------------------------------

local EVT_NAMES = {
  [EVT_KEY]      = "EVT_KEY",
  [EVT_TOUCH]    = "EVT_TOUCH",
  [EVT_SHUTDOWN] = "EVT_SHUTDOWN",
  [EVT_CLOSE]    = "EVT_CLOSE",
  [EVT_OPEN]     = "EVT_OPEN",
}

-- ---------------------------------------------------------------------------
-- Key value names
-- ---------------------------------------------------------------------------

local KEY_NAMES = {
  [KEY_ENTER_BREAK]   = "KEY_ENTER_BREAK",
  [KEY_ENTER_FIRST]   = "KEY_ENTER_FIRST",
  [KEY_ENTER_LONG]    = "KEY_ENTER_LONG",

  [KEY_UP_BREAK]      = "KEY_UP_BREAK",
  [KEY_UP_FIRST]      = "KEY_UP_FIRST",
  [KEY_UP_LONG]       = "KEY_UP_LONG",

  [KEY_MDL_BREAK]     = "KEY_MDL_BREAK",
  [KEY_MDL_FIRST]     = "KEY_MDL_FIRST",
  [KEY_MDL_LONG]      = "KEY_MDL_LONG",

  [KEY_RIGHT_BREAK]   = "KEY_RIGHT_BREAK",
  [KEY_RIGHT_FIRST]   = "KEY_RIGHT_FIRST",
  [KEY_RIGHT_LONG]    = "KEY_RIGHT_LONG",

  [KEY_DISP_BREAK]    = "KEY_DISP_BREAK",
  [KEY_DISP_FIRST]    = "KEY_DISP_FIRST",
  [KEY_DISP_LONG]     = "KEY_DISP_LONG",

  [KEY_DOWN_BREAK]    = "KEY_DOWN_BREAK",
  [KEY_DOWN_FIRST]    = "KEY_DOWN_FIRST",
  [KEY_DOWN_LONG]     = "KEY_DOWN_LONG",

  [KEY_RTN_BREAK]     = "KEY_RTN_BREAK",
  [KEY_RTN_FIRST]     = "KEY_RTN_FIRST",
  [KEY_RTN_LONG]      = "KEY_RTN_LONG",

  [KEY_LEFT_BREAK]    = "KEY_LEFT_BREAK",
  [KEY_LEFT_FIRST]    = "KEY_LEFT_FIRST",
  [KEY_LEFT_LONG]     = "KEY_LEFT_LONG",

  [KEY_SYS_BREAK]     = "KEY_SYS_BREAK",
  [KEY_SYS_FIRST]     = "KEY_SYS_FIRST",
  [KEY_SYS_LONG]      = "KEY_SYS_LONG",

  [KEY_PAGE_BREAK]    = "KEY_PAGE_BREAK",
  [KEY_PAGE_FIRST]    = "KEY_PAGE_FIRST",
  [KEY_PAGE_LONG]     = "KEY_PAGE_LONG",

  [KEY_PAGE_UP]       = "KEY_PAGE_UP",
  [KEY_PAGE_DOWN]     = "KEY_PAGE_DOWN",
  [KEY_PAGE_PREVIOUS] = "KEY_PAGE_PREVIOUS",
  [KEY_PAGE_NEXT]     = "KEY_PAGE_NEXT",

  [KEY_EXIT_FIRST]    = "KEY_EXIT_FIRST",
  [KEY_EXIT_LONG]     = "KEY_EXIT_LONG",
  [KEY_EXIT_BREAK]    = "KEY_EXIT_BREAK",

  [KEY_MODEL_FIRST]   = "KEY_MODEL_FIRST",
  [KEY_MODEL_LONG]    = "KEY_MODEL_LONG",
  [KEY_MODEL_BREAK]   = "KEY_MODEL_BREAK",

  [KEY_SYSTEM_FIRST]  = "KEY_SYSTEM_FIRST",
  [KEY_SYSTEM_LONG]   = "KEY_SYSTEM_LONG",
  [KEY_SYSTEM_BREAK]  = "KEY_SYSTEM_BREAK",

  [ROTARY_RIGHT]      = "ROTARY_RIGHT",
  [ROTARY_LEFT]       = "ROTARY_LEFT",
  [KEY_ROTARY_RIGHT]  = "KEY_ROTARY_RIGHT",
  [KEY_ROTARY_LEFT]   = "KEY_ROTARY_LEFT",
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function nameOrNumber(map, n)
  if n == nil then return "nil" end
  return map[n] or tostring(n)
end

local lastLine = nil

-- ---------------------------------------------------------------------------
-- Public debug function
-- ---------------------------------------------------------------------------

function M.debug(tag, category, value, x, y, options)
  options = options or {}

  if options.onlyKey and category ~= EVT_KEY then
    return
  end

  if options.onlyValues and not options.onlyValues[value] then
    return
  end

  local catName = nameOrNumber(EVT_NAMES, category)

  local valName
  if category == EVT_KEY then
    valName = nameOrNumber(KEY_NAMES, value)
  else
    valName = tostring(value)
  end

  local line = string.format(
    "[%s] %s  %s  x=%s y=%s",
    tag or "event",
    catName,
    valName,
    tostring(x),
    tostring(y)
  )

  if options.throttleSame and line == lastLine then
    return nil
  end

  lastLine = line
  if not options.returnOnly then
    print(line)
  end
  return line
end

return M
