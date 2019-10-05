a = 1
function foo(b)
    return function(c) local d = a+b+c return d end
end

print(foo(2)(3))

function alias()
    return foo
end

print(alias()(3)(4))