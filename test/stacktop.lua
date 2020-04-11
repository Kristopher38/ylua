local a = {}

function f() return 1,2,30,4 end
function ret2 (a,b) return a,b end

local a,b
a,b = ret2(f())
assert(a==1)
assert(b==2)