--[[
  Toolbar action: launch app
]] --

local rfsuite = require("rfsuite")
local M = {}


function M.launchApp()
    if (system.openPage) and rfsuite.sysIndex['app'] then
        system.openPage(2,  rfsuite.sysIndex['app'] )   --second param is the index - but what is it?
    end
end

function M.wakeup()

end

function M.reset()

end

return M
