-- Settings -> ActiveLook -> Settings.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
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
    local setupDialog
    local function closeSetupDialog()
      if setupDialog then setupDialog:close(); setupDialog = nil end
    end

    local function showHint(message)
      closeSetupDialog()
      setupDialog = form.openDialog({
        title = "ActiveLook",
        message = message,
        buttons = {{label = "@i18n(app.btn_ok)@", action = function() setupDialog = nil; return true end}},
        wakeup = function() end,
        paint = function() end,
      })
    end
    local hasGlassesMenu = type(system.registerGlasses) == "function" and requireModule("lib/ethos_version.lua").atLeast({26, 2, 0})
    local displayField
    local line
    if hasGlassesMenu then
      line = form.addLine("@i18n(app.modules.settings.activelook_glasses_menu)@")
      form.addBooleanField(line, nil,
        function() return settings.activelook.register_glasses == true end,
        function(value)
          local enabled = value == true
          if settings.activelook.register_glasses == enabled then return end
          settings.activelook.register_glasses = enabled
          if displayField then displayField:enable(enabled) end
          updateSaveEnabled()
          showHint("@i18n(app.modules.settings.activelook_restart_radio)@")
        end)
    end

    line = form.addLine("@i18n(app.modules.settings.feature_activelook)@")
    displayField = form.addBooleanField(line, nil,
      function() return settings.activelook.enabled == true end,
      function(value)
        if value == true and hasGlassesMenu and not settings.activelook.register_glasses then return end
        local wasEnabled = settings.activelook.enabled == true
        settings.activelook.enabled = value == true
        updateSaveEnabled()
        if settings.activelook.enabled and not wasEnabled then
          showHint("@i18n(app.modules.settings.activelook_setup_hint)@")
        end
      end)
    if displayField and hasGlassesMenu then displayField:enable(settings.activelook.register_glasses == true) end

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
    return closeSetupDialog
  end)
end

return {open = open}
