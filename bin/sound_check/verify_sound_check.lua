-- Gate for #2366: `generate-googleapi.py --check` reconciles a voice manifest with
-- the audio tree, offline. A manifest entry without a WAV, a WAV without an entry,
-- and a key the English manifest declares but the locale does not all make the
-- check exit non-zero. An entry without a translation is reported and does not fail.
--
-- The check runs the real script on fixture trees under a scratch folder. The
-- speech libraries are replaced by modules that fail on import, so the check is
-- shown to need neither them nor credentials.
--
-- Run it:
--     lua5.4 bin/sound_check/verify_sound_check.lua
--
-- The harness needs `python3` on the PATH, which the Lua CI job has on Ubuntu
-- runners. Without the --check option in the generator, every case that expects
-- a check result goes red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local GENERATOR = ROOT .. "/bin/sound-generator/generate-googleapi.py"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

-- ---------------------------------------------------------------------------
-- Harness helpers
-- ---------------------------------------------------------------------------

local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local function shellQuote(s)
  if IS_WINDOWS then return '"' .. s .. '"' end
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function makeDir(path)
  if IS_WINDOWS then
    os.execute("mkdir " .. shellQuote((path:gsub("/", "\\"))) .. " 2>nul")
  else
    os.execute("mkdir -p " .. shellQuote(path))
  end
end

local function removeTree(path)
  if IS_WINDOWS then
    os.execute("rmdir /s /q " .. shellQuote((path:gsub("/", "\\"))) .. " 2>nul")
  else
    os.execute("rm -rf " .. shellQuote(path))
  end
end

local function writeFile(path, content)
  local dir = path:match("^(.*)/[^/]*$")
  if dir then makeDir(dir) end
  local f = assert(io.open(path, "wb"))
  f:write(content or "")
  f:close()
end

local SCRATCH = (os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP")
  or (IS_WINDOWS and "." or "/tmp")) .. "/rfsuite_sound_check"
removeTree(SCRATCH)
makeDir(SCRATCH)

-- Runs the generator. Returns the exit code and the captured output.
local function runGenerator(args, env)
  local prefix = ""
  if env then
    if IS_WINDOWS then
      prefix = "set " .. env .. " && "
    else
      prefix = env .. " "
    end
  end
  local parts = { "python3", shellQuote(GENERATOR) }
  for _, a in ipairs(args) do parts[#parts + 1] = a end
  local cmd = prefix .. table.concat(parts, " ") .. " 2>&1"
  local p = assert(io.popen(cmd, "r"))
  local out = p:read("*a")
  local _, _, code = p:close()
  return code, out
end

local function has(out, text)
  return out:find(text, 1, true) ~= nil
end

local function manifestEntry(file, translation)
  local t = translation == nil and "null" or ('"' .. translation .. '"')
  return string.format('  {"file": "%s", "english": "x", "translation": %s, "needs_translation": false}',
    file, t)
end

local function writeManifest(path, entries)
  writeFile(path, "[\n" .. table.concat(entries, ",\n") .. "\n]\n")
end

local function writeTree(root, locale, variant, files)
  for _, f in ipairs(files) do
    writeFile(string.format("%s/audio/%s/%s/%s", root, locale, variant, f), "RIFF")
  end
end

-- Builds a fixture and runs the check on it.
--   entries  the locale manifest
--   wavs     the WAV files that exist under audio/<locale>/<variant>/
--   opts     locale, variant, english (manifest entries), englishJson (path override),
--            noLocale (do not write the locale manifest), env (environment prefix)
local function checkFixture(name, entries, wavs, opts)
  opts = opts or {}
  local locale = opts.locale or "en"
  local variant = opts.variant or "default"
  local root = SCRATCH .. "/" .. name
  local jsonDir = root .. "/json"
  makeDir(jsonDir)
  writeManifest(jsonDir .. "/en.json", opts.english or entries)
  local manifestPath = jsonDir .. "/" .. locale .. ".json"
  if not opts.noLocale then
    writeManifest(manifestPath, entries)
  end
  writeTree(root, locale, variant, wavs)
  local args = {
    "--json", shellQuote(manifestPath),
    "--base-dir", locale,
    "--variant", variant,
    "--check",
    "--audio-root", shellQuote(root .. "/audio"),
  }
  if opts.englishJson then
    args[#args + 1] = "--english-json"
    args[#args + 1] = shellQuote(opts.englishJson)
  end
  return runGenerator(args, opts.env)
end

-- ---------------------------------------------------------------------------
-- Cases
-- ---------------------------------------------------------------------------

local TWO = { manifestEntry("app/a.wav", "A"), manifestEntry("app/b.wav", "B") }

print("Reconciliation")

do
  local code, out = checkFixture("clean", TWO, { "app/a.wav", "app/b.wav" })
  check("a manifest that matches the tree exits 0", code == 0, out)
  check("the report counts zero discrepancies",
    has(out, "Declared, but no WAV file: 0") and has(out, "WAV file, but no manifest entry: 0"), out)
end

do
  local code, out = checkFixture("missing", TWO, { "app/a.wav" })
  check("a declared file without a WAV exits 1", code == 1, out)
  check("the missing file is named",
    has(out, "Declared, but no WAV file: 1") and has(out, "app/b.wav"), out)
end

do
  local code, out = checkFixture("orphan", TWO, { "app/a.wav", "app/b.wav", "app/extra.wav" })
  check("a WAV without a manifest entry exits 1", code == 1, out)
  check("the orphan is named",
    has(out, "WAV file, but no manifest entry: 1") and has(out, "app/extra.wav"), out)
end

do
  local code, out = checkFixture("adjfunctions", TWO,
    { "app/a.wav", "app/b.wav", "adjfunctions/0.wav", "adjfunctions/10.wav" })
  check("WAVs under adjfunctions/ are not orphans", code == 0, out)
  check("the adjfunctions/ WAVs are not reported",
    has(out, "WAV file, but no manifest entry: 0") and not has(out, "adjfunctions/0.wav"), out)
end

do
  local code, out = checkFixture("absent_key", { manifestEntry("app/a.wav", "A") }, { "app/a.wav" }, {
    locale = "de",
    english = TWO,
  })
  check("a key the English manifest declares and the locale lacks exits 1", code == 1, out)
  check("the absent key is named",
    has(out, "Declared in English, not in this manifest: 1") and has(out, "app/b.wav"), out)
end

do
  local locale = { manifestEntry("app/a.wav", "A"), manifestEntry("app/b.wav", nil) }
  local code, out = checkFixture("untranslated", locale, { "app/a.wav", "app/b.wav" },
    { locale = "de", english = TWO })
  check("an entry without a translation is reported",
    has(out, "No translation (the English text is spoken): 1") and has(out, "app/b.wav"), out)
  check("an entry without a translation does not fail the check", code == 0, out)
end

print("Inputs")

do
  local code, out = checkFixture("no_tree", TWO, {}, { locale = "fr" })
  check("a locale without an audio folder exits 1 with a message",
    code == 1 and has(out, "no audio folder"), out)
end

do
  -- The English manifest sits beside the locale manifest, but the locale manifest is not written:
  -- the check must not fall back to comparing English with itself.
  local code, out = checkFixture("no_english", TWO, { "app/a.wav", "app/b.wav" }, {
    locale = "de",
    noLocale = true,
    englishJson = SCRATCH .. "/no_english/json/missing_en.json",
  })
  check("a missing English manifest exits 1 with a message",
    code == 1 and has(out, "no English manifest"), out)
end

print("Offline")

do
  -- Stand-ins that fail on import. --check must never load them.
  local blocked = SCRATCH .. "/blocked"
  writeFile(blocked .. "/sox.py", 'raise RuntimeError("sox was imported by --check")\n')
  writeFile(blocked .. "/google/__init__.py", 'raise RuntimeError("google was imported by --check")\n')
  local envVar = IS_WINDOWS and ("PYTHONPATH=" .. blocked) or ("PYTHONPATH=" .. shellQuote(blocked))
  local code, out = checkFixture("offline", TWO, { "app/a.wav", "app/b.wav" }, { env = envVar })
  check("--check runs without the speech libraries",
    code == 0 and not has(out, "was imported"), out)
end

do
  local manifest = SCRATCH .. "/clean/json/en.json"
  local code, out = runGenerator({ "--json", shellQuote(manifest),
    "--base-dir", "en", "--variant", "default" })
  check("building without --voice exits 1 with a message",
    code == 1 and has(out, "--voice is required"), out)
end

removeTree(SCRATCH)

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
