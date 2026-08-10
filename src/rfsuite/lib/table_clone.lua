-- Shared copy helpers for the small preference stores (settings_store.lua,
-- model_preferences.lua, app/pages/settings_dashboard_theme.lua) that keep
-- their data as a flat "section -> key -> scalar" table. Each of those files
-- used to hand-roll its own copySection()/copySettings(); this is now the
-- one place that logic lives, so a fix here fixes all of them.

if package.loaded["rfsuite.lib.table_clone"] then
  return package.loaded["rfsuite.lib.table_clone"]
end

local table_clone = {}

-- One flat level: {key = scalar, ...} -> a new table with the same
-- keys/values. Non-table input yields an empty table rather than erroring,
-- matching every caller's own prior behavior.
function table_clone.shallow(source)
  local target = {}
  if type(source) ~= "table" then return target end
  for key, value in pairs(source) do
    target[key] = value
  end
  return target
end

-- Two levels: {section = {key = scalar, ...}, ...}. Each section is itself
-- shallow-copied, so mutating a clone's section never touches the source's.
function table_clone.nested(source)
  local target = {}
  if type(source) ~= "table" then return target end
  for section, values in pairs(source) do
    target[section] = table_clone.shallow(values)
  end
  return target
end

package.loaded["rfsuite.lib.table_clone"] = table_clone
return table_clone
