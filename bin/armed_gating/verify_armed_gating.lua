-- Runs both #2302 armed-gating suites in one harness (one job in pr_jobs.py).
--
--     lua5.4 bin/armed_gating/verify_armed_gating.lua
--
-- suite_armed_gating.lua: the derivation rules of app/armed_gating.lua, and the real
--   menu tree of app/tool.lua against an explicit expected classification.
-- suite_menu_container.lua: the real app/menu_container.lua and tile_grid.lua: the
--   forbidden icon, the silent refused press, and the rebuild on arm/disarm.
--
-- Each suite ends in os.exit, so the runner replaces os.exit for the duration of a
-- suite and reads the code the suite asked for. Both suites must pass.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  local last = 0
  for i = 1, #path do
    local ch = path:sub(i, i)
    if ch == "/" or ch == string.char(92) then last = i end
  end
  if last == 0 then return "." end
  return path:sub(1, last - 1)
end

local ROOT = (arg and arg[1]) or (scriptDir() .. "/../..")
local SUITES = {"suite_armed_gating.lua", "suite_menu_container.lua"}

local realExit = os.exit
local failed = 0

for _, name in ipairs(SUITES) do
  local path = scriptDir() .. "/" .. name
  local code = nil
  os.exit = function(c) code = (c == true and 0) or (c == false and 1) or c or 0; error({suiteExit = true}) end
  arg = {ROOT}
  local ok, err = pcall(dofile, path)
  os.exit = realExit
  if not ok and not (type(err) == "table" and err.suiteExit) then
    print(string.format("%s: error: %s", name, tostring(err)))
    code = 1
  end
  code = code or 0
  print(string.format("%s: %s", name, code == 0 and "PASS" or "FAIL"))
  if code ~= 0 then failed = failed + 1 end
end

print(string.format("\n%d suite(s), %d failed", #SUITES, failed))
realExit(failed == 0 and 0 or 1)
