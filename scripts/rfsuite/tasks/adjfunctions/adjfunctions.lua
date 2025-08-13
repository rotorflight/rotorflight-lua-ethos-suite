--[[
 * Optimized adjfunctions.lua
 * Goals: reduce RAM/CPU usage while preserving behavior
 * Changes:
 *  - Use numeric keys for adjFunctions (no string concat, fewer interned strings)
 *  - Cache preference flags and frequently used functions per wakeup
 *  - Minimize os.clock() calls
 *  - Simplify flag-setting branches
 *  - Avoid work when events are disabled
 *  - Keep firstRun behavior intact (no audio on very first valid tick)
]]

local arg = {...}
local config = arg[1]

local adjfunc = {}
local firstRun = true

local initTime = os.clock()

-- Compact table: id -> list of wav tokens
local adjWavs = {
  [5] = {"pitch","rate"},
  [6] = {"roll","rate"},
  [7] = {"yaw","rate"},
  [8] = {"pitch","rc","rate"},
  [9] = {"roll","rc","rate"},
  [10] = {"yaw","rc","rate"},
  [11] = {"pitch","rc","expo"},
  [12] = {"roll","rc","expo"},
  [13] = {"yaw","rc","expo"},
  [14] = {"pitch","p","gain"},
  [15] = {"pitch","i","gain"},
  [16] = {"pitch","d","gain"},
  [17] = {"pitch","f","gain"},
  [18] = {"roll","p","gain"},
  [19] = {"roll","i","gain"},
  [20] = {"roll","d","gain"},
  [21] = {"roll","f","gain"},
  [22] = {"yaw","p","gain"},
  [23] = {"yaw","i","gain"},
  [24] = {"yaw","d","gain"},
  [25] = {"yaw","f","gain"},
  [26] = {"yaw","cw","gain"},
  [27] = {"yaw","ccw","gain"},
  [28] = {"yaw","cyclic","ff"},
  [29] = {"yaw","collective","ff"},
  [30] = {"yaw","collective","dyn"},
  [31] = {"yaw","collective","decay"},
  [32] = {"pitch","collective","ff"},
  [33] = {"pitch","gyro","cutoff"},
  [34] = {"roll","gyro","cutoff"},
  [35] = {"yaw","gyro","cutoff"},
  [36] = {"pitch","dterm","cutoff"},
  [37] = {"roll","dterm","cutoff"},
  [38] = {"yaw","dterm","cutoff"},
  [39] = {"rescue","climb","collective"},
  [40] = {"rescue","hover","collective"},
  [41] = {"rescue","hover","alt"},
  [42] = {"rescue","alt","p","gain"},
  [43] = {"rescue","alt","i","gain"},
  [44] = {"rescue","alt","d","gain"},
  [45] = {"angle","level","gain"},
  [46] = {"horizon","level","gain"},
  [47] = {"acro","gain"},
  [48] = {"gov","gain"},
  [49] = {"gov","p","gain"},
  [50] = {"gov","i","gain"},
  [51] = {"gov","d","gain"},
  [52] = {"gov","f","gain"},
  [53] = {"gov","tta","gain"},
  [54] = {"gov","cyclic","ff"},
  [55] = {"gov","collective","ff"},
  [56] = {"pitch","b","gain"},
  [57] = {"roll","b","gain"},
  [58] = {"yaw","b","gain"},
  [59] = {"pitch","o","gain"},
  [60] = {"roll","o","gain"},
  [61] = {"crossc","gain"},
  [62] = {"crossc","ratio"},
  [63] = {"crossc","cutoff"},
  [64] = {"acc","pitch","trim"},
  [65] = {"acc","roll","trim"},
  [66] = {"yaw","inertia","precomp","gain"},
  [67] = {"yaw","inertia","precomp","cutoff"},
  [68] = {"pitch","setpoint","boost","gain"},
  [69] = {"roll","setpoint","boost","gain"},
  [70] = {"yaw","setpoint","boost","gain"},
  [71] = {"collective","setpoint","boost","gain"},
  [72] = {"yaw","dyn","ceiling","gain"},
  [73] = {"yaw","dyn","deadband","gain"},
  [74] = {"yaw","dyn","deadband","filter"},
  [75] = {"yaw","precomp","cutoff"},
}

-- State
local adjfuncAdjValueSrc = nil
local adjfuncAdjFunctionSrc = nil
local adjfuncAdjValue = nil
local adjfuncAdjFunction = nil
local adjfuncAdjValueOld = nil
local adjfuncAdjFunctionOld = nil
local adjfuncAdjTimer = os.clock()
local adjfuncAdjfuncIdChanged = false
local adjfuncAdjfuncValueChanged = false
local adjfuncAdjJustUp = false
local adjfuncAdjJustUpCounter
local adjfuncPendingFuncAnnounce = false
local adjfuncPendingFuncAnnounce = false -- new sticky flag


function adjfunc.wakeup()
  local now = os.clock()
  local events = rfsuite.preferences and rfsuite.preferences.events
  if not (events and (events.adj_f or events.adj_v)) then return end
  if (now - initTime) < 5 then return end

  adjfuncAdjValue = rfsuite.tasks.telemetry.getSensor("adj_v")
  adjfuncAdjFunction = rfsuite.tasks.telemetry.getSensor("adj_f")
  if adjfuncAdjValue == nil or adjfuncAdjFunction == nil then return end

  if type(adjfuncAdjValue) == "number" then
    adjfuncAdjValue = adjfuncAdjValue - (adjfuncAdjValue % 1)
  end
  if type(adjfuncAdjFunction) == "number" then
    adjfuncAdjFunction = adjfuncAdjFunction - (adjfuncAdjFunction % 1)
  end

  adjfuncAdjfuncIdChanged    = (adjfuncAdjFunction ~= adjfuncAdjFunctionOld)
  adjfuncAdjfuncValueChanged = (adjfuncAdjValue ~= adjfuncAdjValueOld)
if adjfuncPendingFuncAnnounce and not firstRun and events.adj_f then
          local wavs = adjWavs[adjfuncAdjFunction]
          if wavs then
            local playFile = rfsuite.utils and rfsuite.utils.playFile
            if playFile then
              for i = 1, #wavs do
                playFile("adjfunctions", wavs[i] .. ".wav")
              end
            end
            adjfuncPendingFuncAnnounce = false
            adjfuncAdjfuncIdChanged = false
          end
        end
        if adjfuncAdjfuncIdChanged then adjfuncPendingFuncAnnounce = true end
  if adjfuncAdjfuncIdChanged then adjfuncPendingFuncAnnounce = true end

  if adjfuncAdjJustUp == true then
    adjfuncAdjJustUpCounter = (adjfuncAdjJustUpCounter or 0) + 1
    adjfuncAdjfuncIdChanged = false
    adjfuncAdjfuncValueChanged = false
    if adjfuncAdjJustUpCounter == 10 then adjfuncAdjJustUp = false end
  else
    if adjfuncAdjFunction ~= 0 then
      adjfuncAdjJustUpCounter = 0
      if (now - adjfuncAdjTimer) >= 2 then
        if adjfuncPendingFuncAnnounce and not firstRun and events.adj_f then
          local wavs = adjWavs[adjfuncAdjFunction]
          if wavs then
            local playFile = rfsuite.utils and rfsuite.utils.playFile
            if playFile then
              for i = 1, #wavs do
                playFile("adjfunctions", wavs[i] .. ".wav")
              end
            end
            adjfuncPendingFuncAnnounce = false
          end
        end

        if adjfuncAdjfuncValueChanged or adjfuncAdjfuncIdChanged then
          if (adjfuncAdjValue ~= nil) and (not firstRun) and events.adj_v then
            if system and system.playNumber then system.playNumber(adjfuncAdjValue) end
          end
          adjfuncAdjfuncValueChanged = false
          firstRun = false
        end

        adjfuncAdjTimer = now
      end
    end
  end

  adjfuncAdjValueOld = adjfuncAdjValue
  adjfuncAdjFunctionOld = adjfuncAdjFunction
end

return adjfunc
