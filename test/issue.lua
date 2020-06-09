-- fixed-point operator
Z = function (le)
    local function a (f)
        return le(
            function (x) 
                return f(f)(x) 
            end
        )
    end
    return a(a)
end


-- non-recursive factorial

F = function (g)
    return function (n)
        if n == 0 then 
            return 1
        else 
            return n*g(n-1) 
        end
    end
end

fat = Z(F)
assert(fat(0) == 1 and fat(4) == 24 and Z(F)(5)==5*Z(F)(4))