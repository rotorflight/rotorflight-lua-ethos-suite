-- Crash-safe file replacement for the files RFSuite owns on the SD card.
--
-- Why this exists: io.open(path, "w") truncates the target on open, before a
-- single byte has been written. A radio that is powered off, put to sleep, or
-- run flat in that window leaves the file at 0 bytes or half a section, and
-- the INI reader then loads whatever happened to survive -- silently, because
-- an unparsable line is skipped rather than reported. The pilot's calibrated
-- thresholds, switch layout and battery statistics are simply gone, with no
-- error anywhere to explain it.
--
-- The fix is the same one EdgeTX uses: never write the live file. Stage the
-- content in a sibling temp file, flush and close it, and only then swap it
-- into place. Until that swap the previous file is untouched, so a power loss
-- at any point in the write leaves either the old contents or the new ones --
-- never a half-written mixture. A temp file left behind by an interrupted
-- write is inert: the next save stages over the same path and overwrites it.
--
-- Usage:
--   local f = atomicWrite.stage(path)
--   if not f then return false end
--   f:write("...")
--   return atomicWrite.commit(f, path)
--
-- or, when the whole content is already one string:
--   return atomicWrite.write(path, contents)
--
-- The handle stage() returns is the temp file's, so write to it exactly as you
-- would to a normal io.open() handle. Pass the *live* path to commit() and
-- abort() -- that is the file being replaced, and it is never opened for
-- writing.
--
-- Staging is a separate call from committing on purpose: writing section by
-- section straight into the temp handle keeps the peak memory of a save at
-- what it was before, instead of serializing the entire file into one string
-- first.

if package.loaded["rfsuite.lib.atomic_write"] then
  return package.loaded["rfsuite.lib.atomic_write"]
end

local atomicWrite = {}

-- Deterministic sibling name. A fixed path (rather than a counter or a clock)
-- means an interrupted write leaves at most one stale temp file, and the next
-- save overwrites that exact path instead of accumulating new ones.
function atomicWrite.tempPath(path)
  return path .. ".tmp"
end

-- Existence probe used to decide whether the swap happened. It deliberately
-- goes through io.open() rather than os.stat(): opening for read and closing
-- again is the one existence check this codebase already relies on everywhere
-- else (ini.load_ini_file() returns nil on a missing file the same way), so it
-- needs no Ethos-specific assumption. Only ever called on a save, so the extra
-- open costs nothing that matters.
local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  pcall(function() file:close() end)
  return true
end

-- Plain truncating write. Only reached when the platform offers no way to swap
-- files at all, or when two attempts at a safe swap have both failed; on Ethos
-- os.rename is present, so this is the safety net, not the normal path.
local function writeDirect(path, data)
  local file = io.open(path, "w")
  if not file then return false end
  local ok = pcall(function()
    file:write(data)
    if file.flush then file:flush() end
  end)
  pcall(function() file:close() end)
  return ok
end

-- Byte-preserving read of a whole file, used only by the two fallbacks below.
--
-- Tries file:read("*a") first, which is standard Lua (desktop / CLI harnesses)
-- and reads the entire file in one call. Falls back to io.read(file, "L") which
-- is the Ethos C-extension spelling this codebase reads with (see
-- ini.load_file_as_string), where the line terminator is included. The terminator
-- is re-appended only when it is missing, so the copy is byte-exact on both.
-- Losing a separator here would silently fuse two `[section]` headers into one.
local function readWholeFile(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = nil
  if file.read then
    local ok, res = pcall(function() return file:read("*a") end)
    if ok and type(res) == "string" then
      content = res
    end
  end
  if content == nil then
    if file.seek then pcall(function() file:seek("set", 0) end) end
    local chunks = {}
    while true do
      local ok, chunk = pcall(io.read, file, "L")
      if not ok or not chunk then break end
      if not chunk:match("\n$") then chunk = chunk .. "\n" end
      chunks[#chunks + 1] = chunk
    end
    content = table.concat(chunks)
  end
  pcall(function() file:close() end)
  return content
end

function atomicWrite.discardTemp(path)
  if not (os and os.remove) or type(path) ~= "string" or path == "" then return false end
  local ok, res = pcall(os.remove, atomicWrite.tempPath(path))
  return (ok and res) and true or false
end

-- Open the temp file for writing. Returns nil when it cannot be created, which
-- is the only stage at which the live file is still at risk -- and at that
-- point nothing has been truncated yet.
function atomicWrite.stage(path)
  if type(path) ~= "string" or path == "" then return nil end
  return io.open(atomicWrite.tempPath(path), "w")
end

-- Move a fully staged temp file onto the live path.
--
-- The filesystem state, not the return value of os.rename, decides whether the
-- swap happened: Ethos' os.rename may report nothing at all on success, and
-- reading a nil return as failure would make the fallback below delete the
-- file that was just written. The temp file being gone is the proof.
function atomicWrite.commit(handle, path)
  if not handle then return false end
  if type(path) ~= "string" or path == "" then return false end

  local closed = pcall(function()
    if handle.flush then handle:flush() end
    handle:close()
  end)
  if not closed then return false end

  local temp = atomicWrite.tempPath(path)

  if not (os and os.rename) then
    local data = readWholeFile(temp)
    if not data then return false end
    local ok = writeDirect(path, data)
    atomicWrite.discardTemp(path)
    return ok
  end

  pcall(os.rename, temp, path)

  if fileExists(temp) then
    -- The swap did not take effect. os.rename refuses to overwrite an existing
    -- file on some platforms, so drop the target and retry once. The temp file
    -- still holds the new contents at this point, so if the retry also fails
    -- the new settings are not lost.
    pcall(os.remove, path)
    pcall(os.rename, temp, path)
  end

  if fileExists(temp) then
    -- Still not swapped after two attempts. Leaving the target missing would
    -- be worse than the exposure this module exists to remove, so fall back to
    -- writing the staged contents straight over it -- the same truncating
    -- write the old code did, reached only once the safe route has failed
    -- twice. The temp file is kept when even that fails: it is then the only
    -- copy of what the caller tried to save.
    local data = readWholeFile(temp)
    local ok = data ~= nil and writeDirect(path, data)
    if ok then atomicWrite.discardTemp(path) end
    return ok == true
  end

  return true
end

-- Give up on a staged write: close the handle and drop the temp file. The live
-- file is never involved, so a caller can simply return false.
function atomicWrite.abort(handle, path)
  if handle then pcall(function() handle:close() end) end
  if type(path) == "string" then atomicWrite.discardTemp(path) end
end

-- Convenience for callers that already hold the complete content as a string.
function atomicWrite.write(path, data)
  local handle = atomicWrite.stage(path)
  if not handle then return false end
  local ok = pcall(function() handle:write(tostring(data or "")) end)
  if not ok then
    atomicWrite.abort(handle, path)
    return false
  end
  return atomicWrite.commit(handle, path)
end

package.loaded["rfsuite.lib.atomic_write"] = atomicWrite
return atomicWrite
