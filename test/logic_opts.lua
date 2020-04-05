-- TESTSET
local a,b,c
c = a and b
assert(c==nil)
c = a or b
assert(c==nil)

a,b = 3, 5
c = not a 
assert(c == false)
c = a and b
assert(c == 5)
c = a or b
assert(c == 3)

-- TEST
a,b = false, 3
if a or b then
    assert(true)
else
    assert(false)
end
if a and b then
    assert(false)
else
    assert(true)
end