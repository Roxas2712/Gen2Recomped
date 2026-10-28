-- Guest-frame deadlines, independent of display refresh. By Roxas2712.
local M={PERIOD=280896/16777216,MAX_DEBT=.25}
function M.advance(deadline,completed)
 local scheduled=deadline+M.PERIOD
 local reset=completed-M.MAX_DEBT
 return math.max(scheduled,reset),math.max(0,reset-scheduled)
end
return M
