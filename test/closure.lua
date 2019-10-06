a = 1
function foo(b)
    return function(c) local d = a+b+c return d end
end

assert(foo(5)(6)==12,"ok")
print(foo(2)(3))

function alias()
    return foo
end
assert(alias()(100)(200)==301,"ok")
print(alias()(3)(4))