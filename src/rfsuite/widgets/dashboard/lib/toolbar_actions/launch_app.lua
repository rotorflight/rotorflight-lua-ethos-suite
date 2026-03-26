--[[
  Toolbar action: launch app
]] --

local rfsuite = require("rfsuite")
local M = {}


function M.launchApp()
    if (system.openPage) and rfsuite.sysIndex['app'] then
        system.openPage({system=rfsuite.sysIndex['app']})
    end
end

function M.wakeup()

end

function M.reset()

end

return M
