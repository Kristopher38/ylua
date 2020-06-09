local maxI = math.maxinteger
local minI = math.mininteger

do
  -- for very long moves, just check initial accesses and interrupt
  -- move with an error
  local function checkmove (f, e, t, x, y)
    local pos1, pos2
    local a = setmetatable({}, {
                __index = function (_,k) pos1 = k end,
                __newindex = function (_,k) pos2 = k; error() end, })
    local st, msg = pcall(table.move, a, f, e, t)
    print(st, msg, pos1, pos2)
    assert(not st and not msg and pos1 == x and pos2 == y)
  end
  checkmove(1, maxI, 0, 1, 0)
  checkmove(0, maxI - 1, 1, maxI - 1, maxI)
  checkmove(minI, -2, -5, -2, maxI - 6)
  checkmove(minI + 1, -1, -2, -1, maxI - 3)
  checkmove(minI, -2, 0, minI, 0)  -- non overlapping
  checkmove(minI + 1, -1, 1, minI + 1, 1)  -- non overlapping
end