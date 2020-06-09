a, e = 1, 1
function foo(b)
    return function(c) local d = a+b+c e = e * 2 return d end
end

assert(foo(5)(6)==12)
assert(e==2)
assert(foo(2)(3)==6)
assert(e==4)

function alias()
    return foo
end

assert(alias()(100)(200)==301)
assert(e==8)
assert(alias()(3)(4)==8)
assert(e==16)

u, v = 3, 5
function p()
    u = 1
    local function q()
        return v
    end
    v = q() + 2
end

p()
assert(v==7)
assert(u==1)