-- small bug

local t = {nil, "return ", "3"}
f, msg = load(function () return table.remove(t, 1) end)
assert(f() == nil)   -- should read the empty chunk