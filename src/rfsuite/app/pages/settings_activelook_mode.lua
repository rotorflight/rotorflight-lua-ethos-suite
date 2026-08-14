-- Shared Settings -> ActiveLook mode layout page.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageCommon = requireModule("app/pages/settings_activelook_common.lua")
local activeConfig = requireModule("lib/activelook_config.lua")

local modePage = {}

local function openMode(modeKey, label, opts)
  local title = "@i18n(app.modules.settings.name)@ / ActiveLook / " .. label
  pageCommon.openPage(title, opts, function(settings, updateSaveEnabled)
    settings.activelook = activeConfig.withDefaults(settings.activelook)
    bus.publish("activelook.control", {previewMode = modeKey})

    local previewTop
    local previewBottom
    local slotFields = {}

    local function setFieldEnabled(field, enabled)
      if field and field.enable then field:enable(enabled == true) end
    end

    local function updatePreview()
      local line1, line2 = activeConfig.layoutPreview(settings.activelook["layout_" .. modeKey])
      if previewTop and previewTop.value then previewTop:value(line1) end
      if previewBottom and previewBottom.value then previewBottom:value(line2) end
      local active = activeConfig.LAYOUT_ACTIVE[settings.activelook["layout_" .. modeKey]] or activeConfig.LAYOUT_ACTIVE.two_top_two_bottom
      for i = 1, 4 do setFieldEnabled(slotFields[i], active[i] == true) end
    end

    local layoutLine = form.addLine("Layout")
    local slots = form.getFieldSlots(layoutLine, {0, 0})
    form.addChoiceField(layoutLine, slots[1], activeConfig.LAYOUT_CHOICES,
      function() return activeConfig.layoutKeyToChoice(settings.activelook["layout_" .. modeKey]) end,
      function(value)
        settings.activelook["layout_" .. modeKey] = activeConfig.layoutChoiceToKey(value)
        updatePreview()
        updateSaveEnabled()
      end)
    previewTop = form.addStaticText(layoutLine, slots[2], "")

    local previewLine = form.addLine("")
    local previewSlots = form.getFieldSlots(previewLine, {0, 0})
    previewBottom = form.addStaticText(previewLine, previewSlots[2], "")

    for i = 1, 4 do
      local key = modeKey .. "_" .. i
      local line = form.addLine("Slot " .. tostring(i))
      slotFields[i] = form.addChoiceField(line, nil, activeConfig.SENSOR_CHOICES,
        function() return activeConfig.keyToChoice(settings.activelook[key]) end,
        function(value)
          settings.activelook[key] = activeConfig.choiceToKey(value)
          updateSaveEnabled()
        end)
    end

    updatePreview()
  end)
end

function modePage.create(modeKey, label)
  return {
    open = function(opts) openMode(modeKey, label, opts) end,
  }
end

return modePage
