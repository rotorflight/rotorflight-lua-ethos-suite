-- Every Lua file under src/ must parse.
--
-- Run it (from the repository root):
--     lua5.4 bin/lua_syntax/verify_lua_syntax.lua
--     lua5.4 bin/lua_syntax/verify_lua_syntax.lua --self-test
--
-- Most harnesses load only the modules they test, so a file that no harness loads is never parsed in
-- CI. A broken line in such a file passes every check and only fails on the radio, when the page that
-- loads it opens. PR #2722 had one: its servo type module held a literal "\r\n" as text, did not parse,
-- and all 136 checks were green.
--
-- This compiles every tracked src/**/*.lua with load() in text mode, without running it. The list
-- comes from `git ls-files`, so it is the same on Linux in CI and on Windows.
--
-- --self-test checks that the checker itself goes red: a chunk with the same kind of broken line must
-- be refused, and a well-formed chunk accepted.

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

-- Compiles `source` as Lua text without running it. Returns true, or false and the error.
local function parses(source, name)
  local chunk, err = load(source, "@" .. name, "t")
  if chunk then return true end
  return false, err
end

-- The checker must be able to go red. Run on every call, so CI proves it too.
do
  local brokenOk = parses("local OWNED = {}\\r\\nlocal x = 1\n", "broken.lua")
  local fineOk = parses("local OWNED = {}\nlocal x = 1\nreturn x\n", "fine.lua")
  if brokenOk or not fineOk then
    print("FAIL  self-check: broken accepted=" .. tostring(brokenOk) .. ", well-formed accepted=" .. tostring(fineOk))
    os.exit(1)
  end
  if SELF_TEST then
    print("OK  self-test: a broken line is refused, a well-formed chunk is accepted")
    os.exit(0)
  end
end

local list = io.popen('git ls-files -- "src/*.lua"')
if not list then
  print("FAIL  could not list the files (git ls-files)")
  os.exit(1)
end

local files, bad = 0, {}
for path in list:lines() do
  path = path:gsub("\r$", "")
  if path ~= "" then
    local f = io.open(path, "rb")
    if not f then
      bad[#bad + 1] = path .. ": cannot open"
    else
      local source = f:read("a")
      f:close()
      files = files + 1
      local ok, err = parses(source, path)
      if not ok then bad[#bad + 1] = err end
    end
  end
end
list:close()

if files == 0 then
  print("FAIL  no Lua files found under src/ (run from the repository root)")
  os.exit(1)
end

for _, line in ipairs(bad) do print("FAIL  " .. line) end
if #bad > 0 then
  print(string.format("%d of %d files do not parse", #bad, files))
  os.exit(1)
end
print(string.format("OK  all %d Lua files under src/ parse", files))
os.exit(0)
