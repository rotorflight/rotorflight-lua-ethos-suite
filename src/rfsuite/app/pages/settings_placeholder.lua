-- Small shared placeholder for Settings sections whose menu shape now exists
-- but whose real editor is still to be built.

local requireModule = assert(loadfile("lib/require.lua"))()
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")

local placeholder = {}

function placeholder.new(pageTitle, message)
  local page = {}

  function page.open(opts)
    opts = opts or {}
    local disposed = false

    local function goBack()
      if disposed then return end
      disposed = true
      if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
      if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
      if opts.onBack then opts.onBack() end
    end

    form.clear()
    header.build(pageTitle, {onBack = goBack})
    form.addLine(message)

    if opts.setEventHandler then
      opts.setEventHandler(function(category, value)
        if closeKey.shouldHandleClose(category, value) then
          goBack()
          return true
        end
        return false
      end)
    end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then
      opts.setCleanupHandler(function()
        disposed = true
      end)
    end
  end

  return page
end

return placeholder
