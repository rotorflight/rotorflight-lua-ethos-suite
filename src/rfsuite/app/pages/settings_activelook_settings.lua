-- Settings -> ActiveLook -> Settings.

local requireModule = assert(loadfile("lib/require.lua"))()
local pageCommon = requireModule("app/pages/settings_activelook_common.lua")
local activeConfig = requireModule("lib/activelook_config.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / ActiveLook / @i18n(app.modules.settings.activelook_settings)@"

local function switchFromConfig(value)
  if type(value) ~= "string" then return nil end
  local category, member = value:match("([^,]+),([^,]+)")
  category = tonumber(category)
  member = tonumber(member)
  if not category or not member then return nil end
  return system.getSource({category = category, member = member})
end

local function switchToConfig(source)
  if not source then return "" end
  if not (source.category and source.member) then return "" end
  return tostring(source:category()) .. "," .. tostring(source:member())
end

local function open(opts)
  pageCommon.openPage(PAGE_TITLE, opts, function(settings, updateSaveEnabled)
    settings.activelook = activeConfig.withDefaults(settings.activelook)

    local line = form.addLine("@i18n(app.modules.settings.feature_activelook)@")
    form.addBooleanField(line, nil,
      function() return settings.activelook.enabled == true end,
      function(value)
        settings.activelook.enabled = value == true
        updateSaveEnabled()
      end)

    line = form.addLine("@i18n(app.modules.settings.activelook_hide_display)@")
    form.addSwitchField(line, nil,
      function() return switchFromConfig(settings.activelook.display_switch) end,
      function(source)
        settings.activelook.display_switch = switchToConfig(source)
        updateSaveEnabled()
      end)

    line = form.addLine("Offset X")
    local xField = form.addNumberField(line, nil, -20, 20,
      function() return tonumber(settings.activelook.offset_x) or 0 end,
      function(value)
        settings.activelook.offset_x = activeConfig.clampOffset(value)
        updateSaveEnabled()
      end)
    if xField and xField.suffix then xField:suffix("px") end

    line = form.addLine("Offset Y")
    local yField = form.addNumberField(line, nil, -20, 20,
      function() return tonumber(settings.activelook.offset_y) or 0 end,
      function(value)
        settings.activelook.offset_y = activeConfig.clampOffset(value)
        updateSaveEnabled()
      end)
    if yField and yField.suffix then yField:suffix("px") end
  end)
end

return {open = open}
