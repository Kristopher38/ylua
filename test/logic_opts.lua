local a,b,c
c = a and b
assert(c==nil)
c = a or b
assert(c==nil)
a,b,c = 1,2,4
local d = not a 
assert(d == false)
d = a and b
a,b = 3, 5
d = a and b
assert(d == 5)
d = a or b
assert(d == 3) 
print(a,b,c,d)