--[[
  Toolbar action: launch app
]] --

local rfsuite = require("rfsuite")
local M = {}


function M.launchApp()
    rfsuite.utils.print_r(rfsuite.sysIndex)
    if rfsuite.sysIndex['app'] and  system.gotoScreen then
        system.gotoScreen(2, rfsuite.sysIndex['app'] )   
    end
end

function M.wakeup()

end

function M.reset()

end

return M
