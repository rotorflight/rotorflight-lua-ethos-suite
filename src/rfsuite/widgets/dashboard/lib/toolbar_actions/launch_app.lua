--[[
  Toolbar action: launch app
]] --

local rfsuite = require("rfsuite")
local M = {}


function M.launchApp()
    if system.gotoScreen then
        system.gotoScreen(2, 5 )   --second param is the index - but what is it?
    end
end

function M.wakeup()

end

function M.reset()

end

return M
