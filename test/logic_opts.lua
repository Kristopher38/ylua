local a,b,c
c = a and b
assert(c==nil)
c = a or b
assert(c==nil)
a,b,c = 1,2,4
local d = not a 
assert(d == false)
d = a and b
assert(d==1)
d = a or b
assert(d==2)
print(a,b,d)